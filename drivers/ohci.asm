;====================================================
;USB driver for OHCI
;Copyright (C) 2026 Technodon
;====================================================

bits 32
[org 0x61000]
;=========OHCI=========
get_ohci_devices:
    ;Gets: EAX = OHCI BASE
    pusha
    mov [ohci_base], eax
    cmp dword [ohci_base], 0
    je .done                ;no OHCI controller found

    mov eax, [ohci_base]
    or dword [eax+8], 1     ;set Bit 0 to reset controller

.wait_reset_end:
    mov edi, [eax+8]
    test edi, 1
    jnz .wait_reset_end

    mov edi, hcca
    mov [eax+0x18], edi     ;set Host Controller Communications Area
    
    mov ecx, 0x80000002     ;set Bit 1 and Bit 31 (Writeback Done Head & Master Interrupt Enable)
    mov [eax+0x10], ecx     ;InterruptEnable
    mov ecx, [eax+0x48]
    and ecx, 0xff
    mov esi, 0x54
    xor ebx, ebx

.loop:
    push esi
    add esi, eax
    mov edx, [esi]
    pop esi

    test edx, 1
    jz .next_port

    call init_ohci_port     ;send GET_DESCRITOR and set address
.next_port:
    inc ebx
    add esi, 4
    dec ecx
    jnz .loop
.done:
    popa
    clc
    ret

;==== INIT OHCI PORT - GET_DESCRIPTOR and set address ====
init_ohci_port:
    ;EAX = [ohci_base]
    ;ESI = port offset (0x54 = 1. Port, 0x58 = 2. Port...)
    ;-----------------------------
    ;1: Send a GET_DESCRIPTOR (type 0x01, device descriptor)
    ;2: Set the Address of device
    ;3: Send a GET_DESCRITPOR again but with type 0x02 to get the full lenght of all descriptors
    ;4: Send a GET_DESCRIPTOR again but with the full lenght set, so we can read the interface descriptor to see what devices are there (keyboard, usb-stick,...)
    pusha
    push eax
    add esi, eax
    mov dword [esi], 16     ;set Bit 4 (reset status)

.wait_reset:
    mov eax, [esi]
    test eax, 16
    jnz .wait_reset
    pop eax

    ;set controller into operational mode
    mov edi, [eax+4]
    and edi, 0xbf               ;rm Bit 6
    or edi, 128                 ;set Bit 7 (set operational mode)
    mov [eax+4], edi

    mov dword [esi], 2          ;set bit 1 (PortEnable)

    ;GET_DESCRIPTOR (device descriptor)
    ;connect TDs
    mov edi, td_data
    mov [td_setup+8], edi        ;NextTD is on offset 8

    mov edi, td_status
    mov [td_data+8], edi

    mov edi, td_empty
    mov [td_status+8], edi

    mov dword [td_empty+8], 0
    push ebx
    ;fill TDs
    mov ebx, ohci_setup_packet  ;address of 1.Byte in transfer buffer
    mov [td_setup+4], ebx
    mov ebx, ohci_setup_packet+7    ;address of last byte in transfer buffer
    mov [td_setup+12], ebx
    mov dword [td_setup], 0xfe200000         ;direction = SETUP (00b),  no interrupts

    mov ebx, ohci_descriptor_buffer
    mov [td_data+4], ebx
    mov ebx, ohci_descriptor_buffer+17
    mov [td_data+12], ebx
    mov dword [td_data], 0xfe100000  ;direction = IN + data toggle, no interrupts

    mov dword [td_status+4], 0
    mov dword [td_status+12], 0
    mov dword [td_status], 0xfe080000    ;OUT, no int, data toggle

    mov ebx, td_empty
    mov [control_ed+4], ebx
    mov ebx, td_setup
    mov [control_ed+8], ebx

    mov dword [control_ed], 0x00080000  ;max packet size
    or dword [control_ed], 8192         ;set Bit 13
    pop ebx

    mov edi, control_ed
    mov [eax+0x20], edi

    or dword [eax+4], 16    ;control list enable
    or dword [eax+8], 2    ;control list filled

    push eax
