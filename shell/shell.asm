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
    mov esi, command_buffer
    call string_uppercase
    mov esi, [argument]
    call string_uppercase

    mov esi, command_buffer
    push esi
    lodsb
    pop esi
    cmp al, '>'
    je exec_sh

    mov edi, command_buffer
    mov esi, help_str
    call cmp_str
    ;jc .show_help

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

    mov edi, command_buffer
    mov esi, memmap_str
    call cmp_str
    jc show_mmap

    mov edi, command_buffer
    mov esi, tasklist_str
    call cmp_str
    jc show_tasks

    mov edi, command_buffer
    mov esi, taskkill_str
    call cmp_str
    jc kill_task_sh

    mov edi, command_buffer
    mov esi, pci_str
    call cmp_str
    jc show_pci

    mov edi, command_buffer
    mov esi, lsdisk_str
    call cmp_str
    jc list_drives

    mov edi, command_buffer
    mov esi, cdisk_str
    call cmp_str
    jc change_drive

    mov edi, command_buffer
    mov esi, osdev_discord_str
    call cmp_str
    jc .osdev_dc

    mov edi, command_buffer
    mov esi, usb_str
    call cmp_str
    jc show_usb_devices

    mov edi, command_buffer
    mov esi, bgcolor_str
    call cmp_str
    jc .set_bgcolor

    mov edi, command_buffer
    mov esi, cd_str
    call cmp_str
    jc cd_directory

    mov edi, command_buffer
    mov esi, meminfo_str
    call cmp_str
    jc show_memory_info

    mov edi, command_buffer
    mov esi, reboot_str
    call cmp_str
    jc .reboot_system

    mov edi, command_buffer
    mov esi, dhcp_str
    call cmp_str
    jc .init_dhcp

    jmp .exec_program
    ret
.reboot_system:
    xor ah, ah
    mov bh, 0x02
    int 0x35

    ret
.init_dhcp:
    cmp byte [.dhcp], 1
    je .dhcp_error

    mov ah, 0x03
    mov ebx, [load_network_stack.heap]
    mov esi, file_dhcp_sys
    mov edi, file_dhcp_sys
    int 0x35

    mov ah, 0x0b
    mov ecx, 0x1000
    mov esi, [load_network_stack.heap]
    int 0x35

; .wait_ip:
;     mov edi, NET_INTERFACE
;     mov eax, [edi]
;     cmp eax, 0
;     je .wait_ip

    mov byte [.dhcp], 1
    ret

.dhcp_error:
    mov esi, .dhcp_error_str
    mov ebx, COLOR_RED
    call print_string
    ret
.dhcp: db 0
.dhcp_error_str: db 'Error: DHCP Request already sent', 0x0a, 0
.osdev_dc:
    mov esi, osdev_discord_msg
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    ret
.set_bgcolor:
    mov esi, [argument]
    call string_uppercase

    cmp word [esi], '-H'
    je .set_bgcolor_help

    xor ebx, ebx
.loop:
    lodsb

    cmp al, 0
    je .done_convert

    cmp al, '0'
    jb .loop
    cmp al, '9'
    jbe .number

    cmp al, 'A'
    jb .loop
    cmp al, 'F'
    jbe .string

    jmp .loop

.number:
    sub al, '0'
    jmp .add
.string:
    sub al, 0x41 - 10
.add:
    shl ebx, 4
    movzx edx, al
    or ebx, edx
    jmp .loop

.set_bgcolor_help:
    mov esi, setbgcolor_helpmsg
    mov ebx, 0x00ffffff
    call print_string
    mov esi, setbgcolor_helpmsg2
    mov ebx, COLOR_GREEN
    call print_string

    call print_newline
    ret
.done_convert:
    mov [bgcolor], ebx
    call clear_screen

;     xor ah, ah
;     xor edi, edi
;     mov esi, dir_configs_str
;     int 0x33

;     mov ah, 0x0a
;     int 0x35

;     push esi
;     push ecx

;     mov edi, esi

;     mov ah, 0x0a
;     xor edx, edx    ;root directory
;     mov esi, dir_configs_str
;     mov bl, [drive_number]
;     int 0x33
;     jc .bgcolor_error
;     mov word [.configs_cluster], ax

;     mov ah, 0x0a
;     mov edx, edi
;     add edi, 0x500
;     mov esi, file_bgcolor_cfg
;     mov bl, [drive_number]
;     int 0x33
;     jc .bgcolor_error

;     mov esi, edi
;     pop ecx

