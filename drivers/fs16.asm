;=====================================================================
;INT 0x33
;AH = 0x00: get file information                            input: EDI = pointer to directory, ESI = filename               output: ECX = size, EAX = flags, EBX = first cluster
;AH = 0x01: get file list of the current directory          input: EDI = buffer for file list                               output: filled buffer with file names
;AH = 0x02: read a file into memory                         input: EDI = buffer in memory, ESI = filename                   output: no CF if successful, length of file in ECX
;AH = 0x03: write a file to disk                            input: ESI = filename, ECX = filesize (bytes), EDI = buffer     output: CF if error
;AH = 0x04: rename a file                                   input: ESI = old filename, EDI = new filename                   output: CF if error
;AH = 0x05: delete a file                                   input: ESI = filename                                           output: CF if error
;AH = 0x06: copy file from dir to subdir                    input: ESI = filename, EDI = directory                          output: CF if error
;AH = 0x07: copy file to another disk
;AH = 0x08: load program into memory                        input: ESI = program name, EDI = address in memory              output: CF if error
;AH = 0x09: format a drive / partition with FAT16           input: AL  = drive number, BL = partition number (0-3)          output: CF if error

;AH = 0x0A: load file from not-root directory               input: ESI = file name, EDI = address where to load, EDX = address from where to load (directory), BL = drive number       output: CF if error
;AH = 0x0B: load file from not-root directory               input: ESI = file name, EDI = where to save (directory cluster), EDX = address from where to load, ECX = length, BL = drive number       output: CF if error
;AH = 0x20: change drive - load MBR of new drive and change parameters      input: ESI = pointer to argument with drive number and partition (eg. 1.1 / 2.3)
; Drive Numbers:
;     0 = First Floppy
;     1 = Second Floppy
;     2 = First HDD / SSD / USB Flash Drive
;     3 = Second HDD / SSD / USB Flash Drive
;     ...
;     25 = CD
;     0xFF = Boot Drive
;---------------------------------------------------------------------
;Copyright (C) 2026 Technodon
;=====================================================================

cluster_to_sec:
;FirstSectorOfCluster = (cluster - 2) * BPB_SectorsPerCluster + DataStartSector
    sub ax, 2
    xor cx, cx
    mov cl, [sec_per_cluster]
    mul cx
    add ax, [data_start]
    ret

fs16_write_root:
    pusha

    xor dx, dx
    mov ax, [root_sectors]
    movzx bx, byte [sec_per_cluster]
    div bx
    movzx edx, ax
    movzx ecx, word [root_start]
    mov esi, root_addr
.loop:
    movzx ebx, byte [sec_per_cluster]
    mov ah, 0x03
    int 0x32
    jc .error

    push edx
    mov eax, 512
    movzx edx, byte [sec_per_cluster]
    imul eax, edx
    add esi, eax
    pop edx

    movzx eax, byte [sec_per_cluster]
    add ecx, eax
    dec edx
    jnz .loop

    popa
    clc
    ret
.error:
    popa
    stc
    ret
fs16_write_fat:
    pusha
    xor dx, dx
    mov ax, [fat_size]
    xor ebx, ebx
    movzx bx, byte [sec_per_cluster]
    div bx
    movzx edx, ax

    movzx ecx, word [reserved_sectors]
    mov esi, fat_addr
.loop:
    movzx ebx, byte [sec_per_cluster]
    mov ah, 0x03
    int 0x32
    jc .error

    push edx
    xor eax, eax
    mov eax, 512
    movzx edx, byte [sec_per_cluster]
    imul eax, edx
    add esi, eax
    pop edx

    movzx ax, byte [sec_per_cluster]
    add cx, ax
    dec edx
    jnz .loop

    popa
    clc
    ret
.error:
    popa
    stc
    ret



