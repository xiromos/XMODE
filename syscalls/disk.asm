;================================================================
;syscall for disk I/O like Int 0x13
;INT 0x32
;ATA driver
;AH = 0x02: read sectors into memory            (EBX = sector count, EDI = adress in memory, ECX = LBA)
;AH = 0x03: write sectors to the disk           (EBX = sector count, ESI = buffer, ECX = LBA)
;AH = 0x04: get drive information
;AH = 0x0A: read a sector from the disk with extended LBA       (EBX = sector count, EDI = adress in memory, ECX = pointer to LBA struct)
;AH = 0x0B: write a sector to the disk with extended LBA        (EBX = sector count, EDI = pointer to buffer in memory, ECX = pointer to LBA)
;AH = 0x12: read sectors with DMA
;AH = 0x13: write sectors with DMA
;----------------------------------------------------------------
;0x1F0 = Data
;0x1F2 = Sector count
;0x1F3 = LBA 0–7
;0x1F4 = LBA 8–15
;0x1F5 = LBA 16–23
;0x1F6 = Drive + LBA high
;0x1F7 = Status / Command
;----------------------------------------------------------------
;Copyright (C) 2026 Technodon
;================================================================
diskio_handler:
    cmp ah, 0x02
    je .read_sectors
    cmp ah, 0x03
    je .write_sectors
    cmp ah, 0x04
    je .get_drive_info
    cmp ah, 0x0a
    je .read_sectors
    cmp ah, 0x0b
    je .write_sectors
    cmp ah, 0x12
    je read_dma
    cmp ah, 0x13
    je write_dma
    stc
    iret

.read_sectors:
    pusha
    cmp ebx, 0
    je .reset_disk
.wait:
    mov dx, 0x1f7
    in al, dx
    test al, 0x80
    jnz .wait
    cmp ah, 0x0a
    je .lba48
    jmp .disk_ok
.reset_disk:
    call reset_ata
    jmp .read_done
.disk_ok:
    cmp ebx, 256
    jb .last_read

    mov dx, 0x1f2       ;sector count
    xor al, al
    out dx, al           ;256 sectors

    mov dx, 0x1f3       ;lba bits 0-7
    mov al, cl
    out dx, al

    mov dx, 0x1f4       ;lba bits 8-15
    mov al, ch
    out dx, al

    mov eax, ecx
    shr eax, 16

    mov dx, 0x1f5       ;lba bits 16-23
    out dx, al

    mov dx, 0x1f6       ;drive + lba high
    mov al, 0xe0
    or al, ah
    out dx, al

    mov dx, 0x1f7
    mov al, 0x20        ;read command
    out dx, al
    push ecx
    mov ecx, 256
.read_loop:
    mov dx, 0x1f7
    in al, dx
    test al, 0x08
    jz .read_loop

    mov dx, 0x1f0
    mov ax, 256     ;512 bytes
.read_word:
    push ax
    in ax, dx
    stosw
    pop ax
    dec ax
    jnz .read_word
    loop .read_loop
    pop ecx
    sub ebx, 256
    add ecx, 256
    jmp .disk_ok

.last_read:
    cmp bl, 0
    je .read_done

    mov dx, 0x1f2       ;sector count
    mov al, bl
    out dx, al

    mov dx, 0x1f3       ;lba bits 0-7
    mov al, cl
    out dx, al

    mov dx, 0x1f4       ;lba bits 8-15
    mov al, ch
    out dx, al

    mov eax, ecx
    shr eax, 16

    mov dx, 0x1f5       ;lba bits 16-23
    out dx, al

    mov dx, 0x1f6       ;drive + lba high
    mov al, 0xe0
    or al, ah
    out dx, al

    mov dx, 0x1f7
    mov al, 0x20        ;read command
    out dx, al

    mov ecx, ebx
.read_loop_last:
    mov dx, 0x1f7
    in al, dx
    test al, 0x08
    jz .read_loop_last

    mov dx, 0x1f0
    mov ax, 256     ;512 bytes
