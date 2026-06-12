load_coff_obj:
    ;EDI = Address of program
    mov eax, [edi+8]        ;Offset 8: pointer to symbol table
    add eax, edi            ;pointer to symbol table
    mov ecx, [edi+12]       ;number of symbols

    mov esi, eax
    push edi
    mov edi, SYMBOL_TABLE_ADDR
.loop:
    ;skip undefined symbols
    ; cmp byte [esi+12], 0xffff   ;section number
    ; je .undefined
    ; cmp byte [esi+12], 0
    ; je .undefined

    cmp byte [esi+17], 0
    ;je .skip_aux
    jmp .skip_aux

.undefined:
    movzx ebx, byte [esi+17]
    cmp ecx, ebx
    jbe .done

    sub ecx, ebx
    imul ebx, 18
    add esi, ebx
    jmp .next
    
.skip_aux:
    push esi
    push edi
    push ecx
    mov ecx, 8
    rep movsb
    pop ecx
    pop edi
    pop esi

    mov ebx, [esi+8]
    mov [edi+8], ebx
    mov bx, [esi+12]
    mov [edi+12], bx

    add edi, 14
.next:
    add esi, 18
    dec ecx
    jnz .loop
.done:
    pop edi

    movzx eax, word [edi+16]
    mov esi, edi
    add esi, 20     ;skip file header
    add esi, eax    ;skip optional header

    push edi
    movzx ecx, word [edi+2]    ;number of sections
    mov edi, RELOCATION_TABLE_CONTENTS
    xor ebx, ebx
.loop2:
    inc ebx
    mov eax, [esi+24]          ;file offset to relocation table
    
    mov edx, ebx
    imul edx, 16

    push edi
    add edi, edx

    mov [edi], bx       ;section number
    mov edx, [esi+20]
    mov [edi+2], edx    ;file offset
    mov edx, [esi+16]
    mov [edi+6], edx    ;size
    mov [edi+10], eax   ;pointer to relocation table
    mov dx, [esi+32]
    mov [edi+14], dx    ;number of relocation table entries
    pop edi

    add esi, 40

    dec ecx
    jnz .loop2

    pop edi
    mov esi, RELOCATION_TABLE_CONTENTS
    add esi, 16
    mov ecx, ebx

.section_loop:
    movzx edx, word [esi+14]
    test edx, edx
    jz .next_section

    push ecx
    mov eax, [esi+10]
    add eax, edi
    movzx ecx, word [esi+14]    ;number of relocation table entries

    mov edx, [esi+2]            ;file offset
    add edx, edi                ;section base in RAM

    call coff_relocate_section
    pop ecx
.next_section:
    add esi, 16
    dec ecx
    jnz .section_loop

    movzx eax, word [edi+16]
    add eax, 20
    add eax, edi

    movzx ecx, word [edi+2]     ;number of sections

    ;first section (.text)
    push edi
.loop3:
    push ecx
    mov esi, eax
    mov edi, section_text_str
    mov ecx, 8
    repe cmpsb
    pop ecx
    je .found

    add eax, 40
    dec ecx
    jnz .loop3

    pop edi
    jmp .error

.found:
    pop edi

    mov ebx, [eax+20]
    add ebx, edi
    mov edi, ebx

    clc
    ret
.error:
    stc
    ret


coff_relocate_section:
    pusha
.loop:
    mov ebx, [eax]      ;virtual address
    mov esi, [eax+4]    ;symbol table index

    ;find symbol
    imul esi, 14
    add esi, SYMBOL_TABLE_ADDR

    mov ebp, [esi+8]    ;symbol value
    movzx esi, word [esi+12]    ;symbol section

    ;calculate address
    imul esi, 16
    add esi, RELOCATION_TABLE_CONTENTS

    mov esi, [esi+2]    ;pointer to raw data
    add esi, edi

    add esi, ebp        ;symbol address in RAM

    mov ebp, edx        ;section base
    add ebp, ebx        ; + virtual address

    push ecx
    mov ecx, [ebp]      ;get offset
    add esi, ecx        ;add offset
    mov [ebp], esi      ;write offset
    pop ecx

    add eax, 10

    dec ecx
    jnz .loop

    popa
    ret