;     push ecx
; .loop_bgcolor:
;     lodsb
;     dec ecx
;     jz .bgcolor_error

;     cmp al, 0x0a
;     je .loop_bgcolor
;     cmp al, 0x20
;     je .loop_bgcolor

;     cmp al, '#'
;     je .bgcolor_skipcomment

;     dec esi
;     mov edi, [bgcolor]
;     mov [esi], edi

;     pop ecx
;     pop esi

;     push esi
;     push ecx

;     mov ah, 0x0b
;     movzx edi, word [.configs_cluster]
;     add esi, 0x500
;     mov edx, esi
;     mov esi, file_bgcolor_cfg
;     mov bl, [drive_number]
;     int 0x33
;     jc .bgcolor_error

;     pop ecx
;     pop esi

;     mov ah, 0x0b
;     int 0x35
    ret
; .bgcolor_skipcomment:
;     lodsb
;     dec ecx
;     jz .bgcolor_error
;     cmp al, 0x0a
;     jne .bgcolor_skipcomment
;     jmp .loop_bgcolor

; .bgcolor_error:
;     pop esi
;     pop ecx
;     mov esi, .bgcolor_error_str
;     mov ebx, COLOR_RED
;     call print_string
;     ret
.bgcolor_error_str: db 'Error while saving backgroundcolor at /XCONFIGS/BGCOLOR.CFG', 0x0a, 0
.configs_cluster: dw 0

.clear_arg_buffer:
    mov edi, read_buffer2
    mov eax, 0xffffffff
    mov ecx, 3
    rep stosd
    
    mov edi, command_buffer
    mov ecx, 11
    jmp .prep_buffer
.exec_program:
    mov esi, [argument]
    cmp esi, 0xffffffff
    je .clear_arg_buffer

    mov edi, read_buffer2
    xor ecx, ecx
    call parse_arg_loop

    mov edi, command_buffer
    mov ecx, 11
.prep_buffer:
    cmp byte [edi], 0
    je .clear_full
    inc edi
    dec ecx
    jnz .prep_buffer
    jmp .load_program
.clear_full:
    mov byte [edi], 0x20    ;space
    inc edi
    dec ecx
    jnz .clear_full
.load_program:
    mov esi, command_buffer
    mov edi, read_buffer
    mov ecx, 11
    repe movsb

    mov edi, read_buffer+8
    mov byte [edi], 'X'
    mov byte [edi+1], 'M'
    mov byte [edi+2], 'E'

    xor ah, ah
    mov edi, [cur_dir_addr]
    mov esi, read_buffer
    int 0x33
    jnc .found_xme_executable

    mov esi, read_buffer
    mov byte [esi+8], 'O'
    mov byte [esi+9], 'B'
    mov byte [esi+10], 'J'
    xor ah, ah
    mov edi, [cur_dir_addr]
    mov esi, read_buffer
    int 0x33
    jc .exec_prog_err

    jmp .found_prog
.found_xme_executable:
    mov al, '+'
    call print_char
    ;call load_xme
.found_prog:
    ;mov [program_address], edi

    mov esi, read_buffer
    mov edi, read_buffer
    mov ebx, [cur_dir_addr]
    mov ah, 0x02
    int 0x35
    jc .program_error
    ret
.program_error:
    cmp ah, 0x01
    je .program_coff_error

    mov esi, .program_error_str
    mov ebx, COLOR_RED
    call print_string
    ret
.program_coff_error:
    mov esi, .program_coff_error_str
    mov ebx, COLOR_RED
    call print_string
    call print_newline
    ret

.program_error_str: db 'Something went wrong while loading program (Filesystem error)', 0x0a, 0
.program_coff_error_str: db 'Error while relocating COFF file, are you sure this is a COFF Objekt file?', 0x0a, 0
.exec_prog_err:
    ret

.show_help:
    xor ah, ah
    mov edi, [cur_dir_addr]
    mov esi, program_help_bin
    int 0x33
    jc .exec_prog_err

    mov esi, program_help_bin
    mov edi, read_buffer
    mov ecx, 11
    rep movsb

    jmp .found_prog

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
    mov ebx, 0x00ffffff
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
    jz .rename_loop_lmt

    stosb
    mov ebx, 0x00ffffff
    call print_char
    jmp .rename_loop

