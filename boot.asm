;=========================================================================
;64-Bit Bootloader for xmode OS
;stored in the directory /EFI/BOOT/
;-------------------------------------------------------------------------
;Copyright (C) 2026 Technodon
;=========================================================================

section .text
    global _efi_main

_efi_main:
    mov [rel image_handle], rcx
    mov [rel system_table], rdx

    mov rax, [rdx+SYSTEM_TABLE.BOOT_SERVICES]
    lea rcx,[rel gop_guid]
    xor rdx, rdx
    lea r8, [rel gop]

    sub rsp, 40
    call qword [rax+BOOT_SERVICES.LOCATE_PROTOCOL]
    add rsp, 40
    test rax, rax
    jnz .failed

    mov rbx, [rel gop]
    mov rbx, [rbx+0x18]

    mov rax, [rbx+24]     ;frame buffer base
    mov [rel recom_frame_buffer], rax

    mov rdx, [rbx+8]
    mov eax, [rdx+4]
    mov [rel recom_width], eax

    mov eax, [rdx+8]
    mov [rel recom_height], eax

    mov eax, [rdx+32]
    mov [rel recom_pitch], eax

    mov rcx, 2000
    mov rdi, [rel recom_frame_buffer]
    mov eax, [rel recom_width]
    mov ebx, [rel recom_height]
.loop:
    mov [rdi], dword 0x000000ff
    add rdi, 4
    dec rcx
    jnz .loop

    mov rbx, [rel gop]
    mov rax, [rbx+24]       ;mode

    mov ecx, [rax]          ;max mode
    xor esi, esi
.search_loop:
    cmp esi, ecx
    jge .no_xga

    mov rcx, [rel gop]
    mov edx, esi
    lea r8, [rel info_size]
    lea r9, [rel info_ptr]

    mov rdi, rcx

    sub rsp, 40
    call qword [rcx]
    add rsp, 40

    mov rcx, rdi

    test rax, rax
    jnz .next_mode

    mov rdx, [rel info_ptr]
    mov eax, [rdx+4]            ;width
    cmp eax, 1024               ;search for XGA resolution
    jne .next_mode

    mov eax, [rdx+8]            ;height
    cmp eax, 768
    jne .next_mode

    ;found
    mov rcx, [rel gop]
    mov edx, esi

    mov rdi, rcx

    sub rsp, 40
    call qword [rcx+8]          ;SetMode
    add rsp, 40

    mov rcx, rdi

    test rax, rax
    jnz .no_xga

    mov rbx, [rel gop]
    mov rbx, [rbx+24]

    mov rax, [rbx+24]
    mov [rel frame_buffer], rax

    mov rdx, [rbx+8]
    mov eax, [rdx+4]
    mov [rel width], eax
    mov eax, [rdx+8]
    mov [rel height], eax
    mov eax, [rdx+12]       ;PixelFormat (BBGGRRXX)
    imul eax, 4             ;bytes per pixel
    mov [rel bpp], eax


    mov rdi, [rel frame_buffer]
    mov rcx, 2000
.loop2:
    mov [rdi], dword 0x00ff0000
    add rdi, 4
    dec rcx
    jnz .loop2

    lea rsi, [rel graphic_success]
    call print_string

    call get_vendor

    mov rax, [rel system_table]
    mov rax, [rax+SYSTEM_TABLE.BOOT_SERVICES]       ;BootServices
    lea rcx, [rel sfs_guid]
    xor rdx, rdx
    lea r8, [rel simple_fs]

    sub rsp, 40
    call qword [rax+BOOT_SERVICES.LOCATE_PROTOCOL]
    add rsp, 40

    test rax, rax
    jnz .no_bootservices

    ;open root
    mov rcx, [rel simple_fs]
    lea rdx, [rel root]

    sub rsp, 40
    call qword [rcx+8]
    add rsp, 40

    test rax, rax
    jnz .root_failed

    mov rcx, [rel root]
    lea rdx, [rel xmode_file]
    lea r8, [rel xmode_bin]
    mov r9, 1       ;EFI_FILE_MODE_READ

    sub rsp, 56
    mov qword [rsp+32], 0
    call qword [rcx+8]
    add rsp, 56

    test rax, rax
    jnz .no_file_found

    ;get file size
    mov qword [rel info_size], 256

    mov rcx, [rel xmode_file]
    lea rdx, [rel file_info_guid]
    lea r8, [rel info_size]
    lea r9, [rel file_info]

    sub rsp, 40
    call qword [rcx+64]
    add rsp, 40

    test rax, rax
    jnz .no_file_found

    mov rax, [rel file_info+8]
    mov [rel xmode_size], rax

    mov rcx, [rel xmode_file]
    lea rdx, [rel xmode_size]
    mov r8, 0x8000      ;buffer - kernel is loaded at 0x00008000

    sub rsp, 40
    call qword [rcx+32]
    add rsp, 40

    lea rsi, [rel kernel_found_str]
    call print_string

