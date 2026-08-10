;============================================================================================
;Part of the network stack
;Copyright (C) 2026 Technodon
;-------------------------------
;Application
;Protocol
;IP             <
;Driver
;============================================================================================

section .text
start:
    ;expects pointer to list of functions in EAX:
    ;EAX+0: transmit_packet()
    ;EAX+4: double pointer to buffer with packets (will be increased per packet)
    ;EAX+8: (6 bytes) MAC address
    ;EAX+14: (WORD) pointer to 16bit variable packet_size (if zero than there is no current packet to process)

    ;returns in EDX a pointer to function add_ipheader()

    ;on second call:

    ;EBX = pointer to NET_INTERFACE structure
    ;EBX+40: process_packet_udp()
    ;EBX+44: process_packet_tcp()
    ;EBX+48: process_packet_icmp()
    ;EBX+52: process_packet_arp()

    cmp byte [run], 1
    je .second

    mov ebx, [eax]
    mov [transmit_packet], ebx
    mov ebx, [eax+4]
    mov [cur_buffer_addr], ebx
    mov ebx, [ebx]
    mov [buffer_addr], ebx

    mov ebx, [eax+14]
    mov [packet_size], ebx

    mov esi, eax
    add esi, 8
    mov ecx, 6
    mov edi, mac_addr
    rep movsb

    mov ah, 0x13
    mov ebx, check_packets
    mov esi, taskname
    int 0x35

    mov byte [run], 1

    mov ah, 0x0a
    mov ecx, 0x1000
    int 0x35
    mov [mac_buffer], esi
    mov edi, esi
    mov ecx, MAC_BUFFER_ENTRIES
    xor eax, eax
    rep stosd

    mov edx, add_ipheader
    ret

.second:
    mov [net_interface], ebx
    mov ecx, [ebx+40]
    mov [process_packet_udp], ecx
    mov ecx, [ebx+44]
    mov [process_packet_tcp], ecx
    mov ecx, [ebx+48]
    mov [process_packet_icmp], ecx
    mov ecx, [ebx+52]
    mov [process_packet_arp], ecx

    ret

check_packets:
    mov edi, [packet_size]
    cmp word [edi], 0
    je .yield

    cli
    call process_packet
.yield:
    int 0x20
    jmp check_packets

    mov ah, 0x05
    int 0x35


increase_buffer_ptr:
    ;ECX = size of packet in bytes
    push esi
    push edi
    push eax

    mov esi, [cur_buffer_addr]
    mov eax, [esi]
    add eax, ecx
    mov [esi], eax

    mov edi, [buffer_addr]
    add edi, 0x2000
    cmp eax, edi
    jb .skip

    mov eax, edi
    mov [esi], eax
.skip:

    pop eax
    pop edi
    pop esi
    ret


process_packet:
    cli
    pusha
    mov edi, [cur_buffer_addr]
    mov edi, [edi]
    mov ax, [edi+12]
    cmp ax, 0x0008          ;0x0800: IPv4 packet
    je .process_ipv4_header
    cmp ax, 0x0608
    je .process_arp_packet
    
    ;ignore IPv6
.done:
    mov ecx, [packet_size]
    mov bx, [ecx]
    mov word [ecx], 0
    movzx ecx, bx
    call increase_buffer_ptr
    sti
    popa
    ret

.process_ipv4_header:
    push edi
    add edi, 14

    movzx eax, byte [edi]
    mov bl, al
    shr bl, 4
    cmp bl, 4
    jne .no_ipv4

    and al, 0x0f
    imul eax, 4

    mov esi, edi
    add esi, eax

    push esi
    
    mov ecx, [packet_size]
    movzx ecx, word [ecx]
    sub ecx, eax    ;IPv4 header
    sub ecx, 14     ;Ethernet header

    mov al, [edi+9]
    cmp al, 0x11
    je .udp_packet
    cmp al, 0x01
    je .ping
    cmp al, 0x06
    je .tcp_packet

.done_ipv4:
    pop esi

    pop edi
    jmp .done
.no_ipv4:
    pop edi
    jmp .done

.udp_packet:
    mov edx, [edi+12]
    call dword [process_packet_udp]
    jmp .done_ipv4
.tcp_packet:
    jmp .done_ipv4