.ren_done:
    mov byte [edi], 0
    mov esi, read_buffer2
    mov edi, read_buffer3
    xor ecx, ecx
    call parse_arg_loop

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
    mov al, 0x20
    stosb
    dec edi
    sub dword [cur_x], 8
    mov ebx, [bgcolor]
    mov al, 0xff
    call print_char
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
    mov esi, [argument]
    mov edi, read_buffer
    call clear_buffer
    call parse_arg

    mov esi, write_prompt
    mov ebx, 0x00ffffff
    call print_string
    call print_newline

    mov edi, file_buffer
    call get_text

    mov esi, read_buffer
    mov edi, file_buffer
    mov ah, 0x03
    int 0x33
    jc .write_error

    call print_newline
    mov esi, write_success
    mov ebx, COLOR_GREEN
    call print_string
    call print_newline
    ret
.write_error:
    call print_newline
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
    cmp al, '%'
    je .print_sys
    cmp al, 0x0a
    je .newline
    cmp al, 0x08
    je .print_disk_volume
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
.print_sys:
    mov al, ' '
    call print_char
    push esi
    mov esi, sys_str
    call print_string
    pop esi
    jmp print_buffer_ls
.print_disk_volume:
    mov al, ' '
    call print_char
    push esi
    mov esi, .vol_label
    call print_string
    pop esi
    jmp print_buffer_ls
.done:
    ret
.vol_label: db 'Volume Label', 0

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

print_hex8:
    pusha
    mov ecx, 8       ;counter to print 4 chars !!!!change it to print less or more chars!!!!
.char_loop:
    dec ecx

    mov eax, edx      ;copy dx
    shr edx, 4       ;shift 4 bits to the right
    and eax, 0xf     ;mask ah to get the last 4 bits

    mov esi, hex8_out;memory adress of the string
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
    mov ebx, hex8_out
    call print_hex_string
    popa
    ret

parse_arg:
    xor ecx, ecx
    mov esi, [argument]      ;pointer to argument (filename)
    mov edi, read_buffer
parse_arg_loop:
    pusha
.parse_arg_loop:
    mov al, [esi]
    cmp al, 0       ;check for 0-terminator
    je .add_spaces     ;invalid string
    cmp al, '.'     ;chech for extension
    je .add_spaces
    stosb           ;stores al in EDI
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
; .search_space2:
;     mov al, [esi]
;     cmp al, 0
;     je .ret_shell
;     cmp al, ' '
;     je .save_arg2
;     inc esi
;     dec ecx
;     jnz .search_space2
;     ret
; .save_arg2:
;     inc esi
;     mov [argument2], esi  ;pointer to argument
;     ret
.ret_shell:
    mov dword [argument], 0xffffffff
    mov dword [argument2], 0xffffffff
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


get_text:
    xor ecx, ecx
.loop:
    xor ah, ah
    int 0x31
    cmp al, 0x1b        ;escape
    je .done
    cmp al, 0x09        ;tab
    je .tab
    cmp al, 0x08
    je .handle_backspace
    cmp al, 0x0d
    je .newline

    stosb
    mov ebx, 0x00ffffff
    call print_char
    inc ecx
    jmp .loop
.tab:
    mov al, 0x20
    push ecx
    mov ecx, 4
    repe stosb
    mov ecx, 4
    mov ebx, 0x00ffffff
.space:
    call print_char
    dec ecx
    jnz .space
    pop ecx
    add ecx, 4
    jmp .loop
.done:
    ret

.handle_backspace:
    cmp ecx, 0
    jbe .loop
    cmp dword [cur_x], 0
    je .loop
    sub dword [cur_x], 8
    mov al, 0xff
    call print_char
    sub dword [cur_x], 8
    dec edi
    mov al, 0x20
    stosb
    dec edi
    dec ecx
    jmp .loop
.newline:
    call print_newline
    mov al, 0x0a
    stosb
    inc ecx
    jmp .loop

show_mmap:
    call print_newline
    mov esi, mmap_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline

    mov esi, mmap_bytes_per_entry
    call print_string
    mov eax, [mmap_entries]
    call print_dec
    call print_newline
    call print_newline

    movzx ecx, word [main.memmap_entries]
    mov esi, mmap_buffer
.loop2:
    mov eax, [esi+4]
    mov edx, eax
    call print_hex8

    mov eax, [esi]
    mov edx, eax
    call print_hex8

    mov al, 0x20
    call print_char

    mov eax, [esi+12]
    mov edx, eax
    call print_hex8

    mov eax, [esi+8]
    mov edx, eax
    call print_hex8

    mov al, 0x20
    call print_char

    mov eax, [esi+16]
    call print_dec

    call print_newline
    add esi, [mmap_entries]
    dec ecx
    jnz .loop2
    call print_newline

    mov esi, .usable_mem_str
    mov ebx, 0x00ffffff
    call print_string

    mov eax, [main.usable_mem]
    cmp eax, 0xffffffff
    jne .skip

    mov esi, .overflow_str
    call print_string
    jmp .continue
