# Scheduler

The scheduler sits in timer interrupt IRQ0 and is executed every 100ms.
How it works:
- push registers to stack
- check if there is a next task with higher PID
- if yes check its attributes
- if no fall back to task with PID 1 (shell) and also check its attributes
- if there are any flags set in the attributes field jump back and search a next free task
- load the new ESP from the task structure and pop all registers from stack
- perform an IRET and execute next program

Code (x86 NASM syntax):

```asm
irq0_handler:
    cli
    pushad              ;save all registers
    push ds
    push es
    push fs
    push gs

    cmp word [task_count], 2        ;end scheduler if shell is the only active task
    jb .done

    movzx eax, word [current_task]
    imul eax, TASK_SIZE
    mov edi, tasks_esp
    add edi, eax
    mov [edi+15], esp               ;save ESP in task structure

    mov bx, [current_task]
    inc bx
.search_loop:                       ;search for next free task (0 and 0xe5 are empty task fields)
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
    mov ax, 1                       ;fall back to shell

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

    mov esp, [edi+15]                               ;load next ESP from task structure

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
    mov bx, ax
    inc bx
    cmp dword [edi+11], 0x0000df00                      ;waiting for disk attribute
    je .search_loop     ;skip this task

    ;unknown attribute
    jmp .continue
```

## Task Structure

```asm
tasks_esp:
    times 11 db 0
    times 4 dd 0    ;task 0 (reserved)

    times 11 db 0
    times 4 dd 0    ;task 1 (shell)

    times 11 db 0
    times 4 dd 0    ;task 2

    times 11 db 0
    times 4 dd 0    ;task 3

    times 11 db 0
    times 4 dd 0    ;task 4

    times 11 db 0
    times 4 dd 0    ;task 5
```

### One Entry

- 11 Bytes: Taskname (8.3 format)
- 4  Bytes: Attributes / Flags
- 4  Bytes: ESP
- 4  Bytes: startaddress in memory
- 4  Bytes: size of program