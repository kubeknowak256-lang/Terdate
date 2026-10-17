#!/bin/sh
# Start Terdate TB in QEMU
cd "$(dirname "$0")"
exec qemu-system-i386 -name "Terdate TB" -drive format=raw,file=terdate.img,if=floppy -boot a -m 64 "$@"
