.PHONY: all clean hdd run run-dbg kernel kernel-dbg limine

all: kernel

clean:
	rm -rf disk/boot/limine/*
	rm -rf disk/boot/kernel
	rm -rf disk/EFI/BOOT/*
	rm -f FOZOS.img
	rm -rf obj
	-rm -rf /mnt/fozos
	-sudo umount /mnt || true
	-sudo losetup -d /dev/loop101 || true
	-sudo losetup -d /dev/loop102 || true

hdd: clean zig-out/bin/kernel limine
	dd if=/dev/zero bs=1M count=0 seek=64 of=FOZOS.img
	sgdisk FOZOS.img -n 1:2048:16384 -t 1:ef00 -N 2 -c 1:"UEFI" -c 2:"Fext2" 
	./limine/limine bios-install FOZOS.img
	mformat -i FOZOS.img@@1M
	mmd -i FOZOS.img@@1M ::/EFI ::/EFI/BOOT ::/boot ::/boot/limine
	mcopy -i FOZOS.img@@1M zig-out/bin/kernel ::/boot
	mcopy -i FOZOS.img@@1M limine.conf ::/boot/limine
	mcopy -i FOZOS.img@@1M limine/limine-bios.sys ::/boot/limine
	mcopy -i FOZOS.img@@1M limine/BOOTX64.EFI ::/EFI/BOOT
	mcopy -i FOZOS.img@@1M limine/BOOTIA32.EFI ::/EFI/BOOT
	losetup /dev/loop101 FOZOS.img
	losetup /dev/loop102 FOZOS.img -o 9437184
	mkfs.ext2 /dev/loop102 -L "FOZOS_EXT2" -b 4096 -I 128
	mkdir -p /mnt/fozos
	mount /dev/loop102 /mnt/fozos
	as -o apps/testapp/test.o apps/testapp/test.S --64
	ld  -nostdlib --nmagic -o indisk/testapp apps/testapp/test.o
	cp -r indisk/* /mnt/fozos 
	umount /mnt/fozos
	-losetup -d /dev/loop101 || true
	-losetup -d /dev/loop102 || true

run: kernel hdd
	qemu-system-x86_64 -bios /usr/share/OVMF/OVMF_CODE.fd -drive id=nvme0,file=FOZOS.img,if=none,format=raw -debugcon stdio -device nvme,serial=deadbeef,drive=nvme0 -m 2G -no-reboot -no-shutdown
run-dbg: kernel-dbg hdd
	qemu-system-x86_64 -bios /usr/share/OVMF/OVMF_CODE.fd -drive id=nvme0,file=FOZOS.img,if=none,format=raw -debugcon stdio -device nvme,serial=deadbeef,drive=nvme0 -m 2G -no-reboot -no-shutdown -s -S

kernel: limine
	mkdir -p obj
	zig cc -c -masm=intel kernel/arch/x64/interrupts/idt.S -o obj/idt.o
	zig build -freference-trace

kernel-dbg: limine
	mkdir -p obj
	zig cc -c -masm=intel kernel/arch/x64/interrupts/idt.S -o obj/idt.o
	zig build -Doptimize=Debug

limine:
	cd limine && make
