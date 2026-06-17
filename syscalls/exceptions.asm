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
    cli
    pushad
    push ds
    push es
    push fs
    push gs

    cmp word [task_count], 2
    jb .done

    movzx eax, word [current_task]
    imul eax, TASK_SIZE
    mov edi, tasks_esp
    add edi, eax
    mov [edi+15], esp

    mov bx, [current_task]
    inc bx
.search_loop:
    mov edi, tasks_esp

    movzx eax, bx
    imul eax, TASK_SIZE
    add edi, eax
    cmp byte [edi], 0
    je .next
    cmp byte [edi], 0xe5
    je .next

    mov ax, bx
    jmp .load_next
.next:
    inc bx
    cmp bx, [task_slots]
    ja .load_shell

    mov edi, tasks_esp
    jmp .search_loop
.load_shell:
    mov ax, 1

.load_next:
    ;check attributes
    cmp dword [edi+11], 0
    jne .check_attributes
.continue:
    mov [current_task], ax

    ;load next task context
    movzx eax, word [current_task]
    imul eax, TASK_SIZE
    mov edi, tasks_esp
    add edi, eax

    mov esp, [edi+15]

    ;update TSS.ESP0
    movzx eax, word [current_task]
    imul eax, tasks_kernel_stack_off
    add eax, tasks_kernel_stack 

    mov [tss+4], eax
.done:
    mov al, 0x20
    out 0x20, al

    pop gs
    pop fs
    pop es
    pop ds
    popad
    iretd

.check_attributes:
    cli
    hlt
    cmp dword [edi+11], 0x0000df00
    je .search_loop     ;skip this task

    ;unknown attribute
    jmp .continue
irq1_handler:
    cli
    push ebx
    push edi
    push ecx
    xor ecx, ecx
    in al, 0x60
    mov ah, al

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
    ; mov ebx, [buf_head]
    ; mov [key_buffer+ebx], al
    ; inc ebx
    ; and ebx, 255
    ; mov [buf_head], ebx
    movzx edi, word [main_task]
    mov ebx, edi
    imul edi, KEY_BUFFER_SIZE
    add edi, KEY_BUFFER

    movzx ecx, byte [BUFFER_HEAD+ebx]
    mov [edi+ecx], al
    inc cl

    mov [BUFFER_HEAD+ebx], cl
    cmp al, 0x3b        ;F1
    jne .done
    call switch_tasks
.done:
    push ax
    mov al, 0x20
    out 0x20, al
    pop ax
.end:
    pop ecx
    pop edi
    pop ebx
    iret

keyboard_handler:
    cmp ah, 0
    je .get_key
    iret

.get_key:
    push ebx
    push edi
    push ecx

    cmp byte [usb_keyboard_used], 1
    je .usb_keyboard

.block:
    movzx ecx, word [main_task]
    mov bx, [current_task]
    cmp bx, [main_task]
    jne .sleep

    cli
    movzx ebx, byte [BUFFER_TAIL+ecx]
    movzx eax, byte [BUFFER_HEAD+ecx]
    sti

    cmp bl, al
    je .sleep

    mov edi, ecx
    imul edi, KEY_BUFFER_SIZE
    add edi, KEY_BUFFER

    mov al, [edi+ebx]
    inc byte [BUFFER_TAIL+ecx]

    pop ecx
    pop edi
    pop ebx
    iret

.sleep:
    sti
    hlt
    jmp .block

.usb_keyboard:
    movzx ebx, word [main_task]
    movzx ecx, word [current_task]
    cmp cx, [main_task]
    jne .sleep_usb

    cli
    mov al, [BUFFER_TAIL+ebx]
    mov cl, [BUFFER_HEAD+ebx]
    sti

    cmp al, cl
    je .sleep_usb


    mov edi, ebx
    imul edi, KEY_BUFFER_SIZE
    add edi, KEY_BUFFER

    movzx ecx, byte [BUFFER_TAIL+ebx]
    add edi, ecx

    ;mov dl, [edi]   ;modifier

    push ebx
    movzx ebx, byte [edi+1] ;Key1
    movzx eax, byte [usb_keymap+ebx]
    pop ebx

    add ecx, 7
    and ecx, 0xff
    mov [BUFFER_TAIL+ebx], cl

    cmp byte [edi+1], 0
    je .sleep_usb

    pop ecx
    pop edi
    pop ebx
    iret
