[org 0x8000]
bits 16

start:
    cli
    xor ax, ax
    mov es, ax
    mov ds, ax


    mov eax, [0x7c00+28]
    mov [hidden_sectors], eax

    mov ax, 0x4F02
    mov bx, 0x4118   ; 1024x768x24bit
    int 0x10
    ;mov ax, 0x03
    ;int 0x10

    mov ax, 0x4f01
    mov cx, 0x118
    mov di, vbe_info
    int 0x10
    mov dx, [vbe_info+0x10]     ;pitch (bytes per scanline)
    mov [pitch], dx
    mov ax, [vbe_info+0x12]     ;width
    mov bx, [vbe_info+0x14]     ;height
    mov cl, [vbe_info+0x19]     ;bits per pixel
    mov edx, [vbe_info+0x28]
    mov [frame_buffer], edx
    movzx eax, cl
    shr eax, 3
    mov [bpp], al               ;should be 3

    ;get memory map
    xor eax, eax
    xor ebx, ebx
    mov di, mmap_buffer
.next:
    mov eax, 0xe820
    mov edx, 0x534D4150
    mov ecx, 24
    int 0x15
    jc .done

    cmp eax, 0x534D4150
    jne .done
    mov [mmap_entries], ecx
    add di, cx
    cmp ebx, 0
    jne .next
.done:
    
    mov ax, tss
    shr ax, 16
    mov byte [gdt_start.descriptor+4], al
    mov byte [gdt_start.descriptor+7], ah
    lgdt [gdt_descriptor]   ;load GDT
    mov eax, cr0
    or eax, 1        ;set PE
    mov cr0, eax
    jmp far code_off:main

    frame_buffer: dd 0
gdt_start:
    dq 0

    ;code segment
    dw 0xffff
    dw 0x0000
    db 0x00
    db 0b10011010   ;access byte
    db 0b11001111   ;flags
    db 0x00

    dw 0xffff
    dw 0x0000
    db 0x00
    db 0b10010010
    db 0b11001111
    db 0x00

    dw 0xffff
    dw 0x0000
    db 0x00
    db 0b11110010
    db 0b11001111
    db 0x00

    dw 0xffff
    dw 0x0000
    db 0x00
    db 0b11111010
    db 0b11001111
    db 0x00
.descriptor:
    dw tss.end - tss - 1
    dw tss
    db 0
    db 0b10001001
    db 0
    db 0
.end:

gdt_descriptor: dw gdt_start.end - gdt_start - 1
                dd gdt_start

; extern kmain
; global main
times 250 -($ - start) db 0
bits 64
uefi:
    cli
    mov [rel frame_buffer], edx
    mov [rel bpp], cl
    mov [rel real_width], ebx

    lea eax, [rel tss]
    shr eax, 16
    mov byte [rel gdt_start.descriptor+4], al
    mov byte [rel gdt_start.descriptor+7], ah
    lgdt [rel gdt_descriptor]

    mov rax, cr0
    btr rax, 31
    mov cr0, rax

    mov ecx, 0xC0000080
    rdmsr
    btr eax, 8
    wrmsr

    mov rax, cr0
    or rax, 1
    mov cr0, rax
bits 32
    jmp far code_off:uefi2
uefi2:
    mov eax, [real_width]
    movzx ebx, byte [bpp]
    mul ebx
    mov [pitch], eax
;     mov ecx, 10000
;     mov eax, 0x00ffffff
;     mov edi, [frame_buffer]
;     movzx ebx, byte [bpp]
; .loop:
;     mov [edi], eax
;     add edi, ebx
;     dec ecx
;     jnz .loop
    ;hlt
main:
    mov ax, data_off
    mov es, ax
    mov ds, ax
    mov ss, ax
    mov esp, 0x90000
    mov fs, ax
    mov gs, ax

    call set_idt
    lidt [idt_descriptor]
    call remap_pic
    ; mov al, 0xfc
    ; out 0x21, al
    xor al, al
    out 0xa1, al
    sti
    mov eax, [frame_buffer]
    mov [cur], eax
    mov dword [bgcolor], 0x0014c4be
    mov edi, [frame_buffer]
    mov ecx, width*height
    movzx eax, byte [bpp]
