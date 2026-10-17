#!/bin/sh
# Terdate TB build script (needs NASM)
set -e
cd "$(dirname "$0")"
nasm -f bin boot.asm -o boot.bin
nasm -f bin load.asm -o load.bin
nasm -f bin image.asm -o terdate.img
echo "OK: terdate.img built (loader: $(wc -c < load.bin) bytes)"
