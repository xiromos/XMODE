shell:
    mov ebx, 0x00ffffff
    mov esi, prompt_msg
    mov ah, 0x01    ;print string
    int 0x30
    call get_command
    call check_args
    mov ah, 0x03
    int 0x30
    call exec_cmd
    mov edi, read_buffer
    call clear_buffer
    jmp shell


get_command:
    mov edi, command_buffer
    mov ecx, 50
.loop:
    call print_cursor
    xor ah, ah
    int 0x31
    push ax
    call delete_cursor
    pop ax
    cmp al, 0x08
    je .handle_backspace
    cmp al, 0x0d
    je .done
    dec ecx
    cmp ecx, 0
    je .done
    stosb
    mov ebx, 0x00ffffff
    mov ah, 0x02
    int 0x30
    jmp .loop

.handle_backspace:
    ;call delete_cursor
    cmp ecx, 50
    jae .loop
    inc ecx
    dec di
    cmp dword [cur_x], 0
    je .loop
    sub dword [cur_x], 8
    mov ebx, [bgcolor]
    mov al, 0xff
    mov ah, 0x02
    int 0x30
    sub dword [cur_x], 8
    jmp .loop
.done:
    mov byte [edi], 0
    ret

print_cursor:
    mov al, '_'
    mov ebx, 0x00ffffff
    call print_char
    ret
delete_cursor:
    sub dword [cur_x], 8
    mov al, 0xff
    call print_char
    sub dword [cur_x], 8
    ret
exec_cmd:
    mov edi, command_buffer
    mov esi, help_str
    call cmp_str
    jc .show_help

    mov edi, command_buffer
    mov esi, clear_str
    call cmp_str
    jc .clear_screen

    mov edi, command_buffer
    mov esi, ls_str
    call cmp_str
    jc .list_files

    mov edi, command_buffer
    mov esi, read_str
    call cmp_str
    jc .read_file

    mov edi, command_buffer
    mov esi, del_str
    call cmp_str
    jc .delete_file

    mov edi, command_buffer
    mov esi, rename_str
    call cmp_str
    jc .rename_file

    mov edi, command_buffer
    mov esi, write_str
    call cmp_str
    jc .write_file
    ret
.show_help:
    mov esi, help_msg
    mov ah, 0x01
    int 0x30
    mov ah, 0x03
    int 0x30
    ret

.clear_screen:
    call clear_screen
    ret

.list_files:
    mov ah, 0x01
    mov edi, file_buffer
    int 0x33

    call print_newline
    mov esi, file_buffer
    call print_buffer_ls
    call print_newline
    ret

.read_file:
    mov esi, [argument]
    mov edi, read_buffer
    call clear_buffer
    call parse_arg

    mov ah, 0x02
    mov edi, file_buffer
    mov esi, read_buffer
    int 0x33

    mov esi, file_buffer
    mov ebx, 0x00ffffff
    xor edx, edx
    cmp ecx, 0
    jne .read_file_loop
    ret
.read_file_loop:
    lodsb
    cmp al, 0x0a
    je .handle_newline
    call print_char
    loop .read_file_loop

    call print_newline
    ret
.handle_newline:
    call print_newline
    inc edx
    cmp edx, 40
    jae .wait_for_read
    jmp .read_file_loop
.wait_for_read:
    xor ah, ah
    int 0x31
    cmp al, 'q'
    je print_buffer_ls.done
    xor edx, edx
    jmp .read_file_loop
.read_error:
    mov esi, read_error_msg
    mov ebx, COLOR_RED
    call print_string
    call print_newline
    ret
.rename_file:
    mov esi, [argument]
    mov edi, read_buffer
    call clear_buffer
    call parse_arg

    mov edi, read_buffer2
    call clear_buffer

    mov esi, ren_prompt
    mov ebx, 0x00ffffff
    call print_string
    mov edi, read_buffer2
    mov ecx, 12
.rename_loop:
    xor ah, ah
    int 0x31
    cmp al, 'q'
    je .quit_rename
    cmp al, 0x0d
    je .ren_done
    cmp al, 0x08
    je .ren_handle_backspace
    
    dec ecx
    cmp ecx, 0
    je .rename_loop_lmt

    mov ebx, 0x00ffffff
    call print_char
    stosb
    jmp .rename_loop

.ren_done:
    mov byte [edi], 0
    mov esi, read_buffer2
    mov edi, read_buffer3
    xor ecx, ecx
    call parse_arg.parse_arg_loop

    pusha
    mov esi, read_buffer
    mov ecx, 11
    call print_buffer
    mov esi, read_buffer2
    mov ecx, 11
    call print_buffer
    popa

    mov ah, 0x04
    mov esi, read_buffer
    mov edi, read_buffer3
    int 0x33
    jc .rename_error
    ret
.ren_handle_backspace:
    cmp ecx, 12
    jae .rename_loop
    inc ecx
    cmp dword [cur_x], 0
    je .rename_loop
    dec edi
    sub dword [cur_x], 8
    mov ebx, [bgcolor]
    mov al, 0xff
    mov ah, 0x02
    int 0x30
    sub dword [cur_x], 8
    jmp .rename_loop
.rename_error:
    call print_newline
    mov esi, ren_err_msg
    mov ebx, COLOR_RED
    call print_string
    call print_newline
    ret
.rename_loop_lmt:
    inc ecx
    jmp .rename_loop
.quit_rename:
    call print_newline
    ret