.skip:
    mov ebx, 1000
    xor edx, edx
    div ebx
    call print_dec

    mov esi, .kb_str
    mov ebx, 0x00ffffff
    call print_string

    call print_newline
    mov esi, .available_memory
    mov ebx, 0x00ffffff
    call print_string

    mov eax, [main.max_addr]
    xor edx, edx
    mov ebx, 1000
    div ebx
    call print_dec

    mov esi, .kb_str
    mov ebx, 0x00ffffff
    call print_string

.continue:
    call print_newline
    ret

.usable_mem_str: db 'Usable Memory: ', 0
.overflow_str: db 'More than 4GB', 0
.available_memory: db 'Available Memory: ', 0
.kb_str: db ' KB', 0

show_tasks:
    mov esi, task_list_header
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    
    call print_newline
    mov esi, tasks_esp
    add esi, TASK_SIZE     ;skip task 0
    mov dx, [max_tasks]
    xor eax, eax
.loop:
    cmp byte [esi], 0xe5
    je .skip
    cmp byte [esi], 0
    je .skip

    inc eax
    call print_dec
    push eax
    mov ebx, 0x00ffffff
    mov al, ':'
    call print_char
    mov al, 0x20
    call print_char
    pop eax

    mov cx, 11
    push esi
    push eax
.print_loop:
    lodsb
    mov ebx, 0x00ffffff
    call print_char

    cmp cx, 4
    jne .skip1

    mov al, '.'
    call print_char
.skip1:
    dec cx
    jnz .print_loop
    pop eax
    pop esi
    call print_newline
.skip:
    add esi, TASK_SIZE
    dec dx
    jnz .loop

    call print_newline
    ret


kill_task_sh:
    mov esi, [argument]
    mov edi, read_buffer
    mov ecx, 11
    call parse_arg

    movzx edx, word [max_tasks]
    mov edi, tasks_esp
    mov esi, read_buffer
    xor ax, ax
.loop:
    mov ecx, 11
    push esi
    push edi
    repe cmpsb
    pop edi
    pop esi
    je .found

    add edi, TASK_SIZE
    inc ax
    dec edx
    jnz .loop

    mov esi, task_not_found
    mov ebx, COLOR_RED
    call print_string
    call print_newline
    ret

.found:
    mov bx, ax
    mov ah, 0x06
    call kill_task
    ret

show_pci:
    ;Byte:  BUS
    ;Byte:  DEVICE
    ;Byte:  FUNCTION
    ;Byte:  PADDING
    ;DWORD: VENDOR ID / DEVICE ID
    ;DWORD: CLASS / SUBCLASS

    mov esi, 0x8a000
    mov ebx, 0x00ffffff
.loop:
    lodsb
    
    push esi
    push eax
    mov esi, pci_bus_str
    call print_string
    pop eax
    pop esi

    movzx edx, al
    call print_hex4

    mov al, 0x20
    call print_char

    lodsb

    push esi
    push eax
    mov esi, pci_device_str
    call print_string
    pop eax
    pop esi

    movzx edx, al
    call print_hex4

    mov al, 0x20
    call print_char

    lodsb

    push esi
    push eax
    mov esi, pci_function_str
    call print_string
    pop eax
    pop esi

    movzx edx, al
    call print_hex4

    mov al, 0x20
    call print_char

    inc esi      ;skip padding
    lodsw

    push esi
    push eax
    mov esi, pci_vendorid_str
    call print_string
    pop eax
    pop esi

    movzx edx, ax
    call print_hex4

    mov al, 0x20
    call print_char

    lodsw

    push esi
    push eax
    mov esi, pci_deviceid_str
    call print_string
    pop eax
    pop esi

    movzx edx, ax
    call print_hex4

    mov al, 0x20
    call print_char

    lodsw

    push esi
    push eax
    mov esi, pci_class_str
    call print_string
    pop eax
    pop esi

    movzx edx, ax
    call print_hex4

    mov al, 0x20
    call print_char

    lodsw

    push esi
    push eax
    mov esi, pci_subclass_str
    call print_string
    pop eax
    pop esi

    movzx edx, ax
    call print_hex4

    mov al, 0x20
    call print_char

    call print_newline

    inc esi
    mov al, [esi]
    cmp al, '$'
    jne .loop
    ret