.get_mmap:
    ;get memory map
    mov rax, [rel system_table]
    mov rax, [rax+SYSTEM_TABLE.BOOT_SERVICES]

    lea rcx, [rel mmap_size]
    mov rdx, [rel mmap]
    lea r8, [rel map_key]
    lea r9, [rel desc_size]

    sub rsp, 48
    lea r10, [rel desc_ver]
    mov [rsp+32], r10
    call qword [rax+BOOT_SERVICES.GET_MEMORY_MAP]
    add rsp, 48

    test rax, rax
    jnz .get_mmap

    call .copy_mmap

    mov rax, [rel system_table]
    mov rax, [rax+SYSTEM_TABLE.BOOT_SERVICES]
    mov rcx, [rel image_handle]
    mov rdx, [rel map_key]

    sub rsp, 40
    call qword [rax+BOOT_SERVICES.EXIT_BOOT_SERVICES]
    add rsp, 40

    test rax, rax
    jnz .exit_fail

    jmp exit_boot
    cli
    hlt
.copy_mmap:
    xor rdx, rdx
    mov rax, [rel mmap_size]
    mov rcx, [rel desc_size]
    div rcx
    mov rcx, rax

    xor rbx, rbx

    mov rsi, [rel mmap]
    mov rdi, MEM_MAP_ADDR
    mov rdx, [rel desc_size]
.loop_copy:
    mov eax, [rsi]
    cmp eax, 0
    jne .no_nullentry

    add rsi, rdx
    dec rcx
    jnz .loop_copy
    jmp .done_copy
.no_nullentry:
    movzx rax, dword [rsi]          ;type
    cmp eax, 7
    je .free_mem
    cmp eax, 3
    je .free_mem
    cmp eax, 4
    je .free_mem

    mov dword [rdi+16], 2
.continue_copy:
    mov rax, [rsi+8]        ;start address
    mov [rdi], rax

    mov rax, [rsi+24]       ;size in 4Kib pages
    shl rax, 12
    mov [rdi+8], rax

    add rdi, 20
    add rsi, rdx

    inc rbx
    dec rcx
    jnz .loop_copy

.done_copy:
    lea rsi, [rel kernel_packet]
    mov [rsi+8], ebx
    ret
.free_mem:
    mov dword [rdi+16], 1
    jmp .continue_copy
.next_mode:
    inc rsi
    jmp .search_loop
.failed:
    mov ecx, 0xaaaaaaaa         ;debug
    mov ebx, 0x77777777
    cli
    hlt
.no_xga:
    lea rsi, [rel no_xga_str]
    call print_string
    cli
    hlt
.no_bootservices:
    lea rsi, [rel bootservices_fail]
    call print_string
    cli
    hlt
.root_failed:
    lea rsi, [rel root_failed_str]
    call print_string
    cli
    hlt
.no_file_found:
    lea rsi, [rel file_not_found]
    call print_string
    cli
    hlt
.mmap_fail:
    lea rsi, [rel mmap_error]
    call print_string
    cli
    hlt
.exit_fail:
    lea rsi, [rel exit_error]
    call print_string
    cli
    hlt
print_string:
    ;msg in ESI
    mov rax, [rel system_table]
    mov rbx, [rax+64]           ;ConOut
    mov rcx, rbx
    mov rdx, rsi

    sub rsp, 40
    call qword [rbx+8]
    add rsp, 40

    ret

