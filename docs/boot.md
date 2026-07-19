# Boot Process

## Legacy BIOS
- BIOS loads MBR (Master Boot Record - 1. sector of drive) to address 0x7c00
- executes the bootloader
- bootloader loads Root Directory, FAT and searches for KERNEL.BIN
- if found it gives the file full control and pass some arguments about where the root and data LBA is

Then Xiromos Kernel does following things:
- initializes Video Mode (Mode 0x12, 640x480, 4Bit colors)
- gets information about drive and filesystem
- prints logo
- counts and initializes drives
- activates A20 Gate
- loads directory SYS and file SYS/AUTOSTRT.SYS
- checks content of the file
- if the first char of the file is '1', Xiromos Kernel loads file XMODE.BIN from Root Directory to address 0x8000
- sets BIOS VBE Mode 0x118 (1024x768, 24bit)
- performs a far jump to 0x8000

## UEFI
- UEFI searches for /EFI/BOOT/BOOTX64.EFI
- executes it
- bootloader searches for video mode 1024x768 (XGA)
- if found it sets that video mode
- then bootloader opens the root directory and searches for XMODE.BIN
- if found UEFI loads it to 0x8000
- then it asks for memory map from UEFI and copies it to address 0x1ff000
- bootloader calls ExitBootservices()
- it passes into registers information about video mode (like address of frame buffer, bytes per pixel,...)
- jumps to 0x8000+250 to skip BIOS code in kernel
- stores information about frame buffer in variables and switches to protected mode, while also disabling paging to load later its own page directory


### After Bootloaders

- kernel loads IDT (interrupt descriptor table) and remaps PIC (Programmable Interrupt Controller) to 0x20
- it activates paging in CR0 (identity mapping) and initializes heap memory
- then it scans PCI for IDE / AHCI / OHCI controller
- when found AHCI or IDE it calls the 'init' function for them and stores information about all drives in a list
- after that it takes information from the boot sector about filesystem and calculates Root Directory and Data Area start LBAs
- kernel loads DRIVERS directory and checks if an OHCI controller was found
- if yes it searches for /DRIVERS/OHCI.SYS and loads it to 0x61000, executing it if found
- driver gives kernel information about Open Host Controller so it can set up an IRQ handler for it
- after registering 1. task (SHELL.SYS) in the task list the kernel performs a switch to User Mode (Ring 3) and executes shell code

The operating system is now ready to work and waits for commands.