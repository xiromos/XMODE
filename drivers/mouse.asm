;==========================================================================
;PS/2 mouse driver
;Copyright (C) 2026 Technodon
;==========================================================================

init_mouse:
    ;enable mouse
    mov al, 0xa8
    out 0x64, al

    ;enable interrupts
    mov al, 0x20
    out 0x64, al
    in al, 0x60
    or al, 2        ;enable IRQ12
    out 0x64, 0x60
    out 0x60, al

    call mouse_write
    mov al, 0xf4
    call mouse_write
    ret
mouse_write:
    push eax
.wait:
    in al, 0x64
    test al, 2
    jnz .wait
    mov al, 0xd4
    out 0x64, al
.wait2:
    in al, 0x64
    test al, 2
    jnz .wait2

    pop eax
    out 0x60, al
    ret