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
;=======================================================

output_handler:
    pusha
    cmp ah, 0x01
    je .print_string
    cmp ah, 0x02
    je .print_char
    cmp ah, 0x03
    je .print_newline
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