.write_file:
    mov esi, argument
    mov edi, read_buffer
    call clear_buffer
    call parse_arg
    mov ecx, 1000     ;test
    mov esi, read_buffer
    mov edi, 0x8000
    mov ah, 0x03
    int 0x33
    jc .write_error

    mov esi, write_success
    mov ebx, COLOR_GREEN
    call print_string
    call print_newline
    ret
.write_error:
    mov esi, write_failure
    mov ebx, COLOR_RED
    call print_string
    call print_newline
    ret
.delete_file:
    mov esi, [argument]
    mov edi, read_buffer
    call clear_buffer
    call parse_arg
    mov ah, 0x05
    mov esi, read_buffer
    int 0x33
    jc .delete_error

    mov esi, del_success_msg
    mov ebx, COLOR_GREEN
    call print_string
    call print_newline
    ret
.delete_error:
    mov esi, delete_failure_msg
    mov ebx, COLOR_RED
    call print_string
    call print_newline
    ret
cmp_str:
    push eax
    push ebx
.loop:
    mov al, [edi]
    mov bl, [esi]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc edi
    inc esi
    jmp .loop
.not_equal:
    pop ebx
    pop eax
    clc
    ret
.equal:
    pop ebx
    pop eax
    stc
    ret

print_buffer_ls:
    lodsb
    cmp al, '#'
    je .print_size
    cmp al, '*'
    je .print_dir
    cmp al, 0x0a
    je .newline
    cmp al, '$'
    je .done

    mov ebx, 0x00ffffff
    call print_char
    jmp print_buffer_ls
.print_size:
    mov al, ' '
    call print_char
.print_size_loop:
    lodsd
    call print_dec
    jmp print_buffer_ls
.newline:
    call print_newline
    jmp print_buffer_ls
.print_dir:
    mov al, ' '
    call print_char
    push esi
    mov esi, dir_str
    call print_string
    pop esi
    jmp print_buffer_ls
.done:
    ret


print_dec:
    pusha
    xor ecx, ecx
    mov ebx, 10
.div_loop:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    cmp eax, 0
    jne .div_loop
.print_loop:
    pop eax
    add al, '0'
    mov ebx, 0x00ffffff
    call print_char
    loop .print_loop
    popa
    ret
print_hex4:
    pusha
    mov ecx, 4       ;counter to print 4 chars !!!!change it to print less or more chars!!!!
.char_loop:
    dec ecx

    mov eax, edx      ;copy dx
    shr edx, 4       ;shift 4 bits to the right
    and eax, 0xf     ;mask ah to get the last 4 bits

    mov esi, hex4_out;memory adress of the string
    add esi, 2       ;skip the 0x
    add esi, ecx      ;add counter to adress

    cmp eax, 0xa     ;check if its a letter or a number
    jl .set_letter   ;if its a number, go to set the value
    add al, 0x27    ;ASCII letters start at 0x61 for 'a'
    jl .set_letter
.set_letter:
    add al, 0x30    ;ASCII number
    mov byte [esi], al   ;add the value of the char at bx
    cmp ecx, 0       ;check the counter
    je .print_hex_done
    jmp .char_loop
.print_hex_done:
    mov ebx, hex4_out
    call print_hex_string
    popa
    ret

print_hex_string:
    mov al, [esi]
    cmp al, 0
    je hex_string_done
    mov ebx, 0x00ffffff
    call print_char
    add esi, 1       ;shift bx to the next character
    jmp print_hex_string
hex_string_done:
    ret


parse_arg:
    pusha
    xor ecx, ecx
    mov esi, [argument]      ;pointer to argument (filename)
    mov edi, read_buffer
.parse_arg_loop:
    mov al, [esi]
    cmp al, 0       ;check for 0-terminator
    je .add_spaces     ;invalid string
    cmp al, '.'     ;chech for extension
    je .add_spaces
    stosb           ;stores al in ES:DI
    inc esi
    inc ecx
    cmp ecx, 8
    jnz .parse_arg_loop
.add_spaces:
    cmp ecx, 8
    je .parse_ext
    mov al, ' '     ;fill the rest of the name with spaces to achieve 8.3 format
    stosb
    inc ecx
    jmp .add_spaces
.parse_ext:
    cmp byte [esi], '.'
    jne .parse_ext_loop
    inc esi
.parse_ext_loop:
    xor ecx, ecx
.loop:
    mov al, [esi]
    cmp al, 0
    je .add_spaces_ext
    stosb
    inc esi
    inc ecx
    cmp ecx, 3
    jb .loop
.add_spaces_ext:
    cmp ecx, 3
    je .done
    mov al, ' '
    stosb
    inc ecx
    jmp .add_spaces_ext
.done:
    popa
    ret

clear_buffer:
    ;expects buffer in EDI
    pusha
    mov al, ' '
    mov ecx, 11
    rep stosb
    popa
    ret


check_args:
    mov esi, command_buffer
    mov ecx, 100
.search_space:
    mov al, [esi]
    cmp al, 0
    je .ret_shell
    cmp al, ' '
    je .save_arg
    inc esi
    dec ecx
    jnz .search_space
    ret
.save_arg:
    mov byte [esi], 0
    inc esi
    mov [argument], esi  ;pointer to argument
    ret
.ret_shell:
    ret

print_buffer:
    lodsb
    cmp al, 0x0a
    je .newline
    mov ebx, 0x00ffffff
    call print_char
    dec ecx
    jnz print_buffer
.done:
    ret
.newline:
    dec ecx
    jz .done
    call print_newline
    jmp print_buffer