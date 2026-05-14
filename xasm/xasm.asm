;16Bit Assembler
;Copyright (C) 2026 Technodon


[org 0x100000]
bits 32

start:
    mov [file_name], esi
    
    mov ah, 0x02
    mov edi, 0x70000
    int 0x33

    mov esi, 0x70000
    mov edi, save_buffer
    xor ecx, ecx
.main_loop:
    lodsb
    inc ecx

    cmp al, '$'
    je .cmp_end

    cmp al, 'm'
    je .check_m

    cmp al, 'c'
    je .check_c

    cmp al, 'r'
    je .check_r

    cmp al, 's'
    je .check_s

    cmp al, 'i'
    je .check_i

    cmp al, 'h'
    je .halt_instruction

    cmp al, ';'
    je .comment

    cmp al, 0x0a
    je .newline
    jmp .main_loop
.check_m:
    dec esi

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, mov_str
    mov ecx, 3
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je instr_mov

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, movs_str
    mov ecx, 4
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je instr_movx
    jmp .invalid_instruction
.check_c:
    dec esi

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, clc_str
    mov ecx, 3
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .clc_instruction

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, cld_str
    mov ecx, 3
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .cld_instruction

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, cli_str
    mov ecx, 3
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .cli_instruction

    jmp .invalid_instruction
.check_r:
    dec esi
    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, retf_str
    mov ecx, 4
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .retf_instruction
    jmp .invalid_instruction
.check_i:
    dec esi

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, iret_str
    mov ecx, 4
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .iret_instruction

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, int_str
    mov ecx, 3
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je instr_int

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, inc_str
    mov ecx, 3
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je instr_inc
    jmp .invalid_instruction
.check_s:
    dec esi

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, stc_str
    mov ecx, 3
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .stc_instruction

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, std_str
    mov ecx, 3
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .std_instruction

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, sti_str
    mov ecx, 3
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .sti_instruction

    jmp .invalid_instruction
.invalid_instruction:
    mov esi, invalid_str
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30
    mov ebx, [line]
    mov ah, 0x04
    int 0x30
    mov ah, 0x03
    int 0x30
    retf

.invalid_comb:
    mov esi, invalid_opcode_str
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30
    mov ebx, [line]
    mov ah, 0x04
    int 0x30
    mov ah, 0x03
    int 0x30
    retf
.newline:
    add dword [line], 1
    jmp .main_loop
.cmp_end:
    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, end_str
    mov ecx, 3
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .done

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, b_str
    mov ecx, 1
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .set_bits

    jmp .main_loop
.done:
    
    mov edi, [file_name]
    mov [edi+8], 'B'
    mov [edi+9], 'I'
    mov [edi+10], 'N'

    mov esi, [file_name]
    mov edi, 0x90000
    mov ah, 0x03
    int 0x33
    jc .save_file_err2

    mov esi, assembled_successful
    mov ebx, COLOR_GREEN
    mov ah, 0x01
    int 0x30
    mov ah, 0x03
    int 0x30
    retf
.save_file_err2:
    mov esi, file_save_err
    mov ah, 0x01
    mov ebx, COLOR_RED
    int 0x30
    mov ah, 0x03
    int 0x30
    retf

.set_bits:
    add esi, 1
    lodsw
    cmp ax, '16'
    je .set_16
    cmp ax, '32'
    je .set_32
    jmp .invalid_instruction
.set_16:
    mov dword [asm_bits], 16
    jmp .main_loop
.set_32:
    mov dword [asm_bits], 32
    jmp .main_loop
.clc_instruction:
    add esi, 3
    mov al, 0xf8
    stosb
    jmp .main_loop
.cld_instruction:
    add esi, 3
    mov al, 0xfc
    stosb
    jmp .main_loop
.cli_instruction:
    add esi, 3
    mov al, 0xfa
    stosb
    jmp .main_loop

.stc_instruction:
    add esi, 3
    mov al, 0xf9
    stosb
    jmp .main_loop
.std_instruction:
    add esi, 3
    mov al, 0xfd
    stosb
    jmp .main_loop
.sti_instruction:
    add esi, 3
    mov al, 0xfb
    stosb
    jmp .main_loop
.comment:
    lodsb
    cmp al, 0x0a
    je .newline
    jmp .comment

.halt_instruction:
    dec esi

    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, hlt_str
    mov ecx, 3
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .halt

    jmp .invalid_instruction
.halt:
    add esi, 3
    mov al, 0xf4
    stosb
    jmp .main_loop

.retf_instruction:
    add esi, 4
    mov al, 0xcb    ;no stack clean
    ;mov al, 0xca   ;clear stack
    stosb
    jmp .main_loop
