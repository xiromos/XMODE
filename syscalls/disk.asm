;================================================================
;syscall for disk I/O like Int 0x13
;INT 0x32
;ATA driver
;AH = 0x02: read sectors into memory            (EBX = sector count, EDI = adress in memory, ECX = LBA)
;AH = 0x03: write sectors to the disk           (EBX = sector count, ESI = buffer, ECX = LBA)
;AH = 0x04: get drive information
;AH = 0x0A: read a sector from the disk with extended LBA       (EBX = sector count, EDI = adress in memory, ECX = pointer to LBA struct)
;AH = 0x0B: write a sector to the disk with extended LBA        (EBX = sector count, EDI = pointer to buffer in memory, ECX = pointer to LBA)
;AH = 0x12: read sectors with DMA                               (BL = sector count, EDI = buffer, ECX = LBA)
;AH = 0x13: write sectors with DMA                              (BL = sector count, EDI = buffer, ECX = LBA)
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
    push dx
    mov al, 0xE7
    mov dx, 0x1f7
    out dx, al
    pop dx
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
    push dx
    mov dx, 0x1f7
    out dx, al       ;flush cache
    pop dx
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
    mov dx, 0x1f7
    out dx, al
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
    mov dx, 0x1f7
    out dx, al
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
;BL = sector count, ECX = LBA, EDI = buffer
read_dma:
    pusha
    sti
.wait:
    hlt
    cmp byte [ide_running], 1
    je .wait

    mov byte [ide_running], 1   ;block IDE controller
    
    ;set PRDT
    mov [prdt], edi

    push ebx
    xor bh, bh
    mov ax, 512
    mul bx
    mov [prdt+4], ax
    pop ebx

    mov dx, [bm_base4]
    add dx, 4
    mov eax, prdt
    out dx, eax

    ;set READ bit
    mov dx, [bm_base4]
    mov al, 0x08        ;READ
    out dx, al

    ;clear status
    mov dx, [bm_base4]
    add dx, 2
    in al, dx
    or al, 0x06
    out dx, al

    mov eax, ecx
    shr eax, 24
    and al, 0x0f
    or al, 0xe0

    mov dx, 0x1f6
    out dx, al      ;Master + LBA

    mov dx, 0x1f2
    mov al, bl           ;sector count
    out dx, al

    mov dx, 0x1f3
    mov al, cl
    out dx, al

    mov dx, 0x1f4
    mov al, ch
    out dx, al

    shr ecx, 16

    mov dx, 0x1f5
    mov al, cl
    out dx, al

    mov dx, 0x1f7   ;set command
    mov al, 0xc8    ;read DMA 28bit LBA
    out dx, al

    mov dx, [bm_base4]
    mov al, 0x09
    out dx, al

    popa
    iret

;================================================================
;BL = sector count, ECX = LBA, EDI = buffer
write_dma:
    pusha
    sti
    ;check if a DMA transfer is currently active

.wait:
    hlt
    cmp byte [ide_running], 1
    je .wait

    mov byte [ide_running], 1   ;block IDE controller
    
    ;set PRDT
    mov [prdt], edi

    push ebx
    xor bh, bh
    mov ax, 512
    mul bx
    mov [prdt+4], ax
    pop ebx

    mov dx, [bm_base4]
    add dx, 4
    mov eax, prdt
    out dx, eax

    ;set WRITE bit
    mov dx, [bm_base4]
    xor al, al
    out dx, al

    ;clear status
    mov dx, [bm_base4]
    add dx, 2
    in al, dx
    or al, 0x06
    out dx, al

    mov eax, ecx
    shr eax, 24
    and al, 0x0f
    or al, 0xe0

    mov dx, 0x1f6
    out dx, al      ;Master + LBA

    mov dx, 0x1f2
    mov al, bl           ;sector count
    out dx, al

    mov dx, 0x1f3
    mov al, cl
    out dx, al

    mov dx, 0x1f4
    mov al, ch
    out dx, al

    shr ecx, 16

    mov dx, 0x1f5
    mov al, cl
    out dx, al

    mov dx, 0x1f7   ;set command
    mov al, 0xca    ;write DMA 28bit LBA
    out dx, al

    mov dx, [bm_base4]
    mov al, 0x01    ;write
    out dx, al
    
    popa
    iret


;====================================================
;AHCI

