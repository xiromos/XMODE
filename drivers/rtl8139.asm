;=====================================================================
;RTL8139 (network card) driver
;Copyright (C) 2026 Technodon
;=====================================================================

section .text
start:
    jmp short init
    ;magic string
    db 'NET '   ;network card
init:
    test eax, (1 << 0)
    jnz .use_io

    mov byte [mmio], 1
    and eax, 0xfffffffe
    mov [mmio_addr], eax

.use_io:
    and ax, 0xfffe
    mov [io_port], ax

    ;power card on
    xor al, al
    mov ebx, 0x52
    call write8

    ;software reset to clear buffers and registers
    mov al, 0x10
    mov ebx, 0x37
    call write8

.wait_reset:
    mov ebx, 0x37
    call read8
    and al, 0x10
    cmp al, 0
    jne .wait_reset

    mov ecx, 0x2000+16
    mov ah, 0x0a
    int 0x35
    mov [buffer_addr], esi

    ;initialize multicast registers
    xor eax, eax
    mov ebx, 0x08
    call write32
    xor eax, eax
    mov ebx, 0x0c
    call write32

    ;send address of receive buffer start location
    mov eax, esi
    mov ebx, 0x30
    call write32

    ;mark buffer as 8kib+16 bytes wide
    mov ebx, 0x44
    call read32

    and eax, ~(1 << 11)
    and eax, ~(1 << 12)

    or eax, (7 << 8)
    or eax, (7 << 13)   ;set max. DMA Burst size to unlimited

    mov al, 0x0a        ;Accept Broadcast and Acceppt Physical Match
    or al, (1 << 7)
    mov ebx, 0x44
    call write32

    ;init CAPR register
    mov ax, 0xfff0
    mov ebx, 0x38
    call write16

    mov ax, 5       ;set TOK and ROK bits
    mov ebx, 0x3c
    call write16
    mov ax, 0xffff  ;write one to clear
    mov ebx, 0x3e
    call write16

    mov al, 0x0c    ;set RE (receiver enabled) and TE (transmitter enabled) bits
    mov ebx, 0x37
    call write8

    ;read MAC address
    xor ebx, ebx
    call read8
    mov [mac_addr], al

    mov ebx, 1
    call read8
    mov [mac_addr+1], al

    mov ebx, 2
    call read8
    mov [mac_addr+2], al

    mov ebx, 3
    call read8
    mov [mac_addr+3], al

    mov ebx, 4
    call read8
    mov [mac_addr+4], al

    mov ebx, 5
    call read8
    mov [mac_addr+5], al

    call get_ip_addr

    mov edx, kernel_packet
    mov edi, interrupt_handler
    mov [edx+4], edi
    ret



;#################### FUNCTIONS ####################
write8:
    ;AL = byte to write;EBX = Offset
    cmp byte [mmio], 1
    je .use_mmio

    push edx
    movzx edx, word [io_port]
    add edx, ebx
    out dx, al
    pop edx

    ret

.use_mmio:
    push edx
    mov edx, [mmio_addr]
    add edx, ebx
    mov [edx], al
    pop edx

    ret

write16:
;AX = word to write
;EBX = Offset
    cmp byte [mmio], 1
    je .use_mmio

    push edx
    movzx edx, word [io_port]
    add edx, ebx
    out dx, ax
    pop edx

    ret

.use_mmio:
    push edx
    mov edx, [mmio_addr]
    add edx, ebx
    mov [edx], ax
    pop edx

    ret

write32:
    ;EAX = dword to write
    ;EBX = Offset
    cmp byte [mmio], 1
    je .use_mmio

    push edx
    movzx edx, word [io_port]
    add edx, ebx
    out dx, eax
    pop edx

    ret

.use_mmio:
    push edx
    mov edx, [mmio_addr]
    add edx, ebx
    mov [edx], eax
    pop edx

    ret

