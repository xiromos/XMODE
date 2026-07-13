RED="\033[31m"
GREEN="\033[32m"
MAGENTA="\033[35m"
RESET="\033[0m"

set -e
trap 'printf "${RED}Build failed!${RESET}\n"; exit 1' ERR

# UNCOMMENT FOR BUILD WITH XIROMOS
# nasm -f bin kernel/kernel.asm -o kernel/kernel.bin
# nasm -f bin drivers/ohci.asm -o bin/ohci.bin
# nasm -f win32 programs/help.asm -o programs/help.obj
# nasm -f win32 programs/window.asm -o programs/window.obj
# nasm -f bin xasm/xasm.asm -o  xasm/xasm.bin



# UNCOMMENT FOR BUILD WITH XIROMOS
# nasm -f win64 boot.asm -o boot.obj
# x86_64-w64-mingw32-ld -dll -shared --subsystem 10 -e _efi_main -o bootx64.efi boot.obj
# nasm -f win32 programs/coff.asm -o programs/coff.obj


### IGNORE
# mmd -i ~/Downloads/OS/disk.img ::/EFI
# mmd -i  ~/Downloads/OS/disk.img ::/EFI/BOOT
# mcopy -i  ~/Downloads/OS/disk.img bootx64.efi ::/EFI/BOOT
# mcopy -i  ~/Downloads/OS/disk.img kernel/kernel.bin ::XMODE.BIN
# mcopy -i  ~/Downloads/OS/disk.img programs/help.obj ::HELP.OBJ
# mcopy -i  ~/Downloads/OS/disk.img programs/window.obj ::WINDOW.OBJ
# mcopy -i  ~/Downloads/OS/disk.img xasm/xasm.bin ::XASM.BIN
# mcopy -i ~/Downloads/OS/disk.img programs/coff.obj ::COFF.OBJ
# mcopy -i  ~/Downloads/OS/disk.img sys/ ::SYS
# mattrib -i  ~/Downloads/OS/disk.img +s ::SYS/AUTOSTRT.SYS
# mattrib -i  ~/Downloads/OS/disk.img +s ::SYS/1BOOT.SYS
# mcopy -i  ~/Downloads/OS/disk.img xasm/test.asm ::TEST.ASM
# mcopy -i ~/Downloads/OS/disk.img configs/ ::XCONFIGS
# mmd -i ~/Downloads/OS/disk.img ::/DRIVERS
# mcopy -i ~/Downloads/OS/disk.img bin/ohci.bin ::/DRIVERS/OHCI.SYS
# mcopy -i ~/Downloads/OS/disk.img shell/test.sh ::TEST.SH

### FOR BUILD WITH XIROMOS
# mmd -i ~/Downloads/Xiromos/disk.img ::/EFI
# mmd -i  ~/Downloads/Xiromos/disk.img ::/EFI/BOOT
# mcopy -i  ~/Downloads/Xiromos/disk.img bootx64.efi ::/EFI/BOOT
# mcopy -i  ~/Downloads/Xiromos/disk.img kernel/kernel.bin ::XMODE.BIN
# mcopy -i  ~/Downloads/Xiromos/disk.img programs/help.obj ::HELP.OBJ
# mcopy -i  ~/Downloads/Xiromos/disk.img programs/window.bin ::WINDOW.BIN
# mcopy -i  ~/Downloads/Xiromos/disk.img xasm/xasm.bin ::XASM.BIN
# mcopy -i  ~/Downloads/Xiromos/disk.img sys/ ::SYS
# mattrib -i  ~/Downloads/Xiromos/disk.img +s ::SYS/AUTOSTRT.SYS
# mattrib -i  ~/Downloads/Xiromos/disk.img +s ::SYS/1BOOT.SYS
# mcopy -i  ~/Downloads/Xiromos/disk.img xasm/test.asm ::TEST.ASM
# mcopy -i ~/Downloads/Xiromos/disk.img configs/ ::XCONFIGS
# mmd -i ~/Downloads/Xiromos/disk.img ::/DRIVERS
# mcopy -i ~/Downloads/Xiromos/disk.img bin/ohci.bin ::/DRIVERS/OHCI.SYS
# mcopy -i ~/Downloads/Xiromos/disk.img shell/test.sh ::TEST.SH

### COMMENT OUT IF BUILD WITH XIROMOS
###################### BUILD OS #############################

nasm -f bin biosboot.asm -o biosboot.bin

dd if=/dev/zero of=build/disk.img bs=1M count=10
mkdosfs -F 16 build/disk.img
#mkdosfs -F 16 build/disk.img -h 2048
dd if=biosboot.bin of=build/disk.img bs=1 count=450 seek=62 skip=62 conv=notrunc

