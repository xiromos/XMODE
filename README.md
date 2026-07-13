## README file

XMODE is a 32Bit operating system which is entirely written in x86 Assembly.<br>
It comes with an 64-Bit UEFI bootloader and a 16-Bit realmode BIOS bootloader.


## Commands

### Standard
**help**: show available commands<br>
**clear**: clear screen<br>
**mmap**: shows memory map + available memory<br>
**pci**: shows all PCI devices<br>
**usb**: shows all USB devices (OHCI only, UHCI planned)
**lsdisk**: lists all available drives and general information about them

### Filesystem
**ls**: list content of current directory<br>
**read**: print file<br>
**write**: create file<br>
**rename**: rename a file<br>
**delete**: delete a file<br>
**cdisk**: switch drive

## Main Features

- FAT16
- Video Mode: 1024x768px (BIOS VBE and GOP supported)
- windows / window manager
- own assembler (only 10 instructions)
- preemptive multitasking
- task states like 'running', 'waiting for disk', 'in queue'
- PCI Busmastering (U)DMA driver for ATA devices
- multi-disk support
- OHCI USB Keyboard driver
- OHCI USB Stick driver
- COFF program loading (32-Bit)
- AHCI driver (in work)
- Sound Blaster 16 driver - play any WAV file and listen music
- allocating and freeing heap memory via syscalls

## Special Features
- some drivers are loaded as external modules from the 'drivers' directory
- scheduler which skips tasks if they are waiting, for example for disk

## TODO

- real Window Manager
- SMP
- APIC support
- finish AHCI driver
- Internet
- improve assembler
- support of higher resolutions (1080p)
- UHCI and EHCI drivers


## How to build
```bash
git clone https://github.com/xiromos/xmode.git
cd xmode
chmod +x buildx.sh
./buildx.sh
```