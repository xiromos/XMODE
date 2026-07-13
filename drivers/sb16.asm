section .text
init:
    ;AL = IRQ number

    push ax
    ;get DSP version
    mov dx, 0x22c
    mov al, 0xe1
    out dx, al

    mov dx, 0x22a
    in al, dx
    mov ah, al
    in al, dx

    mov al, 0x80        ;set IRQ number
    mov dx, 0x224
    out dx, al

    pop ax
    mov dx, 0x225
    out dx, al

    mov dx, 0x224
    mov al, 0x81        ;set DMA mode
    out dx, al

    mov dx, 0x225
    xor al, al
    or al, (1 << 1) | (1 << 5)      ;set DMA 1 for 8-bit and DMA 5 for 16-bit
    out dx, al

    mov edx, kernel_packet
    mov dword [edx], play_wav_file
    mov dword [edx+8], irq_handler
    mov dword [edx+12], pause_play
    mov dword [edx+16], resume_play
    mov dword [edx+20], stop_play
    ret


play_wav_file:
    ;EDI = Address of file in memory
    pusha
.wait:
    cmp byte [active], 1
    je .wait

    mov byte [active], 1

    cmp dword [edi], 'RIFF'
    jne .error

    mov [addr], edi
    mov dword [offset], 0

    mov ax, [edi+22]        ;mode (mono / stereo)
    mov [mode], ax
    mov ebx, [edi+24]       ;sample rate

    mov esi, edi
    add esi, 44

    mov ax, [edi+34]
    mov [bits8], ax
    mov ecx, [edi+40]       ;size
    mov [size], ecx
    cmp ax, 8
    je .check8bit

    cmp ecx, 0x20000
    jb .clear_size

    mov ecx, 0x20000
    sub dword [size], 0x20000
    jmp .play
.check8bit:
    cmp ecx, 0x10000
    jb .clear_size

    mov ecx, 0x10000
    sub dword [size], 0x10000
    jmp .play

.clear_size:
    mov dword [size], 0
.play:
    cmp word [bits8], 8
    je .play_8bit

    ;mask channel 5
    mov dx, 0xd4
    mov al, 0x05
    out dx, al

    mov dx, 0xd8
    out dx, al

    mov dx, 0xd6
    mov al, 0x59
    out dx, al

    mov eax, esi
    shr eax, 1      ; addr / 2, because they are words, not bytes

    mov dx, 0xc4
    out dx, al
    mov al, ah
    out dx, al

    mov eax, esi
    shr eax, 16
    mov dx, 0x8b
    out dx, al

    mov eax, ecx
    shr eax, 1
    dec eax

    mov dx, 0xc6
    out dx, al
    mov al, ah
    out dx, al

    mov dx, 0xd4
    mov al, 0x01
    out dx, al

    mov al, 0x41
    call dsp_write
    mov eax, ebx
    shr eax, 8
    call dsp_write
    mov eax, ebx
    call dsp_write

    mov al, 0xb0    ;0xb6 = autoplay
    call dsp_write

    mov ax, [mode]
    cmp ax, 1
    je .mono

    mov al, 0x30        ;stereo (bit 5), signed (bit 4)

    mov eax, ecx
    shr eax, 2
    dec eax

    call dsp_write
    mov al, ah
    call dsp_write
    jmp .done

.mono:
    mov al, 0x10        ;mono, signed (bit 4)
    call dsp_write

    mov eax, ecx
    shr eax, 1
    dec eax

    call dsp_write
    mov al, ah
    call dsp_write

.done:
    cmp byte [irq_call], 1
    je .irq_done

    popa
    clc
    ret
.irq_done:
    clc
    ret
.play_8bit:
    ;mask channel 5
    mov dx, 0x0a
    mov al, 0x05
    out dx, al

    mov dx, 0x0c
    out dx, al

    mov dx, 0x0b
    mov al, 0x49
    out dx, al

    mov eax, esi

    mov dx, 0x02
    out dx, al
    mov al, ah
    out dx, al

    mov eax, esi
    shr eax, 16
    mov dx, 0x83
    out dx, al

    mov eax, ecx
    dec eax

    mov dx, 0x03
    out dx, al
    mov al, ah
    out dx, al

    mov dx, 0x0a
    mov al, 0x01
    out dx, al

    mov al, 0x41
    call dsp_write
    mov eax, ebx
    shr eax, 8
    call dsp_write
    mov eax, ebx
    call dsp_write

    mov al, 0x14        ;0xc6 = autoplay
    call dsp_write

    mov ax, [mode]
    cmp ax, 1
    je .mono8

    mov al, 0x20
    jmp .continue8
.mono8:
    xor al, al
