.model tiny
.286
.code
org 100h
locals @@

KEY_NUM_MINUS       equ 74
KEY_NUM_PLUS        equ 78
COUNT_OF_DIGIT      equ 10
COUNT_MIDDLE_SIMBOL equ 7
NEXT_LINE_OFFSET    equ 71 * 2 ; 9 символов в строке занимает рамка, всево в строке 80 символов, 80 - 9 = 71
                               ; * 2 т.к. 1 символ занимает 2 байта(сам символ и его цвет)
UP_LEFT_SIMBOL          equ '/'
UP_RIGHT_SIMBOL         equ '\'
DOWN_LEFT_SIMBOL        equ '\'
DOWN_RIGHT_SIMBOL       equ '/'
VERTICAL_LEFT_SIMBOL    equ '|'
VERTICAL_RIGHT_SIMBOL   equ '|'
HORIZONTAL_UP_SIMBOL    equ '-'
HORIZONTAL_DOWN_SIMBOL  equ '-'

Start: jmp Main

New09 PROC
    push ax ; save reg

    in al, 60h
    cmp al, KEY_NUM_MINUS
    jne @@next ; if pres button on numpud '-'
        mov word ptr cs:[offset drowable], 0 ; drowable = false

        jmp @@end_interapt

    @@next:
    cmp al, KEY_NUM_PLUS
    jne @@end ; else if pres button on numpud '+'
        mov word ptr cs:[offset drowable], 0101h ; drowable = true
        
        jmp @@end_interapt

    @@end:

    pop ax ; return reg

    db 0eah     ; jmp to original 09
old9ofs: dw 0
old9seg: dw 0

@@end_interapt:
    in al, 61h      ; blink keybourd controller (61h - keybourd controller)
    or al, 80h      ; 80h = 1000 0000
    out 61h, al
    and al, not 80h ; not 80h = 0111 1111
    out 61h, al
    mov al, 20h     ; interapt end
    out 20h, al

    pop ax ; return reg

    iret
New09 ENDP

New08 PROC
    cmp word ptr cs:[drowable], 0 ; check is drowable
    je @@exit                     ; exit if no drowable

    ;jmp @@exit

    push ax es cx dx bx sp bp si di ds ss ; save regs

    call drow_all_frame ; drowe all regs

    pop ss ds di si bp sp bx dx cx es ax ; return regs
@@exit:
    db 0eah             ; jmp to original 08
old8ofs: dw 0
old8seg: dw 0
New08 ENDP


; destroy bx, al;
; need ds:si = get from , es:di = write to
; si += 1, di += 4
write_byte PROC
    lodsb                ; get byte

    xor bx, bx           ; mov byte to bl for not destroy ax(ah)
    mov bl, al

    shl bx, 4            ; 0012 -> 0120
    shr bl, 4            ; 0120 -> 0102
    
    cmp bl, COUNT_OF_DIGIT
    jl @@digit_l         ; if bl >= COUNT_OF_DIGIT
        add bl, 'a' - COUNT_OF_DIGIT ; bl = bl + 'a' - COUNT_OF_DIGIT
        jmp @@end1
    @@digit_l:           ; else
        add bl, '0'      ; bl += '0'
    @@end1:

    cmp bh, COUNT_OF_DIGIT
    jl @@digit_h         ; if bh >= 10
        add bh, 'a' - COUNT_OF_DIGIT ; bh = bh + 'a' - COUNT_OF_DIGIT
        jmp @@end2
    @@digit_h:           ; else
        add bh, '0'      ; bh += '0'
    @@end2:

    mov al, bh           ; write byte
    stosw                ; first symbol
    mov al, bl
    stosw                ; second symbol

    ret
write_byte ENDP

; destroy ax, di += 8
; need di = first symbol in line
; write to buf '|' + name of reg + '=' + reg data(bigending) + '|' 
; need bx = 2 symbol = name of reg, si = ptr to data reg (word)
dump_reg PROC
    mov al, VERTICAL_LEFT_SIMBOL   ; write first symbol of line in frame
    stosw

    mov al, bh    ; get first simbol of name reg
    stosw         ; drow first simbol
    mov al, bl    ; get second simbol of name reg
    stosw         ; drow second simbol

    mov al, '='           ; write '='
    stosw

    call write_byte       ; write first pice of reg
    call write_byte       ; write second pice of reg

    mov al, VERTICAL_RIGHT_SIMBOL   ; write last symbol of line in farme
    stosw

    add di, NEXT_LINE_OFFSET
    ret