.iret_instruction:
    add esi, 4
    mov al, 0xcf
    stosb
    jmp .main_loop
;-------------instructions--------------
instr_mov:
    add esi, 3

    lodsb
    cmp al, 0x20        ;space
    jne start.invalid_instruction

    mov bl, 0xb8        ;ax
    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, ax_str
    mov ecx, 2
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .found_reg

    mov bl, 0xbb        ;bx
    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, bx_str
    mov ecx, 2
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .found_reg

    mov bl, 0xb9        ;cx
    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, cx_str
    mov ecx, 2
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .found_reg

    mov bl, 0xba        ;dx
    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, dx_str
    mov ecx, 2
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .found_reg

    mov bl, 0xbe        ;si
    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, si_str
    mov ecx, 2
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .found_reg

    mov bl, 0xbf        ;di
    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, di_str
    mov ecx, 2
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .found_reg

    mov bl, 0xbd        ;bp
    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, bp_str
    mov ecx, 2
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .found_reg

    mov bl, 0xbc        ;sp
    push esi
    push edi
    push ecx
    mov edi, esi
    mov esi, sp_str
    mov ecx, 2
    repe cmpsb
    pop ecx
    pop edi
    pop esi
    je .found_reg

    jmp start.invalid_instruction
.found_reg:
    add esi, 2

    mov al, bl
    stosb
    xor bx, bx
    lodsb
    cmp al, 0x20
    jne start.invalid_instruction

    lodsb
    cmp al, 0x0a
    je start.invalid_comb
    cmp al, 0x20
    je start.invalid_comb
    sub al, '0'
    mov bh, al

    lodsb
    cmp al, 0x0a
    je .done
    cmp al, 0x20
    je .done
    sub al, '0'
    add bh, al

    lodsb
    cmp al, 0x0a
    je .done
    cmp al, 0x20
    je .done
    sub al, '0'
    add bl, al

    lodsb
    cmp al, 0x0a
    je .done
    cmp al, 0x20
    je .done
    sub al, '0'
    add bl, al
.done:
    xor eax, eax
    cmp dword [asm_bits], 32
    je .store32
    mov ax, bx
    stosw
    jmp start.main_loop
.store32:
    movzx eax, bx
    stosd
    jmp start.main_loop
instr_movx:
    jmp start.main_loop
instr_int:
    add esi, 3
    xor eax, eax
    lodsb
    cmp al, 0x20
    jne start.invalid_instruction

    mov al, 0xcd
    stosb

    lodsb
    cmp al, 0x20
    je start.invalid_instruction
    cmp al, 0x0a
    je start.invalid_instruction
    mov ah, al
    lodsb
    cmp al, 0x20
    je .skip
    cmp al, 0x0a
    je .skip
    jmp .convert
.skip:
    xor al, al
.convert:
    add al, ah
    add al, '0'
    add ah, '0'

    cmp dword [asm_bits], 32
    je .bits32
    stosw
    jmp start.main_loop
.bits32:
    stosd
    jmp start.main_loop
instr_inc:
    add esi, 3
    jmp start.main_loop
file_name: dd 0
end_str: db 'end', 0
b_str: db 'b', 0
parse_name_err: db 'Invalid filename', 0
file_save_err: db 'Error while saving file', 0
assembled_successful: db 'File compiled successfully!', 0
COLOR_RED       equ 0x00db0b0b
COLOR_GREEN     equ 0x0023db0b
save_buffer     equ 0x90000
line: dd 1
asm_bits: dd 0

invalid_str: db 'Unknown instruction at line ', 0
invalid_opcode_str: db 'Invalid opcode at line ', 0
;register
ax_str: db 'ax', 0
bx_str: db 'bx', 0
cx_str: db 'cx', 0
dx_str: db 'dx', 0
si_str: db 'si', 0
di_str: db 'di', 0
bp_str: db 'bp', 0
sp_str: db 'sp', 0
; B8 = AX
; B9 = CX
; BA = DX
; BB = BX
; BC = SP
; BD = BP
; BE = SI
; BF = DI
;instructions
mov_str: db 'mov', 0
movs_str: db 'movs', 0

clc_str: db 'clc', 0
cld_str: db 'cld', 0
cli_str: db 'cli', 0
stc_str: db 'stc', 0
std_str: db 'std', 0
sti_str: db 'sti', 0
hlt_str: db 'hlt', 0
int_str: db 'int', 0
dec_str: db 'dec', 0
inc_str: db 'inc', 0
retf_str: db 'retf', 0
iret_str: db 'iret', 0