fs16_handler:
    cmp ah, 0
    je fs16_get_file_information
    cmp ah, 0x01
    je fs16_get_file_list
    cmp ah, 0x02
    je fs16_read_file
    cmp ah, 0x03
    je fs16_write_file
    cmp ah, 0x04
    je fs16_rename_file
    cmp ah, 0x05
    je fs16_delete_file
    cmp ah, 0x06
    je fs16_copy_file
    cmp ah, 0x08
    je fs16_load_program
    cmp ah, 0x09
    je fs16_format_drive
    cmp ah, 0x0a
    je fs16_load_file
    cmp ah, 0x20
    je fs16_change_drive
    or dword [esp+8], 1
    iret
 
fs16_get_file_list:
    pusha
    mov esi, root_addr
    mov dx, [root_entries]
.loop:
    mov al, [esi]
    cmp al, 0x00
    je .done
    cmp al, 0xe5
    je .free_entry

    mov ecx, 8
    push esi
    rep movsb
    mov byte [edi], '.'
    inc edi

    mov ecx, 3
    rep movsb
    pop esi

    cmp byte [esi+0xb], 0x10
    je .dir
    cmp byte [esi+0xb], 0x24
    je .system

    mov al, '#'
    stosb
    jmp .continue
.system:
    mov al, '%'
    stosb
    mov al, 0x0a
    stosb
    jmp .free_entry
.dir:
    mov al, '*'
    stosb
.continue:
    mov eax, [esi+0x1c]
    stosd

    mov al, 0x0a
    stosb
.free_entry:
    add esi, 32
    dec dx
    jnz .loop
.done:
    mov byte [edi], '$'
    popa
    iret


;=======================read a file into memory===============================
fs16_read_file:
    pusha
    push edi
    mov edi, root_addr
    mov dx, [root_entries]
.loop:
    mov ecx, 11
    push esi
    push edi
    repe cmpsb
    pop edi
    pop esi
    je .found

    add edi, 32
    dec dx
    jnz .loop

    pop edi
    popa
    or dword [esp+8], 1         ;set carry flag
    iret

.found:
    mov ax, [edi+0x1a]
    mov [cluster16], ax
    mov ecx, [edi+0x1c]         ;file size
    pop edi
    mov [esp+24], ecx           ;save ECX to the stack
.load:
    mov ax, [cluster16]
    call cluster_to_sec
    movzx ecx, ax

    mov ah, 0x02
    movzx ebx, byte [sec_per_cluster]
    int 0x32

    mov eax, 512
    mul ebx
    add edi, eax

    mov bx, [cluster16]
    shl bx, 1
    mov ax, [fat_addr+bx]
    mov [cluster16], ax
    cmp ax, 2
    jb .invalid_cluster
    cmp ax, 0xfff8
    jb .load
    popa
    and dword [esp+8], 0xfffffffe
    iret
.invalid_cluster:
    popa
    or dword [esp+8], 1         ;set carry flag
    iret

;======================write file======================================
fs16_write_file:
    pusha
    push edi
    mov [file_size16], ecx
    mov [argument], esi
    mov edi, root_addr
    mov dx, [root_entries]
.search_loop:
    mov al, [edi]
    cmp al, 0x00
    je .free_entry
    cmp al, 0xe5
    je .free_entry

    add edi, 32
    dec dx
    jnz .search_loop

    pop edi
    popa
    or dword [esp+8], 1
    iret

.free_entry:
    mov eax, edi
    pop edi
    mov ecx, [file_size16]
    push eax        ;save root adress

    mov eax, 512
    movzx ebx, byte [sec_per_cluster]
    imul eax, ebx

    add ecx, eax
    dec ecx

    mov ebx, ecx
    mov ecx, eax
    mov eax, ebx

    xor edx, edx
    div ecx
    mov ecx, eax

    mov ebx, 2       ;cluster 0 and 1 are reserved
    push edi         ;save buffer for later
    mov edx, [fat_size]
    mov eax, 512
    imul edx, eax    ;set limit
    shr edx, 1
.first_cluster:
    mov edi, fat_addr
    mov eax, ebx
    shl bx, 1
    cmp [edi+ebx], 0
    je .found_first_cluster
    mov ebx, eax
    inc ebx
    dec edx
    jnz .first_cluster
