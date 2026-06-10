section .text
start:
    mov esi, header
    mov ebx, 0x0003f0fc
    mov ah, 0x01
    int 0x30

    mov esi, help
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30

    mov esi, clear
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30

    mov esi, header2
    mov ebx, 0x0003f0fc
    mov ah, 0x01
    int 0x30

    mov esi, read
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30

    mov esi, write
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30

    mov esi, rename
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30

    mov esi, del
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30

    mov esi, ls
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30
    
    mov esi, syntax_header
    mov ebx, 0x0003f0fc
    mov ah, 0x01
    int 0x30

    mov esi, syntax
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30

    mov ah, 0x03
    int 0x30

    mov ah, 0x05
    int 0x35

section .data
header: db '----Standard Commands----', 0x0a, 0
help: db 'HELP: shows this help message', 0x0a, 0
clear: db 'CLEAR: clears the screen', 0x0a, 0
ram: db 'RAM: shows available ram', 0x0a, 0
reboot: db 'REBOOT: restarts the system', 0x0a, 0x0a, 0

header2: db '----File Operation Commands----', 0x0a, 0
read: db 'READ: read a text file', 0x0a, 0
write: db 'WRITE: write a text file [max. 512 bytes]', 0x0a, 0
rename: db 'RENAME: rename a file', 0x0a, 0
del: db 'DEL: delete a file or a program [some are protected]', 0x0a, 0
ls: db 'LS: list content of the current directory', 0x0a, 0
mkdir: db 'MKDIR: create a directory', 0x0a, 0
cd: db 'CD: change directory, [arguments are "/" and "-"]', 0x0a, 0
deldir: db 'DELDIR: delete an empty directory', 0x0a, 0
cdisk: db 'CDISK: change disk', 0x0a, 0x0a, 0

syntax_header: db 'Syntax: command <argument>', 0x0a, 0
syntax: db 'You can give the command only one argument.', 0x0a,
        db 'If there is any command that requires two arguments,', 0x0a,
        db 'give it the first argument and then press Enter, because', 0x0a,
        db 'the command will ask you for the second argument.', 0x0a,
        db 'If there is any command you doesnt want to execute anymore', 0x0a,
        db 'press "q". This will always bring you back', 0x0a,
        db 'to the terminal.', 0x0a, 0