ahci_init:
    pusha
    cmp dword [abar], 0                 ;no AHCI
    je .no_ahci
    mov eax, [abar]

    mov esi, ahci_device_list_addr      ;0x8b000
    mov ebx, [eax+0xc]                  ;Ports Implemented
    xor ecx, ecx
.loop:
    cmp ecx, 32
    jae .done

    bt ebx, ecx
    jnc .next

    jmp .found_port
.next:
    inc ecx
    jmp .loop
.done:
    mov byte [ahci_active], 1
    popa
    ret

.found_port:
    mov edi, eax
    add edi, 0x100

    mov edx, ecx
    imul edx, 0x80

    ;check if port is emtpy
    add edi, edx
    mov edx, [edi+0x28]     ;PxSSTS
    and edx, 0x0f
    cmp edx, 3
    jne .empty_port

    ; mov edx, [edi+0x28]
    ; shr edx, 8
    ; and edx, 0x0f
    ; cmp edx, 1
    ; jne .empty_port

    ;port has an active device
    ;store information in ESI (16 bytes):
    ;-Port Number
    ;-Port Address
    ;-Signature (device type)
    mov [esi], ecx
    mov [esi+4], edi
    mov edx, [edi+0x24]     ;PxSIG
    test edx, edx
    jz .empty_port
    mov [esi+8], edx        ;0x00000101 = SATA, 0xEB140101 = ATAPI
    inc word [ahci_devices]
    mov dword [edi+0x14], 0xffffffff        ;enable interrupts

    movzx edx, byte [avail_disks]
    imul edx, DRIVE_LIST_ENTRY
    add edx, DRIVE_LIST_ADDR
    mov [edx], eax      ;ABAR
    mov [edx+4], edi    ;Port Address
    mov [edx+8], cl     ;Port Number
    mov [edx+9], 0xaa   ;Drive Type
    inc byte [avail_disks]

    ;stop port
    mov ebx, [edi+0x18]
    and ebx, ~(1 << 0)
    and ebx, ~(1 << 4)
    mov [edi+0x18], ebx

    ;wait for port
.wait:
    mov ebx, [edi+0x18]
    test ebx, (1 << 15)
    jnz .wait
    test ebx, (1 << 14)
    jnz .wait


    push edi
    push ecx
    push eax

    mov edi, [edi]      ;Command List Base

    xor eax, eax
    mov ecx, 1024/4
    rep stosd

    pop eax
    pop ecx
    pop edi

    ;set command lists
    push edi
    mov edi, AHCI_PORT_MEM_OFF
    imul edi, ecx
    add edi, AHCI_MEM_BASE
    mov edx, edi           ;address of Command List
    pop edi

    mov [edi], edx          ;PxCLB
    mov dword [edi+4], 0    ;PxCLBU

    push edi
    mov edi, AHCI_PORT_MEM_OFF
    imul edi, ecx
    add edi, AHCI_MEM_BASE
    add edi, CMD_LIST_SIZE
    mov edx, edi            ;address of Reveived FIS
    pop edi

    mov [edi+0x8], edx
    mov dword [edi+12], 0


    mov ebx, [edi+0x18]
    or ebx, (1 << 4)        ;FIS Receive Enable
    or ebx, (1 << 1)        ;SUD
    or ebx, (1 << 0)        ;ST
    mov [edi+0x18], ebx
.empty_port:
    add esi, 12
    inc ecx
    jmp .loop
.no_ahci:
    mov byte [ahci_active], 0
    popa
    ret