.found_first_cluster:
    mov [first_cluster16], ax
    mov [prev_cluster16], ax
    dec ecx
    jz .one_cluster
    inc ecx
.loop:
    mov bx, ax
    shl bx, 1
    cmp [edi+ebx], 0
    je .next_cluster
    inc ax
    dec edx
    jnz .loop
    jmp .error
.next_cluster:
    mov bx, [prev_cluster16]
    shl bx, 1
    mov [edi+ebx], ax
    mov [prev_cluster16], ax

    pop edi
    push eax
    push ecx
    push ebx
    call cluster_to_sec
    mov ecx, eax
    movzx ebx, byte [sec_per_cluster]
    mov esi, edi
    mov ah, 0x03
    int 0x32

    imul ebx, 512
    add edi, ebx

    pop ebx
    pop ecx
    pop eax

    push edi
    mov edi, fat_addr
    jc .error
    inc ax
    dec ecx
    jnz .loop
    jmp .last_cluster
.one_cluster:
    mov word [edi+ebx], 0xfff8
    movzx eax, word [first_cluster16]
    call cluster_to_sec
    movzx ecx, ax
    movzx ebx, byte [sec_per_cluster]
    pop edi
    mov esi, edi
    mov ah, 0x03
    int 0x32
    jnc .done
.error:
    pop eax
    popa
    or dword [esp+8], 1
    iret
.last_cluster:
    mov bx, [prev_cluster16]
    shl bx, 1
    mov word [fat_addr+bx], 0xfff8
    pop edi
.done:
    mov esi, [argument]
    pop eax
    mov edi, eax
    call fs16_write_fat

    mov ecx, 11
    push edi
    rep movsb
    pop edi

    mov byte [edi+0x0b], 0x20       ;archive
    mov ax, [first_cluster16]
    mov [edi+0x1a], ax
    mov ecx, [file_size16]
    mov [edi+0x1c], ecx
    call fs16_write_root
    popa
    and dword [esp+8], 0xfffffffe
    iret
;======================delete a file===================================
fs16_delete_file:
    pusha
    mov edi, root_addr
    mov dx, [root_entries]
.search_loop:
    mov ecx, 11
    push esi
    push edi
    repe cmpsb
    pop edi
    pop esi
    je .found

    add edi, 32
    dec dx
    jnz .search_loop

    popa
    or dword [esp+8], 1
    iret

.found:
    mov ax, [edi+0x1a]
    mov [cluster16], ax
    mov byte [edi], 0xe5        ;mark file as deleted

.del_loop:
    shl ax, 1
    mov bx, ax
    mov ax, [fat_addr+bx]
    mov word [fat_addr+bx], 0x0000
    cmp ax, 0xfff8
    jb .del_loop

    call fs16_write_fat
    jc .error
    call fs16_write_root
    jc .error

    popa
    and dword [esp+8], 0xfffffffe
    iret

.error:
    popa
    or dword [esp+8], 1
    iret

;==========================rename a file===========================
fs16_rename_file:
    pusha
    push edi
    mov edi, root_addr
    mov dx, [root_entries]
.search_loop:
    mov ecx, 11
    push esi
    push edi
    repe cmpsb
    pop edi
    pop esi
    je .found

    add edi, 32
    dec dx
    jnz .search_loop

    pop edi
    popa
    or dword [esp+8], 1
    iret

.found:
    mov edx, edi
    pop edi
    mov esi, edi
    mov edi, edx
    mov ecx, 11
    rep movsb

    call fs16_write_root

    popa
    and dword [esp+8], 0xfffffffe
    iret

;==========================copy file===============================
fs16_copy_file:
    pusha
    push edi
    mov edi, root_addr
    mov dx, [root_entries]
.search_loop:
    mov ecx, 11
    push esi
    push edi
    repe cmpsb
    pop edi
    pop esi
    je .found

    add edi, 32
    dec dx
    jnz .search_loop

    pop edi
    popa
    or dword [esp+8], 1
    iret