.loop:
    add edi, eax
    mov dword [edi], 0x0014c4be
    loop .loop

    ;0xFFFFFFFF = white
    ;0x00FF0000 = red
    ;0x11111111 = dark gray
    ;call kmain
    mov ebx, 0x00FFFFFF
    mov esi, gdt_loaded_msg
    call print_string
    call print_newline

    mov esi, idt_loaded_msg
    call print_string
    call print_newline
    ; disk read
    ; mov ah, 0x01
    ; mov edi, 0x15000
    ; mov ecx, 100
    ; mov ebx, 255
    ; int 0x32
    mov esi, cur_bmbase_str
    mov ebx, 0x00ffffff
    call print_string

    call scan_disk_pci
    mov edx, [bm_base]
    call print_hex8

    mov ebx, init_system
    mov esi, program_init_sys
    mov ah, 0x03
    int 0x35

    ;cli
    ;hlt
;     mov al, '+'
;     call print_char
; .leap1:
;     hlt
;     jmp .leap1

; .carry:
;     mov al, 'C'
;     call print_char
;     cli
;     hlt
    mov al, 0x20
    call print_char

    mov edx, [abar]
    call print_hex8

    mov al, 0x20
    call print_char

    mov edx, [ohci_base]
    call print_hex8
    call print_newline

    ;call ahci_init
    mov esi, ahci_initialized
    mov ebx, 0x00ffffff
    call print_string
    call print_newline

    call search_boot_device

    ;test write with DMA
    mov edi, 0x8000
    mov ebx, 4
    mov ecx, 100
    mov ah, 0x13
    ;int 0x32

    xor al, al
    ;call read_ahci
    ;cli
    ;hlt
    call get_bpb_data

    mov ax, [root_entries]
    mov bx, 32
    mul bx

    mov bx, 512
    add ax, bx
    dec ax
    xor dx, dx
    div bx

    mov [root_sectors], ax

    ;calculate root dir start
    ;ReservedAreaCnt + (NumberOfFATs * FATSz16)

    xor ax, ax
    mov al, [fat_num]
    mov bx, [fat_size]
    mul bx
    add ax, [reserved_sectors]
    add ax, [hidden_sectors]
    mov [root_start], ax

    ;calculate data start sector
    xor ax, ax
    mov ax, [root_start]
    add ax, [root_sectors]
    mov [data_start], ax

    call load_root
    call load_fat

    movzx eax, byte [sec_per_cluster]
    movzx ebx, word [bytes_per_sec]
    mul ebx 

    mov ebx, 32
    div ebx
    mov [subdir_entries], ax

    ;init system and drivers
;     cmp byte [ide_found], 1
;     jne .skip_ide
;     call ide_init

; .skip_ide:
;     cmp byte [ahci_found], 1
;     jne .skip_ahci
;     call ahci_init

; .skip_ahci:
    cmp byte [ohci_found], 1
    jne .skip_ohci

    ;load drivers directory
    mov esi, dir_drivers_str
    mov edi, DIR_DRIVERS_ADDR
    mov ah, 0x02
    int 0x33
    jnc .load_ohci

    call print_newline
    mov esi, .error_load_drivers
    mov ebx, COLOR_RED
    call print_string
    cli
    hlt
.error_load_drivers: db 'Error loading Drivers directory (either not found or disk error). System halted', 0
.load_ohci:
    mov esi, file_ohci_sys
    mov edi, OHCI_DRIVER_ADDR
    mov edx, DIR_DRIVERS_ADDR
    mov ah, 0x0a
    mov bl, 0xff
    int 0x33

    mov eax, [ohci_base]
    call OHCI_DRIVER_ADDR
    mov [usb_keybuffer], edx

    mov [usb_keyboard_tdptr], edi
    mov [usb_keyboard_edptr], esi

    ;get USB devices
    mov esi, USB_DEVICE_LIST
.loop_usb:
    lodsb
    je .keyboard
    cmp al, 3
    je .usb_stick

    cmp al, 0xee
    je .skip_ohci
    jmp .loop_usb

.keyboard:
    mov byte [usb_keyboard_used], 1
    jmp .skip_ohci
.usb_stick:
    ;put USB stick into drive list...
.skip_ohci:
    call load_configs
    jc .config_err

    mov ebx, 0x00FFFFFF
    mov esi, gdt_loaded_msg
    call print_string
    call print_newline

    mov esi, idt_loaded_msg
    call print_string
    call print_newline

    mov esi, cur_bmbase_str
    mov ebx, 0x00ffffff
    call print_string

    mov edx, [bm_base]
    call print_hex8

    mov al, 0x20
    call print_char

    mov edx, [abar]
    call print_hex8

    mov al, 0x20
    call print_char

    mov edx, [ohci_base]
    call print_hex8
    call print_newline

    ;call ahci_init
    mov esi, ahci_initialized
    mov ebx, 0x00ffffff
    call print_string
    call print_newline

    mov esi, fs_loading_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline

    mov ebx, 0x00ffffff
    mov esi, start_msg
    mov ah, 0x01
    int 0x30
    call print_newline
    inc word [task_count]
    jmp .init_first_task

