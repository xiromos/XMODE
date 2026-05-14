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
bits 32
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
    mov al, 0xfc
    out 0x21, al
    sti
    mov eax, [frame_buffer]
    mov [cur], eax
    mov dword [bgcolor], 0x0014c4be
    mov edi, [frame_buffer]
    mov ecx, width*height
.loop:
    add edi, 3
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
    movzx edx, word [bm_base4]
    call print_hex8
    call print_newline
    call ata_identify

    mov ah, 0x12
    ;int 0x32
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
    mov [root_start], ax

    ;calculate data start sector
    xor ax, ax
    mov ax, [root_start]
    add ax, [root_sectors]
    mov [data_start], ax

    mov esi, fs_loading_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline

    call load_root
    call load_fat

    movzx eax, byte [sec_per_cluster]
    movzx ebx, word [bytes_per_sec]
    mul ebx 

    mov ebx, 32
    div ebx
    mov [subdir_entries], ax
    mov ebx, 0x00ffffff
    mov esi, start_msg
    mov ah, 0x01
    int 0x30
    call print_newline
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
    xor ebx, ebx
    cmp word [fat_size], 32
    jb .continue
    mov ebx, 32
    jmp .load
.continue:
    mov bx, [fat_size]
.load:
    int 0x32
    jc disk_error
    ret


scan_disk_pci:
    xor ebx, ebx
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

    push eax
    call pci_read
    pop eax

    cmp ax, 0xffff
    je .skip

    mov ecx, eax
    or eax, 0x08
    call pci_read
    mov ebx, eax
    mov eax, ecx

    mov edx, ebx
    shr edx, 24
    cmp dl, 0x01
    jne .skip

    mov edx, ebx
    shr edx, 16
    cmp dl, 0x6     ;AHCI
    je .found
    cmp dl, 0x01
    je .found       ;IDE
    jmp .skip
.found:
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
    mov ebx, eax
    mov eax, ecx
    or eax, 0x04
    call pci_write

    call read_bar4
    jmp .done
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

ata_identify:
    mov dx, 0x1f6
    mov al, 0xe0
    out dx, al

    mov dx, 0x1f7
    mov al, 0xec
    out dx, al
.wait:
    in al, dx
    test al, 0x80
    jnz .wait

    test al, 0x08
    jz .wait

    mov ecx, 256
    mov dx, 0x1f0
.read:
    in ax, dx
    dec ecx
    jnz .read
    ret
%include "/home/technodon/Downloads/xmode/data/data.asm"
%include "/home/technodon/Downloads/xmode/data/font.asm"
%include "/home/technodon/Downloads/xmode/kernel/stdfunc.asm"
%include "/home/technodon/Downloads/xmode/syscalls/output.asm"
%include "/home/technodon/Downloads/xmode/syscalls/exceptions.asm"
%include "/home/technodon/Downloads/xmode/syscalls/idt.asm"
%include "/home/technodon/Downloads/xmode/shell/shell.asm"
%include "/home/technodon/Downloads/xmode/drivers/fs16.asm"
font8x16:
    incbin "/home/technodon/Downloads/xmode/data/DEFAULT.FNT"
disk_error_msg: db 'Disk Read Error', 0

;memory map
;0x0000 - 0x4000:      root directory
;0x4000 - 0x7c00:      FAT
;0x7c00 - 0x8000:      boot sector
;0x8000 - 0x50000:     kernel
;0x95000 - 0xffffffff: programs