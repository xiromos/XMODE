;=========================================================
;System API
;AH = 0x01: Freeze System (debug)
;AH = 0x02: start a foreground task (that means the task has control over keyboard and screen)          ;EBX = Address in Memory of Task, ESI = pointer to Taskname
;AH = 0x03: start a background task                                                                     ;EBX = Address in Memory of Task, ESI = pointer to Taskname
;AH = 0x04: terminate a task (not the caller)                                                           ;EBX = PID or ESI = Taskname (if one is set, other should be zero)  CF on error
;   Error ist set if the PID is 0 or 1 or if the task is a kernel task
;AH = 0x05: terminate the process which called the syscall
;AH = 0x0A: allocate heap                                                                               ;Output: ESI = pointer to 4KB heap chunk
;AH = 0x0B: free heap                                                                                   ;Input: ESI = pointer to allocated chunk


program_sys_handler:
    cmp ah, 0x01
    je .test_stop
    cmp ah, 0x02
    je start_task_fg
    cmp ah, 0x03
    je start_task_bg
    cmp ah, 0x04
    je kill_task
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


start_task_bg:
    ;EAX = Task Address
    ;ESI = Task Name
    pusha
    cmp ebx, 0
    je .error
    cmp esi, 0
    je .error

    mov eax, ebx

    push eax
    mov ax, [max_tasks]
    cmp word [task_count], ax
    jae .too_much_tasks

    ;save shell context
    mov eax, 1
    imul eax, TASK_SIZE
    mov edi, tasks_esp
    add edi, eax
    mov [edi+15], esp

    mov dx, [task_slots]
    mov ecx, 2

    mov edi, tasks_esp
    add edi, TASK_SIZE*2     ;skip task 0 + shell
    pop eax
.find_loop:
    cmp byte [edi], 0xe5
    je .found_slot
    cmp byte [edi], 0
    je .found_slot

    add edi, TASK_SIZE

    inc ecx
    dec dx
    jnz .find_loop

    popa
    or dword [esp+8], 1
    iret
.found_slot:
    push esi
    push ecx
    mov ecx, 11
    rep movsb
    pop ecx
    pop esi

    mov [kernel_stack], esp

    mov edx, eax
    mov eax, program_stack_off
    imul eax, ecx
    add eax, program_stack
    mov esp, eax
    mov eax, edx

    ; mov eax, program_addr_off
    ; imul eax, ecx
    ; add eax, program_addr

    push ss
    push esp
    ;pushfd                 ;bug - if program does infinite loop -> freeze
    push dword 0x202        ;enable interrupt flag
    push cs
    push eax

    pushad
    push ds
    push es
    push fs
    push gs

    movzx eax, cx
    imul eax, TASK_SIZE
    mov edi, tasks_esp
    add edi, eax
    mov [edi+15], esp

    inc word [task_count]

    int 0x20
    mov esp, [kernel_stack]

    popa
    and dword [esp+8], 0xfffffffe
    iret
.too_much_tasks:
    popa
    or dword [esp+8], 1
    iret
.error:
    popa
    or dword [esp+8], 1
    iret

start_task_fg:
    ;EAX = Task Address
    ;ESI = Task Name
    pusha
    cmp ebx, 0
    je .error
    cmp esi, 0
    je .error

    mov eax, ebx

    push eax
    mov ax, [max_tasks]
    cmp word [task_count], ax
    jae .too_much_tasks

    ;save shell context
    mov eax, 1
    imul eax, TASK_SIZE
    mov edi, tasks_esp
    add edi, eax
    mov [edi+15], esp

    mov dx, [task_slots]
    mov ecx, 2

    mov edi, tasks_esp
    add edi, TASK_SIZE*2     ;skip task 0 + shell
    pop eax
.find_loop:
    cmp byte [edi], 0xe5
    je .found_slot
    cmp byte [edi], 0
    je .found_slot

    add edi, TASK_SIZE

    inc ecx
    dec dx
    jnz .find_loop

    popa
    or dword [esp+8], 1
    iret
.found_slot:
    push esi
    push ecx
    mov ecx, 11
    rep movsb
    pop ecx
    pop esi

    mov [kernel_stack], esp

    mov edx, eax
    mov eax, program_stack_off
    imul eax, ecx
    add eax, program_stack
    mov esp, eax
    mov eax, edx

    ; mov eax, program_addr_off
    ; imul eax, ecx
    ; add eax, program_addr

    push ss
    push esp
    ;pushfd                 ;bug - if program does infinite loop -> freeze
    push dword 0x202        ;enable interrupt flag
    push cs
    push eax

    pushad
    push ds
    push es
    push fs
    push gs

    movzx eax, cx
    imul eax, TASK_SIZE
    mov edi, tasks_esp
    add edi, eax
    mov [edi+15], esp

    mov [main_task], cx
    inc word [task_count]

    int 0x20
    mov esp, [kernel_stack]

    popa
    and dword [esp+8], 0xfffffffe
    iret
.too_much_tasks:
    popa
    or dword [esp+8], 1
    iret
.error:
    popa
    or dword [esp+8], 1
    iret
kill_task:
    ;ESI = Taskname or EAX = PID
    ;If Taskname or PID is set, the other register should be zero
    pusha
    popa
    iret


alloc_heap:
    pusha
    popa
    iret
free_heap:
    pusha
    popa
    iret

;Loading of Programs

; Program  | Startaddress        | Size
; 1          0x1000000             0x400000
; 2          0x1400000           | 0x20000
; 3          0x1420000           | 0x80000
; 4          0x14a0000           | 0x200000
; ...

; If a program terminates it gives free space back.
; The program loader checks if the new loaded program
; fits into that space, if yes than the loader marks this space
; as used, if not than the loader searches other free memory. If nothing
; is found then it shows an error. The Addresses of Programs and its size
; are stored in a table.