.ping:
    mov edx, [edi+12]
    call dword [process_packet_icmp]
    jmp .done_ipv4


.process_arp_packet:
    mov esi, [net_interface]
    mov eax, [esi]

    mov ebx, [edi+38]
    cmp eax, ebx
    jne .done

    mov ebx, [edi+28]   ;IPv4 address of sender

    cmp word [edi+20], 0x0100
    je .check_reply

    mov esi, edi
    add esi, 22

    mov edi, [mac_buffer]
    mov ecx, [mac_buffer_off]
    add edi, ecx
    mov [edi], ebx  ;store IPv4 address
    add edi, 4
    mov ecx, 6
    rep movsb       ;store MAC Address

    mov ecx, [mac_buffer_off]
    add ecx, MAC_BUFFER_ENTRY
    cmp ecx, 0x1000
    jb .skip

    xor ecx, ecx
.skip:
    mov [mac_buffer_off], ecx
    jmp .done
.check_reply:
    mov esi, arp_reply_packet
    mov [esi+28], eax   ;set our own IP
    mov [esi+38], ebx   ;set destination IP

    ;set destination MAC
    mov eax, [edi+6]
    mov [esi+32], eax
    mov [esi], eax
    mov ax, [edi+10]
    mov [esi+36], ax
    mov [esi+4], ax

    ;set our own MAC
    mov ebx, [mac_addr]
    mov [esi+6], ebx
    mov [esi+22], ebx
    mov bx, [mac_addr+4]
    mov [esi+10], bx
    mov [esi+26], bx

    mov edi, arp_reply_packet
    mov eax, ARP_PACKET_SIZE
    call dword [transmit_packet]
    jmp .done

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

add_ipheader:
    ;ESI = pointer to packet
    ;ECX = packet size (only user data)
    ;EDX = IPv4 address
    ;AL = protocol
    ;BX = header size

    ;mov [test1], al
    mov [header_size], bx
    ;IPv4 header
    mov byte [esi+14], 0x45
    mov byte [esi+15], 0
    mov ebx, ecx

    add ebx, 20     ;packet length with header + IPv4 header
    movzx ebp, word [header_size]
    add ebx, ebp

    xchg bl, bh
    mov [esi+16], bx
    
    mov bx, [ethernet_id]
    mov word [esi+18], bx
    inc word [ethernet_id]

    mov word [esi+20], 0
    mov byte [esi+22], 0x80  ;time to live
    mov byte [esi+23], al
    mov word [esi+24], 0
    ;ESI+24 = checksum (WORD)

    mov ebx, [net_interface]
    mov ebx, [ebx]  ;own IP address
    mov [esi+26], ebx   ;source IP
    mov [esi+30], edx   ;destination IP

    ;ethernet header
    mov dword [esi], 0xffffffff
    mov word [esi+4], 0xffff

    cmp edx, 0xffffffff     ;check if IP is broadcast
    je .skip_mac

    ;check if IP is out of network
    push edi
    push ecx

    mov edi, [net_interface]
    mov ebp, [edi+60]   ;get subnet mask
    mov eax, edx
    and eax, ebp

    mov ecx, [edi+4]    ;get gateway IP
    and ecx, ebp

    cmp eax, ecx

    pop ecx
    pop edi
    jne .global_net

    ;get MAC address of IPv4 address
    push eax
    push ebx

    call get_mac_addr

    mov [esi], eax
    mov [esi+4], bx
    
    pop ebx
    pop eax

.skip_mac:
    push esi
    push ecx
    add esi, 6
    mov edi, esi
    mov ecx, 6
    mov esi, mac_addr
    rep movsb
    pop ecx
    pop esi

    mov dx, 0x0800  ;IPv4
    xchg dl, dh
    mov [esi+12], dx

    ;get checksum
    push esi
    push ecx
    add esi, 14
    mov ecx, 10
    call compute_rfc1071_checksum
    pop ecx 
    pop esi
    mov [esi+24], ax

    mov edi, esi
    mov eax, ecx
    movzx ebx, word [header_size]
    add eax, 20+14
    add eax, ebx

;     cmp byte [test1], 1
;     jne .skip1
 
;     cli
;     hlt
; .skip1:

    call dword [transmit_packet]
    jc .error

    clc
    ret

