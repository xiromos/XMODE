;=======================================================
;output functions for user programs
;Copyright (C) 2026 Technodon
;0x30
;AH = 0x01: print colored string
;   ESI: pointer to null-terminated string
;   EBX: color (0x00RRGGBB)
;AH = 0x02: print a single character
;   AL: character
;   EBX: color (0x00RRGGBB)
;AH = 0x03: newline
;AH = 0x04: print decimal number
;   EBX: number
;=======================================================

output_handler:
    pusha
    cmp ah, 0x01
    je .print_string
    cmp ah, 0x02
    je .print_char
    cmp ah, 0x03
    je .print_newline
    cmp ah, 0x04
    je .print_dec
    popa
    iret
.print_string:
    mov [color], ebx
    lodsb
    cmp al, 0
    je .done_print
    call print_char
    jmp .print_string
.done_print:
    popa
    iret

.print_char:
    mov [color], ebx
    cmp al, 0x0a
    je .newline

    call draw_char
    add dword [cur_x], 8
    cmp dword [cur_x], width
    jae .newline
    jmp .done
.newline:
    mov dword [cur_x], 0
    add dword [cur_y], 16    ;font is 8x16
    cmp dword [cur_y], height
    jae .scroll
.done:
    popa
    iret
.scroll:
    call scroll
    mov dword [cur_y], height - 16
    jmp .done

.print_newline:
    mov dword [cur_x], 0
    add dword [cur_y], 16
    cmp dword [cur_y], height
    jae .scroll
    popa
    iret
.print_dec:
    mov eax, ebx
    xor ecx, ecx
    mov ebx, 10
.div_loop:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    cmp eax, 0
    jne .div_loop
.print_loop:
    pop eax
    add al, '0'
    mov ebx, 0x00ffffff
    call print_char
    loop .print_loop
    popa
    iret