RED="\033[31m"
GREEN="\033[32m"
MAGENTA="\033[35m"
RESET="\033[0m"

set -e
trap 'printf "${RED}Build failed!${RESET}\n"; exit 1' ERR

nasm -f bin kernel/kernel.asm -o kernel/kernel.bin
nasm -f bin programs/help.asm -o programs/help.bin
nasm -f bin programs/window.asm -o programs/window.bin
nasm -f bin xasm/xasm.asm -o  xasm/xasm.bin


# nasm -f elf32 ~/Downloads/xmode/kernel/kernel.asm -o ~/Downloads/xmode/kernel/kernel.o
# gcc -m32 -ffreestanding -c ~/Downloads/xmode/kernel/kernel.c -o ~/Downloads/xmode/kernel/kernelc.o
# ld -m elf_i386 -T ~/Downloads/xmode/build/linker.ld -o ~/Downloads/xmode/kernel/kernel.bin ~/Downloads/xmode/kernel/kernel.o ~/Downloads/xmode/kernel/kernelc.o
# printf "${GREEN}Succesfully compiled files!${RESET}\n"

nasm -f win64 boot.asm -o boot.obj
x86_64-w64-mingw32-ld -dll -shared --subsystem 10 -e _efi_main -o bootx64.efi boot.obj

mmd -i ~/Downloads/OS/disk.img ::/EFI
mmd -i  ~/Downloads/OS/disk.img ::/EFI/BOOT
mcopy -i  ~/Downloads/OS/disk.img bootx64.efi ::/EFI/BOOT
mcopy -i  ~/Downloads/OS/disk.img kernel/kernel.bin ::XMODE.BIN
mcopy -i  ~/Downloads/OS/disk.img programs/help.bin ::HELP.BIN
mcopy -i  ~/Downloads/OS/disk.img programs/window.bin ::WINDOW.BIN
mcopy -i  ~/Downloads/OS/disk.img xasm/xasm.bin ::XASM.BIN
mcopy -i  ~/Downloads/OS/disk.img sys/ ::SYS
mattrib -i  ~/Downloads/OS/disk.img +s ::SYS/AUTOSTRT.SYS
mattrib -i  ~/Downloads/OS/disk.img +s ::SYS/1BOOT.SYS
mcopy -i  ~/Downloads/OS/disk.img xasm/test.asm ::TEST.ASM


# Memory Map        (OS needs min. 25MB RAM)
# 0x0000 - 0x3fff: ROOT Directory
# 0x4000 - 0x7bff: FAT
# 0x7c00 - 0x7dff: MBR Boot Sector
# 0x7e00: Memory Map
# 0x8000 - 0x50000: Kernel
# 0x8a000: PCI list   (512bytes)
# 0x8a200: AHCI device list (512bytes)
# 0x8b000 - 0x8cfff: Command tables for AHCI (8KB)
# 0x91000 - 0x9f0000: proram kernel stack
# 0x2000000 - 0x2200000: programs
# 0x1a0000 - 0x1f0000: programs stack
# 0x200000 - 0x14fffff: window buffers