.config_err:
    mov esi, configs_load_err
    mov ebx, COLOR_RED
    call print_string
    call print_newline
.init_first_task:
    mov edi, tasks_esp
    add edi, TASK_SIZE      ;task 1 - shell
    mov esi, shell_task_str
    mov ecx, 11
    rep movsb
    ; write to disk
    ; mov ah, 0x03
    ; mov edi, 0x15000
    ; mov ecx, 100
    ; mov ebx, 255
    ; int 0x32

    ; extended disk write
    ; mov ah, 0x0b
    ; mov esi, 0x15000
    ; mov ecx, 4
    ; mov [disk_lba], ecx
    ; mov ecx, disk_lba
    ; mov ebx, 100
    ; int 0x32
    ; jc disk_error
    ;call clear_screen
    ;====JUMP INTO RING 3====
    cli
    mov word [tss+8], 2*8   ;kernel data
    mov [tss+4], esp
    call flush_tss
    call print_char
    mov ax, (3*8) | 3   ;ring 3 data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov eax, esp
    push (3*8) | 3  ;data selector
    push user_stack
    pushf
    push (4*8) | 3
    push shell
    sti
    iret
halt:
    hlt
    jmp halt


remap_pic:
    push eax
    
    mov al,11h              ; Initialization Command Word (ICW) 1
    out 20h,al              ; Into first PIC
    out 0A0h,al             ; Into casscaded second PIC

    mov al,20h              ; Load starting interrupt 20h (ICW2)
    out 21h,al              ; Into first PIC
    mov al,28h              ; Load starting interrupt 28h
    out 0A1h,al             ; Into second PIC

    mov al,04h              ; ICW3
    out 21h,al              ; First PIC
    mov al,02h              ; ICW3
    out 0A1h,al             ; Second PIC

    mov al,01h              ; ICW4
    out 21h,al              ; First PIC
    out 0A1h,al             ; Second PIC

    pop eax
    
    ret

flush_tss:
    mov ax, (5 * 8) | 0
    ltr ax
    ret
disk_error:
    mov esi, disk_error_msg
    call print_string
.halt:
    hlt
    jmp .halt

get_bpb_data:
    ; extended disk read
    push eax
    mov ah, 0x0a
    mov edi, 0x7c00        ;buffer
    mov ecx, 0             ;LBA
    mov [disk_lba], ecx
    mov ecx, disk_lba
    mov ebx, 1        ;sector count
    int 0x32

    mov ax, [0x7c00+11]
    mov [bytes_per_sec], ax
    mov al, [0x7c00+13]
    mov [sec_per_cluster], al
    mov ax, [0x7c00+14]
    mov [reserved_sectors], ax
    mov al, [0x7c00+16]
    mov [fat_num], al
    mov ax, [0x7c00+17]
    mov [root_entries], ax
    mov ax, [0x7c00+19]
    mov [total_sectors], ax
    mov ax, [0x7c00+22]
    mov [fat_size], ax
    mov eax, [0x7c00+28]
    mov [hidden_sectors], eax
    mov eax, [0x7c00+32]
    mov [total_sectors32], eax
    pop eax
    ret
load_root:
    mov ah, 0x02
    xor edi, edi
    xor ecx, ecx
    mov cx, [root_start]
    xor ebx, ebx
    mov bx, [root_sectors]
    int 0x32
    jc disk_error
    ret
load_fat:
    mov ah, 0x02
    mov edi, 0x4000
    xor ecx, ecx
    mov cx, [reserved_sectors]
    add ecx, [hidden_sectors]
    xor ebx, ebx
    cmp word [fat_size], 25
    jb .continue
    mov ebx, 25
    jmp .load
.continue:
    mov bx, [fat_size]
.load:
    int 0x32
    jc disk_error
    ret


scan_disk_pci:
    mov byte [avail_disks], 2
    xor ebx, ebx
    mov edi, 0x8a000
.bus_loop:
    cmp byte [pci_bus], 255
    jae .done
    mov byte [pci_device], 0
.device_loop:
    cmp byte [pci_device], 32
    jae .next_bus
    mov byte [pci_function], 0