read_ahci:
    pusha
    ;AL = AHCI Port

    ; Px + 0x00  CLB   (Command List Base)
    ; Px + 0x04  CLBU
    ; Px + 0x08  FB    (FIS Base)
    ; Px + 0x0C  FBU
    ; Px + 0x10  IS    (Interrupt Status)
    ; Px + 0x14  IE    (Interrupt Enable)
    ; Px + 0x18  CMD   (Command and Status)
    ; Px + 0x1C  reserved
    ; Px + 0x20  TFD   (Task File Data)
    ; Px + 0x24  SIG   (Signature)
    ; Px + 0x28  SSTS  (SATA Status)
    ; Px + 0x2C  SCTL
    ; Px + 0x30  SERR
    ; Px + 0x34  SACT
    ; Px + 0x38  CI    (Command Issue)

    xor ah, ah
    cmp ax, [ahci_devices]      ;check if device is valid
    ;jae .no_device
    imul ax, AHCI_PORT_ENTRY_SIZE

    movzx ebx, ax
    mov esi, ahci_device_list_addr
    add esi, ebx

    mov eax, [esi+4]            ;port address

    mov ebx, [eax+0x38]
    ;or ebx, [eax+0x34]
    not ebx
    bsf ecx, ebx
    ;jz .no_free_slot

    mov edi, [eax]
    mov edx, ecx
    shl edx, 5      ;*32
    add edi, edx
    ; Command Header
    ; DWORD 0: flags + PRDT length
    ; DWORD 1: PRDT base addr low
    ; DWORD 2: PRDT base addr high
    ; DWORD 3: reserved

    mov edx, [esi]      ;port number
    mov esi, AHCI_MEM_BASE
    imul edx, AHCI_PORT_MEM_OFF
    add esi, edx
    add esi, CMD_LIST_SIZE
    add esi, RECEIVED_FIS_SIZE
    mov edx, CMD_TABLES_SIZE
    imul edx, ecx       ;slot number
    add esi, edx        ;address of command table

    push esi
    push edi
    push eax
    push ecx

    xor eax, eax
    mov edi, esi
    mov ecx, 256/4
    rep stosd

    pop ecx
    pop eax
    pop edi
    pop esi

    ;set Command Header
    mov dword [edi], 0x00010005         ;FIS length + PRDT entries
    mov dword [edi+4], esi
    mov dword [edi+8], 0
    mov dword [edi+12], 0

    ;set PRDT
    mov dword [esi+0x80], 0x5000        ;example
    mov dword [esi+0x84], 0
    mov dword [esi+0x88], 511
    mov dword [esi+0x8C], (1 << 31)

    ;set FIS
    mov byte [esi], 0x27
    mov byte [esi+1], 0x80
    mov byte [esi+2], 0x25      ;read DMA extended
    mov byte [esi+4], 0         ;LBA 0
    mov byte [esi+5], 0         ;LBA 1
    mov byte [esi+6], 0         ;LBA 2

    mov byte [esi+7], 0x40      ;device byte 

    mov byte [esi+8], 0         ;LBA 3
    mov byte [esi+9], 0         ;LBA 4
    mov byte [esi+10], 0        ;LBA 5

    mov byte [esi+12], 1        ;sector count 1
    mov byte [esi+13], 0        ;sector count 2

    mov dword [eax+0x30], 0xffffffff    ;clear errors
    mov dword [eax+0x10], 0xffffffff    ;interrupt status
    mov ebx, 1
    shl ebx, cl
    mov edx, [eax+0x38]
    or edx, ebx
    mov [eax+0x38], edx
    
    mov edx, [eax+0x10]
    call print_hex8
    call print_newline

    mov edx, [eax+0x20]
    call print_hex8
    call print_newline

    mov edx, [eax+0x30]
    call print_hex8
    call print_newline

    mov edx, [eax+0x38]
    call print_hex8
    call print_newline
    popa
    mov al, '#'
    call print_char
    ret


; Drive List in Memory at 0x8a700

; AHCI
; DWORD 1: ABAR
; DWORD 2: Port Address
; BYTE 1:  Port Number
; BYTE 2:  0xAA (Drive Type)

; IDE
; DWORD 1: Busmaster Address (if 0 then DMA is not supported)
; BYTE 1:  Master / Slave
; BYTE 2:  Primary / Secondary  (1 = primary, 2 = secondary)
; WORD 1:  Base Channel
; Byte 3:  ATA / ATAPI (0x00 = ATA, 0xaf = ATAPI)
; BYTE 4:  0xDE (Drive Type)



ide_init:
    pusha
    ; PCI
    ; BAR0	Primary Command Base
    ; BAR1	Primary Control Base
    ; BAR2	Secondary Command Base
    ; BAR3	Secondary Control Base
    ; BAR4	Busmaster IDE Base

    ;test primary master
    mov dx, 0x1f0
    mov al, 0xa0
    call identify_ata
    jc .device2

    mov dx, 0x1f0
    movzx edi, byte [avail_disks]
    imul edi, DRIVE_LIST_ENTRY
    add edi, DRIVE_LIST_ADDR

    mov byte [edi+4], 0xa0
    mov byte [edi+5], 1
    mov word [edi+6], dx
    cmp cl, 0xaf
    jne .ata1
    mov byte [edi+8], 0xaf