read8:
    ;EBX = Offset
    ;Output: EAX
    cmp byte [mmio], 1
    je .use_mmio

    push edx
    movzx edx, word [io_port]
    add edx, ebx
    in al, dx
    pop edx

    ret

.use_mmio:
    push edx
    mov edx, [mmio_addr]
    add edx, ebx
    mov al, [edx]
    pop edx

    ret

read16:
    ;EBX = Offset
    ;Output: EAX
    cmp byte [mmio], 1
    je .use_mmio

    push edx
    movzx edx, word [io_port]
    add edx, ebx
    in ax, dx
    pop edx

    ret

.use_mmio:
    push edx
    mov edx, [mmio_addr]
    add edx, ebx
    mov ax, [edx]
    pop edx

    ret

read32:
    ;EBX = Offset
    ;Output: EAX
    cmp byte [mmio], 1
    je .use_mmio

    push edx
    movzx edx, word [io_port]
    add edx, ebx
    in eax, dx
    pop edx

    ret

.use_mmio:
    push edx
    mov edx, [mmio_addr]
    add edx, ebx
    mov eax, [edx]
    pop edx

    ret

;##################### SEND PACKETS #####################
transmit_packet:
    ;EAX = size (max. 1792)
    ;EDI = physical address of packet to transmit
    cli
    pusha
    cmp eax, 1792
    ja .error

    ;call get_mac_addr

    movzx ebx, byte [current_tx]
    imul ebx, REG_OFFSET
    add ebx, TX_REG_START

    push eax
    mov eax, edi
    call write32
    pop eax

    movzx ebx, byte [current_tx]
    imul ebx, REG_OFFSET
    add ebx, TX_REG_STATUS

    and eax, ~(1 << 13)
    call write32

    inc byte [current_tx]
    cmp byte [current_tx], 4
    jb .skip

    mov byte [current_tx], 0

.skip:
    popa
    clc
    ret
.error:
    popa
    stc
    ret

get_mac_addr:
    ;EDX = IPv4 addr
    pusha
    mov ecx, 64
    mov ah, 0x0a
    int 0x35

    push esi
    push ecx

    ;header
    mov dword [esi], 0xffffffff     ;destination MAC address
    mov word [esi+4], 0xffff        ;destination MAC address
    mov eax, [mac_addr]
    mov [esi+6], eax                ;source MAC address
    mov ax, [mac_addr+4]
    mov [esi+10], ax                ;source MAC address

    mov eax, 0x0806
    call swap
    mov [esi+12], ax                ;ARP-Packet

    ;ARP data
    mov word [esi+14], 0x0100            ;hardware type: ethernet (0x0001 but big endian)
    mov word [esi+16], 0x0008            ;protocol type: IPv4 (0x0800 but big endian)

    mov byte [esi+18], 0x06
    mov byte [esi+19], 0x04
    mov word [esi+20], 0x0100            ;request
    mov al, [mac_addr]
    mov [esi+22], al
    mov al, [mac_addr+1]
    mov [esi+23], al
    mov al, [mac_addr+2]
    mov [esi+24], al
    mov al, [mac_addr+3]
    mov [esi+25], al
    mov al, [mac_addr+4]
    mov [esi+26], al
    mov al, [mac_addr+5]
    mov [esi+27], al

    popa
    ret

get_ip_addr:
    ;ask router for our IP address

    push esi
    push edi
    push eax

    mov esi, get_ip_packet

    mov al, [mac_addr]
    mov [esi+6], al
    mov al, [mac_addr+1]
    mov [esi+7], al
    mov al, [mac_addr+2]
    mov [esi+8], al
    mov al, [mac_addr+3]
    mov [esi+9], al
    mov al, [mac_addr+4]
    mov [esi+10], al
    mov al, [mac_addr+5]
    mov [esi+11], al

    mov al, [mac_addr]
    mov [esi+70], al
    mov al, [mac_addr+1]
    mov [esi+71], al
    mov al, [mac_addr+2]
    mov [esi+72], al
    mov al, [mac_addr+3]
    mov [esi+73], al
    mov al, [mac_addr+4]
    mov [esi+74], al
    mov al, [mac_addr+5]
    mov [esi+75], al

    push esi
    add esi, 14
    mov ecx, 10
    call compute_rfc1071_checksum
    pop esi
    mov [esi+24], ax

    mov edi, esi
    mov eax, 286
    call transmit_packet

    pop eax
    pop edi
    pop esi
    ret