.function_loop:
    cmp byte [pci_function], 8
    jae .next_device

    mov eax, 0x80000000
    movzx ebx, byte [pci_bus]
    shl ebx, 16
    or eax, ebx

    movzx ebx, byte [pci_device]
    shl ebx, 11
    or eax, ebx

    movzx ebx, byte [pci_function]
    shl ebx, 8
    or eax, ebx
    
    mov ebx, eax
    ;push eax
    call pci_read
    ;pop eax

    cmp ax, 0xffff
    je .skip

    push ax
    mov al, [pci_bus]
    stosb
    mov al, [pci_device]
    stosb
    mov al, [pci_function]
    stosb
    xor al, al
    stosb       ;padding
    pop ax

    stosd

    mov ecx, ebx
    mov eax, ebx
    or eax, 0x08
    call pci_read
    
    stosd
    mov byte [edi], 0x0a
    inc edi

    mov ebx, eax
    mov eax, ecx

    ;class
    mov edx, ebx
    shr edx, 24

    cmp dl, 0x01
    je .ahci_ide


    cmp dl, 0x0c
    je .serial_bus_controller
    jmp .skip
    ;sub class
.ahci_ide:
    mov edx, ebx
    shr edx, 16
    cmp dl, 0x6     ;AHCI
    je .found_ahci
    cmp dl, 0x01
    je .found_ide       ;IDE
    jmp .skip
.serial_bus_controller:
    mov edx, ebx
    shr edx, 16
    cmp dl, 0x03
    je .usb

    jmp .skip
.found_ide:
    cmp byte [ide_found], 1
    je .skip

    mov eax, 0x80000000
    movzx ebx, byte [pci_bus]
    shl ebx, 16
    or eax, ebx

    movzx ebx, byte [pci_device]
    shl ebx, 11
    or eax, ebx

    movzx ebx, byte [pci_function]
    shl ebx, 8
    or eax, ebx

    mov ecx, eax
    or eax, 0x04
    call pci_read
    or eax, 0x0007
    and eax, ~(1 << 10) ;rm Bit 10 (interrupt disable)

    mov ebx, eax
    mov eax, ecx
    or eax, 0x04
    call pci_write

    call read_bar4

    call ide_init
    mov byte [ide_found], 1       ;block initialization of other IDE controllers
    jmp .skip
.found_ahci:
    mov edx, ebx
    shr edx, 8
    cmp dl, 0x01        ;Programming Interface
    jne .skip

    cmp byte [ahci_found], 1
    je .skip

    mov eax, 0x80000000
    movzx ebx, byte [pci_bus]
    shl ebx, 16
    or eax, ebx

    movzx ebx, byte [pci_device]
    shl ebx, 11
    or eax, ebx

    movzx ebx, byte [pci_function]
    shl ebx, 8
    or eax, ebx

    mov ecx, eax
    or eax, 0x04
    call pci_read
    or eax, 0x0005  ;IO + bus master
    and eax, ~(1 << 10)
    mov ebx, eax
    mov eax, ecx
    or eax, 0x04
    call pci_write

    call read_bar5

    mov eax, ecx
    or eax, 0x3c
    call pci_read

    and eax, 0xff
    add al, 0x20
    mov [ahci_irq], al

    movzx ebx, al
    mov eax, ahci_interrupt_handler
    call set_idt_entry

    mov byte [ahci_found], 1
    call ahci_init
    jmp .next_device
.usb:
    mov edx, ebx
    shr edx, 8
    cmp dl, 0
    je .uhci
    cmp dl, 0x10
    je .ohci
    cmp dl, 0x20
    je .ehci
    cmp dl, 0x30
    je .xhci
    jmp .next_device

.uhci:
    jmp .next_device
.ohci:
    cmp byte [ohci_found], 1
    je .skip

    mov eax, 0x80000000
    movzx ebx, byte [pci_bus]
    shl ebx, 16
    or eax, ebx

    movzx ebx, byte [pci_device]
    shl ebx, 11
    or eax, ebx

    movzx ebx, byte [pci_function]
    shl ebx, 8
    or eax, ebx

    mov ecx, eax

    call read_bar0
    and eax, 0xfffffff0
    mov [ohci_base], eax

    mov eax, ecx
    add eax, 4

    call pci_read
    mov ebx, eax
    and bx, 0xfdff  ;rm Bit 10 (Interrupt Disable)

    mov eax, ecx
    add eax, 4
    call pci_write

    ;get IRQ
    mov eax, ecx
    add eax, 0x3c
    call pci_read

    add al, 0x20
    movzx ebx, al
    mov eax, ohci_interrupt_handler
    call set_idt_entry

    ;call get_ohci_devices
    mov byte [ohci_found], 1
    jmp .next_device
