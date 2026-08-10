section .text
start:
    ;get domain name
    pop eax     ;a bug
    pop esi

    mov edi, domain_name
    xor ecx, ecx
.loop_copy:
    lodsb
    cmp al, 0
    je .done_copy
    stosb
    inc ecx
    cmp ecx, 64
    jb .loop_copy

    mov esi, error_length
    call print_string

    mov ah, 0x05
    int 0x35

.done_copy:
    stosb

    ;get buffer for packets
    mov ecx, 0x2000
    mov ah, 0x0a
    int 0x35
    jc .error_mem
    mov [heap], esi

    mov ah, 0x21
    mov al, 0x02    ;open socket
    xor bh, bh      ;IPv4
    mov bl, 0x03    ;UDP
    xor dx, dx      ;port
    int 0x35
    jc .no_internet

    mov [socket_num], cx

    int 0x20
    mov ah, 0x03
    int 0x30

    ;#### DNS CHECK ####
    ; ;github.com
    ; mov edi, domain_name
    ; call get_ip

    ; mov ah, 0x03
    ; int 0x30

    ; mov esi, github_str
    ; call print_string

    ; mov eax, edx
    ; call print_addr

    ; mov ah, 0x03
    ; int 0x30

    ; ;vkvideo.ru
    ; mov edi, vkvideo_ru
    ; call get_ip

    ; mov esi, vkvideo_str
    ; call print_string

    ; mov eax, edx
    ; call print_addr

    ; mov ah, 0x03
    ; int 0x30

    ; ;ruwiki.ru
    ; mov edi, ruwiki_ru
    ; call get_ip

    ; mov esi, ruwiki_str
    ; call print_string

    ; mov eax, edx
    ; call print_addr

    ; mov ah, 0x03
    ; int 0x30

    ; ;prosdev.org
    ; mov edi, prosdev_org
    ; call get_ip

    ; mov esi, prosdev_str
    ; call print_string

    ; mov eax, edx
    ; call print_addr

    ; mov ah, 0x03
    ; int 0x30

    mov ah, 0x0a
    mov ecx, 0x1000
    int 0x35
    jc .error_mem

    mov [heap2], esi

    ;open ICMP socket
    mov ah, 0x21
    mov al, 0x02
    xor bh, bh
    mov bl, 0x01
    xor dx, dx
    int 0x35
    jc error

    mov [socket_num2], cx
    mov ebp, 4
.loop:
    ;get IPv4 address first
    mov cx, [socket_num]
    mov edi, domain_name
    call get_ip
    
    mov cx, [socket_num2]
    mov esi, icmp_packet
    
    ;set sequence number
    mov ax, [packet_number]
    xchg al, ah
    mov [esi+6], ax
    inc word [packet_number]

    mov bx, cx
    shl ebx, 16

    mov ecx, 32
    mov ah, 0x21
    mov al, 0x03
    int 0x35

.wait:
    mov cx, [socket_num2]
    mov ah, 0x21
    mov al, 0x04
    int 0x35
    jc .timed_out

    mov esi, [heap2]
    call check_icmp_packet

    dec ebp
    jnz .loop

.done:
    ;close UDP socket
    mov cx, [socket_num]
    mov ah, 0x21
    mov al, 0x05
    int 0x35

    ;close ICMP socket
    mov cx, [socket_num2]
    mov ah, 0x21
    mov al, 0x05
    int 0x35

    ;clear heap
    mov esi, [heap]
    mov ecx, 0x1000
    mov ah, 0x0b
    int 0x35

    mov esi, [heap2]
    mov ecx, 0x1000
    mov ah, 0x0b
    int 0x35

    ;end of program
    mov ah, 0x05
    int 0x35

.error_mem:
    mov esi, low_memory_str
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30

    mov ah, 0x05
    int 0x35
.no_internet:
    mov esi, no_internet_str
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30

    mov ah, 0x05
    int 0x35

.timed_out:
    mov esi, packet_num_str
    call print_string

    movzx ebx, word [packet_number]
    dec ebx
    mov ah, 0x04
    int 0x30

    mov al, ':'
    mov ah, 0x02
    mov ebx, 0x00ffffff
    int 0x30

    mov al, 0x20
    mov ah, 0x02
    mov ebx, 0x00ffffff
    int 0x30

    mov esi, timed_out_str
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30

    dec ebp
    jnz .loop
    jmp .done