.found:
    mov esi, edi
    mov edi, file_buffer
    mov ecx, 32
.loop:
    lodsb
    stosb
    dec ecx
    jnz .loop

    ;load the directory...
    pop edi
    popa
    and dword [esp+8], 0xfffffffe
    iret

;============load program=====================
fs16_load_program:
    pusha
    push edi
    mov edi, root_addr
    mov dx, [root_entries]
.search_loop:
    mov ecx, 11
    push esi
    push edi
    repe cmpsb
    pop edi
    pop esi
    je .found

    add edi, 32
    dec dx
    jnz .search_loop

    pop edi
    popa
    or dword [esp+8], 1
    iret
.found:
    mov ax, [edi+0x1a]
    mov [cluster16], ax

    pop edi
.loop:
    movzx eax, word [cluster16]
    call cluster_to_sec
    mov ecx, eax
    movzx ebx, byte [sec_per_cluster]
    mov ah, 0x02
    int 0x32
    jc .error

    mov eax, 512
    imul eax, ebx
    add edi, eax

    mov ax, [cluster16]
    shl ax, 1
    movzx ebx, ax
    mov eax, [fat_addr+ebx]
    mov [cluster16], ax

    cmp ax, 2
    jb .error
    cmp ax, 0xfff8
    jb .loop

    popa
    and dword [esp+8], 0xfffffffe
    iret
.error:
    popa
    or dword [esp+8], 1
    iret

fs16_change_drive:
    pusha
    mov edx, [esi]  ;get drive number
    mov [.drive_number], dl

    mov dh, 0x0b    ;No extended LBA
    mov eax, 1      ;read 1 sector
    xor ecx, ecx    ;LBA 0
    mov edi, 0x7c00
    call read_drive
    jc .error

    cmp byte [esi+1], '.'
    je .switch_partition

.get_fs:
    mov ah, 0x01
    mov esi, .fat16_str
    mov edi, 0x7c00+54
    mov ecx, 8
    repe cmpsb
    jne .error

    mov edi, 0x7c00

    mov ax, [edi+11]
    mov [bytes_per_sec], ax
    mov al, [edi+13]
    mov [sec_per_cluster], al
    mov ax, [edi+14]
    mov [reserved_sectors], ax
    mov al, [edi+16]
    mov [fat_num], al
    mov ax, [edi+17]
    mov [root_entries], ax
    mov ax, [edi+19]
    mov [total_sectors], ax
    mov ax, [edi+22]
    mov [fat_size], ax
    mov eax, [edi+28]
    mov [hidden_sectors], eax
    mov eax, [edi+32]
    mov [total_sectors32], eax
    
    push ecx
    push eax
    push edi
    mov ecx, 0x3000/4
    mov edi, 0x4000
    xor eax, eax
    rep stosd

    pop edi
    pop eax
    pop ecx

    movzx eax, word [fat_size]
    cmp eax, 25
    jbe .next
    mov eax, 25     ;load only the first 25 sectors of the FAT
.next:
    movzx ecx, word [reserved_sectors]
    add ecx, [hidden_sectors]
    mov dl, [.drive_number]
    mov dh, 0x0b
    mov edi, 0x4000
    call read_drive
    xor ah, ah
    jc .error
    
    xor edx, edx
    movzx eax, word [root_entries]
    imul eax, 32
    movzx ebx, word [bytes_per_sec]
    div ebx
    mov [root_sectors], ax

    movzx ebx, word [reserved_sectors]
    xor ecx, ecx
    movzx cx, byte [fat_num]
    imul cx, [fat_size]
    add ecx, ebx
    add ecx, [hidden_sectors]
    mov [root_start], cx

    push ecx
    push eax
    push edi
    mov ecx, 0x4000/4
    xor edi, edi
    xor eax, eax
    rep stosd

    pop edi
    pop eax
    pop ecx

    xor edi, edi
    mov dh, 0x0b
    mov dl, [.drive_number]
    call read_drive
    xor ah, ah
    jc .error

    mov ax, [root_start]
    add ax, [root_sectors]
    mov [data_start], ax

    popa
    and dword [esp+8], 0xfffffffe
    iret

