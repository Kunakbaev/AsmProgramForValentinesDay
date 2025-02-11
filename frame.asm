.model tiny



; -----------------------------------------------
;                       DATA
; -----------------------------------------------


.data


; TableFormat: db '123456789' ; for debug purposes
; TableFormat: db '�Ŀ� ����'; single edge
; TableFormat db 218, 196, 191, 179, 32, 179, 192, 196, 217 ; single edge
TableFormat db 201, 205, 187, 186, 32, 186, 200, 205, 188 ; double edge
TextMessage db 'I am so stupid and dumb'                  ; message that is shown in the middle of table
tableWidth  db 50

.code
org 100h

start:
    call drawFrameAndMessage

    mov ax, 4c00h
    int 21h

drawFrameAndMessage     proc
    call drawFrame

    mov bx, 0b800h
    mov es, bx ; set memory segment to video memory
    mov ah, 5Dh ; set color attribute
    ; cld df ; just in case, we need si += 1 during lodsb
    mov di, 15 * 2 * 80
    mov cx, 23 ; text message len
    lea si, TextMessage ; save TextMessage string address to SI
    mov cx, [80h]
    mov si, 81h
    call drawTextMessage

    ret
    endp

; Draws frame of table
; Entry: None
; Exit : None
; Destr: si, ax, bx
drawFrame   proc
    mov bx, 0b800h
    mov es, bx ; set memory segment to video memory
    mov ah, 4Eh ; set color attribute
    ; cld df ; just in case, we need si += 1 during lodsb
    lea si, TableFormat ; save TableFormat string address to SI

    ; draw first line of frame
    mov di, 10 * 2 * 80 ; move video memory pointer to the 10th line
    mov cx, 40 ; TODO: hardcoded, frame width
    call drawLine
    add di, 2 * 80 ; move video memory pointer to the next line
    add si, 3

    mov cx, 10 - 2 ; hardcoded, frame height
    cycleThroughRows:
        push cx ; save cx

        ; lea si, TableFormat + 3
        mov cx, 40 ; TODO: hardcoded, frame width
        call drawLine
        add di, 2 * 80 ; move video memory pointer to the next line

        pop cx ; restore cx
        loop cycleThroughRows

    add si, 3
    ; draw last line of frame
    ; lea si, TableFormat + 6
    mov cx, 40 ; TODO: hardcoded, frame width
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

    add di, 2 * 10 ; x coord offset
    ; draws first symbol of row
    lodsb ; puts beginning style character to AL
    mov es:[di], ax ; saves char with color to video memory
    add di, 2 ; move col position

    lodsb ; puts middle style character to AL
    sub cx, 2 ; number of chars in the middle = width - 2 (first and last characters)
    cycleThroughCols:
        mov es:[di], ax ; save char with color attr to video memory
        add di, 2 ; move col position
        loop cycleThroughCols

    ; draws lasty symbol of row
    lodsb ; puts ending style character to AL
    mov es:[di], ax ; saves char with color to video memory
    add di, 2 ; move col position

    pop si ; restore si (can be changed to -3 = number of lodsb)
    pop di ; restore di
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

    add di, 2 * 20 ; x coord offset
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

