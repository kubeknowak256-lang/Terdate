# Building Terdate TB

A tiny 32-bit bootable system that runs batch (`.bat`) files. This guide explains
**how to build and start it** — by hand, and with your own `build` / `run` scripts —
whether or not the tools are in your `PATH`.

## What you need

| Tool | What for | Download |
|------|----------|----------|
| **NASM** | assembles the `.asm` sources | https://www.nasm.us/ |
| **QEMU** | runs the resulting disk image | https://www.qemu.org/download/ |

Install from your package manager if you prefer:

```sh
# Debian / Ubuntu
sudo apt install nasm qemu-system-x86
# Fedora
sudo dnf install nasm qemu-system-x86
# Arch
sudo pacman -S nasm qemu-system-x86
# macOS (Homebrew)
brew install nasm qemu
```

On Windows use the installers from the links above.

Check that both tools are visible (if these commands fail, see
[Tools not in PATH](#tools-not-in-path)):

```
nasm -v
qemu-system-i386 --version
```

Tested with NASM 2.16 and QEMU 8.2.

## Build by hand

Open a terminal **in the project folder** (the one containing `boot.asm`). This matters:
the build embeds the `.bat` files with `incbin`, and the paths are relative to the
current folder.

```
nasm -f bin boot.asm -o boot.bin
nasm -f bin load.asm -o load.bin
nasm -f bin image.asm -o terdate.img
```

- `boot.asm` → `boot.bin` — the 512-byte boot sector.
- `load.asm` → `load.bin` — the loader and interpreter (it includes the other `.asm`
  modules and embeds the batch files listed in `data.asm`).
- `image.asm` → `terdate.img` — glues the two together and pads to a 1.44 MB image,
  so it works as a floppy or as a hard disk.

Assembling again after any change to an `.asm` or embedded `.bat` file is all it takes;
there is nothing else to install or link.

### Without `image.asm`

You can simply concatenate the two binaries. The result is smaller and must be started
as a **hard disk** (not as a floppy):

```sh
# Linux / macOS
cat boot.bin load.bin > terdate.img
```
```bat
:: Windows (cmd)
copy /b boot.bin + load.bin terdate.img
```

## Run

With QEMU in your `PATH`:

```
qemu-system-i386 -drive format=raw,file=terdate.img,if=floppy -boot a -m 64
```

Run it from the folder that contains `terdate.img`, or give the full path to the image.

| Option | Meaning |
|--------|---------|
| `-drive format=raw,file=terdate.img,if=floppy` | use the image as a floppy disk |
| `-boot a` | boot from the floppy |
| `-m 64` | 64 MB of RAM (8 MB or more is enough) |
| `-serial stdio` | optional: mirror everything printed on screen to your terminal |

Hard-disk variant (also works with the unpadded image from `cat` / `copy /b`):

```
qemu-system-i386 -drive format=raw,file=terdate.img -m 64
```

## Tools not in PATH

If `nasm` or `qemu-system-i386` is "not recognized" / "command not found", either call
the program by its full path or add its folder to `PATH` for the current terminal.

**Full path**

```bat
:: Windows (quote the path because of the space)
"C:\Program Files\NASM\nasm.exe" -f bin boot.asm -o boot.bin
"C:\Program Files\qemu\qemu-system-i386.exe" -drive format=raw,file=terdate.img,if=floppy -boot a -m 64
```

```sh
# Linux / macOS
/opt/nasm/bin/nasm -f bin boot.asm -o boot.bin
/opt/qemu/bin/qemu-system-i386 -drive format=raw,file=terdate.img,if=floppy -boot a -m 64
```

The folders above are typical defaults; the real ones depend on how you installed the
tools, so look at where the installer put them.

**Temporarily add to PATH (this terminal only)**

```bat
:: Windows cmd
set "PATH=%PATH%;C:\Program Files\NASM;C:\Program Files\qemu"
```
```powershell
# Windows PowerShell
$env:Path += ";C:\Program Files\NASM;C:\Program Files\qemu"
```
```sh
# Linux / macOS
export PATH="$PATH:/opt/nasm/bin:/opt/qemu/bin"
```

To make it permanent on Windows, add the folders under *System Properties →
Environment Variables → Path* and open a new terminal.

## Writing your own build and run scripts

Put these next to `boot.asm`. Each one works when the tools are in `PATH` and falls
back to a default location (or one you set) when they are not.

### `build.bat` (Windows)

```bat
@echo off
cd /d "%~dp0"

rem Use nasm from PATH, otherwise from the default install folder
set "NASM=nasm"
where nasm >nul 2>&1 || set "NASM=C:\Program Files\NASM\nasm.exe"

"%NASM%" -f bin boot.asm -o boot.bin  || goto :err
"%NASM%" -f bin load.asm -o load.bin  || goto :err
"%NASM%" -f bin image.asm -o terdate.img || goto :err

echo OK: terdate.img built
goto :eof

:err
echo BUILD FAILED
exit /b 1
```

### `run.bat` (Windows)

```bat
@echo off
cd /d "%~dp0"

rem Use qemu from PATH, otherwise from the default install folder
set "QEMU=qemu-system-i386"
where qemu-system-i386 >nul 2>&1 || set "QEMU=C:\Program Files\qemu\qemu-system-i386.exe"

"%QEMU%" -name "Terdate TB" -drive format=raw,file=terdate.img,if=floppy -boot a -m 64
```

If your tools live somewhere else, change the path on the `set "NASM=..."` /
`set "QEMU=..."` lines.

### `build.sh` (Linux / macOS)

```sh
#!/bin/sh
set -e
cd "$(dirname "$0")"

# Use nasm from PATH, or override:  NASM=/path/to/nasm ./build.sh
NASM=${NASM:-nasm}

"$NASM" -f bin boot.asm -o boot.bin
"$NASM" -f bin load.asm -o load.bin
"$NASM" -f bin image.asm -o terdate.img
echo "OK: terdate.img built"
```

### `run.sh` (Linux / macOS)

```sh
#!/bin/sh
cd "$(dirname "$0")"

# Use qemu from PATH, or override:  QEMU=/path/to/qemu-system-i386 ./run.sh
QEMU=${QEMU:-qemu-system-i386}

exec "$QEMU" -name "Terdate TB" -drive format=raw,file=terdate.img,if=floppy -boot a -m 64 "$@"
```

Make the shell scripts executable once, then use them:

```sh
chmod +x build.sh run.sh
./build.sh
./run.sh
```

Extra QEMU options can be appended to `./run.sh`, for example `./run.sh -serial stdio`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `nasm` / `qemu-system-i386` not recognized | Use the full path or add the folder to `PATH` (see above); open a new terminal after changing `PATH` permanently. |
| `unable to open input file` for a `.bat` / `.txt` | Run `nasm` from the project folder; `incbin` paths are relative to it. |
| `No bootable device` / black screen | Rebuild; make sure `boot.bin` is exactly 512 bytes and you started the right `terdate.img`. |
| Floppy start fails with the `cat` / `copy /b` image | That image is not floppy-sized; start it as a hard disk (no `if=floppy`) or build with `image.asm`. |
| QEMU window is too small / you want text output in the terminal | Add `-serial stdio`. |
