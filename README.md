# FOZOS
## Info
Made with limine.
Supported platforms: x86-64
Written in: zig, c, assembly
## Goals
  1. Stable
  2. Built in desktop enviroment
## Features implimented:
  1. TTY
  2. debug printing
  3. pmm
  4. vmm
  5. nvme(basic)
## Build
  1. To build FOZOS first you must have these dependencies: make, zig(0.13.0), qemu, git, sgdisk, clang 
  2. run make in the root of the project
  3. That's it! project will now build for x64 which is the only currently supported architecture
  and it will also be run in qemu.