.read_word_last:
    push ax
    in ax, dx
    stosw
    pop ax
    dec ax
    jnz .read_word_last
    loop .read_loop_last
.read_done:
    popa
    and dword [esp+8], 0xfffffffe       ;remove carry flag from the stack
    ;or dword [esp+8], 1               ;set carry flag
    iret

.lba48:
    cmp ebx, 256
    jb .ext_last_read

    mov dx, 0x1f2       ;sector count
    xor al, al
    out dx, al           ;256 sectors

    mov dx, 0x1f3
    mov al, [ecx+3]
    out dx, al

    mov dx, 0x1f4
    mov al, [ecx+4]
    out dx, al

    mov dx, 0x1f5
    mov al, [ecx+5]
    out dx, al

    mov dx, 0x1f2
    mov al, bl
    out dx, al

    mov dx, 0x1f3
    mov al, [ecx]
    out dx, al

    mov dx, 0x1f4
    mov al, [ecx+1]
    out dx, al

    mov dx, 0x1f5
    mov al, [ecx+2]
    out dx, al

    mov dx, 0x1f6
    mov al, 0x40        ;LBA mode
    out dx, al

    mov dx, 0x1f7
    mov al, 0x24        ;read 48bit
    out dx, al

    push ecx
    mov ecx, 256
.ext_read_loop:
    mov dx, 0x1f7
    in al, dx
    test al, 0x08
    jz .ext_read_loop

    mov dx, 0x1f0
    mov ax, 256     ;512 bytes
.ext_read_word:
    push ax
    in ax, dx
    stosw
    pop ax
    dec ax
    jnz .ext_read_word
    loop .ext_read_loop
    pop ecx
    sub ebx, 256
    add ecx, 256
    jmp .lba48

.ext_last_read:
    cmp bl, 0
    je .ext_read_done

    mov dx, 0x1f2       ;sector count
    mov al, bh
    out dx, al

    mov dx, 0x1f3
    mov al, [ecx+3]
    out dx, al

    mov dx, 0x1f4
    mov al, [ecx+4]
    out dx, al

    mov dx, 0x1f5
    mov al, [ecx+5]
    out dx, al

    mov dx, 0x1f2
    mov al, bl
    out dx, al

    mov dx, 0x1f3
    mov al, [ecx]
    out dx, al

    mov dx, 0x1f4
    mov al, [ecx+1]
    out dx, al

    mov dx, 0x1f5
    mov al, [ecx+2]
    out dx, al

    mov dx, 0x1f6
    mov al, 0x40        ;LBA mode
    out dx, al

    mov dx, 0x1f7
    mov al, 0x24        ;read 48bit
    out dx, al

    mov ecx, ebx
.ext_read_loop_last:
    mov dx, 0x1f7
    in al, dx
    test al, 0x08
    jz .ext_read_loop_last

    mov dx, 0x1f0
    mov ax, 256     ;512 bytes
.ext_read_word_last:
    push ax
    in ax, dx
    stosw
    pop ax
    dec ax
    jnz .ext_read_word_last
    loop .ext_read_loop_last
.ext_read_done:
    popa
    and dword [esp+8], 0xfffffffe       ;remove carry flag from the stack
    ;or dword [esp+8], 1               ;set carry flag
    iret


.write_sectors:
    pusha
    cmp ebx, 0
    je .write_done
._wait:
    mov dx, 0x1f7
    in al, dx
    test al, 0x80
    jnz ._wait
    cmp ah, 0x0b
    je .write_lba48
