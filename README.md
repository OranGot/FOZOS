# FOZOS
This is an os I am making for fun and it's not intended for any use so far.
## Info

Made with limine.
Supported platforms: x86-64
Written in: zig, c, assembly
## Goals
  1. Stable
  2. Built in desktop enviroment
  3. Customisable
## Features implimented:
  1. tty
  2. debug printing
  3. pmm
  4. vmm
  5. nvme(basic)
  6. gpt
  7. EXT2(basic)
  8. extremely basic system calls
  9. userspace enter
## Build
### Dependencies
To build FOZOS, ensure you have the following dependencies installed:
- `make`
- `zig` (0.14.0)
- `qemu`
- `git`
- `sgdisk`
### Cloning the Repository
Clone the repository recursively to include the Limine submodule(can be slow, can be faster by adding --depth 1):
```bash
git clone --recursive https://github.com/OranGot/FOZOS.git
```
### Building the Kernel
To build the kernel, run:
```bash
make kernel
```
### Running the OS
To run the OS as a disk using QEMU, use:
```bash
sudo make run
```
### Debugging
For debugging purposes, you can build a debug version of the kernel by appending `-dbg` to the target:
```bash
make kernel-dbg
```
To run the debug version, use:
```bash
sudo make run-dbg
```
### Note
Creating the image uses Loop Devices, which require `sudo` permissions. and also `clean` step for delting mount point ect
