all: img
clean:
	rm -rf disk/boot/limine/*
	rm -rf disk/boot/kernel
	rm -rf disk/EFI/BOOT/*
	-sudo umount /mnt || true
	-sudo losetup -d /dev/loop101 || true
	-sudo losetup -d /dev/loop102 || true
hdd:
	-losetup -d /dev/loop101 || true
	-losetup -d /dev/loop102 || true

	-umount /mnt/fozos || true
	clang -c -masm=intel kernel/arch/x64/interrupts/idt.S -o obj/idt.o
	rm -f FOZOS.img
	dd if=/dev/zero bs=1M count=0 seek=64 of=FOZOS.img
	sgdisk FOZOS.img -n 1:2048:8192 -t 1:ef00 -N 2 -c 1:"UEFI" -c 2:"Fext2" 
	./limine/limine bios-install FOZOS.img
	mformat -i FOZOS.img@@1M
	mmd -i FOZOS.img@@1M ::/EFI ::/EFI/BOOT ::/boot ::/boot/limine
	mcopy -i FOZOS.img@@1M zig-out/bin/kernel ::/boot
	mcopy -i FOZOS.img@@1M limine.conf ::/boot/limine
	mcopy -i FOZOS.img@@1M limine/limine-bios.sys ::/boot/limine
	mcopy -i FOZOS.img@@1M limine/BOOTX64.EFI ::/EFI/BOOT
	mcopy -i FOZOS.img@@1M limine/BOOTIA32.EFI ::/EFI/BOOT
	losetup /dev/loop101 FOZOS.img
	losetup /dev/loop102 FOZOS.img -o 5242880
	mkfs.ext2 /dev/loop102 -L "FOZOS_EXT2" -b 4096 -I 128 
	mount /dev/loop102 /mnt/fozos
	cp -r indisk/* /mnt/fozos 
	umount /mnt/fozos
	-losetup -d /dev/loop101 || true
	-losetup -d /dev/loop102 || true

run-nvme:
	qemu-system-x86_64 -bios /usr/share/OVMF/OVMF_CODE.fd -drive id=nvme0,file=FOZOS.img,if=none,format=raw -debugcon stdio -device nvme,serial=deadbeef,drive=nvme0 -m 2G -no-reboot -no-shutdown -trace pci_nvme_read
run-dbg:
	qemu-system-x86_64 -bios /usr/share/OVMF/OVMF_CODE.fd -drive id=nvme0,file=FOZOS.img,if=none,format=raw -debugcon stdio -device nvme,serial=deadbeef,drive=nvme0 -m 2G -no-reboot -no-shutdown -s -S


dbg:
	zig build -Doptimize=Debug
	make hdd
	make run-dbg
img: 
	zig build -freference-trace 
	make hdd 
	make run-nvme
