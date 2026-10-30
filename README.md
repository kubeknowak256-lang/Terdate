# Terdate

Terdate is a lightweight, retro-styled operating system built around a custom 32-bit kernel: the Terdate TB kernel.

The project is designed to be easy to inspect, modify, and redistribute. It focuses on simplicity, compatibility with classic system workflows, and a minimal bootable environment suitable for experimentation and learning.

> Status: early development
>
> The system has been tested in QEMU and is not yet validated on physical hardware.

## Overview

Terdate combines:

- a custom bootable kernel written in NASM assembly
- a small command-oriented runtime environment
- a batch-driven user interface for experimentation
- a simple file-system and OS-style workflow

The repository currently contains:

- `kernel/` — kernel source and related assembly files
- `system/` — runtime builds and bootable system variants
- `BUILDING.md` — build instructions and usage tips
- `CHANGELOG.md` — version history
- `LICENSE` — Apache License 2.0

## Quick start

### Run the bootable pre-alpha build

1. Install QEMU.
2. Open the folder containing the pre-alpha disk image.
3. Run:

```bash
qemu-system-i386 -drive format=raw,file=terdate_pre-alpha001r_qemu-boot-x32.img,if=floppy -boot a -m 64
```

This is the simplest way to boot the system in an emulator and test the current build.

### Run the `rd` build on Windows

1. Open a version folder such as `system/rd/rd141026fa`.
2. Double-click `syson.bat`.
3. When prompted with `[y/n]`, choose `n`.

This launches the batch-based runtime environment.

## Build from source

For full instructions, see [BUILDING.md](BUILDING.md).

The build process requires:

- NASM
- QEMU

Example:

```bash
nasm -f bin boot.asm -o boot.bin
nasm -f bin load.asm -o load.bin
nasm -f bin image.asm -o terdate.img
```

## Repository layout

```text
.
├── BUILDING.md
├── CHANGELOG.md
├── LICENSE
├── README.md
├── kernel/
│   └── tb/
├── system/
│   ├── alpha/
│   └── rd/
└── .gitignore
```

## Versions

| Folder | Description | Typical usage |
|--------|-------------|---------------|
| `system/rd/rd131026a` | First `rd` build from 13 Oct 2026 | Start via `syson.bat` |
| `system/rd/rd141026fa` | Improved `rd` build with logging and extended commands | Start via `syson.bat` |
| `system/alpha/pre-alpha001r` | Pre-alpha bootable disk image | Boot with QEMU |
| `kernel/tb/tb 01b` | Terdate TB kernel source code | Build and inspect the kernel |

## Contributing

Contributions are welcome.

For a clean development workflow:

- keep changes focused and well-documented
- build the project before submitting changes
- document any new commands, features, or build steps
- prefer readable assembly and scripts with clear structure

Please also see [BUILDING.md](BUILDING.md) for build- and run-related guidance.

## License

This project is licensed under the [Apache License 2.0](LICENSE).

## Project goals

Terdate is intended to be:

- easy to understand and modify
- lightweight and minimal
- suitable for experimentation with OS/kernel concepts
- accessible for educational and hobbyist use

If you want to extend the system, improve the runtime, or clean up the build workflow, this repository is set up to support that kind of iterative development.
