code_off        equ 0x08
data_off        equ 0x10
vidmem          equ 0xb8000
col             equ 80
line            equ 25
COLOR_RED       equ 0x00c21515
COLOR_GREEN     equ 0x001bcc49
cur: dd 0
gdt_loaded_msg: db '> GDT loaded', 0
idt_loaded_msg: db '> IDT loaded', 0
starting_shell_msg: db '> Starting shell...', 0
interupt_msg: db 'Interupt!', 0
start_msg: db '< XMODE Shell >', 0x0a,
           db 'Type "help" for help', 0
prompt_msg: db '# ', 0
argument: dd 0
scan_codes:
    db 0                  ; 0x00
    db 27                 ; ESC

    db '1','2','3','4','5','6','7','8','9','0'
    db '-','=',8          ; Backspace
    db 9                 ; Tab

    db 'q','w','e','r','t','y','u','i','o','p'
    db '[',']',13        ; Enter

    db 0                 ; Ctrl
    db 'a','s','d','f','g','h','j','k','l'
    db ';',"'",'`'

    db 0                 ; Left Shift
    db '\','z','x','c','v','b','n','m'
    db ',', '.', '/'

    db 0                 ; Right Shift
    db '*'              ; Numpad *
    db 0                ; Alt
    db ' '              ; Space
    db 0                ; Caps Lock

    ; F1–F10
    db 0,0,0,0,0,0,0,0,0,0

    ; More control keys
    db 0                ; Num Lock
    db 0                ; Scroll Lock

    ; Numpad
    db '7','8','9','-'
    db '4','5','6','+'
    db '1','2','3','0'
    db '.'
keymap_shift:
    db 0, 27, '!','@','#','$','%','^','&','*','(',')','_','+', 8
    db 9
    db 'Q','W','E','R','T','Y','U','I','O','P','{','}', 13
    db 0
    db 'A','S','D','F','G','H','J','K','L',':','"','~'
    db 0
    db '|','Z','X','C','V','B','N','M','<','>','?'
    db 0
    db '*'
    db 0
    db ' '
    db 0                ; Caps Lock

    ; F1–F10
    db 0,0,0,0,0,0,0,0,0,0

    ; More control keys
    db 0                ; Num Lock
    db 0                ; Scroll Lock

    ; Numpad
    db '7','8','9','-'
    db '4','5','6','+'
    db '1','2','3','0'
    db '.'

key_buffer: times 256 db 0
buf_head:   dd 0
buf_tail:   dd 0
shift: db 0
vbe_info: times 256 db 0
rows: dd 16
width       equ 1024
height      equ 768
max_rows    equ 48      ;768 / 16
bpp: db 0
pitch: dd 0
cur_x: dd 0
cur_y: dd 0
color: dd 0
bgcolor: dd 0
user_stack  equ 0x95000
tss:
    dd 0    ; dd prev_tss
    dd 0   ; dd esp0
    dd 0   ; dd ss0
    dd 0   ; dd esp1
    dd 0   ; dd ss1
    dd 0   ; dd esp2
    dd 0   ; dd ss2
    dd 0   ; dd ctr3
    dd 0   ; dd einsp
    dd 0   ; dd extflags
    dd 0   ; dd _eax
    dd 0   ; dd _ecx
    dd 0   ; dd _edx
    dd 0   ; dd _ebx
    dd 0   ; dd _esp
    dd 0   ; dd _ebp
    dd 0   ; dd _esi
    dd 0   ; dd _edi
    dd 0   ; dd _es
    dd 0   ; dd _cs
    dd 0   ; dd _ss
    dd 0   ; dd _ds
    dd 0   ; dd _fs
    dd 0   ; dd _gs
    dd 0   ; dd _ldt
    dw 0   ; dw _trap
    dw 0   ; dw iomap_base
.end:
hex4_out: db '0x0000', 0
;commands
help_msg: db 'In progress...', 0
help_str: db 'help', 0
clear_str: db 'clear', 0
ls_str: db 'ls', 0
read_str: db 'read', 0
del_str: db 'del', 0
rename_str: db 'rename', 0
write_str: db 'write', 0
command_buffer: db 0 dup(50)
;disk
fs_loading_str: db 'Loading FAT16...', 0
disk_lba:           ;extended read/write needs a structure which points to the LBA
    db 0
    db 0
    db 0
    db 0
    db 0
    db 0

;filesystem
sec_per_cluster: db 0
reserved_sectors: dw 0
fat_num: db 0
root_entries: dw 0
total_sectors: dw 0
fat_size: dw 0
hidden_sectors: dd 0
total_sectors32: dd 0

root_start: dw 0
root_sectors: dw 0
data_start: dw 0

root_addr       equ 0
fat_addr        equ 0x4000

dir_str: db '<DIR>', 0
read_buffer: db 0 dup(13)
read_buffer2: db 0 dup(13)
read_buffer3: db 0 dup(11)
file_buffer     equ 0x20000
cluster16: dw 0
first_cluster16: dw 0
file_size16: dd 0

read_error_msg: db 'Error while reading file', 0

del_success_msg: db 'File deleted', 0
delete_failure_msg: db 'Error while deleting file. Disk corrupted', 0

ren_prompt: db 'Enter new filename: ', 0
ren_err_msg: db 'Error while renaming file. File might be corrupted', 0

write_success: db 'File saved!', 0
write_failure: db 'Error while writing file. Disk might be corrupted', 0