;test file to compile with Xiromos Assembler
$b32        ;set 32bit mode
mov ax 77   ;mov the number 77 into AX register
mov bp 67
int 48
retf        ;go back to shell
$end        ;end of program