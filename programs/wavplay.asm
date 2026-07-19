;=============================================================
;program to play .wav files
;Copyright (C) 2026 Technodon
;=============================================================

;ERROR using Argument -R after -C crashes
section .text
start:
    ;ARG1 (ESI): filename
    ;ARG2 (EDI): empty
    pop eax     ;old SS
    pop esi

    cmp word [esi], '-C'
    je .cancel_play
    cmp word [esi], '-H'
    je .show_help
    cmp word [esi], '-R'
    je .resume_play
    cmp word [esi], '-P'
    je .pause_play

    cmp dword [esi], 0xffffffff
    je .show_help


    xor ah, ah
    xor edi, edi
    int 0x33

    push esi

    mov [size], ecx
    mov ah, 0xc
    int 0x35

    mov [heap], esi
    mov edi, esi
    xor edx, edx
    pop esi
    mov ah, 0x0a
    mov bl, 0xff
    int 0x33
    jc .disk_error

    mov edi, [heap]
    mov bh, 0x01
    mov ah, 0x20        ;play WAV file
    int 0x35
    jc .no_sound

.done:
    mov esi, [heap]
    mov ecx, [size]
    mov ah, 0x0d
    int 0x35

    mov ah, 0x05
    int 0x35

.disk_error:
    mov esi, disk_error_msg
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30

    jmp .done
.no_filename:
    mov esi, no_filename_msg
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30

    mov ah, 0x05
    int 0x35
.no_sound:
    mov esi, no_sound_msg
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30

    jmp .done
.cancel_play:
    mov ah, 0x20
    mov bh, 0x04
    int 0x35
    jnc .done2

    mov esi, cancel_err_msg
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30
    jmp .done2
.show_help:
    mov esi, help_msg
    mov ebx, 0x00ffffff
    mov ah, 0x01
    int 0x30

    jmp .done2
.pause_play:
    mov ah, 0x20
    mov bh, 0x02
    int 0x35
    jnc .done2

    mov esi, pause_err_msg
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30
    jmp .done2
.resume_play:
    mov ah, 0x20
    mov bh, 0x03
    int 0x35
    jnc .done2

    mov esi, resume_err_msg
    mov ebx, COLOR_RED
    mov ah, 0x01
    int 0x30
.done2:
    mov ah, 0x05
    int 0x35
section .data
heap: dd 0
size: dd 0
disk_error_msg: db 'Error while loading file', 0x0a, 0
no_filename_msg: db 'No file specified', 0x0a, 0
no_sound_msg: db 'Error while playing sound. Maybe there is no supported soundcard', 0x0a, 0
cancel_err_msg: db 'Error while cancelling play. Couldnt find a playing song', 0x0a, 0
pause_err_msg: db 'Error while pausing audio. No WAV file currently playing', 0x0a, 0
resume_err_msg: db 'Error while trying to resume play WAV file. No WAV file currently playing', 0x0a, 0

help_msg:
    db 'WAVPLAY - program for playing WAV files', 0x0a,
    db 'Supported arguments: ', 0x0a,
    db '<filename.wav>: play this WAV file', 0x0a,
    db '-p: pause play of WAV file', 0x0a,
    db '-r: resume play of WAV file', 0x0a,
    db '-c: cancel play of WAV file', 0x0a,
    db '-h: show this message', 0x0a, 0
COLOR_RED       equ 0xbf0d0d