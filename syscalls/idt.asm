;----IDT----
idt_start:
    times 256 dq 0
.end:
idt_descriptor:
    dw idt_start.end - idt_start
    dd idt_start


set_idt_entry:
    ; eax = handler adress
    ; ebx = interrupt number

    mov word [idt_start + ebx*8 + 0], ax
    mov word [idt_start + ebx*8 + 2], 0x08
    mov byte [idt_start + ebx*8 + 4], 0
    mov byte [idt_start + ebx*8 + 5], 0b11101110
    shr eax, 16
    mov word [idt_start + ebx*8 + 6], ax
    ret


set_idt:
    mov ecx, 256
    mov edi, idt_start
    xor eax, eax
    rep stosd

    mov ecx, 256
    xor ebx, ebx

.setidt_loop:
    mov eax, isr_default
    call set_idt_entry
    inc ebx
    loop .setidt_loop

    mov eax, int0x0
    xor ebx, ebx
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 1
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 2
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 3
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 4
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 5
    call set_idt_entry

    mov eax, int0x6
    mov ebx, 0x6
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 7
    call set_idt_entry

    mov eax, int0x08
    mov ebx, 8
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 9
    call set_idt_entry

    mov eax, int_err
    mov ebx, 10
    call set_idt_entry

    mov eax, int_err
    mov ebx, 11
    call set_idt_entry

    mov eax, int_err
    mov ebx, 12
    call set_idt_entry

    mov eax, int_err
    mov ebx, 13
    call set_idt_entry

    mov eax, int0xd
    mov ebx, 0xd
    call set_idt_entry

    mov eax, int0xe
    mov ebx, 0x0e
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 15
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 16
    call set_idt_entry

    mov eax, int_err
    mov ebx, 17
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 18
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 19
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 20
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 21
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 22
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 23
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 24
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 25
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 26
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 27
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 28
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 29
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 30
    call set_idt_entry

    mov eax, int_no_err
    mov ebx, 31
    call set_idt_entry

    mov eax, irq0_handler
    mov ebx, 0x20
    call set_idt_entry

    mov eax, irq1_handler
    mov ebx, 0x21
    call set_idt_entry

    mov eax, output_handler
    mov ebx, 0x30
    call set_idt_entry

    mov eax, keyboard_handler
    mov ebx, 0x31
    call set_idt_entry

    mov eax, diskio_handler
    mov ebx, 0x32
    call set_idt_entry

    mov eax, fs16_handler
    mov ebx, 0x33
    call set_idt_entry
    ret

isr_default:
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
    mov al, 'I'
    call print_char
    pop edx

    mov [color], edx
    pop ecx
    pop ebx
    mov [cur_y], ecx
    mov [cur_x], ebx
    popa
    iret