dump_reg ENDP

; write first line of frame in videomem
; need di = first symbol in line
; destroy al, cx
; di = first symbol in next line, cx = 0
drow_first_line PROC
    mov al, UP_LEFT_SIMBOL      ; drow first symbol of first line in frame
    stosw

    mov cx, COUNT_MIDDLE_SIMBOL ; count of middle simbol in first line in frame
    mov al, HORIZONTAL_UP_SIMBOL   ; drow middle simbol of first line in frame
    rep
    stosw

    mov al, UP_RIGHT_SIMBOL     ; drow last symbol of first line in farme
    stosw

    add di, NEXT_LINE_OFFSET
    ret
drow_first_line ENDP

; write last line of frame in videomem
; need di = first symbol in line
; destroy al, cx
; out di = first symbol in next line, cx = 0
drow_last_line PROC
    mov al, DOWN_LEFT_SIMBOL    ; drow first symbol of last line in frame
    stosw

    mov cx, COUNT_MIDDLE_SIMBOL ; count of middle simbol in last line in frame
    mov al, HORIZONTAL_DOWN_SIMBOL   ; drow middle simbol of last line in frame
    rep
    stosw

    mov al, DOWN_RIGHT_SIMBOL   ; drow last symbol of last line in farme
    stosw

    add di, NEXT_LINE_OFFSET
    ret
drow_last_line ENDP

; destroy bx, ds, es, si, di, ax, cx
; need 11 word in stack (register data, ss ds di si bp sp bx dx cx es ax)
; out cx = 0, ah = 5eh
drow_all_frame PROC
    mov bx, ss         ; set ds to get reg from
    mov ds, bx

    mov bx, sp         ; set ptr to get reg from
    add bx, 2          ; offset + 2 byte (because call drow_all_frame)
    mov si, bx         ; set si to from ptr

    mov bx, 0b800h     ; 0b800h - ptr to videomem
    mov es, bx         ; set es to videomem
    xor di, di         ; set ptr to begin of videomem

    mov ah, 5eh        ;set dump color

    call drow_first_line  ; drow first line of frame
    
    ; Далее нужно сделать столькоже вызовов функции dump_reg, сколько регистров вы добавили в стек.
    ; Регистры будут выведены в последоваельности в которой вы их добавили в стек.
    ; Перед каждым вызовом функции dump_reg, нужно в регистрок bx положить название соответствующего регистра который будет выведен.
    mov bx, 'SS'       ; save name to reg
    call dump_reg      ; write reg to buf

    mov bx, 'DS'
    call dump_reg

    mov bx, 'DI'
    call dump_reg

    mov bx, 'SI'
    call dump_reg

    mov bx, 'BP'
    call dump_reg

    mov bx, 'SP'
    call dump_reg

    mov bx, 'BX'
    call dump_reg

    mov bx, 'DX'
    call dump_reg

    mov bx, 'CX'
    call dump_reg

    mov bx, 'ES'
    call dump_reg

    mov bx, 'AX'
    call dump_reg

    call drow_last_line ; drow last line of frame

    ret
drow_all_frame ENDP

drowable:
    db 2 DUP(1)
swap_byte_buffer:
    db 0
ProgramEnd:

Main:
    cli
    xor bx, bx
    mov ds, bx  ; set ds to interupt segment

    mov bx, cs  ; set es to code segment
    mov es, bx

    mov bx, 8d * 4d         ; bx = ptr to get  int 08 jmp addres
    mov di, offset old8ofs  ; di = ptr to save int 08 jmp addres

    mov ax, [bx]         ; save int 08 offset
    stosw

    mov ax, [bx + 2]     ; save int 08 segment
    stosw

    mov [bx], offset New08 ; vrite to int 08 jmp, new 08 offset and new 08 segment
    mov [bx + 2], cs


    mov bx, 9d * 4d          ; bx = ptr to get  int 09 jmp addres
    mov di, offset old9ofs   ; di = ptr to save int 09 jmp addres

    mov ax, [bx]          ; save int 09 offset
    stosw

    mov ax, [bx + 2]      ; save int 09 segment
    stosw

    mov [bx], offset New09 ; vrite to int 09 jmp, new 09 offset and new 09 segment
    mov [bx + 2], cs
    sti

    mov dx, offset ProgramEnd  ; calc how mach segment save
    shr dx, 4                  ; 4 -> 2^4 = 16, 16 byte in one segment
    inc dx                     ; +1 -> ceil

    mov ax, 3100h ; exit with save program in memory
    int 21h
end start
