## README file

XMODE is a 32Bit operating system which is entirely written in Assembly.<br>
Currently it has no bootloader because it is made for the Xiromos OS.<br>
Here you can read how to install XMODE in Xiromos: https://github.com/xiromos/Xiromos


## Commands

### Standard
**help**: show available commands<br>
**clear**: clear screen<br>
**mmap**: shows memory map

### Filesystem
**ls**: list content of current directory<br>
**read**: print file<br>
**write**: create file<br>
**rename**: rename a file<br>
**delete**: delete a file<br>

## Features

- FAT16
- VESA Video Mode: 1024x768px
- windows
- own assembler
- preemptive multitasking
- DMA driver for hard disks
- multi-disk support

## How to use

To execute a program write it name in capital letters into the terminal. If you want to do a file operation (e.g. read FILE.TXT)<br>
the filename has to be capital. Because there is no mouse support you can switch between programs via the F1 key. It then opens a <br>
window in which you can chose a current active task. To do that just type the number of the task or press ESC. To get a list of <br>
available commands type "help". Also, if you dont boot with UEFI you will probably use Xiromos. To use XMODE just type "XMODE".

## TODO

- Window Manager
- Multi-Core support
- make AHCI driver
- Internet
- improve assembler
- support of higher resolutions (1080p)