.continue8:
    call dsp_write

    mov eax, ecx
    dec eax

    call dsp_write
    mov al, ah
    call dsp_write

    cmp byte [irq_call], 1
    je .done2

    popa
    clc
    ret
.done2:
    clc
    ret
.error:
    mov byte [active], 0
    stc
    ret

dsp_write:
    push edx
    mov dx, 0x22c
    push ax
.wait:
    in al, dx
    and al, 0x80
    jnz .wait
    pop ax

    out dx, al
    pop edx
    ret

; #### PAUSE / RESUME / STOP FUNCTIONS ####
pause_play:
    cmp word [bits8], 0
    je .error
    
    cmp word [bits8], 8
    je .pause8bit

    mov al, 0xd5
    call dsp_write
    clc
    ret
.pause8bit:
    mov al, 0xd0
    call dsp_write
    clc
    ret
.error:
    stc
    ret
resume_play:
    cmp word [bits8], 0
    je pause_play.error

    cmp word [bits8], 8
    je .resume8bit

    mov al, 0xd6
    call dsp_write
    clc
    ret
.resume8bit:
    mov al, 0xd4
    call dsp_write
    clc
    ret
stop_play:
    cmp byte [active], 0
    je pause_play.error

    cmp word [bits8], 8
    je .stop8bit

    ;mask channel
    mov dx, 0xd4
    mov al, 0x05
    out dx, al

    ;stop playing
    mov al, 0xd5
    call dsp_write

    call .reset_dsp

    mov dx, 0xd8
    xor al, al
    out dx, al  ;reset flip-flop

    mov dx, 0xd4
    mov al, 0x01
    out dx, al

    mov byte [active], 0
    clc
    ret
.stop8bit:
    ;mask channel
    mov dx, 0x0a
    mov al, 0x05
    out dx, al
    
    mov al, 0xd0
    call dsp_write

    call .reset_dsp

    mov dx, 0x0c
    xor al, al
    out dx, al

    mov dx, 0x0a
    mov al, 0x01
    out dx, al

    mov byte [active], 0
    clc
    ret
.reset_dsp:
    mov dx, 0x226
    mov al, 1
    out dx, al

    mov dx, 0x80
    in al, dx
    in al, dx
    in al, dx
    in al, dx

    mov dx, 0x226
    xor al, al
    out dx, al

    mov dx, 0x22e
.wait_dsp:
    in al, dx
    test al, (1 << 7)
    jz .wait_dsp

    mov dx, 0x22a
    in al, dx
    ret
; #### INTERRUPT HANDLER ####

irq_handler:
    pusha
    mov dx, 0x22e
    in al, dx
    mov dx, 0x22f
    in al, dx

    cmp word [bits8], 8
    je .bit8

    cmp dword [size], 0
    je .done

    cmp dword [size], 0x20000
    jb .last_block

    sub dword [size], 0x20000
    mov ecx, 0x20000
    add dword [offset], ecx
    mov edi, [addr]
    mov ebx, [edi+24]       ;sample rate
    mov esi, edi
    add esi, 44
    add esi, [offset]

    mov byte [irq_call], 1
    call play_wav_file.play
    mov byte [irq_call], 0

.done_play_block:
    mov al, 0x20
    out 0x20, al
    popa
    iret
.last_block:
    mov ecx, [size]
    
    cmp word [bits8], 8
    je .add_8bit

    add dword [offset], 0x20000
    jmp .next
.add_8bit:
    add dword [offset], 0x10000
.next:
    mov dword [size], 0
    mov edi, [addr]
    mov ebx, [edi+24]       ;sample rate
    mov esi, edi
    add esi, 44
    add esi, [offset]

    mov byte [irq_call], 1
    call play_wav_file.play
    mov byte [irq_call], 0
    jmp .done_play_block
.bit8:
    cmp dword [size], 0
    je .done

    cmp dword [size], 0x10000
    jb .last_block

    sub dword [size], 0x10000
    mov ecx, 0x10000
    add dword [offset], ecx
    mov edi, [addr]
    mov ebx, [edi+24]
    mov esi, edi
    add esi, 44
    add esi, [offset]

    mov byte [irq_call], 1
    call play_wav_file.play
    mov byte [irq_call], 0

    jmp .done_play_block
.done:
    mov al, 0x20
    out 0x20, al

    mov dword [offset], 0
    mov byte [active], 0
    mov word [bits8], 0
    popa
    iret

section .data
active: db 0
irq_call: db 0

section .bss
kernel_packet:
    resd 1        ;play WAV audio file
    resd 1
    resd 1        ;IRQ handler
    resd 1        ;pause play
    resd 1        ;resume play
    resd 1        ;stop play
mode: resb 1
size: resd 1
addr: resd 1
bits8: resw 1
offset: resd 1