;=============================================================
;########################## FUNCTIONS ########################
;=============================================================

check_icmp_packet:
    ;ESI = pointer to packet
    ;returns IPv4 address in EDX
    push ebp

    mov ebp, esi
    mov edi, esi
    add edi, 12

    ;print 'Packet X: '
    mov esi, packet_num_str
    call print_string

    movzx ebx, word [edi+6]
    xchg bl, bh
    mov ah, 0x04
    int 0x30

    mov al, ':'
    mov ah, 0x02
    mov ebx, 0x00ffffff
    int 0x30

    mov al, 0x20
    mov ah, 0x02
    mov ebx, 0x00ffffff
    int 0x30

    cmp byte [edi], 0
    jne .no_reply

    ;print 'Successfully received response from 255.255.255.255'
    mov esi, response_success
    call print_string

    mov eax, [ebp]
    call print_addr

    mov ah, 0x03
    int 0x30
    pop ebp
    ret


.no_reply:
    mov esi, no_reply_str
    call print_string
    pop ebp
    ret

get_ip:
    ;EDI = domain name
    ;returns IPv4 address in EDX
    mov ah, 0x21
    mov al, 0x07    ;resolve domain name
    int 0x35
    jc .error

    ret
.error:
    mov edx, 0xffffffff
    ret
print_string:
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30
    ret
print_addr:
    ;EAX = IP Address
    cmp eax, 0xffffffff ;error
    je .error

    push ebx
    mov ebx, eax
    call print_dec

    push ebx
    mov esi, str
    call print_string
    pop ebx

    mov eax, ebx
    shr eax, 8
    and eax, 0xff
    call print_dec

    push ebx
    mov esi, str
    call print_string
    pop ebx

    mov eax, ebx
    shr eax, 16
    and al, 0xff
    call print_dec

    push ebx
    mov esi, str
    call print_string
    pop ebx

    mov eax, ebx
    shr eax, 24
    and al, 0xff
    call print_dec

    pop ebx
    ret

.error:
    mov esi, error_msg
    mov ebx, COLOR_RED
    call print_string
    ret

print_dec:
    push ebx
    movzx ebx, al
    mov ah, 0x04
    int 0x30
    pop ebx
    ret

error:
    mov esi, socket_err
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30

    mov ah, 0x05
    int 0x35
error_dns:
    mov esi, error_msg
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30

    mov ah, 0x05
    int 0x35

section .data
domain_name: times 64 db 0
socket_num: dw 0
socket_num2: dw 0
COLOR_RED   equ 0xe30909
low_memory_str: db 'Low memory. Couldnt allocate buffer for packet', 0x0a, 0
no_internet_str: db 'No Internet Connection', 0x0a, 0
socket_err: db 'Error while opening socket. Closing program...', 0x0a, 0
github_str: db 'IP Address of github.com: ', 0
str: db '.', 0
heap: dd 0
heap2: dd 0

vkvideo_ru: db 'vkvideo.ru', 0
vkvideo_str: db 'IP Address of vkvideo.ru: ', 0
ruwiki_ru: db 'ruwiki.ru', 0
ruwiki_str: db 'IP Address of ruwiki.ru: ', 0
prosdev_org: db 'prosdev.org', 0
prosdev_str: db 'IP Address of prosdev.org: ', 0


error_msg: db 'Error, Couldnt get answer of DNS server', 0

icmp_packet:
    db 8    ;type 8 (echo request)
    db 0
    dw 0    ;checksum (will be set by OS)
    dw 0    ;identifier (will be set by OS)
    dw 0    ;sequence number

    times 24 db 0

packet_number: dw 1
packet_num_str: db 'Packet ', 0
no_reply_str: db 'Error: Not an ICMP Echo Replay packet', 0x0a, 0
response_success: db 'Successfully received response from ', 0
error_length: db 'Error: domain name too long', 0x0a, 0
timed_out_str: db 'Connection timed out', 0x0a, 0