;############################## INTERRUPT HANDLER ##############################
interrupt_handler:
    pusha
    mov ebx, 0x3c
    call read16
    test ax, ax
    jz .done    ;shared IRQ

    push ax

    test ax, (1 << 0)
    jz .packet_received_err

    call handle_received_packet

.packet_received_err:
    test ax, (1 << 1)
    jz .transmit_ok

    call handle_receive_err

.transmit_ok:
    test ax, (1 << 2)
    jz .transmit_error

    call transmit_okay

.transmit_error:
    test ax, (1 << 3)
    jz .buffer_overflow

call handle_transmit_error

.buffer_overflow:
    test ax, (1 << 4)
    jz .done

    call handle_buffer_overflow

.done:
    pop ax

    mov ebx, 0x3c
    call write16
    popa
    ret

handle_received_packet:
    push eax
    xor ecx, ecx
    mov ebx, 0x38
    call read16

    add ax, 16
    movzx edx, ax
    mov edi, [buffer_addr]
    add edi, edx

    ; cli
    ; hlt
    ;copy buffer into ram...

    movzx ecx, word [edi+2]
    add edx, ecx
    add dx, 4

    add edx, 3
    and edx, 0xfffffffc

    cmp dx, 0x2000
    jb .skip

    sub dx, 0x2000

.skip:
    sub edx, 16
    mov ax, dx

    mov ebx, 0x38
    call write16
    pop eax

    inc dword [receive_success_count]
    mov edx, [receive_success_count]
    mov edi, [kernel_packet]
    mov [edi+24], edx

    ret

handle_receive_err:
    push eax
    mov ebx, 0x38
    call read16

    add ax, 16
    movzx edx, ax
    mov edi, [buffer_addr]
    add edi, edx
    mov dx, [edi+2]
    add dx, ax
    add dx, 4
    cmp dx, 0x2000+16
    jb .skip

    sub dx, 0x2000

.skip:
    sub dx, 16
    mov ax, dx

    mov ebx, 0x38
    call write16
    pop eax

    inc dword [receive_error_count]
    mov edx, [receive_error_count]
    mov edi, [kernel_packet]
    mov [edi+20], edx
    ret

transmit_okay:
    inc dword [transmit_success_count]
    mov edx, [transmit_success_count]
    mov edi, kernel_packet
    mov [edi+16], edx
    ret

handle_buffer_overflow:
    push eax
    mov ebx, 0x37
    call read8

    and al, ~(1 << 3)   ;clear receiver enable bit

    ;read buffer...

    mov ebx, 0x3e
    call read16

    or ax, (1 << 4)
    call write16

    mov ebx, 0x37
    call read8
    or al, (1 << 3)     ;set receiver enable bit again
    pop eax
    ret

handle_transmit_error:
    push eax
    mov ebx, 0x10
    call read32
    or eax, (1 << 13) ;set own bitcall write32

    mov ebx, 0x14
    call read32
    or eax, (1 << 13) ;set own bit
    call write32

    mov ebx, 0x18
    call read32
    or eax, (1 << 13) ;set own bit
    call write32

    mov ebx, 0x1c
    call read32
    or eax, (1 << 13) ;set own bit
    call write32

    inc dword [transmit_error_count]
    mov edx, [transmit_error_count]
    mov edi, kernel_packet
    mov [edi+12], edx
    pop eax
    ret