.wait_controller:
    mov eax, [td_data]
    shr eax, 28
    and eax, 0x0f

    cmp eax, 0x0f
    je .wait_controller

    cmp eax, 0
    jne .init_port_error

    pop eax


    ;SET_ADDRESS
    push ebx
    inc bx
    mov [set_address_packet+2], bx

    mov edi, td_status
    mov [td_setup+8], edi
    
    mov edi, td_empty
    mov dword [td_status+8], edi

    ;fill setup TD
    mov ebx, td_setup
    mov edi, set_address_packet
    mov [ebx+4], edi
    mov edi, set_address_packet+7
    mov [ebx+12], edi
    mov dword [ebx], 0xfe200000         ;SETUP / DATA0

    ;fill status TD
    mov dword [td_status+4], 0
    mov dword [td_status+12], 0
    mov dword [td_status], 0xfe100000        ;IN
    pop ebx
    add ebx, 1

    mov edi, td_setup
    mov [control_ed+8], edi     ;HeadP = first TD
    mov edi, td_empty
    mov [control_ed+4], edi     ;TailP = last TD

    or dword [eax+8], 2         ;set ControlListFilled to active

    push eax
.wait_address:
    mov eax, [td_status]
    shr eax, 28
    and eax, 0x0f
    cmp eax, 0x0f
    je .wait_address

    cmp eax, 0
    jne .init_port_error
    pop eax

    ;update address in control_ed
    mov edi, [control_ed]
    and edi, 0xffffff80
    or edi, ebx         ;set address
    mov [control_ed], edi

    ;GET_DESCRIPTOR 2 (configuration descriptor, not device)

    mov byte [ohci_setup_packet+3], 0x02        ;configuration descriptor
    mov word [ohci_setup_packet+6], 9           ;read 9 bytes

    ;connect TDs
    mov edi, td_data
    mov [td_setup+8], edi        ;NextTD is on offset 8

    mov edi, td_status
    mov [td_data+8], edi

    mov edi, td_empty
    mov [td_status+8], edi

    mov dword [td_empty+8], 0

    push ebx
    ;fill TDs
    mov ebx, ohci_setup_packet  ;address of 1.Byte in transfer buffer
    mov [td_setup+4], ebx
    mov ebx, ohci_setup_packet+7    ;address of last byte in transfer buffer
    mov [td_setup+12], ebx
    mov dword [td_setup], 0xfe200000         ;direction = SETUP (00b),  no interrupts

    mov ebx, ohci_descriptor_buffer
    mov [td_data+4], ebx
    mov ebx, ohci_descriptor_buffer+8
    mov [td_data+12], ebx
    mov dword [td_data], 0xfe100000  ;direction = IN + data 0, no interrupts

    mov dword [td_status+4], 0
    mov dword [td_status+12], 0
    mov dword [td_status], 0xfe080000    ;OUT, no int, data toggle

    mov ebx, td_empty
    mov [control_ed+4], ebx
    mov ebx, td_setup
    mov [control_ed+8], ebx
    pop ebx

    or dword [eax+8], 2    ;control list filled

    push eax
.wait_controller2:
    mov eax, [td_data]
    shr eax, 28
    and eax, 0x0f

    cmp eax, 0x0f
    je .wait_controller2

    cmp eax, 0
    jne .init_port_error
    pop eax

    ; mov edi, [ohci_descriptor_buffer]
    ; cli
    ; hlt

    ;get total length
    movzx ecx, word [ohci_descriptor_buffer+2]
    cmp ecx, 9
    jb .init_port_error                                   ;check if value is valid

    mov [ohci_setup_packet+6], cx

    mov edi, td_data
    mov [td_setup+8], edi
    mov edi, td_status
    mov [td_data+8], edi
    mov edi, td_empty
    mov [td_status+8], edi
    mov dword [td_empty+8], 0

    mov edi, ohci_setup_packet
    mov [td_setup+4], edi
    mov edi, ohci_setup_packet+7
    mov [td_setup+12], edi

    mov edi, ohci_descriptor_buffer
    mov [td_data+4], edi
    add edi, ecx
    dec edi
    mov [td_data+12], edi

    mov dword [td_setup], 0xfe200000        ;SETUP, data0
    mov dword [td_data], 0xfe100000         ;IN, data1
    mov dword [td_status], 0xfe080000       ;OUT, data1

    mov edi, td_setup
    mov [control_ed+8], edi
    mov edi, td_empty
    mov [control_ed+4], edi

    or dword [eax+8], 2

    push eax