.disk_ready:

    cmp ebx, 256
    jb .last_write

    mov dx, 0x1f2       ;sector count
    xor al, al
    out dx, al           ;256 sectors

    mov dx, 0x1f3       ;lba bits 0-7
    mov al, cl
    out dx, al

    mov dx, 0x1f4       ;lba bits 8-15
    mov al, ch
    out dx, al

    mov eax, ecx
    shr eax, 16

    mov dx, 0x1f5       ;lba bits 16-23
    out dx, al

    mov dx, 0x1f6       ;drive + lba high
    mov al, 0xe0
    or al, ah
    out dx, al

    mov dx, 0x1f7
    mov al, 0x30        ;write command
    out dx, al
    push ecx
    mov ecx, 256
.write_loop:
    in al, dx
    test al, 0x08
    jz .write_loop

    mov dx, 0x1f0
    mov ax, 256     ;512 bytes
.write_word:
    push ax
    lodsw
    out dx, ax
    add esi, 2
    pop ax
    dec ax
    push ax
    mov al, 0xE7
    out 0x1F7, al
    pop ax
    jnz .write_word
    loop .write_loop
    pop ecx
    sub ebx, 256
    add ecx, 256
    jmp .disk_ready

.last_write:
    cmp bl, 0
    je .write_done

    mov dx, 0x1f2       ;sector count
    mov al, bl
    out dx, al

    mov dx, 0x1f3       ;lba bits 0-7
    mov al, cl
    out dx, al

    mov dx, 0x1f4       ;lba bits 8-15
    mov al, ch
    out dx, al

    mov eax, ecx
    shr eax, 16

    mov dx, 0x1f5       ;lba bits 16-23
    out dx, al

    mov dx, 0x1f6       ;drive + lba high
    mov al, 0xe0
    or al, ah
    out dx, al

    mov dx, 0x1f7
    mov al, 0x30        ;write command
    out dx, al

    mov ecx, ebx
.write_loop_last:
    mov dx, 0x1f7
    in al, dx
    test al, 0x08
    jz .write_loop_last

    mov dx, 0x1f0
    mov ax, 256     ;512 bytes
.write_word_last:
    push ax
    mov ax, [esi]
    out dx, ax
    pop ax
    add esi, 2
    dec ax
    push ax
    mov al, 0xE7
    out 0x1F7, al       ;flush cache
    pop ax
    jnz .write_word_last
    loop .write_loop_last

.write_done:
    popa
    and dword [esp+8], 0xfffffffe       ;remove carry flag from the stack
    ;or dword [esp+8], 1               ;set carry flag
    iret
.write_lba48:
    cmp ebx, 256
    jb .ext_last_write

    mov dx, 0x1f2       ;sector count
    xor al, al
    out dx, al           ;256 sectors

    mov dx, 0x1f3
    mov al, [ecx+3]
    out dx, al

    mov dx, 0x1f4
    mov al, [ecx+4]
    out dx, al

    mov dx, 0x1f5
    mov al, [ecx+5]
    out dx, al

    mov dx, 0x1f2
    mov al, bl
    out dx, al

    mov dx, 0x1f3
    mov al, [ecx]
    out dx, al

    mov dx, 0x1f4
    mov al, [ecx+1]
    out dx, al

    mov dx, 0x1f5
    mov al, [ecx+2]
    out dx, al

    mov dx, 0x1f6
    mov al, 0x40        ;LBA mode
    out dx, al

    mov dx, 0x1f7
    mov al, 0x34        ;write 48bit
    out dx, al

    push ecx
    mov ecx, 256
.ext_write_loop:
    mov dx, 0x1f7
    in al, dx
    test al, 0x08
    jz .ext_write_loop

    mov dx, 0x1f0
    mov ax, 256     ;512 bytes
.ext_write_word:
    mov dx, 0x1f0
    push ax
    mov ax, [esi]
    out dx, ax
    add esi, 2
    pop ax
    dec ax
    push ax
    mov al, 0xE7
    out 0x1F7, al
    pop ax
    jnz .ext_write_word
    loop .ext_write_loop
    pop ecx
    sub ebx, 256
    add ecx, 256
    jmp .write_lba48

