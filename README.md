## README file

XMODE is a 32Bit operating system which is entirely written in x86 Assembly.<br>
It comes with an UEFI bootloader, but if you use BIOS (like SeaBIOS in QEMU) you <br>
have to install it on Xiromos. <br>
Here you can read how to install XMODE in Xiromos: https://github.com/xiromos/Xiromos


## Commands

### Standard
**help**: show available commands<br>
**clear**: clear screen<br>
**mmap**: shows memory map<br>
**pci**: shows all PCI devices
**usb**: shows all USB devices (OHCI only, UHCI planned)

### Filesystem
**ls**: list content of current directory<br>
**read**: print file<br>
**write**: create file<br>
**rename**: rename a file<br>
**delete**: delete a file<br>
**cdisk**: switch disk

## Features

- FAT16
- VESA Video Mode: 1024x768px
- windows / window manager
- own assembler
- preemptive multitasking
- task states like 'running', 'waiting for disk', 'in queue'
- PCI Busmastering (U)DMA driver for hard disks
- multi-disk support
- OHCI Keyboard driver
- AHCI driver (in work)

## Special Features
- some drivers are loaded as external modules from the 'drivers' directory
- scheduler which skips tasks if they are waiting, for example for disk

## How to use

Switch Tasks via F1 Key. It doesnt matter if you type command with or without capital <br>
letters because shell isnt case sensitive.

## TODO

- real Window Manager
- Multi-Core support
- APIC support
- finish AHCI driver
- Internet
- improve assembler
- support of higher resolutions (1080p)
- UCHI and EHCI drivers