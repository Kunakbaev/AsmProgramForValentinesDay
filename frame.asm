.model tiny



; -----------------------------------------------
;                       DATA
; -----------------------------------------------


.data


; contains all possible formats for frame
FrameStyles                 db 201, 205, 187, 186, 32, 186, 200, 205, 188 ; double edge
                            db 218, 196, 191, 179, 32, 179, 192, 196, 217 ; single edge
                            db '123456789'                                ; for debug purposes
                            db '#-#| |#-#'
CurrentFrameStyle           db 9 dup(?)
TextMessage                 db 'I am so stupid and dumb'                  ; message that is shown in the middle of table
backgroundColor             db 1 dup(?)                                   ; Is it ok to store just one byte in memory?

VIDEO_MEMORY_ADDR           equ 0b800h
EXIT_CODE                   equ 4c00h
COMMAND_LINE_MEMORY_ADDR    equ 80h
TEXT_MESSAGE_COLOR_ATTR     equ 3Fh
SCREEN_WIDTH                equ 80
STYLE_STRING_LEN            equ 9
STYLE_STRING_ONE_ROW_LEN    equ 3



.code
org 100h

start:
    cld  ; just in case, we need si += 1 during lodsb
    call extractArgsFromCommandLine
    call drawFrameAndMessage

    mov ax, 4c00h
    int 21h


; turns string into number (base = 10)
; Entry : SI - address of string to process
;         CX - len of input string
; Exit  : BX - result
; Destr : AL
atoiBase10      proc
    mov bx, 0
    digitCycle:
        push cx         ; save CX

        ; BX *= 10
        mov cx, bx
        shl bx, 3       ; BX *= 8
        add bx, cx
        add bx, cx

        xor ax, ax      ; AX = 0
        lodsb           ; load current char to AL
        add bx, ax
        sub bx, '0'

        pop cx
        loop digitCycle

    ret
    endp


; ASK: copypaste?
; turns string into number (base = 16)
; Entry : SI - address of string to process
;         CX - len of input string
; Exit  : BX - result
; Destr : AL
atoiBase16      proc
    mov bx, 0
    digitHexCycle:
        push cx         ; save CX

        ; BX *= 16
        shl bx, 4

        xor ax, ax      ; AX = 0
        lodsb           ; load current char to AL
        add bx, ax

        cmp al, 'A' ; FIXME:
        jge letterChar
            sub bx, '0'
            jmp ifEnd
        letterChar:
            add bx, 10
            sub bx, 'A'
        ifEnd:

        pop cx
        loop digitHexCycle

    ret
    endp



; reads bytes from DI till space (reads no more than CX chars),
;    saves leftLen in AX, than stores len of read word in cx
; Entry : DI - memory address where text message lies
;         AL - char untill which we parse
; Exit  : CX - read word len
;         DI - symbol AFTER space
;         SI - starting position
;         AL - left command line len
; Destr : None
parseSymbolsTillChar       proc
    mov si, di  ; save previous char position
    repne scasb ; search for the next space (end of word)
    mov ax, cx  ; save left command line len
    mov cx, di
    sub cx, si  ; store len of word in cx
    dec cx

    ret
    endp

; ASK: cringe?
; Exit  : AL - left command line lne
parseSymbolsTillSpace       proc
    mov al, ' '
    call parseSymbolsTillChar

    ret
    endp

; Exit  : AL - left command line lne
parseQuotedWord     proc
    mov al, "'" ;
    inc di          ; skip quoted symbol
    dec cx
    call parseSymbolsTillChar
                    ; di points to space
    ; dec cx          ; -1 because of quote symbol
    inc di          ; skip space symbol
    dec ax

    ret
    endp

; Loads chosen frame styel to CurrentFrameStyle
; if index = 0, reads style from command line
; Entry : BX - style index
;         CX - command line len
; Exit  : CX - new command line len
decideFrameStyle        proc
    push cx ; save cx
    cmp bx, 0
    je userInputFrameStyle
        mov si, offset FrameStyles

        mov cx, bx
        dec cx
        bruh:
            add si, STYLE_STRING_LEN
            loop bruh

        push di ; save di
        mov cx, STYLE_STRING_LEN
        mov di, offset CurrentFrameStyle
        rep movsb
        pop di  ; restore  di
        pop cx
        jmp inputStyleIfEnd

    userInputFrameStyle:
        pop cx
        call parseQuotedWord
        push ax
        ; push ax
        push di ; save di
                ; si points to beginning of user's style
        mov di, offset CurrentFrameStyle
        mov cx, STYLE_STRING_LEN
        rep movsb

        pop di  ; restore di
        pop cx  ; restore command line len
    inputStyleIfEnd:


    ret
    endp

