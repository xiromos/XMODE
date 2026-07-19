;#########################################################
;####### EXECUTION OF SHELL SCRIPTS ######################
;#########################################################

exec_sh:
    add esi, 1
    mov edi, read_buffer
    mov ecx, 11
    rep movsb

    mov edi, read_buffer2
    mov esi, read_buffer
    xor ecx, ecx
    call parse_arg_loop

    xor ah, ah
    mov edi, [cur_dir_addr]
    mov esi, read_buffer2
    int 0x33
    jc .fs_error

    mov ah, 0x0a
    int 0x35

    mov [.heap_ptr], esi
    mov [.heap_size], ecx

    mov edi, esi
    mov esi, read_buffer2
    mov edx, [cur_dir_addr]
    mov bl, [drive_number]
    mov ah, 0x0a
    int 0x33
    jc .load_error

    mov esi, [.heap_ptr]
    mov ecx, [.heap_size]

    call .exec_script

    mov ah, 0x0b
    int 0x35
    ret


.fs_error:
    mov esi, .error_str
    mov ebx, COLOR_RED
    call print_string
    ret
.load_error:
    mov esi, .load_err_str
    mov ebx, COLOR_RED
    call print_string
    ret
.error_str: db 'File not found', 0x0a, 0
.load_err_str: db 'Error while loading file', 0x0a, 0
.heap_ptr: dd 0
.heap_size: dd 0



.exec_script:
    pusha
.loop:
    lodsb
    cmp al, ' '
    je .next

    cmp al, '#'
    je .skip_comment

    cmp al, 0x0a
    je .next

    jmp .exec_cmd
.next:
    dec ecx
    jnz .loop
.done:
    popa
    ret


.skip_comment:
    lodsb

    cmp al, 0x0a
    je .next

    dec ecx
    jnz .skip_comment
    jmp .done

.exec_cmd:
    dec esi
    mov edi, command_buffer

.loop_copy:
    jecxz .loop_copy_done   ;jump if ECX is zero
    lodsb
    dec ecx
    cmp al, 0x0a
    je .loop_copy_done

    cmp al, 0x20
    je .get_arg

    stosb
    jmp .loop_copy
.loop_copy_done:
    mov byte [edi], 0

    push ecx
    push esi
    call exec_cmd
    pop esi
    pop ecx

    cmp ecx, 0
    je .done

    jmp .loop


.get_arg:
    mov byte [edi], 0
    mov edi, read_buffer2
    xor ebx, ebx
.arg_loop:
    lodsb
    dec ecx
    cmp al, 0x0a
    je .arg_done

    cmp ebx, 11
    je .arg_done
    stosb
    inc ebx
    jmp .arg_loop

.arg_done:
    mov byte [edi], 0
    mov edi, read_buffer2
    mov dword [argument], edi
    
    push ecx
    push esi
    call exec_cmd
    pop esi
    pop ecx

    cmp ecx, 0
    je .done

    jmp .loop