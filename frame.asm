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
tableWidth db 50

.code
org 100h

start:
    call drawFrame
    call drawTextMessage

;     mov cx, 5
;     drawTableFormat:
;         ; mov ax, TableFormat
;         mov si, cx
;         lea bx, TableFormat
;         mov al, bx[si-1]
;         mov ah, 4Eh
;         push bx
;         push cx
;         add cx, 37  ; col index
;         mov bx, 20 ; row index
;         call drawSymbol
;         pop cx
;         pop bx
;
;         loop drawTableFormat

    mov ax, 4c00h
    int 21h

; Draws frame of table
; Entry: None
; Exit : None
; Destr: si, ax, bx
drawFrame   proc
    mov si, 0

    ; draw first line
    mov bx, 10
    push bx ; save bx
    call drawLine
    pop bx ; restore bx
    inc bx ; move to the next row
    add si, 3 ; change output style of first, middle, last char

    mov cx, 10 - 2 ; height of table - 2 (first and last rows)
    rowsCycle:
        push cx ; save cx

        push bx ; save bx
        call drawLine
        pop bx ; restore bx

        inc bx ; move to the next row
        pop cx ; restore cx
        loop rowsCycle

    add si, 3 ; change output style of first, middle, last char
    ; draw last line
    push bx ; save bx
    call drawLine
    pop bx ; restore bx

    ret
    endp



; Draws line of code
; Entry: SI = startIndex of beginning char
;        BX = row
; Exit :
; Destr: ax, bx, cx
drawLine    proc
    push cx ; save cx

    ; draw ending char
    push bx ; save bx
    lea bx, TableFormat
    mov al, bx[si + 2]
    mov ah, 4Eh
    lea bx tableWidth
    mov cx, [tableWidth] - 1 ; col position
    pop bx ; restore bx
    call drawSymbol

    mov cx, 40 - 2          ; cycle through all rows (40 - 2 times)
    colsCycle:
        push cx ; save cx
        ; draw middle char
        push bx ; save bx
        lea bx, TableFormat
        mov al, bx[si + 1]
        mov ah, 4Eh
        pop bx ; restore bx
        call drawSymbol
        pop cx
        push cx ; save cx
        call drawSymbol

        pop cx ; restore cx
        loop colsCycle

    ; draw beginning char
    push bx ; save bx
    lea bx, TableFormat ; TODO: copypaste
    mov al, bx[si]
    mov ah, 4Eh
    mov cx, 0 ; col position
    pop bx ; restore bx
    call drawSymbol

    pop cx ; restore cx

    ret
    endp



drawTextMessage     proc
    ; hardcoded len = 23, offset = 5
    mov cx, 23
    charLoop:
        push cx ; save cx

        mov si, cx
        lea bx, TextMessage
        mov al, bx[si - 1]
        mov ah, 4Eh
        add cx, 5   ; col pos
        mov bx, 15  ; row pos
        call drawSymbol
        pop cx ; restore cx
        loop charLoop

    ret
    endp


; Draws one symbol in video memory
; Entry: AL = letter code;
;        AH = color attr;
;        CX = col position
;        BX = row position
; Exit : None
; Destr: bx, es
; TODO: refactor with stack
drawSymbol  proc
    push bx ; save bx
    push ax ; save ax

    push bx
    mov bx, 0b800h   ; memory addr where video memory begins
    mov es, bx
    pop bx

    ; bx = rowPos(bx) * 80 * 2 + colPos(cx) * 2
    ; rowPos is already in stack
    mov ax, 80 * 2 ; double screen width
    mul bx
    mov bx, ax

    mov ax, 2
    mul cx
    add bx, ax

    pop ax ; restore orig value of ax
    mov es:[bx], ax
    pop bx ; restore orig value of bx

    ret
    endp

end start