; command line args format:
;       height, width, color of frame (in HEX), frameStyleIndex
; Entry : None
; Exit  : BX - height of frame
;         DX - width  of frame
;         AH - color of frame
;         SI - memory address where text message lies
;         CX - text message len
; Destr :
extractArgsFromCommandLine      proc
    mov si, COMMAND_LINE_MEMORY_ADDR        ; memory address where command line len lies
    xor cx, cx                              ; cx = 0
    mov cl, [si]                            ; load command line len to cx
    mov di, COMMAND_LINE_MEMORY_ADDR + 2    ; memory address where command line string lies (at 81h lies space)
    push ds
    pop es

    ; -------------------------------------------------------
    ; count len of height word and store it in cx
    call parseSymbolsTillSpace
    push ax

                        ; transform height string to integer
    call atoiBase10
    pop cx              ; restore command line len
    push bx             ; save bx (height)

    ; -------------------------------------------------------
    ; count len of width word and store it in cx
    call parseSymbolsTillSpace
    push ax

    ; transform width string to integer
    call atoiBase10
    pop cx              ; restore command line len
    mov dx, bx          ; store width of frame

    ; -------------------------------------------------------
    ; count len of background color word (it's always eq 2, but we need to move di) and store it in cx
    call parseSymbolsTillSpace
    push ax

    ; transform width string to integer
    call atoiBase16
    pop cx              ; restore command line len
    mov byte ptr backgroundColor, bl

    ; -------------------------------------------------------
    ; count len of style index word and store it in cx
    call parseSymbolsTillSpace
    push ax             ; save command line len

    ; transform style index string to integer
    call atoiBase10
    pop  cx             ; restore command line len
    call decideFrameStyle

    pop bx              ; restore bx (height)

    ; -------------------------------------------------------
    call parseQuotedWord

    ret
    endp

; Entry : DI, address of string
; Exit  : DI, centered position of string
; Destr : AX
centerMessagePosition       proc
    ; center text by y coord
    push dx ; save dx, destroyed during mul
    mov di, bx
    shr di, 1 ; di = bx / 2, we want to place text message in the middle row
    add di, 2 ; if height is odd, we want center line, also lines are numbered in one indexation
    mov ax, 2 * SCREEN_WIDTH
    mul di
    mov di, ax

    ; center text by x coord
    pop dx
    mov ax, dx
    sub ax, cx
    shr ax, 1 ; round to the even number
    shl ax, 1
    add di, ax

    ret
    endp

; Draws frame and puts text message
; Entry : BX, DX - height and width of frame
;       : CX - len of text message
;       : SI - memory address where text message lies
; Exit  : None
; Destr :
drawFrameAndMessage     proc
    push si                        ; save address of message si
    push cx                        ; save text message len
    call drawFrame
    pop  cx                        ; restore len
    pop  si                        ; restore si (address)

    push VIDEO_MEMORY_ADDR         ; set memory segment to video memory
    pop  es

    call centerMessagePosition

    xor ax, ax
    mov ah, TEXT_MESSAGE_COLOR_ATTR         ; set color attribute
    call drawTextMessage

    ret
    endp

; Draws frame of table
; Entry: None
; Exit : None
; Destr: si, ax, bx
drawFrame   proc
    push bx ; save frame height
    mov bx, VIDEO_MEMORY_ADDR
    mov es, bx ; set memory segment to video memory
    ; cld df ; just in case, we need si += 1 during lodsb
    push dx;
    mov si, offset CurrentFrameStyle ; save CurrentFrameStyle string address to SI
    mov ah, backgroundColor ; set color attribute
    pop dx


    ; draw first line of frame
    mov di, 2 * 2 * SCREEN_WIDTH ; move video memory pointer to the 2th line
    mov cx, dx ; TODO: hardcoded, frame width
    call drawLine
    add di, 2 * SCREEN_WIDTH ; move video memory pointer to the next line
    add si, STYLE_STRING_ONE_ROW_LEN

    pop bx ; restore height
    mov cx, bx ; hardcoded, frame height
    dec cx ; cx -= 2, height - 2 (because first and last rows are already considered)
    dec cx
    cycleThroughRows:
        push cx ; save cx

        ; lea si, TableFormat + 3
        mov cx, dx ; TODO: hardcoded, frame width
        call drawLine
        add di, 2 * SCREEN_WIDTH ; move video memory pointer to the next line

        pop cx ; restore cx
        loop cycleThroughRows

    add si, STYLE_STRING_ONE_ROW_LEN
    ; draw last line of frame
    mov cx, dx
    call drawLine

    ret
    endp

; Draws line of code
; Entry: AH = color attribute
;        DS:SI = address of style string sequence
;        ES:DI = address in video memory where to begin drawing line
;        CX = frame width
; Require: DF (direction flag) = 0
; Exit :
; Destr:
drawLine    proc
    push di ; save di
    push si ; save si

                                ; add di, 2 * 10 ; x coord offset
                                ; draws first symbol of row
    lodsb                       ; puts beginning style character to AL
    mov es:[di], ax             ; saves char with color to video memory
    add di, 2                   ; move col position

    lodsb                       ; puts middle style character to AL
    sub cx, 2                   ; number of chars in the middle = width - 2 (first and last characters)
    cycleThroughCols:
        mov es:[di], ax         ; save char with color attr to video memory
        add di, 2               ; move col position
        loop cycleThroughCols

                                ; draws last symbol of row
    lodsb                       ; puts ending style character to AL
    mov es:[di], ax             ; saves char with color to video memory
    add di, 2                   ; move col position

    pop si                      ; restore si (can be changed to -3 = number of lodsb)
    pop di                      ; restore di
    ret
    endp

; Draws text message
; Entry: AH = color attribute
;        DS:SI = address of message string
;        ES:DI = address in video memory where to begin drawing text
;        CX = line length
; Require: DF (direction flag) = 0
; Exit :
; Destr:
drawTextMessage     proc
    push di                 ; save di
    push si                 ; save si

    charLoop:
        lodsb               ; load char from message to al
        mov es:[di], ax     ; save char with color attr to video memory
        add di, 2           ; move col position
        loop charLoop

    pop si                  ; restore si
    pop di                  ; restore di
    ret
    endp

end start

/*

https://av-assembler.ru/instructions/mul.php

*/
