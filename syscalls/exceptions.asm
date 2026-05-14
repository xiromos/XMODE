int0x0:
    pusha
    mov ebx, [cur_x]
    mov ecx, [cur_y]
    push ebx
    push ecx

    mov dword [cur_x], 0
    mov dword [cur_y], 0
    mov edx, [color]

    push edx
    mov dword [color], 0x00a60808
    mov al, '0'
    call print_char
    pop edx

    mov [color], edx
    pop ecx
    pop ebx
    mov [cur_y], ecx
    mov [cur_x], ebx
    popa
    add dword [esp], 1
    iret

int0x6:
    pusha
    mov ebx, [cur_x]
    mov ecx, [cur_y]
    push ebx
    push ecx

    mov dword [cur_x], 0
    mov dword [cur_y], 0
    mov edx, [color]

    push edx
    mov dword [color], 0x00a60808
    mov ebx, [color]
    mov al, '6'
    call print_char
    pop edx

    mov [color], edx
    pop ecx
    pop ebx
    mov [cur_y], ecx
    mov [cur_x], ebx
    popa
    add dword [esp], 2
    ;call kill_processes
    iret

int0x08:
    pusha
    mov ebx, [cur_x]
    mov ecx, [cur_y]
    push ebx
    push ecx

    mov dword [cur_x], 0
    mov dword [cur_y], 0
    mov edx, [color]

    push edx
    mov dword [color], 0x00a60808
    mov al, '8'
    call print_char
    pop edx

    mov [color], edx
    pop ecx
    pop ebx
    mov [cur_y], ecx
    mov [cur_x], ebx
    popa
    add dword esp, 1
    iret
int0xd:
    pusha
    mov ebx, [cur_x]
    mov ecx, [cur_y]
    push ebx
    push ecx

    mov dword [cur_x], 0
    mov dword [cur_y], 0
    mov edx, [color]

    push edx
    mov dword [color], 0x00a60808       ;red
    mov al, 'D'                         ;0x0d
    call print_char
    pop edx

    mov [color], edx
    pop ecx
    pop ebx
    mov [cur_y], ecx
    mov [cur_x], ebx
    popa
    add esp, 4              ;skip error code
    add dword [esp], 1      ;add EIP 1 to skip instruction
    iret

int0xe:
    pusha
    mov ebx, [cur_x]
    mov ecx, [cur_y]
    push ebx
    push ecx

    mov dword [cur_x], 0
    mov dword [cur_y], 0
    mov edx, [color]

    push edx
    mov dword [color], 0x00a60808
    mov al, 'E'
    call print_char
    pop edx

    mov [color], edx
    pop ecx
    pop ebx
    mov [cur_y], ecx
    mov [cur_x], ebx
    popa
    iret

int_no_err:
    pusha
    mov ebx, [cur_x]
    mov ecx, [cur_y]
    push ebx
    push ecx

    mov dword [cur_x], 0
    mov dword [cur_y], 0
    mov edx, [color]

    push edx
    mov dword [color], 0x00a60808
    mov al, 'X'
    call print_char
    pop edx

    mov [color], edx
    pop ecx
    pop ebx
    mov [cur_y], ecx
    mov [cur_x], ebx
    popa
    iret
int_err:
    pusha
    mov ebx, [cur_x]
    mov ecx, [cur_y]
    push ebx
    push ecx

    mov dword [cur_x], 0
    mov dword [cur_y], 0
    mov edx, [color]

    push edx
    mov dword [color], 0x00a60808
    mov al, 'E'
    call print_char
    pop edx

    mov [color], edx
    pop ecx
    pop ebx
    mov [cur_y], ecx
    mov [cur_x], ebx
    popa
    add dword esp, 4
    iret

irq0_handler:
    push ax
    mov al, 0x20
    out 0x20, al
    pop ax
    iret

irq1_handler:
    push ebx
    in al, 0x60

    cmp al, 0xaa
    je .no_shift
    cmp al, 0xb6
    je .no_shift

    cmp al, 0x80
    jae .done

    cmp al, 0x2a
    je .shift
    cmp al, 0x36
    je .shift
    cmp al, 0xb6
    je .no_shift
    jmp .continue

.shift:
    mov byte [shift], 1
    jmp .done
.no_shift:
    mov byte [shift], 0
    jmp .done
.continue:
    cmp al, 0
    je .done

    cmp byte [shift], 1
    je .get_shift

    movzx ebx, al
    mov al, [scan_codes+ebx]
    jmp .save
.get_shift:
    movzx ebx, al
    mov al, [keymap_shift+ebx]
.save:
    mov ebx, [buf_head]
    mov [key_buffer+ebx], al
    inc ebx
    and ebx, 255
    mov [buf_head], ebx
.done:
    push ax
    mov al, 0x20
    out 0x20, al
    pop ax
.end:
    pop ebx
    iret


keyboard_handler:
    cmp ah, 0
    je .get_key
    iret

.get_key:
    push ebx
.block:
    cli
    mov ebx, [buf_tail]
    mov eax, [buf_head]
    sti

    cmp ebx, eax
    je .sleep
    mov al, [key_buffer+ebx]

    inc ebx
    and ebx, 255
    mov [buf_tail], ebx

    pop ebx
    iret

.sleep:
    hlt
    jmp .block

irq12_handler:
    iret

irq14_handler:
    pusha
    mov byte [dma_done], 1

    ;read IDE status
    mov dx, 0x1f7
    in al, dx

    mov dx, [bm_base4]
    add dx, 2
    in al, dx

    mov al, 0x04
    out dx, al

    mov al, 0x20
    out 0xa0, al
    out 0x20, al
    popa
    iret