.wait_controller3:
    mov eax, [td_data]
    shr eax, 28
    and eax, 0x0f

    cmp eax, 0x0f
    je .wait_controller3

    cmp eax, 0
    jne .init_port_error
    pop eax

    ;SET_CONFIGURATION
    push eax
    movzx eax, byte [ohci_descriptor_buffer+5]
    mov byte [ohci_setup_packet], 0
    mov byte [ohci_setup_packet+1], 0x09   ;set configuration

    mov [ohci_setup_packet+2], al
    pop eax
    mov byte [ohci_setup_packet+3], 0
    mov word [ohci_setup_packet+4], 0
    mov word [ohci_setup_packet+6], 0

    mov edi, td_status
    mov [td_setup+8], edi

    mov edi, td_empty
    mov [td_status+8], edi
    mov dword [td_empty+8], 0

    mov edi, ohci_setup_packet
    mov [td_setup+4], edi
    mov edi, ohci_setup_packet+7
    mov [td_setup+12], edi

    mov dword [td_setup], 0xfe200000    ;not accessed, SETUP, DATA0
    mov dword [td_status], 0xfe100000
    mov dword [td_status+4], 0
    mov dword [td_status+12], 0

    mov edi, td_empty
    mov [control_ed+4], edi

    mov edi, td_setup
    mov [control_ed+8], edi

    or dword [eax+8], 2
    push eax
.wait_controller4:
    mov eax, [td_status]
    shr eax, 28
    and eax, 0x0f

    cmp eax, 0x0f
    je .wait_controller4

    cmp eax, 0
    jne .init_port_error
    pop eax


    ;GET USB DEVICE
    mov edi, ohci_descriptor_buffer
    add edi, 9

    push eax
    cmp byte [edi], 9                         ;length of packet should be 9 bytes
    jne .init_port_error
    cmp byte [edi+1], 4
    jne .init_port_error
    pop eax

    ;OFF +5 (+14): bInterfaceClass
    ;OFF +6 (+15): bInterfaceSubClass
    ;OFF +7 (+16): bInterfaceProtocol
    cmp byte [edi+5], 0x03      ;HID
    je .hid_device
    cmp byte [edi+5], 0x02
    je .printer
    cmp byte [edi+5], 0x08      ;Mass Storage
    je .mass_storage
    cmp byte [edi+5], 0x09
    je .usb_hub

.done:
    mov esi, USB_DEVICE_LIST
    add esi, dword [usb_list_offset]
    mov dword [esi], 0xeeeeeeee     ;set end of list
    mov byte [ohci_descriptor_buffer], 0x80
    mov byte [ohci_descriptor_buffer+1], 0x06
    mov byte [ohci_setup_packet+3], 0x01        ;set device descriptor (for next port)
    mov word [ohci_setup_packet+6], 18          ;set packet size to 18 bytes (for next port)
    clc
    popa
    ret

.hid_device:
    cmp byte [edi+6], 0x01      ;Boot interface / 0x00 = No subclass
    ja .unknown
    cmp byte [edi+7], 0x01
    je .hid_keyboard
    cmp byte [edi+7], 0x0
    je .hid_mouse

    jmp .unknown

.hid_keyboard:
    mov esi, USB_DEVICE_LIST
    add esi, dword [usb_list_offset]
    mov dword [esi], 1
    add dword [usb_list_offset], 4

    ;GET ENDPOINT DESCRIPTOR
    mov edi, ohci_descriptor_buffer
    add edi, 9              ;skip configuration descriptor
.find_ep:
    cmp byte [edi+1], 5
    je .found_endpoint

    movzx edx, byte [edi]

    push eax
    test edx, edx
    jz .init_port_error
    pop eax

    add edi, edx
    jmp .find_ep

    ;SET ED
.found_endpoint:
    ;EDI + 2: Endpoint Address
    ;EDI + 3: Attributes
    ;EDI + 4: max. Packet Size
    ;EDI +6: Intervall
    
    mov edx, ebx        ;set function address

    movzx ecx, byte [edi+2]
    push ecx
    and ecx, 0x0f
    shl ecx, 7
    or edx, ecx         ;set endpoint address

    pop ecx
    test cl, 0x80
    jz .direction_out

    or edx, (1 << 12)       ;set direction
