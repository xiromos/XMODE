;======================================
;CPUID program to check CPU information
;Copyright (C) 2026 Technodon
;======================================


section .text

start:
    pushfd
    pop eax

    mov ecx, eax
    xor eax, (1 << 21)

    push eax
    popfd

    pushfd
    pop eax

    xor eax, ecx
    and eax, (1 << 21)

    push ecx
    popfd

    cmp eax, 0
    je .no_cpuid

    ;print vendor string
    mov esi, vendor_str
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30

    xor eax, eax
    cpuid

    mov eax, ebx
    call print_register
    mov eax, edx
    call print_register
    mov eax, ecx
    call print_register
    mov ah, 0x03
    int 0x30

    mov esi, line
    mov ebx, COLOR_CYAN
    mov ah, 0x01
    int 0x30
        
    mov eax, 1
    cpuid

    push edx
    call print_features

    mov esi, line
    mov ebx, COLOR_CYAN
    mov ah, 0x01
    int 0x30

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000004
    jb .exit

    mov esi, modelname_str
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30

    mov eax, 0x80000002
    cpuid

    call print_register
    mov eax, ebx
    call print_register
    mov eax, ecx
    call print_register
    mov eax, edx
    call print_register

    mov eax, 0x80000003
    cpuid

    call print_register
    mov eax, ebx
    call print_register
    mov eax, ecx
    call print_register
    mov eax, edx
    call print_register

    mov eax, 0x80000004
    cpuid

    call print_register
    mov eax, ebx
    call print_register
    mov eax, ecx
    call print_register
    mov eax, edx
    call print_register

    mov ah, 0x03
    int 0x30
.exit:
    pop edx
    ;returns EDX
    mov ah, 0x05
    int 0x35



.no_cpuid:
    mov esi, not_supported_msg
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30
    jmp .exit

print_register:
    call print_char
    shr eax, 8
    call print_char
    shr eax, 8
    call print_char
    shr eax, 8
    call print_char
    ret
print_char:
    push eax
    push ebx
    mov ah, 0x02
    mov ebx, COLOR_BLUE
    int 0x30
    pop ebx
    pop eax
    ret

print_features:
    xor eax, eax
    test edx, eax
    jnz .skip

    mov esi, fpu_str
    mov ah, 0x01
    mov ebx, 0x00ffffff
    int 0x30
.skip:
    mov eax, 1
    mov ecx, 30
.loop:
    test edx, eax
    jz .next

    mov esi, fpu_str
    cmp eax, (1 << 1)
    je .print_string

    mov esi, vme_str
    cmp eax, (1 << 2)
    je .print_string

    mov esi, de_str
    cmp eax, (1 << 3)
    je .print_string

    mov esi, tsc_str
    cmp eax, (1 << 4)
    je .print_string

    mov esi, msr_str
    cmp eax, (1 << 5)
    je .print_string

    mov esi, pae_str
    cmp eax, (1 << 6)
    je .print_string

    mov esi, mce_str
    cmp eax, (1 << 7)
    je .print_string

    mov esi, cx8_str
    cmp eax, (1 << 8)
    je .print_string

    mov esi, apic_str
    cmp eax, (1 << 9)
    je .print_string

    mov esi, sep_str
    cmp eax, (1 << 11)
    je .print_string

    mov esi, mttr_str
    cmp eax, (1 << 12)
    je .print_string

    mov esi, pge_str
    cmp eax, (1 << 13)
    je .print_string

    mov esi, mca_str
    cmp eax, (1 << 14)
    je .print_string

    mov esi, cmov_str
    cmp eax, (1 << 15)
    je .print_string

    mov esi, pat_str
    cmp eax, (1 << 16)
    je .print_string

    mov esi, pse36_str
    cmp eax, (1 << 17)
    je .print_string

    mov esi, psn_str
    cmp eax, (1 << 18)
    je .print_string

    mov esi, clflush_str
    cmp eax, (1 << 19)
    je .print_string

    mov esi, ds_str
    cmp eax, (1 << 21)
    je .print_string

    mov esi, acpi_str
    cmp eax, (1 << 22)
    je .print_string

    mov esi, mmx_str
    cmp eax, (1 << 23)
    je .print_string

    mov esi, fxsr_str
    cmp eax, (1 << 24)
    je .print_string

    mov esi, sse_str
    cmp eax, (1 << 25)
    je .print_string

    mov esi, sse2_str
    cmp eax, (1 << 26)
    je .print_string

    mov esi, ss_str
    cmp eax, (1 << 27)
    je .print_string

    mov esi, htt_str
    cmp eax, (1 << 28)
    je .print_string

    mov esi, tm_str
    cmp eax, (1 << 29)
    je .print_string

    mov esi, ia64_str
    cmp eax, (1 << 30)
    je .print_string

    mov esi, pbe_str
    cmp eax, (1 << 31)
    je .print_string
