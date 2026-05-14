[org 0x100000]
bits 32

start:
    mov esi, 300
    mov edi, 200
    mov ebx, 0x00ffffff
    mov ecx, 300
    mov edx, 200
    mov ebp, title
    mov ah, 0x01
    int 0x34

    ; clear window
    ; mov ah, 0x0e
    ; mov edi, window_packet
    ; int 0x30

    ; draw full block char
    ; mov ah, 0x0b
    ; mov al, 0xff
    ; mov edi, window_packet
    ; int 0x30

    mov ah, 0x0a
    mov esi, hello_msg
    mov edi, window_packet
    int 0x30

    mov ah, 0x0b
    mov al, 0x0a
    mov edi, window_packet
    int 0x30
.loop:
    mov ah, 0x0b
    mov al, '>'
    mov edi, window_packet
    int 0x30

    mov ah, 0x0b
    mov al, 0x20
    mov edi, window_packet
    int 0x30

    xor ecx, ecx
    mov edi, command_buffer
.get_input:
    xor ah, ah
    int 0x31

    cmp al, 0x08
    je .handle_backspace
    cmp al, 0x0d
    je .done

    cmp ecx, 20
    jae .get_input
    inc ecx

    push edi
    mov ah, 0x0b
    mov edi, window_packet
    int 0x30
    pop edi
    
    stosb

    cmp al, 'q'
    je .quit
    jmp .get_input

.handle_backspace:
    push edi
    cmp ecx, 0
    jbe .get_input
    sub dword [window_packet+16], 8
    mov al, 0xff
    mov ah, 0x0b
    mov edi, window_packet
    int 0x30
    sub dword [window_packet+16], 8
    dec ecx
    pop edi
    dec edi
    jmp .get_input

.done:
    mov byte [edi], 0
    mov ah, 0x0b
    mov al, 0x0a
    mov edi, window_packet
    int 0x30

    mov edi, command_buffer
    mov esi, clear_str
    call cmp_cmd
    jc .clear_screen

    mov edi, command_buffer
    mov esi, help_str
    call cmp_cmd
    jc .help

    mov esi, no_cmd
    mov ah, 0x0a
    mov edi, window_packet
    int 0x30

    mov ah, 0x0b
    mov al, 0x0a
    mov edi, window_packet
    int 0x30

    jmp .loop

.clear_screen:
    mov ah, 0x0e
    mov edi, window_packet
    int 0x30

    jmp .loop
.help:
    mov ah, 0x0a
    mov esi, help_msg
    mov edi, window_packet
    int 0x30

    mov ah, 0x0b
    mov al, 0x0a
    mov edi, window_packet
    int 0x30
    jmp .loop
.quit:
    retf


cmp_cmd:
    mov al, [edi]
    mov bl, [esi]

    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal

    inc esi
    inc edi
    jmp cmp_cmd
.equal:
    stc
    ret
.not_equal:
    clc
    ret




window_packet:
    dd 0            ;foreground color
    dd 0x00ffffff   ;background color
    dd 300          ;width
    dd 200          ;height
    dd 300          ;CurX
    dd 200          ;CurY
    dd 300          ;original CurX
    dd 200          ;original CurY

hello_msg: db 'Hello from Window-Manager!', 0x0a,
           db 'Type something or press ESC to quit', 0

title: db 'Shell', 0

command_buffer: db 25 dup(0)
clear_str: db 'clear', 0
help_str: db 'help', 0
no_cmd: db 'Not a known command', 0

help_msg: db 'Help', 0x0a,
          db 'HELP: show this message', 0x0a,
          db 'CLEAR: clear screen', 0