list_drives:
    mov esi, DRIVE_LIST_ADDR
    movzx ecx, byte [avail_disks]

    xor eax, eax
.loop1:
    cmp byte [esi+9], 0
    je .no_drive
    inc eax
.no_drive:
    add esi, DRIVE_LIST_ENTRY
    dec ecx
    jnz .loop1

    push eax
    mov esi, avail_drives_str
    mov ebx, 0x00ffffff
    call print_string
    pop eax

    call print_dec
    call print_newline

    mov esi, DRIVE_LIST_ADDR
    movzx ecx, byte [avail_disks]
    xor al, al
.loop2:
    cmp byte [esi+9], 0
    jne .drive
.continue:
    inc al
    add esi, DRIVE_LIST_ENTRY
    dec ecx
    jnz .loop2

    call print_newline

    ret

.drive:
    push esi
    push eax
    add al, 0x41
    call print_char
    mov al, ':'
    call print_char
    mov al, 0x20
    call print_char

    cmp byte [esi+9], 0xaa
    je .ahci
    cmp byte [esi+9], 0xde
    je .ide
    cmp byte [esi+9], 0xbe
    je .usb
    
    mov esi, unknown_drive_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline

    pop eax
    pop esi
    jmp .continue

.ahci:
    mov esi, sata_device_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline

    pop eax
    pop esi
    jmp .continue
.ide:
    cmp byte [esi+8], 0xaf
    je .atapi

    push ecx
    push esi

    mov esi, ide_device_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline

    mov esi, .ide_product_name
    mov ebx, 0x00ffffff
    call print_string
    pop esi

    push esi
    add esi, 23
    mov ecx, 32
    call print_buffer
    call print_newline
    pop esi

    push esi
    mov ebx, [esi+19]       ;block size
    mov eax, [esi+11]       ;low LBA
    cmp dword [esi+15], 0
    jne .lba48

    call .print_size
    jmp .skip_lba48
.lba48:
    push ebx
    mov esi, show_usb_devices.usb_blocksize_str
    mov ebx, 0x00ffffff
    call print_string
    pop ebx

    mov eax, ebx
    call print_dec

    mov al, 'B'
    call print_char
    call print_newline

    mov esi, .high_storage_str
    mov ebx, 0x00ffffff
    call print_string

.skip_lba48:
    call print_newline
    ; add esi, 55
    ; call .print_partitions
    pop esi
    pop ecx

    pop eax
    pop esi
    jmp .continue
.ide_product_name: db '   Product name: ', 0
.high_storage_str: db 'Size: More than 128GB', 0
.atapi_str: db 'CD / DVD (ATAPI Device)', 0

.atapi:
    mov esi, .atapi_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline

    pop eax
    pop esi
    jmp .continue
    ret
.usb:
    push ecx
    push esi

    mov esi, usb_storage_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline

    mov esi, show_usb_devices.usb_vendor_str
    mov ebx, 0x00ffffff
    call print_string
    pop esi

    push esi
    mov ecx, 8
    call print_buffer
    call print_newline

    mov esi, show_usb_devices.usb_productname_str
    mov ebx, 0x00ffffff
    call print_string

    pop esi

    push esi
    add esi, 16
    mov ecx, 16
    call print_buffer
    call print_newline
    pop esi

    mov eax, [esi+32]
    mov ebx, [esi+36]
    call .print_size

    push esi

    ; add esi, 40
    ; call .print_partitions
    pop esi
    pop ecx

    pop eax
    pop esi
    jmp .continue


.print_size:
    ;EAX: max. LBA
    ;EBX: size of one block
    pusha
    push ebx
    push eax
    mov esi, show_usb_devices.usb_blocksize_str
    mov ebx, 0x00ffffff
    call print_string
    pop eax
    pop ebx

    push eax
    mov eax, ebx
    call print_dec

    mov al, 'B'
    call print_char
    call print_newline
    pop eax

    imul eax, ebx

    push eax
    mov esi, show_usb_devices.usb_capacity_str
    mov ebx, 0x00ffffff
    call print_string
    pop eax

    xor edx, edx
    mov ebx, 1000
    div ebx

    call print_dec
    
    mov esi, .kb_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    
    popa
    ret
.kb_str: db ' KB', 0
.print_partitions:
    ret
change_drive:
    ;create a new task so shell works fine while task is waiting for disk