.direction_out:
    or edx, (1 << 13)       ;set Low Speed

    movzx ecx, word [edi+4]
    shl ecx, 16
    or edx, ecx

    mov [usb_keyboard_ed], edx

    mov edx, td_empty
    mov [usb_keyboard_ed+4], edx

    mov edx, usb_keyboard_td
    mov [usb_keyboard_ed+8], edx

    mov dword [usb_keyboard_ed+12], 0   ;set last ED


    ;SET TD
    xor edx, edx
    or edx, (2 << 19)       ;direction: IN
    or edx, (2 << 24)       ;toggle CARRY
    or edx, (15 << 28)      ;set status - not accessed
    mov [usb_keyboard_td], edx

    mov edx, usb_keyboard_buffer
    mov [usb_keyboard_td+4], edx

    mov edx, td_empty
    mov [usb_keyboard_td+8], edx

    mov edx, usb_keyboard_buffer+7
    mov [usb_keyboard_td+12], edx

    mov edi, td_empty
    mov dword [edi], 0
    mov dword [edi+4], 0
    mov dword [edi+8], 0
    mov dword [edi+12], 0

    mov edi, hcca
    add edi, [.hcca_offset]


    mov edx, usb_keyboard_ed
    mov [edi], edx
    or dword [eax+4], (1 << 2)          ;activate periodic scheduling

    mov byte [usb_keyboard_used], 1

    add dword [.hcca_offset], 4
    jmp .done
.hcca_offset: dd 0
.hid_mouse:
    mov esi, USB_DEVICE_LIST
    add esi, dword [usb_list_offset]
    mov dword [esi], 2
    add dword [usb_list_offset], 4

    jmp .done

.printer:
    mov esi, USB_DEVICE_LIST
    add esi, dword [usb_list_offset]
    mov dword [esi], 5
    add dword [usb_list_offset], 4

    jmp .done
.usb_hub:
    mov esi, USB_DEVICE_LIST
    add esi, dword [usb_list_offset]
    mov dword [esi], 6
    add dword [usb_list_offset], 4

    jmp .done

.mass_storage:
    cmp byte [edi+6], 0x06      ;SCSI
    jne .unknown

    cmp byte [edi+7], 0x50
    je .bulk_only_transport     ;common protocol for flash drives
    cmp byte [edi+7], 0x62
    je .fast_extended_drive     ;used by external SSDs or fast flash drives
    cmp byte [edi+7], 0
    je .floppy_device           ;slower USB 1.1 protocol, used for example by floppy drives

.bulk_only_transport:
    mov esi, USB_DEVICE_LIST
    add esi, dword [usb_list_offset]
    mov dword [esi], 3
    add dword [usb_list_offset], 4

    jmp .done
.fast_extended_drive:
    mov esi, USB_DEVICE_LIST
    add esi, dword [usb_list_offset]
    mov dword [esi], 7
    add dword [usb_list_offset], 4

    jmp .done
.floppy_device:
    mov esi, USB_DEVICE_LIST
    add esi, dword [usb_list_offset]
    mov dword [esi], 4
    add dword [usb_list_offset], 4

    jmp .done

.unknown:
    mov esi, USB_DEVICE_LIST
    add esi, dword [usb_list_offset]
    mov dword [esi], 0
    add dword [usb_list_offset], 4
    jmp .done
.init_port_error:
    pop eax
    mov esi, USB_DEVICE_LIST
    add esi, dword [usb_list_offset]
    mov dword [esi], 0xffffffff
    add dword [usb_list_offset], 4
    stc
    popa
    ret


;====data====
ohci_base: dd 0
hcca                    equ 0x102500              ;Host Controller Communications Area, offset 9472B (after 1. AHCI Port Memory Data)
USB_DEVICE_LIST         equ 0x105500              ;offset 21760B (after 2. AHCI Port Memory Data)

align 16
control_ed:                           ;Endpoint Desciptor
    dd 0    ;control
    dd 0    ;TD queue tail
    dd 0    ;TD queue head
    dd 0    ;Next ED
td_setup:
    dd 0
    dd 0
    dd 0
    dd 0
td_data:
    dd 0
    dd 0
    dd 0
    dd 0
td_status:
    dd 0
    dd 0
    dd 0
    dd 0
td_empty: times 4 dd 0
usb_keyboard_ed: times 4 dd 0
usb_keyboard_td: times 4 dd 0

ohci_setup_packet:
    db 0x80          ; Device to Host
    db 0x06          ; GET_DESCRIPTOR

    dw 0x0100        ; Device Descriptor
    dw 0
    dw 18
set_address_packet:
    db 0x00
    db 0x05
    dw 0             ; Address (off 2)
    dw 0
    dw 0
ohci_descriptor_buffer: times 128 db 0
usb_keyboard_buffer: times 8 db 0
usb_keyboard_used: db 0
usb_list_offset: dd 0