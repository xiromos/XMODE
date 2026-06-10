section .text
_start:
    mov esi, hello_msg
    mov ah, 0x01
    mov ebx, 0x00ffffff
    int 0x30

    mov ah, 0x03
    int 0x30

    mov ah, 0x05
    int 0x35

section .data
hello_msg: db 'Hello from COFF Object file!', 0