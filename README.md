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
  1. To build development build of FOZOS first you must have these dependencies: make, zig(0.14.0), qemu, git, sgdisk, clang 
  2. run sudo make in the root of the project
  3. That's it! project will now build for x64 which is the only currently supported architecture
  and it will also be run in qemu.
If you only want to build the kerner run zig build
