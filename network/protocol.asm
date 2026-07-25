;============================================================================================
;Part of the network stack
;Copyright (C) 2026 Technodon
;-------------------------------
;Application
;Protocol       <
;IP
;Driver
;============================================================================================


section .text
start:
    ;returns in EDX a strucure
    ;EDX+0: add_udp_header()           (protocol)
    ;EDX+4: add_tcp_header()           (protocol)
    ;EDX+8: add_arp_header()           (protocol)
    ;EDX+12: add_icmp_header()          (protocol)

    ;EDX+16: process_packet_udp()       (protocol)
    ;EDX+20: process_packet_tcp()       (protocol)
    ;EDX+24: process_packet_icmp()      (protoclo)
    ;EDX+28: process_packet_arp()       (protocol)

    ;on second call:
    ;EBX = pointer to NET_INTERFACE structure
    ;EBX+16: add_ipheader()
    ;EBX+56: application_packet()
    cmp byte [run], 1
    je .second

    mov edx, kernel_packet
    mov dword [edx], add_udp_header
    mov dword [edx+4], add_tcp_header
    mov dword [edx+8], add_arp_header
    mov dword [edx+12], add_icmp_header

    mov dword [edx+16], process_packet_udp
    mov dword [edx+20], process_packet_tcp
    mov dword [edx+24], process_packet_icmp
    mov dword [edx+28], process_packet_arp

    mov byte [run], 1
    ret
.second:
    mov eax, [ebx+16]
    mov [add_ipheader], eax
    mov eax, [ebx+56]
    mov [application_packet], eax
    ret


;#####################################################################################
;################################### ADD UDP HEADER ##################################
;#####################################################################################
add_udp_header:
    ;EAX (bit 16-31): destination port
    ;EAX (bit 0-15): source port
    ;ECX = length of packet
    ;EDX = IPv4 address
    ;ESI = pointer to packet
    cli

    push eax
    push esi
    push ecx
    mov ecx, 0x1000
    mov ah, 0x0a
    int 0x35
    mov [heap], esi
    mov [size], ecx
    pop ecx
    pop esi
    pop eax
    jc .error
    cld

    push edx

    mov edi, [heap]
    add edi, 42      ;leave space for UDP Header + IPv4 header + Ethernet header
    push ecx
    rep movsb

    pop ecx
    mov bx, ax  ;source port
    shr eax, 16 ;destination port

    mov esi, [heap]
    xchg bl, bh
    mov [esi+34], bx ;set source port
    xchg al, ah
    mov [esi+36], ax   ;set destination port

    mov dx, cx
    add dx, 8
    xchg dl, dh
    mov [esi+38], dx
    mov word [esi+40], 0     ;no checksum

    pop edx
    mov al, 0x11    ;UDP
    mov bx, 8       ;header size
    call dword [add_ipheader]

    mov esi, [heap]
    mov ecx, [size]
    mov ah, 0x0b
    int 0x35

    sti
    clc
    ret
.error:
    stc
    ret
add_tcp_header:
    ret
add_arp_header:
    ret
add_icmp_header:
    ret

process_packet_udp:
    ;ESI = pointer to UDP header in packet
    ;ECX = length of payload + UDP Header
    ;EDX = source IPv4 address
    pusha
    mov bx, [esi]
    mov ax, [esi+2]
    add esi, 8
    call dword [application_packet]
    popa
    ret
process_packet_tcp:
    ret
process_packet_icmp:
    ret
process_packet_arp:
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

section .data
kernel_packet:
    dd 0
    dd 0
    dd 0
    dd 0

    dd 0
    dd 0
    dd 0
    dd 0

run: db 0
add_ipheader: dd 0
application_packet: dd 0
heap: dd 0
size: dd 0