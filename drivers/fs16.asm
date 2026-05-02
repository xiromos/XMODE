;=====================================================================
;INT 0x33
;AH = 0x01: get file list of the current directory          input: EDI = buffer for file list                               output: filled buffer with file names
;AH = 0x02: read a file into memory                         input: EDI = buffer in memory, ESI = filename                   output: no CF if successful, length of file in ECX
;AH = 0x03: write a file to disk                            input: ESI = filename, ECX = filesize (bytes), EDI = buffer     output: CF if error
;AH = 0x04: rename a file                                   input: ESI = old filename, EDI = new filename                   output: CF if error
;AH = 0x05: delete a file                                   input: ESI = filename                                           output: CF if error
;AH = 0x06: copy file from dir to subdir                    input: ESI = filename, EDI = directory                          output: CF if error
;AH = 0x07: copy file to another disk
;AH = 0x08: load program into memory                        input: ESI = program name, EDI = adress in memory               output: CF if error
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

    mov al, '#'
    stosb
    jmp .continue
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
    mov cx, 11
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