get_vendor:
    mov rax, [rel system_table]
    mov rsi, [rax+24]           ;FirmwareVendor
    lea rdi, [rel firmware_vendor]
    mov rcx, 16
    rep movsb
    mov ecx, [rax+32]           ;FirmwareRevision

    mov rax,[rel system_table]
    mov rcx,[rax+64]       ; ConOut

    lea rdx,[rel firmware_vendor]

    sub rsp,40
    call qword [rcx+8]     ; OutputString
    add rsp,40

    mov rax,[rel system_table]
    mov rcx,[rax+64]       ; ConOut

    lea rdx,[rel newline]

    sub rsp,40
    call qword [rcx+8]     ; OutputString
    add rsp,40

    ret


exit_boot:
    mov dword [rel kernel_packet+12], 20

    mov rdx, [rel frame_buffer]     ;assumes that the frame buffer is a 32bit address
    lea rsi, [rel firmware_vendor]
    mov [rel kernel_packet], rsi
    mov ecx, [rel bpp]
    mov ebx, [rel width]
    mov edi, [rel height]
    lea rsi, [rel kernel_packet]
    mov rax, 0x8000+250
    jmp rax


;----data---- 
section .data
image_handle: dq 0
system_table: dq 0

gop_guid:
    dd 0x9042a9de
    dw 0x23dc
    dw 0x4a38
    db 0x96,0xfb,0x7a,0xde,0xd0,0x80,0x51,0x6a

sfs_guid:
    dd 0x0964e5b22
    dw 0x6459
    dw 0x11d2
    db 0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b

file_info_guid:
    dd 0x09576e92
    dw 0x6d3f
    dw 0x11d2
    db 0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b


simple_fs: dq 0
root: dq 0

gop: dq 0
recom_frame_buffer: dq 0
recom_pitch: dd 0
recom_width: dd 0
recom_height: dd 0

info_ptr: dq 0
info_size: dq 0

frame_buffer: dq 0
width: dd 0
height: dd 0
bpp: dd 0
SYSTEM_TABLE.BOOT_SERVICES      equ 96
BOOT_SERVICES.LOCATE_PROTOCOL   equ 320
BOOT_SERVICES.EXIT_BOOT_SERVICES    equ 232
BOOT_SERVICES.GET_MEMORY_MAP    equ 56
GOP_SETMODE     equ 8
GOP_GETMODE     equ 24

GOP_MODE_INFORMATION.WIDTH      equ 4
GOP_MODE_INFORMATION.HEIGHT     equ 8
GOP_MODE_INFORMATION.PITCH      equ 32

firmware_vendor: times 16 db 0
firmware_revision: dd 0
graphic_success: dw 'G','r','a','p','h','i','c',' ','M','o','d','e',' ','f','o','u','n','d', 0x0d, 0x0a, 0
no_xga_str: dw 'N','o',' ','X','G','A',' ','f','o','u','n','d',0

xmode_bin: dw '\','X','M','O','D','E','.','B','I','N'
xmode_file: dq 0
xmode_size: dq 0
bootservices_fail: dw 'N','o',' ','B','o','o','t',' ','S','e','r','v','i', 'c','e','s',' ','f','o','u','n','d',0
root_failed_str: dw 'F','a','i','l','e','d',' ','t','o',' ','o','p','e','n',' ','r','o','o','t',0
file_not_found: dw 'K','e','r','n','e','l',' ','n','o','t',' ','f','o','u','n','d',0
kernel_found_str: dw 'K','e','r','n','e','l',' ','l','o','a','d','e','d', 0
mmap_error: dw 'M','m','a','p',' ','n','o','t',' ','f','o','u','n','d',0
exit_error: dw 'E','r','r','o','r',' ','w','h','i','l','e',' ','j','u','m','p','i','n','g',' ','t','o',' ','k','e','r','n','e','l', 0
newline: dw 0x0d, 0x0a, 0

mmap_size dq 65536
mmap      dq 0x100000

map_key         dq 0
desc_size       dq 0
desc_ver        dd 0

file_info: times 32 db 0

MEM_MAP_ADDR            equ 0x70000

section .bss
kernel_packet:
    resq 1        ;pointer to buffer with firmware vendor
    ;memory map
    resd 1        ;memory map entries
    resd 1        ;size of one entry

    ;video output
    resd 1        ;frame buffer
    resd 1        ;width
    resd 1        ;height
    resd 1        ;bytes per pixel