.sleep_usb:
    sti
    hlt
    jmp .usb_keyboard

keyboard_handler2:
    cli
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

switch_tasks:
    pusha
    mov ah, 0x01
    mov ebp, switch_tasks_str
    mov esi, width/2-250
    mov edi, height/2-150
    mov ecx, 500
    mov edx, 200
    mov ebx, 0x00ffffff
    int 0x34
    mov [switch_tasks_win_id], ax

    mov ah, 0x0a
    mov edi, switch_tasks_window
    mov esi, switch_tasks_msg
    int 0x30

    mov al, 0x0a
    mov ah, 0x0b
    mov edi, switch_tasks_window
    int 0x30

    mov esi, tasks_esp
    add esi, TASK_SIZE     ;skip task 0
    mov dx, [max_tasks]
    xor ebx, ebx
.loop:
    cmp byte [esi], 0xe5
    je .skip
    cmp byte [esi], 0
    je .skip

    inc bl
    push bx
    add bl, '0'
    mov al, bl
    pop bx
    mov ah, 0x0b
    mov edi, switch_tasks_window
    int 0x30

    mov al, ':'
    mov ah, 0x0b
    mov edi, switch_tasks_window
    int 0x30
    mov al, 0x20
    mov ah, 0x0b
    mov edi, switch_tasks_window
    int 0x30

    mov cx, 11
    push esi
.print_loop:
    lodsb
    mov edi, switch_tasks_window
    mov ah, 0x0b
    int 0x30
    dec cx
    jnz .print_loop
    pop esi

    mov edi, switch_tasks_window
    mov al, 0x0a
    mov ah, 0x0b
    int 0x30
.skip:
    add esi, TASK_SIZE
    dec dx
    jnz .loop

    xor ax, ax
    sti
.exit:
    hlt
    in al, 0x60

    sub al, 1
    cmp ax, [task_count]
    ja .exit
    add al, 1
    
    cmp al, 0
    je .exit
    cmp al, 0x01
    je .done

    jmp .switch_task
.done:
    mov al, 0x20
    out 0x20, al
    cli
    mov bx, [switch_tasks_win_id]
    mov ah, 0x02
    mov edi, switch_tasks_window
    int 0x34

    mov dword [edi+16], width / 2-250
    mov dword [edi+20], height / 2-150
    popa
    ret

.switch_task:
    cli
    sub al, 1
    mov [main_task], ax

    mov bx, [switch_tasks_win_id]
    mov ah, 0x02
    mov edi, switch_tasks_window
    int 0x34

    mov dword [edi+16], width / 2-250
    mov dword [edi+20], height / 2-150
    popa
    ret
irq14_handler:
    cli
    pusha

    ;stop DMA
    mov dx, [bm_base4]
    xor al, al
    out dx, al

    mov dx, [bm_base4]
    add dx, 2
    in al, dx
    mov bl, al

    mov al, 0x06
    out dx, al
    
    mov dx, 0x1f7
    in al, dx

    ;test if error
    test bl, 0x02
    jnz .error

    cmp byte [ide_running], 1
    jne .done
    mov byte [ide_running], 0

    movzx eax, word [current_task]
    imul eax, TASK_SIZE
    add eax, tasks_esp
    movzx edx, word [max_tasks]
.loop:
    cmp dword [eax+11], 0x0000df00
    je .found
    add eax, TASK_SIZE
    dec edx
    jnz .loop
    jmp .done
.found:
    mov dword [eax+11], 0       ;remove 'wait for drive' attribute

.done:
    mov al, 0x20
    out 0xa0, al
    out 0x20, al
    mov byte [ide_running], 0
    popa
    iret

.error:
    mov al, '%'
    call print_char
    mov al, 0x20
    out 0xa0, al
    out 0x20, al
    mov byte [ide_running], 0
    popa
    iret

irq15_handler:
    cli
    pusha

    mov dx, 0x177
    in al, dx

    mov dx, [bm_base4]
    add dx, 0x0a
    in al, dx
    mov bl, al

    mov al, 0x06
    out dx, al

    ;stop DMA
    mov dx, [bm_base4]
    add dx, 8
    xor al, al
    out dx, al
    
    ;test if error
    test bl, 0x02
    jnz .error

    cmp byte [ide_running], 1
    jne .done
    mov byte [ide_running], 0

    movzx eax, word [current_task]
    imul eax, TASK_SIZE
    add eax, tasks_esp
    movzx edx, word [max_tasks]
