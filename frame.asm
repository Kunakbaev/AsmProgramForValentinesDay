.model tiny



; -----------------------------------------------
;                       DATA
; -----------------------------------------------


.data


; contains all possible formats for frame
FrameStyles         db 201, 205, 187, 186, 32, 186, 200, 205, 188 ; double edge
                    db 218, 196, 191, 179, 32, 179, 192, 196, 217 ; single edge
                    db '123456789'                                ; for debug purposes
CurrentFrameStyle   db 9 dup(?)
TextMessage         db 'I am so stupid and dumb'                  ; message that is shown in the middle of table
templateString      db '10  '

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
        shl bx, 3       ; mul by 8
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

; reads bytes from DI till space (reads no more than CX chars),
;    saves leftLen in AX, than stores len of read word in cx
; Entry : DI - memory address where text message lies
; Exit  : CX - read word len
;         DI - symbol AFTER space
;         SI - starting position
; Destr : AL
parseSymbolsTillSpace       proc
    mov al, ' ' ; char that we search
    mov si, di  ; save previous char position
    repne scasb ; search for the next space (end of word)
    mov ax, cx  ; save left command line len
    mov cx, di
    sub cx, si  ; store len of word in cx
    dec cx

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
    mov si, 80h         ; memory address where command line len lies
    xor cx, cx          ; cx = 0
    mov cl, [si]        ; load command line len to cx
    mov di, 82h         ; memory address where command line string lies (at 81h lies space)
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
    ; count len of style index word and store it in cx
    call parseSymbolsTillSpace
    push ax

    ; transform style index string to integer
    call atoiBase10
    mov si, offset FrameStyles

    mov cx, bx
    dec cx
    ;add si, di
    bruh:
        add si, 9
        loop bruh

    push di ; save di
    mov cx, 9
    mov di, offset CurrentFrameStyle
    rep movsb
    pop di  ; restore  di


    pop cx              ; restore command line len
    pop bx              ; restore bx (height)

    ; -------------------------------------------------------
    call parseSymbolsTillSpace

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
    add di, 2
    mov ax, 2 * 80
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
    push si             ; save address of message si
    push cx             ; save text message len
    call drawFrame
    pop  cx             ; restore len
    pop  si             ; restore si (address)

    push 0b800h         ; set memory segment to video memory
    pop  es

    call centerMessagePosition

    xor ax, ax
    mov ah, 5Dh         ; set color attribute
    call drawTextMessage

    ret
    endp

; Draws frame of table
; Entry: None
; Exit : None
; Destr: si, ax, bx
drawFrame   proc
    push bx ; save frame height
    mov bx, 0b800h
    mov es, bx ; set memory segment to video memory
    ; cld df ; just in case, we need si += 1 during lodsb
    push dx;
    mov si, offset CurrentFrameStyle ; save CurrentFrameStyle string address to SI
    mov ah, 4Ah ; set color attribute
    pop dx


    ; draw first line of frame
    mov di, 2 * 2 * 80 ; move video memory pointer to the 2th line
    mov cx, dx ; TODO: hardcoded, frame width
    call drawLine
    add di, 2 * 80 ; move video memory pointer to the next line
    add si, 3

    pop bx ; restore height
    mov cx, bx ; hardcoded, frame height
    dec cx ; cx -= 2, height - 2 (because first and last rows are already considered)
    dec cx
    cycleThroughRows:
        push cx ; save cx

        ; lea si, TableFormat + 3
        mov cx, dx ; TODO: hardcoded, frame width
        call drawLine
        add di, 2 * 80 ; move video memory pointer to the next line

        pop cx ; restore cx
        loop cycleThroughRows

    add si, 3
    ; draw last line of frame
    ; lea si, TableFormat + 6
    mov cx, dx ; TODO: hardcoded, frame width
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
    push di ; save di
    push si ; save si

    charLoop:
        lodsb ; load char from message to al
        mov es:[di], ax ; save char with color attr to video memory
        add di, 2 ; move col position
        loop charLoop

    pop si ; restore si
    pop di ; restore di
    ret
    endp

end start

/*

https://av-assembler.ru/instructions/mul.php

*/