.next:
    add eax, eax
    dec ecx
    jnz .loop
    ret

.print_string:
    ;ESI = string
    push eax
    push edx
    mov ah, 0x01
    mov ebx, 0x00ffffff
    int 0x30
    pop edx
    pop eax
    jmp .next

section .data
COLOR_CYAN      equ 0x2bedff
COLOR_BLUE      equ 0x2d33f7

not_supported_msg: db 'CPUID Instruction not supported. You are probably using an i386 processor', 0x0a, 0
vendor_str: db 'CPU Vendor: ', 0
modelname_str: db 'CPU Model: ', 0
line: db '--------------------------------------', 0x0a, 0
cpu_features_str: db 'CPU features: ', 0x0a, 0
fpu_str: db 'FPU (Floating Point Unit)', 0x0a, 0
vme_str: db 'VME (Virtual Mode Extensions): extensions for the Virtual 8086 Mode', 0x0a, 0
de_str: db 'DE (Debugging Extensions): allows to set breakpoints in code', 0x0a, 0
pse_str: db 'PSE (Page Size Extension): allows the OS to use bigger pages (eg. 4MB)', 0x0a, 0
tsc_str: db 'TSC (Time Stamp Counter): counter which is increased by every CPU clock cycle', 0x0a, 0
msr_str: db 'MSR (Model Specific Registers): special control registers in CPU', 0x0a, 0
pae_str: db 'PAE (Physical Address Extension): allows 32Bit processors to access up to 64GB of memory', 0x0a, 0
mce_str: db 'MCE (Machine Check Exception): if there are serious hardware errors/defects CPU reports them to OS', 0x0a, 0
cx8_str: db 'CMPXCHG8B instruction available', 0x0a, 0
apic_str: db 'APIC (Advanced Programmable Interrupt Controller) supported, essential for multicore systems', 0x0a, 0
sep_str: db 'SEP: SYSENTER/SYSEXIT instructions available to switch user and kernel mode fast', 0x0a, 0
mttr_str: db 'MTTR (Memory Type Range Registers): reigsters to control cache behaviour of memory regions', 0x0a, 0
pge_str: db 'PGE (Page Global Enable)', 0x0a, 0
mca_str: db 'MCA (Machine Check Architecture): extended architecture of MCE. Lists detailed error report', 0x0a, 0 
cmov_str: db 'CMOV (Conditional Move) instruction available: copies data only if a condition is true', 0x0a, 0
pat_str: db 'PAT (Page Attribute Table): OS has more control about cached memory regions', 0x0a, 0
pse36_str: db 'PSE36 (Page Size Extension 36 bit): extension of PSE which allows addressing 4MB pages in a 64GB physical memory region, without activating PAE', 0x0a, 0
psn_str: db 'PSN (Processor Serial Number): serial number', 0x0a, 0
clflush_str: db 'CLFLUSH (Cache Line Flush) instruction available: transfers data from CPU cache to RAM', 0x0a, 0 
ds_str: db 'DS (Debug Store): region in memory where CPU can write debug information', 0x0a, 0
acpi_str: db 'ACPI (Advanced Configuration and Power Interface): shows, that CPU has special registers for controlling hardware', 0x0a, 0
mmx_str: db 'MMX (Multi-Media Extensions): shows that CPU supports SIMD (Singe Instruction, Multiple Data)', 0x0a, 0
fxsr_str: db 'FXSR (FXSAVE, FXSTOR) instructions available to save FPU and MMX/SSE registers', 0x0a, 0
sse_str: db 'SSE (Streaming SIMD Extensions): brings faster instructions for processing 3D-Grahpics and Audio/Video-Editing', 0x0a, 0
sse2_str: db 'SSE2 (Streaming SIMD Extensions 2): expands SSE with support of floating-point numbers and mathimatical 64-Bit operations', 0x0a, 0
ss_str: db 'SS (Self Snoop): CPU can monitor its caches to check if they are consistant', 0x0a, 0
htt_str: db 'HTT (Hyper-Threading Technology): allows the CPU to a physical CPU core into two logical cores', 0x0a, 0
tm_str: db 'TM (Thermal Monitor): inbuild temperatur sensor, which lowers the amount of clock cycles if CPU is overheating', 0x0a, 0
ia64_str: db 'IA64 (Intel Itanium Architecture): This CPU is an Intel Itanium 64-Bit processor', 0x0a, 0
pbe_str: db 'PBE (Pending Break Enable)', 0x0a, 0