.ata1:
    mov byte [edi+9], 0xde

    inc byte [avail_disks]
    cmp word [bm_base], 0
    je .device2
    mov eax, [bm_base]
    mov [edi], eax

.device2:
    mov dx, 0x1f0
    mov al, 0xb0
    call identify_ata
    jc .device3

    mov dx, 0x1f0
    movzx edi, byte [avail_disks]
    imul edi, DRIVE_LIST_ENTRY
    add edi, DRIVE_LIST_ADDR

    mov byte [edi+4], 0xb0
    mov byte [edi+5], 1
    mov word [edi+6], dx
    cmp cl, 0xaf
    jne .ata2
    mov byte [edi+8], 0xaf
.ata2:
    mov byte [edi+9], 0xde

    inc byte [avail_disks]
    cmp word [bm_base], 0
    je .device3
    mov eax, [bm_base]
    mov [edi], eax
.device3:
    mov dx, 0x170
    mov al, 0xa0
    call identify_ata
    jc .device4

    mov dx, 0x170
    movzx edi, byte [avail_disks]
    imul edi, DRIVE_LIST_ENTRY
    add edi, DRIVE_LIST_ADDR

    mov byte [edi+4], 0xa0
    mov byte [edi+5], 2
    mov word [edi+6], dx
    cmp cl, 0xaf
    jne .ata3
    mov byte [edi+8], 0xaf
.ata3:
    mov byte [edi+9], 0xde

    inc byte [avail_disks]
    cmp word [bm_base], 0
    je .device4
    mov eax, [bm_base]
    mov [edi], eax
.device4:
    mov dx, 0x170
    mov al, 0xb0
    call identify_ata
    jc .done

    mov dx, 0x170
    movzx edi, byte [avail_disks]
    imul edi, DRIVE_LIST_ENTRY
    add edi, DRIVE_LIST_ADDR

    mov byte [edi+4], 0xb0
    mov byte [edi+5], 2
    mov word [edi+6], dx
    cmp cl, 0xaf
    jne .ata4
    mov byte [edi+8], 0xaf
.ata4:
    mov byte [edi+9], 0xde

    inc byte [avail_disks]
    cmp word [bm_base], 0
    je .done
    mov eax, [bm_base]
    mov [edi], eax
.done:
    popa
    ret

identify_ata:
    ;DX = 1. Channel

    mov bx, dx
    add dx, 6
    out dx, al

    mov cx, 4
.loop:
    in al, dx
    dec cx
    jnz .loop

    xor al, al
    mov dx, bx
    add dx, 2
    out dx, al
    inc dx
    out dx, al
    inc dx
    out dx, al
    inc dx
    out dx, al

    add dx, 2
    mov al, 0xec
    out dx, al

    in al, dx
    cmp al, 0
    je .no_device

.wait:
    in al, dx
    test al, 0x80
    jnz .wait

    test al, 1
    jnz .error

    test al, 0x08
    jz .wait

    mov ecx, 256
    sub dx, 7
.loop2:
    in ax, dx
    loop .loop2

    clc
    ret
.no_device:
    stc
    ret
.error:
    ;check if its an ATAPI device
    mov dx, bx
    add dx, 4
    in al, dx
    mov ah, al
    inc dx
    in al, dx
    cmp ah, 0x14    ;LBA1
    jne .no_device
    cmp al, 0xeb
    jne .no_device
    
    mov al, 0xa1
    mov dx, bx
    add dx, 7
    out dx, al

    in al, dx
    cmp al, 0
    je .no_device

.wait2:
    in al, dx
    test al, 0x80
    jnz .wait2

    test al, 0x08
    jz .wait2

    mov cx, 256
    sub dx, 7
.loop3:
    in ax, dx
    loop .loop3

    clc
    mov cl, 0xaf
    ret



get_drive_information:
    ;DL = Drive Number
    ret
read_drive:
    ;DL = Drive Number
    pusha
    movzx esi, dl
    imul esi, DRIVE_LIST_ENTRY
    add esi, DRIVE_LIST_ADDR

    cmp byte [esi+9], 0xaa     ;AHCI
    je .ahci
    cmp byte [esi+9], 0xde     ;IDE
    je .ide


    popa
    stc
    ret
.ide:
    popa
    clc
    ret
.ahci:
    popa
    clc
    ret
write_drive:
    ret