.error:
    ;AH = 0x00: Disk Error
    ;AH = 0x01: Not FAT16 formatted
    ;AH = 0x02: not an active partition
    mov [.error_num], ah
    popa
    or dword [esp+8], 1
    mov ah, [.error_num]
    xor al, al
    iret
.fat16_str: db "FAT16   "
.drive_number: db 0
.error_num: db 0

.switch_partition:
    mov al, [esi+2]
    sub al, 0x30

    cmp al, 4
    ja .error

    mov edi, 0x7c00+446
    xor ah, ah
    imul ax, 16
    movzx ebx, ax
    add edi, ebx

    mov ah, 0x02
    cmp byte [edi], 0x80
    jne .error

    mov eax, [edi+8]
    mov [hidden_sectors], eax

    mov ecx, eax
    mov dh, 0x0b
    mov dl, [.drive_number]
    mov eax, 1
    mov edi, 0x7c00
    call read_drive
    xor ah, ah
    jc .error

    jmp .get_fs

fs16_load_file:
    pusha
    push edi
    mov edi, edx
    mov dx, [subdir_entries]

    cmp bl, 0xff
    je .boot_drive
    mov [.drive_number], bl
    jmp .loop
.boot_drive:
    mov bl, [boot_drive]
    mov [.drive_number], bl
.loop:
    push edi
    push esi
    mov ecx, 11
    repe cmpsb
    pop esi
    pop edi
    je .found

    add edi, 32
    dec dx
    jnz .loop

    pop edi
    popa
    or dword [esp+8], 1
    iret

.found:
    mov ax, [edi+0x1a]
    mov [cluster16], ax
    pop edi
.load_loop:
    movzx eax, word [cluster16]
    call cluster_to_sec

    movzx ecx, ax
    add ecx, dword [hidden_sectors]
    movzx eax, byte [sec_per_cluster]
    mov dl, [.drive_number]
    mov dh, 0x0b
    call read_drive
    jc .error

    movzx ebx, word [bytes_per_sec]
    movzx eax, byte [sec_per_cluster]
    imul eax, ebx
    add edi, eax


    movzx eax, word [cluster16]
    shl eax, 1
    mov ebx, eax
    mov esi, fat_addr
    add esi, ebx
    movzx eax, word [esi]
    mov [cluster16], ax

    cmp ax, 0
    je .error

    cmp ax, 0xfff8
    jb .load_loop

    popa
    and dword [esp+8], 0xfffffffe
    iret
.error:
    popa
    or dword [esp+8], 1
    iret

.drive_number: db 0





;############################################################
;################### FORMAT DRIVE FUNCTION ##################
;############################################################


fs16_format_drive:
    pusha
    ;allocate heap

    ;load MBR to set partition and BPB
    popa
    and dword [esp+8], 0xfffffffe
    iret




;############################################################
;#################### WRITE FILE TO DISK ####################
;############################################################

fs16_write_file2:
    pusha
    popa
    and dword [esp+8], 0xfffffffe
    iret
.error:
    popa
    or dword [esp+8], 1
    iret




fs16_get_file_information:
    pusha
.loop:
    mov ecx, 11
    mov al, [edi]
    cmp al, 0
    je .error

    push esi
    push edi
    repe cmpsb
    pop edi
    pop esi
    je .found

    add edi, 32

    jmp .loop
.error:
    popa
    or dword [esp+8], 1
    iret
.found:
    mov [.tmp], edi
    popa
    mov edi, [.tmp]
    mov ecx, [edi+0x1c]
    movzx eax, byte [edi+0x0b]
    movzx ebx, word [edi+0x1a]
    and dword [esp+8], 0xfffffffe
    iret
.tmp: dd 0