swap:
    ;swap bytes in EAX
    push ebx
    xor ebx, ebx
    mov bx, ax
    xchg bh, bl
    shl ebx, 16
    shr eax, 16
    mov bx, ax
    xchg bh, bl
    mov eax, ebx
    pop ebx
    ret

change_mac:
    ;EAX = bytes 0-3 (big endian!)
    ;BX = bytes 4 and 5 (big endian!)
    push ecx
    push ebx
    mov ecx, 3

    xor ebx, ebx
    call write8

.loop:
    shr eax, 8
    add ebx, 4
    call write8
    dec ecx
    jnz .loop

    pop ebx
    mov ax, bx
    mov ebx, 16
    call write8

    shr ax, 8
    add ebx, 4
    call write8

    pop ecx
    clc
    ret

compute_rfc1071_checksum:
    ;ESI = pointer to IP-Header (offset 14)
    ;ECX = length to compute (in words)
    ;Output of Checksum in AX
    push ecx
    push edx

    xor eax, eax

.loop:
    movzx edx, word [esi]
    xchg dl, dh
    add eax, edx
    add esi, 2
    dec ecx
    jnz .loop

.check_carry:
    mov edx, eax
    shr edx, 16
    and eax, 0xffff
    add eax, edx
    cmp eax, 0xffff
    ja .check_carry

    not ax      ;invert bits
    xchg al, ah

    pop edx
    pop ecx
    ret

section .data
mmio: db 0      ;0 = card uses IO ports, 1 = card uses MMIO
mmio_addr: dd 0
io_port: dw 0
buffer_addr: dd 0
buffer_off: dd 0

REG_OFFSET      equ 4
current_tx: db 0
TX_REG_STATUS   equ 0x10
TX_REG_START    equ 0x20

kernel_packet:
    dd 0        ;transmit_packet()
    dd 0        ;interrupt handler()

    dd 0        ;IPv4 address

    dd 0        ;transmit_error_count
    dd 0        ;transmit_success_count

    dd 0        ;receive_error_count
    dd 0        ;receive_success_count

transmit_error_count: dd 0
transmit_success_count: dd 0
receive_error_count: dd 0
receive_success_count: dd 0
carp_offset: dw 0

mac_addr:
    dd 0
    dw 0
ip_addr: dd 0

get_ip_packet:
    ;ethernet header
    dd 0xffffffff   ;destination MAC address (broadcast)
    dw 0xffff
    dw 0, 0, 0      ;source MAC
    dw 0x0008       ;EtherType: IPv4

    ;IPv4 header
    db 0x45         ;IPv4, header-length 20 bytes
    db 0
    dw 0x1001       ;little endian: 0x128 (total packet length)
    dw 0x1234       ;ID
    dw 0            ;no fragmentation
    db 0x80         ;times to live
    db 0x11         ;protocol: UDP
    dw 0            ;header checksum
    dd 0            ;source IP
    dd 0xffffffff   ;destination IP

    ;UDP header
    db 0, 68    ;source port
    db 0, 67    ;destination port
    dw 0xfc00   ;length
    dw 0        ;checksum

    db 1    ;message type: boot request
    db 1    ;hardware type: ethernet
    db 6    ;hardware address length: 6
    db 0
    dd 0x77777777   ;transaction ID
    dw 0
    dw 0x0080       ;flags: broadcast
    dd 0            ;client IP (CIADDR)
    dd 0            ;your IP (YIADDR)
    dd 0            ;next server IP (SIADDR)
    dd 0            ;relay Agent IP (GIADDR)

    times 6 db 0    ;client MAC address
    times 10 db 0   ;padding

    times 64 db 0   ;server host name
    times 128 db 0  ;boot file name
    dd 0x63825363   ;magic cookie

    db 53           ;option 53
    db 1            ;length 1
    db 1
    db 0xff         ;end of packet