.loop:
    cmp dword [eax+11], 0x0000df00
    je .found
    add eax, TASK_SIZE
    dec edx
    jnz .loop
    jmp .done
.found:
    mov dword [eax+11], 0       ;remove 'wait for drive' attribute

.done:
    mov al, 0x20
    out 0xa0, al
    out 0x20, al
    mov byte [ide_running], 0
    popa
    iret

.error:
    mov al, '%'
    call print_char
    mov al, 0x20
    out 0xa0, al
    out 0x20, al
    mov byte [ide_running], 0
    popa
    iret

ahci_interrupt_handler:
    cli
    pusha
    mov al, '!'
    call print_char
    mov eax, [abar]
    mov ebx, [eax+8]        ;IS
    mov [eax+8], ebx

    mov esi, ahci_device_list_addr
    mov dx, [ahci_devices]
.loop:
    mov eax, [esi+4]        ;port address
    mov ebx, [eax+0x10]     ;IS
    mov [eax+0x10], ebx

    add esi, AHCI_PORT_ENTRY_SIZE
    dec dx
    jnz .loop

    mov al, 0x20
    out 0xa0, al
    out 0x20, al

    popa
    iret

ohci_interrupt_handler:
    cli
    pusha
    mov eax, [ohci_base]
    mov ebx, [eax+12]       ;interrupt status
    mov [eax+12], ebx

    test ebx, 2
    jz .skip_keyboard

    mov edx, [eax+0x30]         ;read DoneHead
    mov dword [eax+0x30], 0     ;clear DoneHead to unblock controller

    ; mov ebx, td_empty
    ; mov [usb_keyboard_td+8], ebx
    ; mov ebx, usb_keyboard_buffer
    ; mov [usb_keyboard_td+4], ebx
    ; mov ebx, usb_keyboard_buffer+7
    ; mov [usb_keyboard_td+12], ebx

    ; mov ebx, [usb_keyboard_td]
    ; and ebx, 0x0fffffff
    ; or ebx, (15 << 28)      ;mark TD as Not Accessed (0x0F)
    ; mov [usb_keyboard_td], ebx

    ; mov ebx, usb_keyboard_td
    ; mov [usb_keyboard_ed+8], ebx
    ; mov ebx, td_empty
    ; mov [usb_keyboard_ed+4], ebx

    mov ebx, td_empty
    mov edi, [usb_keyboard_tdptr]

    mov [edi+8], ebx
    mov ebx, [usb_keybuffer]
    mov [edi+4], ebx
    mov ebx, [usb_keybuffer]
    add ebx, 7
    mov [edi+12], ebx

    mov ebx, [edi]
    and ebx, 0x0fffffff
    or ebx, (15 << 28)      ;mark TD as Not Accessed (0x0F)
    mov [edi], ebx

    mov ebx, [usb_keyboard_tdptr]
    mov edi, [usb_keyboard_edptr]
    mov [edi+8], ebx
    mov ebx, td_empty
    mov [edi+4], ebx

    ;store keys
    movzx edi, word [main_task]
    mov ebx, edi

    imul edi, KEY_BUFFER_SIZE
    add edi, KEY_BUFFER
    movzx ecx, byte [BUFFER_HEAD+ebx]
    add edi, ecx

    mov esi, [usb_keybuffer]
    mov al, [esi]
    add esi, 2

    mov [edi], al
    add edi, 1

    cld
    mov ecx, 6
    rep movsb
    
    movzx ecx, byte [BUFFER_HEAD+ebx]
    add ecx, 7
    and ecx, 0xff
    mov [BUFFER_HEAD+ebx], cl
    ; mov ebx, [usb_keybuffer]
    ; movzx ebx, byte [ebx+2]
    ; test ebx, ebx
    ; jz .skip_keyboard

    ; mov al, [usb_keymap+ebx]
    ; call print_char
.skip_keyboard:
    mov al, 0x20
    out 0xa0, al
    out 0x20, al
    popa
    iret