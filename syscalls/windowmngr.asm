;=============================================================
;INT 0x34
;Syscall for drawing and deleting a window
;AH = 0x1: draw a window                        ;input: ESI = X, EDI = Y, ECX = width, EDX = height, EBX = background color, output: EAX = window ID, EBX = CurX, ECX = CurY, EBP = pointer to title

bits 32

window_functions:
    cmp ah, 0x01
    je .draw_window
    cmp ah, 0x02
    je .rm_window
    ret

.draw_window:
    pusha
    pusha
    xor cx, cx
    mov edi, windows_list
.search_free:
    mov al, [edi]
    cmp al, 0
    je .free_window
    inc cx
    cmp cx, [num_windows]
    jb .search_free
    popa
    popa
    or dword [esp+8], 1
    iret
.free_window:
    mov [window_id], cx
    popa
    push ebp

    mov [win_x], esi
    mov [win_y], edi
    mov [win_width], ecx
    mov [win_height], edx
    mov [win_color], ebx

    mov edi, [frame_buffer]
    xor edx, edx
    mov esi, [win_x]
    sub esi, 1
    movzx eax, byte [bpp]
    mul esi
    add edi, eax

    mov eax, [win_y]
    sub eax, 20
    mov ebx, [pitch]
    mul ebx
    add edi, eax

    mov edx, [win_border_color]
    mov ebx, 20
    movzx eax, byte [bpp]
    mov ecx, [win_width]
    add ecx, 2
.loop1:
    mov [edi], edx
    add edi, eax
    dec ecx
    jnz .loop1

    xor edx, edx
    add edi, [pitch]
    mov ecx, [win_width]
    add ecx, 2
    mul ecx
    sub edi, eax
    movzx eax, byte [bpp]
    mov ecx, [win_width]
    add ecx, 2
    mov edx, [win_border_color]
    dec ebx
    jnz .loop1

    ;title the window
    pop esi

    mov eax, [cur_x]
    push eax
    mov ebx, [cur_y]
    push ebx

    mov eax, [win_x]
    add eax, 1
    mov [cur_x], eax
    mov ebx, [win_y]
    sub ebx, 17
    mov [cur_y], ebx
    
    mov ebx, 0x00ffffff
    cmp byte [esi], 0x80
    jae .untitled
    
    call print_string
    jmp .continue
.untitled:
    mov esi, untitled_str
    call print_string
.continue:
    pop ebx
    mov [cur_y], ebx
    pop eax
    mov [cur_x], eax


    mov ecx, [win_width]
    xor edx, edx
    mov esi, [win_x]
    movzx eax, byte [bpp]
    mul esi
    mov edi, [frame_buffer]
    add edi, eax
    mov eax, [win_y]
    mov ebx, [pitch]
    mul ebx
    add edi, eax
    mov edx, [win_color]
    mov ebx, [win_height]
    movzx eax, byte [bpp]
    sub edi, eax
    push edx
    mov edx, [win_border_color]
    mov [edi], edx
    add edi, eax
    mov esi, [win_border_color]
    pop edx
.loop:
    mov [edi], edx
    add edi, eax
    dec ecx
    jnz .loop

    mov [edi], esi

    xor edx, edx
    add edi, [pitch]
    mov ecx, [win_width]
    mul ecx
    sub edi, eax
    movzx eax, byte [bpp]
    mov ecx, [win_width]
    mov edx, [win_color]
    sub edi, eax
    push edx
    mov edx, [win_border_color]
    mov [edi], edx
    add edi, eax
    pop edx
    dec ebx
    jnz .loop

    mov esi, [win_border_color]
    movzx eax, byte [bpp]
    mov ecx, [win_width]
.loop2:
    mov [edi], esi
    add edi, eax
    dec ecx
    jnz .loop2
    popa
    iret

.rm_window:
    pusha
    popa
    iret