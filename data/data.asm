code_off        equ 0x08
data_off        equ 0x10
code_off_user   equ (4*8) | 3
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

    db 'q','w','e','r','t','z','u','i','o','p'
    db '[',']',13        ; Enter

    db 0                 ; Ctrl
    db 'a','s','d','f','g','h','j','k','l'
    db ';',"'",'`'

    db 0                 ; Left Shift
    db '\','y','x','c','v','b','n','m'
    db ',', '.', '/'

    db 0                 ; Right Shift
    db '*'              ; Numpad *
    db 0                ; Alt
    db ' '              ; Space
    db 0                ; Caps Lock

    ; F1–F10
    db 0x3b,0x3c,0x3d,0x3e,0x3f,0x40,0x41,0x42,0x43,0x44

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
    db 'Q','W','E','R','T','Z','U','I','O','P','{','}', 13
    db 0
    db 'A','S','D','F','G','H','J','K','L',':','"','~'
    db 0
    db '|','Y','X','C','V','B','N','M','<','>','?'
    db 0
    db '*'
    db 0
    db ' '
    db 0                ; Caps Lock

    ; F1–F10
    db 0x3b,0x3c,0x3d,0x3e,0x3f,0x40,0x41,0x42,0x43,0x44

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
KEY_BUFFER      equ 0x50000
KEY_BUFFER_SIZE equ 256
BUFFER_HEAD     equ 0x57000
BUFFER_TAIL    equ 0x57100
shift: db 0
vbe_info: times 256 db 0
rows: dd 16
width       equ 1024
height      equ 768
max_rows    equ 48      ;768 / 16

real_width: dd 0
real_height: dd 0

bpp: db 0
pitch: dd 0
cur_x: dd 0
cur_y: dd 0
color: dd 0
bgcolor: dd 0
user_stack  equ 0x9fb00     ;0x91000
program_stack   equ 0x1a0000
program_stack_off   equ 0x1000      ; ~4KB
kernel_stack dd 0
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
hex8_out: db '0x00000000', 0
mmap_buffer     equ 0x7e00  ;512 bytes after bootloader
mmap_entries: dd 0
mmap_str: db 'Memory Map:           1 - Usable / 2 - Reserved', 0
memmap_str: db 'mmap', 0
mmap_bytes_per_entry: db 'Bytes per Entry: ', 0
;commands
help_msg: db 'In progress...', 0
help_str: db 'help', 0
clear_str: db 'clear', 0
ls_str: db 'ls', 0
read_str: db 'read', 0
del_str: db 'del', 0
rename_str: db 'rename', 0
write_str: db 'write', 0
tasklist_str: db 'tasklist', 0
command_buffer: db 0 dup(50)
;disk
fs_loading_str: db '> Loading FAT16...', 0
disk_lba:           ;extended read/write needs a structure which points to the LBA
    db 0
    db 0
    db 0
    db 0
    db 0
    db 0
align 4
prdt:
    dd 0x00005000            ;buffer
    dw 512                   ;sector size
    dw 0x8000
pci_bus: db 0
pci_device: db 0
pci_function: db 0
bm_base: dd 0
bm_base4: dw 0
dma_done: db 0
cur_bmbase_str: db '< BM Base: ', 0
sec_per_cluster: db 0
reserved_sectors: dw 0
fat_num: db 0
root_entries: dw 0
total_sectors: dw 0
fat_size: dw 0
hidden_sectors: dd 0
total_sectors32: dd 0
bytes_per_sec: dw 0

root_start: dw 0
root_sectors: dw 0
data_start: dw 0
subdir_entries: dw 0

root_addr       equ 0
fat_addr        equ 0x4000
program_addr    equ 0x100000
program_addr_off equ 0x20000
dir_str: db '<DIR>', 0
sys_str: db '<SYS>', 0
read_buffer: times 13 db 0
read_buffer2: times 13 db 0
read_buffer3: times 11 db 0
file_buffer     equ 0x20000
cluster16: dw 0
first_cluster16: dw 0
file_size16: dd 0
prev_cluster16: dw 0

read_error_msg: db 'Error while reading file', 0

del_success_msg: db 'File deleted', 0
delete_failure_msg: db 'Error while deleting file', 0

ren_prompt: db 'Enter new filename: ', 0
ren_err_msg: db 'Error while renaming file', 0

write_success: db 'File saved!', 0
write_failure: db 'Error while writing file', 0
write_prompt: db 'Enter file content (ESC = save):', 0

file_test_txt db        "TEST    TXT"
program_help_bin db     "HELP    BIN"
shell_task_str db       "SHELL   SYS"

;windows and multitasking
windows_list:
    times 10 db 0
num_windows: dw 10
window_id: dw 0
win_x: dd 0
win_y: dd 0
win_width: dd 0
win_height: dd 0
win_color: dd 0
win_border_color: dd 0x001015c2
untitled_str: db 'untitled', 0

char_bgcolor: dd 0
win_pitch: dd 0
win_rows: dd 0
cust_height: dd 0
win_buffer_addr: dd 0

task_count: dw 0
max_tasks: dw 4
current_task: dw 1
task_slots: dw 4

main_task: dw 1

tasks_esp:
    times 11 db 0
    dd 0        ;task 0 (reserved)
    dd 0
    times 11 db 0
    dd 0        ;task 1 (shell)
    dd 0
    times 11 db 0
    dd 0        ;task 2
    dd 0
    times 11 db 0
    dd 0        ;task 3
    dd 0
    times 11 db 0
    dd 0        ;task 4
    dd 0
    times 11 db 0
    dd 0
    dd 0

tasks_kernel_stack      equ 0x90000
tasks_kernel_stack_off  equ 0x1000      ;every task has ~4KB stack
TASK_SIZE               equ 19
task_limit: db 'Maximum amount of tasks achieved!', 0
create_task_err: db 'Error while creating task', 0

switch_tasks_window:
    dd 0            ;foreground color
    dd 0x00ffffff   ;background color
    dd 500          ;width
    dd 200          ;height
    dd width /2-250          ;CurX
    dd height /2-150          ;CurY
    dd width /2-250          ;original CurX
    dd height /2-150          ;original CurY
switch_tasks_str: db 'Switch Tasks - ESC to quit', 0
switch_tasks_win_id: dw 0
switch_tasks_msg: db 'Available Tasks: ', 0