nasm -f bin kernel/kernel.asm -o build/kernel.bin
nasm -f bin drivers/ohci.asm -o build/ohci.bin
nasm -f win32 programs/help.asm -o build/help.obj
nasm -f win32 programs/window.asm -o build/window.obj
nasm -f bin xasm/xasm.asm -o  build/xasm.bin
nasm -f win32 drivers/sb16.asm -o build/sb16.obj
nasm -f win32 drivers/intel-hd_audio.asm -o build/intl_aud.obj
nasm -f win32 programs/cpuid.asm -o build/cpuid.obj
nasm -f win32 programs/wavplay.asm -o build/wavplay.obj

nasm -f win64 boot.asm -o bootx64.obj
x86_64-w64-mingw32-ld -dll -shared --subsystem 10 -e _efi_main -o bootx64.efi bootx64.obj
nasm -f win32 programs/coff.asm -o build/coff.obj

mmd -i build/disk.img ::/EFI
mmd -i  build/disk.img ::/EFI/BOOT
mcopy -i  build/disk.img bootx64.efi ::/EFI/BOOT
mcopy -i  build/disk.img build/kernel.bin ::XMODE.BIN
mcopy -i  build/disk.img build/help.obj ::HELP.OBJ
mcopy -i build/disk.img build/window.obj ::WINDOW.OBJ
mcopy -i  build/disk.img build/xasm.bin ::XASM.BIN
mcopy -i build/disk.img build/coff.obj ::COFF.OBJ
mcopy -i build/disk.img build/cpuid.obj ::CPUID.OBJ
mcopy -i build/disk.img build/wavplay.obj ::WAVPLAY.OBJ
mcopy -i  build/disk.img sys/ ::SYS
mattrib -i  build/disk.img +s ::SYS/AUTOSTRT.SYS
mattrib -i  build/disk.img +s ::SYS/1BOOT.SYS
mcopy -i  build/disk.img xasm/test.asm ::TEST.ASM
mcopy -i build/disk.img configs/ ::XCONFIGS
mmd -i build/disk.img ::/DRIVERS
mcopy -i build/disk.img build/ohci.bin ::/DRIVERS/OHCI.SYS
mcopy -i build/disk.img build/sb16.obj ::/DRIVERS/SB16.SYS
mcopy -i build/disk.img build/intl_aud.obj ::/DRIVERS/INTL_AUD.SYS
mcopy -i build/disk.img shell/test.sh ::TEST.SH
mcopy -i build/disk.img build/test.wav ::TEST.WAV
mcopy -i build/disk.img build/test2.wav ::TEST2.WAV

mdir -i build/disk.img ::
cp /usr/share/OVMF/x64/OVMF_VARS.4m.fd ~/Downloads/xmode/build

qemu-system-x86_64 \
    -drive file=build/disk.img,format=raw,if=ide \
    -drive file=disk4.img,format=raw,if=none,id=disk0 \
    -drive file=disk2.img,format=raw,if=none,id=disk1 \
    -drive file=disk3.img,format=raw,if=none,id=disk2 \
    -device ahci,id=ahci0 \
    -device ide-hd,drive=disk0,bus=ahci0.0 \
    -device ide-hd,drive=disk1,bus=ahci0.1 \
    -device ide-hd,drive=disk2,bus=ahci0.2 \
    -m 50M \
    -drive if=pflash,format=raw,readonly=on,file=build/OVMF_CODE.4m.fd \
    -drive if=pflash,format=raw,file=build/OVMF_VARS.4m.fd \
    -device pci-ohci,id=ohci \
    -device usb-kbd \
    -drive file=disk7.img,format=raw,if=none,id=usbstick \
    -device usb-storage,drive=usbstick \
    -device intel-hda \
    -device sb16,audiodev=snd0 \
    -audiodev alsa,id=snd0 \

# 8 MB: absolute minimum RAM - no programs will work
# 25MB: recommended

# Memory Map
# 0x0000 - 0x3fff: ROOT Directory
# 0x4000 - 0x7bff: FAT
# 0x7c00 - 0x7dff: MBR Boot Sector
# 0x7e00: Memory Map
# 0x8000 - 0x50000: Kernel
# 0x8a000: PCI list   (512bytes)
# 0x8a200: AHCI device list (512bytes)
# 0x100000 - 0x160000: AHCI Command Tables, Command List, FIS, PRDT (1 entry = 0x3000, used = 0x2500, free = 0x500 (for other data))
# 0x91000 - 0x9f0000: program kernel stack
# 0x2000000 - 0x2200000: programs
# 0x1a0000 - 0x1f0000: programs stack
# 0x200000 - 0x14fffff: window buffers


# qemu-system-i386 -hda build/disk.img -hdb disk2.img -hdc disk3.img -hdd disk4.img -device pci-ohci,id=ohci -device usb-kbd -drive file=disk7.img,format=raw,if=none,id=usbstick -device usb-storage,drive=usbstick
# x86_64-w64-mingw32-gcc -c hello.c -o hello.obj
# i686-w64-mingw32-gcc -ffreestanding -c hello.c -o hello.obj