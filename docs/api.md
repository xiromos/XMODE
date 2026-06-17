# INT 0x30
## Video Output

### supported color format in EBX: 0x00RRGGBB

### AH = 0x01:
- print a null-terminated string to screen
- ESI: pointer to null terminated string
- EBX: color
- this function should not be used and will be (hopefully) deleted soon because <br>
  programs should use function 0x0A and print string into their window

### AH = 0x02:
- print a single char to the screen
- AL: ASCII Char
- EBX: color
- should also not be used

### AH = 0x03:
- add [cur_y] 8, next char/string will be printed in a new line
- no arguments needed
- should also not be used and will be removed soon, use function 0x0c instead

### AH = 0x04
- print a number in white in decimal format
- EBX: number
- use function 0x0d

### AH = 0x0A
- prints a string into a custom window (for example into a 400x200px window)
- ESI: pointer to null-terminated string
- EDI: pointer to window packet (special structure with widht/height/cur_x/cur_y/color/...)

### AH = 0x0B
- prints a single char into a window
- AL: character
- EDI: pointer to window packet

### AH = 0x0C
- adds +8 to cur_y in the window packet (sets a newline)
- EDI: window packet

### AH = 0x0D
- prints a decimal value in ASCII chars
- EBX: number
- EFI: window packet

### AH = 0x0E
- clears window (fill window in a specific color)
- EDI: window packet (offset +4B = bgcolor)

## Syscalls

1. Program / shell puts into AH function number
2. passes arguments into other registers
3. calls syscall via interrupt (e.g. 'int 0x30' for Video)
4. waits for syscall-exit and stores return value and checks if error happend (carry flag)