.ehci:
    jmp .next_device
.xhci:
    jmp .next_device

.next_device:
    inc byte [pci_device]
    jmp .device_loop
.skip:
    inc byte [pci_function]
    jmp .function_loop
.next_bus:
    inc byte [pci_bus]
    jmp .bus_loop
.done:
    mov byte [edi], '$'
    mov byte [ide_running], 0
    ret
pci_read:
    ;EAX = PCI adress
    mov dx, 0xcf8
    out dx, eax
    mov dx, 0xcfc
    in eax, dx
    ; push eax
    ; mov edx, eax
    ; call print_hex4
    ; pop eax
    ; hlt
    ret
pci_write:
    ;EAX = PCI adress
    ;EBX = content
    mov dx, 0xcf8
    out dx, eax

    mov dx, 0xcfc
    mov eax, ebx
    out dx, eax
    ret
read_bar4:
    mov eax, 0x80000000
    movzx ebx, byte [pci_bus]
    shl ebx, 16
    or eax, ebx

    movzx ebx, byte [pci_device]
    shl ebx, 11
    or eax, ebx

    movzx ebx, byte [pci_function]
    shl ebx, 8
    or eax, ebx

    or eax, 0x20
    call pci_read

    test eax, 1
    jnz .io
    xor eax, eax
    ret
.io:
    and eax, 0xfffffffc
    mov [bm_base], eax
    mov [bm_base4], ax
    ret

read_bar5:
    mov eax, 0x80000000
    movzx ebx, byte [pci_bus]
    shl ebx, 16
    or eax, ebx

    movzx ebx, byte [pci_device]
    shl ebx, 11
    or eax, ebx

    movzx ebx, byte [pci_function]
    shl ebx, 8
    or eax, ebx

    or eax, 0x24
    call pci_read

    and eax, 0xfffffff0     ;remove flags
    mov [abar], eax         ;AHCI Base Address Register

    ;activate global AHCI interrupts
    mov eax, [abar]
    mov ebx, [eax+4]
    or ebx, (1 << 1)
    mov [eax+4], ebx

    ret
read_bar0:
    ;outputs value in EAX
    add eax, 0x10
    call pci_read
    ret
search_boot_device:
    mov byte [boot_drive], 2
    ret

init_system:
    mov ecx, 0x1000000
.loop:
    dec ecx
    jnz .loop

    mov ah, 0x05
    int 0x35

load_configs:
    ;load configs directory
    mov esi, dir_configs_str
    mov edi, CONFIG_DIR_BUFFER
    mov ah, 0x02
    int 0x33
    jc .error

    ;load BGCOLOR.CFG from configs directory
    mov edx, CONFIG_DIR_BUFFER          ;from where to load
    mov edi, CONFIGS_FILE_BUFFER        ;where to load
    mov esi, file_bgcolor_cfg           ;what to load
    mov bl, 0xff
    mov ah, 0x0a
    int 0x33
    jc .error

    mov esi, CONFIGS_FILE_BUFFER
.loop:
    lodsb
    cmp al, '#'
    je .skip_comment

    sub esi, 1
.convert:
    call string_to_hex6
    mov [bgcolor], esi

    ;set background color
    mov dword [cur_x], 0
    mov dword [cur_y], 0

    mov edi, [frame_buffer]
    mov ecx, [real_width]
    imul ecx, [real_height]
    movzx eax, byte [bpp]
.loop1:
    add edi, eax
    mov dword [edi], esi
    loop .loop1

.done:
    ret
.skip_comment:
    lodsb
    cmp al, 0x0a
    jne .skip_comment
    cmp al, 0
    je .done
    jmp .convert
.error:
    mov esi, configs_load_err
    mov ebx, COLOR_RED
    call print_string
    call print_newline
    ret
%include "data/data.asm"
%include "data/font.asm"
%include "kernel/stdfunc.asm"
%include "syscalls/output.asm"
%include "syscalls/exceptions.asm"
%include "syscalls/idt.asm"
%include "shell/shell.asm"
%include "drivers/fs16.asm"
%include "drivers/pci.asm"
;%include "drivers/ohci.asm"
%include "syscalls/string.asm"
%include "syscalls/system.asm"
font8x16:
    incbin "data/DEFAULT.FNT"
disk_error_msg: db 'Disk Read Error', 0

;memory map
;0x0000 - 0x4000:      root directory
;0x4000 - 0x7c00:      FAT
;0x7c00 - 0x8000:      boot sector
;0x8000 - 0x50000:     kernel
;0x200000: programs