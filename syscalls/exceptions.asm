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

program_sys_handler:
    cmp ah, 0x01
    je .test_stop
    cmp ah, 0x05
    je .terminate_process
.test_stop:
    cli
    hlt
.terminate_process:
    cli

    movzx ecx, word [current_task]
    imul ecx, TASK_SIZE
    mov edi, tasks_esp
    add edi, ecx
    mov byte [edi], 0xe5

    dec word [task_count]

    mov cx, [current_task]
    cmp word [main_task], cx
    jne .skip

    mov word [main_task], 1
.skip:
    mov edi, tasks_esp
    inc word [current_task]
    movzx ecx, word [max_tasks]
    cmp word [current_task], cx
    jbe .check

    mov word [current_task], 1
    jmp .continue
.check:
    imul ecx, TASK_SIZE
    add edi, ecx
    cmp byte [edi], 0xe5
    je .skip
    cmp byte [edi], 0
    je .skip

.continue:
    xor ecx, ecx
    mov cx, [current_task]
    imul cx, TASK_SIZE
    add ecx, tasks_esp

    mov esp, [ecx+15]

    movzx ecx, word [current_task]
    imul ecx, tasks_kernel_stack_off
    add ecx, tasks_kernel_stack 

    mov [tss+4], ecx

    pop gs
    pop fs
    pop es
    pop ds
    popad

    iret
    cli
    hlt

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
    pusha

    mov byte [dma_done], 1

    ;read IDE status
    ; mov dx, 0x1f7
    ; in al, dx

    mov dx, [bm_base4]
    add dx, 2
    in al, dx
    and al, 0x6
    out dx, al

    mov al, 0x04
    out dx, al

    mov al, '1'
    call print_char
    mov al, 0x20
    out 0xa0, al
    out 0x20, al
    mov al, '2'
    call print_char
    popa
    iret