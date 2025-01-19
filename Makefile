all: img
dev:
	-rm -f FOZOS.img || true
	-sudo losetup -d /dev/loop101 || true
	-sudo losetup -d /dev/loop102 || true
	zig build
	dd if=/dev/zero bs=1M count=0 seek=64 of=FOZOS.img
	sudo parted FOZOS.img mklabel msdos mkpart primary ext2 2048s 100% set 1 boot on
	sudo losetup /dev/loop101 FOZOS.img
	sudo losetup /dev/loop102 FOZOS.img -o 1048576
	sudo mkfs.ext2 /dev/loop102

	sudo mount /dev/loop102 /mnt
	./limine/limine bios-install FOZOS.img
	cp -f zig-out/bin/kernel disk/boot
	cp -f limine.conf disk/boot/limine
	cp -f limine/limine-bios.sys disk/boot/limine
	cp -f limine/BOOTX64.EFI disk/EFI/BOOT

	#cp -f limine/BOOTIA32.EFI disk/EFI/BOOT

	sudo cp -r disk/* /mnt/
	ls /mnt/boot
	sudo umount /mnt
	-sudo losetup -d /dev/loop101 || true
	-sudo losetup -d /dev/loop102 || true

	qemu-system-x86_64  -drive id=disk,file=FOZOS.img,if=none,format=raw -debugcon stdio -device ahci,id=ahci -device ide-hd,drive=disk,bus=ahci.0 -m 2G
clean:
	rm -rf disk/boot/limine/*
	rm -rf disk/boot/kernel
	rm -rf disk/EFI/BOOT/*
	-sudo umount /mnt || true
	-sudo losetup -d /dev/loop101 || true
	-sudo losetup -d /dev/loop102 || true
hdd:
	#nasm kernel/arch/x64/interrupts/idt.s -o obj/idt.o -f elf64
	clang -c -masm=intel kernel/arch/x64/interrupts/idt.S -o obj/idt.o
	rm -f FOZOS.img
	dd if=/dev/zero bs=1M count=0 seek=64 of=FOZOS.img
	sgdisk FOZOS.img -n 1:2048 -t 1:ef00
	./limine/limine bios-install FOZOS.img
	mformat -i FOZOS.img@@1M
	mmd -i FOZOS.img@@1M ::/EFI ::/EFI/BOOT ::/boot ::/boot/limine
	mcopy -i FOZOS.img@@1M zig-out/bin/kernel ::/boot
	mcopy -i FOZOS.img@@1M limine.conf ::/boot/limine
	mcopy -i FOZOS.img@@1M limine/limine-bios.sys ::/boot/limine
	mcopy -i FOZOS.img@@1M limine/BOOTX64.EFI ::/EFI/BOOT
	mcopy -i FOZOS.img@@1M limine/BOOTIA32.EFI ::/EFI/BOOT
run:
	qemu-system-x86_64   -drive id=disk,file=FOZOS.img,if=none,format=raw\
 -debugcon stdio -device ahci,id=ahci -device ide-hd,drive=disk,bus=ahci.0 -m 2G -no-reboot -no-shutdown\

run-nvme:
	qemu-system-x86_64 -bios /usr/share/OVMF/OVMF_CODE.fd -drive id=nvme0,file=FOZOS.img,if=none,format=raw -debugcon stdio -device nvme,serial=deadbeef,drive=nvme0 -m 2G -no-reboot -no-shutdown

run-dbg:
	qemu-system-x86_64   -drive id=disk,file=FOZOS.img,if=none,format=raw\
 -debugcon stdio -device ahci,id=ahci -device ide-hd,drive=disk,bus=ahci.0 -m 2G -no-reboot -no-shutdown\
 -s -S -d int,mmu
dbg:
	zig build -Doptimise=Debug
	make hdd
	make run-dbg
img: 
	zig build
	make hdd 
	make run-nvme