;     .cdrive_str: db 'CDRIVE  SHL', 0
;     mov ah, 0x03
;     mov ebx, .change_drive
;     mov esi, .cdrive_str
;     int 0x35
;     ret
; .change_drive:
    mov esi, [argument]
    call string_uppercase

    cmp byte [esi], 0x41
    jb .error
    cmp byte [esi], 0x5a
    ja .error

    mov al, [esi]
    sub al, 0x41
    mov [esi], al

    mov ah, 0x20
    int 0x33
    jc .error

    mov esi, disk_changed_str
    mov ebx, COLOR_GREEN
    call print_string
    call print_newline
    ret
.error:
    push ax
    mov esi, disk_changed_err
    mov ebx, COLOR_RED
    call print_string
    pop ax
    movzx edx, ax
    call print_hex4

    call print_newline
    ret

show_usb_devices:
    pusha
    mov esi, usb_list_header
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    call print_newline

    mov esi, USB_DEVICE_LIST
    mov cl, 1
    movzx dx, byte [usb_devices]
    cmp dx, 0
    je .done
.loop:
    lodsb
    cmp al, 0
    je .unknown
    cmp al, 1
    je .keyboard
    cmp al, 2
    je .mouse
    cmp al, 3
    je .usb_stick
    cmp al, 4
    je .floppy
    cmp al, 5
    je .printer
    cmp al, 6
    je .usb_hub
    cmp al, 7
    je .external_drive
    cmp al, 0xff
    je .error

    cmp al, 0xee
    je .done
.next:
    inc cl
    add esi, USB_LIST_ENTRY-1
    dec dx
    jnz .loop
    jmp .done

.unknown:
    push esi
    movzx eax, cl
    call print_dec
    mov al, ':'
    call print_char
    mov al, 0x20
    call print_char

    mov esi, usb_unknown_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    pop esi
    jmp .next
.keyboard:
    push esi
    movzx eax, cl
    call print_dec
    mov al, ':'
    call print_char
    mov al, 0x20
    call print_char

    mov esi, usb_keyboard_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    pop esi
    jmp .next
.mouse:
    push esi
    mov esi, usb_mouse_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    pop esi
    jmp .next
.usb_stick:
    push edx
    push esi
    mov edi, esi
    movzx eax, cl
    call print_dec
    mov al, ':'
    call print_char
    mov al, 0x20
    call print_char

    mov esi, usb_stick_str
    mov ebx, 0x00ffffff
    call print_string

    mov ebp, [edi+24]       ;LBA
    mov edx, [edi+28]       ;block size
    
    push ebp
    push edx

    call print_newline
    mov esi, .usb_vendor_str
    call print_string

    mov esi, edi
    mov ecx, 8
    call print_buffer

    call print_newline
    mov esi, .usb_productname_str
    call print_string

    mov esi, edi
    add esi, 8
    mov ecx, 16
    mov ebx, 0x00ffffff
    call print_buffer

    call print_newline
    mov esi, .usb_blocksize_str
    mov ebx, 0x00ffffff
    call print_string

    pop edx
    mov eax, edx
    call print_dec

    mov al, 'B'
    mov ebx, 0x00ffffff
    call print_char

    call print_newline
    mov esi, .usb_capacity_str
    mov ebx, 0x00ffffff
    call print_string

    pop ebp
    imul edx, ebp
    mov eax, edx
    call print_dec

    mov al, 'B'
    mov ebx, 0x00ffffff
    call print_char

    call print_newline
    pop esi
    pop edx
    jmp .next
.usb_vendor_str: db '   Producer: ', 0
.usb_productname_str: db '   Product name: ', 0
.usb_capacity_str: db '   Capacity: ', 0
.usb_blocksize_str: db '   Size of one block: ', 0
.floppy:
    push esi
    mov esi, usb_floppy_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    pop esi
    jmp .next
.printer:
    push esi
    mov esi, usb_printer_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    pop esi
    jmp .next
.usb_hub:
    push esi
    mov esi, usb_hub_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    pop esi
    jmp .next
.external_drive:
    push esi
    mov esi, usb_extdrive_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    pop esi
    jmp .next
.error:
    push esi
    movzx eax, cl
    call print_dec
    mov al, ':'
    call print_char
    mov al, 0x20
    call print_char

    mov esi, usb_error_str
    mov ebx, 0x00ffffff
    call print_string
    call print_newline
    pop esi
    jmp .next
.done:
    popa
    ret

cd_directory:
    ret

show_memory_info:
    ret
%include "shell/coff_loader.asm"
%include "shell/shscripts.asm"