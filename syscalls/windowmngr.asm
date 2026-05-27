;=============================================================
;INT 0x34
;Syscall for drawing and deleting a window
;AH = 0x1: draw a window                        ;input: ESI = X, EDI = Y, ECX = width, EDX = height, EBX = background color, EBP = pointer to title  output: EAX = window ID, EBX = CurX, ECX = CurY
;AH = 0x2: remove window                        ;input: EDI = window_packet, bx = window id
;AH = 0xb: draw a window but let window manager decide the size         :output: AX = window id, EBX = width, ECX = height, EDI = CurX, ESI = CurY
bits 32

window_functions:
    cli
    cmp ah, 0x01
    je .draw_window
    cmp ah, 0x02
    je .rm_window
    ret

.draw_window:
    pusha
    pusha
    mov cx, 1
    mov edi, windows_list
.search_free:
    mov al, [edi]
    cmp al, 0
    je .free_window
    inc cx
    inc edi
    cmp cx, [num_windows]
    jb .search_free
    popa
    popa
    or dword [esp+8], 1
    iret
.free_window:
    mov byte [edi], 1
    mov [window_id], cx
    popa

    mov [win_x], esi
    mov [win_y], edi
    mov [win_width], ecx
    mov [win_height], edx
    mov [win_color], ebx

    movzx eax, word [window_id]
    mov edi, window_buffer
    imul eax, edi
    mov edi, eax
    ;add X
    mov esi, [frame_buffer]
    mov ecx, [win_x]
    sub ecx, 1
    movzx eax, byte [bpp]
    mul ecx
    add esi, eax

    ;add Y
    mov ecx, [win_y]
    sub ecx, 20
    mov eax, [pitch]
    mul ecx
    add esi, eax

    mov ecx, [win_width]
    add ecx, 2
    movzx eax, byte [bpp]
    mul ecx
    mov ecx, eax

    mov ebx, [win_height]
    add ebx, 21         ;header + last row
.loop1:
    rep movsb

    add esi, [pitch]
    movzx ecx, byte [bpp]
    mov eax, [win_width]
    add eax, 2
    mul ecx
    sub esi, eax

    mov ecx, eax
    dec ebx
    jnz .loop1
;====draw the window====
.loop3:
    push ebp
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
.loop4:
    mov [edi], edx
    add edi, eax
    dec ecx
    jnz .loop4

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
    jnz .loop4

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
.loop5:
    mov [edi], edx
    add edi, eax
    dec ecx
    jnz .loop5

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
    jnz .loop5

    mov esi, [win_border_color]
    movzx eax, byte [bpp]
    mov ecx, [win_width]
.loop6:
    mov [edi], esi
    add edi, eax
    dec ecx
    jnz .loop6
    popa
    mov ax, [window_id]
    iret

.rm_window:
    pusha
    mov eax, [edi+8]
    mov [win_width], eax
    mov eax, [edi+12]
    mov [win_height], eax
    mov eax, [edi+24]
    mov [win_x], eax
    mov eax, [edi+28]
    mov [win_y], eax

    movzx eax, bx
    sub eax, 1
    mov edi, windows_list
    add edi, eax     ;add window ID
    mov byte [edi], 0

    movzx ecx, bx
    mov eax, window_buffer
    mul ecx
    mov esi, eax

    mov edi, [frame_buffer]
    mov eax, [win_x]
    sub eax, 1
    movzx ebx, byte [bpp]
    mul ebx
    add edi, eax

    mov eax, [win_y]
    sub eax, 20
    mov ebx, [pitch]
    mul ebx
    add edi, eax

    mov ebx, [win_height]
    add ebx, 21         ;header + last row

    mov ecx, [win_width]
    add ecx, 2
    movzx eax, byte [bpp]
    mul ecx
    mov ecx, eax

.rm_loop:
    rep movsb

    add edi, [pitch]
    mov ecx, [win_width]
    add ecx, 2
    movzx eax, byte [bpp]
    mul ecx
    sub edi, eax
    mov ecx, eax

    dec ebx
    jnz .rm_loop
    popa
    iret


window_buffer   equ     0x200000