.global_net:
    push edi
    mov edi, [net_interface]
    mov edx, [edi+8]

    call get_mac_addr

    mov [esi], eax
    mov [esi+4], bx

    pop edi
    jmp .skip_mac

.error:
    stc
    ret

get_mac_addr:
    ;get MAC address of IP using ARP
    ;EDX = IPv4

    ;EtherType:
    ;0x0800 = IPv4
    ;0x0806 = ARP
    ;0x86DD = IPv6

    ;Outputs MAC address in EAX (byte 0-3) and BX (byte 4 and 5)
    push edi
    push esi
    push ecx

    mov esi, [mac_buffer]
    mov ecx, MAC_BUFFER_ENTRIES
.loop:
    cmp dword [esi], edx
    je .found_mac

    cmp dword [esi], 0
    je .skip

    add esi, MAC_BUFFER_ENTRY
    dec ecx
    jnz .loop

.skip:
    mov edi, arp_packet
    mov [edi+38], edx
    mov esi, mac_addr
    add edi, 6
    mov ecx, 6
    rep movsb       ;copy our MAC address

    mov esi, mac_addr
    mov edi, arp_packet
    add edi, 22
    mov ecx, 6
    rep movsb

    push edx
    mov esi, [net_interface]
    mov edx, [esi]      ;get our IP address
    
    mov edi, arp_packet
    mov [edi+28], edx
    mov dword [edi], 0xffffffff
    mov word [edi+4], 0xffff
    mov eax, ARP_PACKET_SIZE
    call dword [transmit_packet]
    pop edx

.wait:
    int 0x20
    mov esi, [mac_buffer]
    mov ecx, MAC_BUFFER_ENTRIES
.wait_response:
    cmp [esi], edx
    je .found

    add esi, MAC_BUFFER_ENTRY
    dec ecx
    jnz .wait_response
    jmp .wait
.found:
    mov eax, [esi+4]
    movzx ebx, word [esi+8]

    pop ecx
    pop esi
    pop edi
    ret
.found_mac:
    mov eax, [esi+4]
    movzx ebx, word [esi+8]

    pop ecx
    pop esi
    pop edi
    ret
section .data
run: db 0
transmit_packet: dd 0
buffer_addr: dd 0
cur_buffer_addr: dd 0
packet_size: dd 0
mac_addr: times 3 dw 0
net_interface: dd 0

process_packet_udp: dd 0
process_packet_tcp: dd 0
process_packet_icmp: dd 0
process_packet_arp: dd 0
ethernet_id: dw 0

taskname: db 'NETCHECKSYS', 0
header_size: dw 0

arp_packet:
    ;ethernet header
    times 3 dw 0    ;destination MAC (for example ff:ff:ff:ff:ff:ff)
    times 3 dw 0    ;source MAC (our own MAC address)
    dw 0x0608       ;EtherType: ARP (big endia: 0x0806)

    ;ARP header
    dw 0x0100       ;htype: Ethernet (big endian: 0x0001)
    dw 0x0008       ;ptype: IPv4 (big endian: 0x0800)
    db 6            ;MAC length
    db 4            ;IP length
    dw 0x0100       ;ARP request

    times 3 dw 0    ;sender MAC (our MAC)
    dd 0            ;sender IPv4 (our IPv4)

    times 3 dw 0    ;destination MAC (empty, because we dont know it)
    dd 0            ;destination IPv4 address
ARP_PACKET_SIZE     equ 42

arp_reply_packet:
    times 3 dw 0
    times 3 dw 0
    dw 0x0608

    dw 0x0100
    dw 0x0008
    db 6
    db 4
    dw 0x0200

    times 3 dw 0    ;own MAC
    dd 0            ;own IP

    times 3 dw 0    ;destination MAC
    dd 0            ;destination IP

arp_received:
    db 0
    dd 0

mac_buffer_off: dd 0
mac_buffer: dd 0
    ;ENTRY
    ;dd 0                    ;IP Address    (big endian)
    ;db 1, 2, 3, 4, 5, 6     ;MAC Address   (big endian)
MAC_BUFFER_ENTRY    equ 10
MAC_BUFFER_ENTRIES  equ 0x1000/4

test1: db 0