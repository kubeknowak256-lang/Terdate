# Terdate

**A lightweight, retro-styled system that is free and easy to modify.**

Terdate is built on its own kernel, currently the 32-bit **Terdate TB** kernel. You can modify and redistribute it freely, as long as you comply with the [Apache License 2.0](LICENSE).

> **Status:** early development. Tested in QEMU, not yet on real hardware.

## Versions

| Folder | What it is | How to run |
|--------|------------|------------|
| `system/rd/rd131026a` | `rd` build from 13 Oct 2026, the first version (Windows batch) | double-click `syson.bat` |
| `system/rd/rd141026fa` | `rd` build from 14 Oct 2026: logging, `tree`, `print`, case-insensitive commands | double-click `syson.bat` |
| `system/alpha/pre-alpha001r` | pre-alpha: bootable 32-bit system with a ready-to-boot disk image | boot the `.img` in QEMU |
| `kernel/tb/tb 01b` | Terdate TB kernel source code (NASM) | see [docs/BUILDING.md](docs/BUILDING.md) |

`rd` builds are named `rd` + date (`DDMMYY`) + a letter suffix.

## Quick start

### Boot the system (QEMU)

Install [QEMU](https://www.qemu.org/download/) and run:

```
qemu-system-i386 -drive format=raw,file=terdate_pre-alpha001r_qemu-boot-x32.img,if=floppy -boot a -m 64
```

(from the folder `system/alpha/pre-alpha001r`). Requirements: 8 MB of RAM or more, VGA text mode, a PS/2 (or emulated) keyboard.

### Run the `rd` versions (Windows)

1. Open the version folder, e.g. `system/rd/rd141026fa`.
2. Double-click `syson.bat`.
3. When asked `[y/n]`, type `n` and press Enter.

A terminal opens with *"Welcome to Terdate Operating System"*. Type `program` or `programl` to see the available programs.

## Build from source

You need NASM and QEMU. Full instructions: [docs/BUILDING.md](docs/BUILDING.md).

## Repository layout

```
kernel/
   tb/        Terdate TB kernel sources
system/
   rd/        rd versions (Windows batch)
   alpha/     alpha versions (bootable)
docs/         build guide
CHANGELOG.md  what changed in each version
LICENSE       Apache License 2.0
```

## License

Apache License 2.0, see [LICENSE](LICENSE). If you modify or redistribute Terdate, you must comply with it.