.ext_last_write:
    cmp bl, 0
    je .ext_write_done

    mov dx, 0x1f2       ;sector count
    mov al, bh
    out dx, al

    mov dx, 0x1f3
    mov al, [ecx+3]
    out dx, al

    mov dx, 0x1f4
    mov al, [ecx+4]
    out dx, al

    mov dx, 0x1f5
    mov al, [ecx+5]
    out dx, al

    mov dx, 0x1f2
    mov al, bl
    out dx, al

    mov dx, 0x1f3
    mov al, [ecx]
    out dx, al

    mov dx, 0x1f4
    mov al, [ecx+1]
    out dx, al

    mov dx, 0x1f5
    mov al, [ecx+2]
    out dx, al

    mov dx, 0x1f6
    mov al, 0x40        ;LBA mode
    out dx, al

    mov dx, 0x1f7
    mov al, 0x34        ;write 48bit
    out dx, al

    mov ecx, ebx
.ext_write_loop_last:
    mov dx, 0x1f7
    in al, dx
    test al, 0x08
    jz .ext_write_loop_last

    mov dx, 0x1f0
    mov ax, 256     ;512 bytes
.ext_write_word_last:
    mov dx, 0x1f0
    push ax
    mov ax, [esi]
    out dx, ax
    add esi, 2
    pop ax
    dec ax
    push ax
    mov al, 0xE7
    out 0x1F7, al
    pop ax
    jnz .ext_write_word_last
    loop .ext_write_loop_last
.ext_write_done:
    popa
    and dword [esp+8], 0xfffffffe       ;remove carry flag from the stack
    ;or dword [esp+8], 1               ;set carry flag
    iret

.get_drive_info:
    iret
reset_ata:
    push eax
    mov al, 4
    out dx, al
    xor eax, eax
    out dx, al
    in al, dx
    in al, dx
    in al, dx
    in al, dx
.rdylp:
    in al, dx
    and al, 0xc0
    cmp al, 0x40
    jne .rdylp
    pop eax
    ret
;================================================================
;EBX = sector count, ECX = LBA, EDI = buffer
read_dma:
    pusha
    ;stop DMA
    mov dx, [bm_base4]
    xor al, al
    out dx, al

    ;clear status
    mov dx, [bm_base4]
    add dx, 2
    in al, dx
    or al, 0x06
    out dx, al

    ;set PRDT
    mov dx, [bm_base4]
    add dx, 4
    mov eax, prdt
    out dx, eax
.wait:
    mov dx, 0x1f7
    in al, dx
    test al, 0x80
    jnz .wait

    mov dx, 0x1f6
    mov al, 0xe0       ;Master + LBA
    out dx, al

    mov dx, 0x1f2
    mov al, 1           ; 1 sector
    out dx, al

    mov dx, 0x1f3
    mov al, 1
    out dx, al

    mov dx, 0x1f4
    mov al, 0
    out dx, al

    mov dx, 0x1f5
    out dx, al

    mov dx, 0x1f7   ;set command
    mov al, 0xc8    ;read DMA 28bit LBA
    out dx, al
.wait_rdy:
    in al, dx
    test al, 0x80
    jnz .wait_rdy

    test al, 0x08
    jnz .continue

    test al, 0x01
    jnz .error

    jmp .wait_rdy
.continue:
    mov dx, [bm_base4]
    mov al, 0x09
    out dx, al
    
    mov dx, [bm_base4]
    add dx, 2
    mov byte [dma_done], 0
.wait_dma:
    ; in al, dx
    ; test al, 0x01
    cmp byte [dma_done], 1
    jne .wait_dma

    ;stop DMA
    mov dx, [bm_base4]
    mov al, 0
    out dx, al
    
    ;test if error
    mov dx, [bm_base4]
    add dx, 2
    in al, dx
    test al, 0x02
    jnz .error
    
    mov esi, 0x5000
    mov edx, [esi]
    call print_hex8
    popa
    iret
.error:
    mov al, '!'
    call print_char
    popa
    iret
write_dma:
    iret