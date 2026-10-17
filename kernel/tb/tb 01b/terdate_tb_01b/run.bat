@echo off
rem Start Terdate TB in QEMU
cd /d "%~dp0"
set "Q=C:\Program Files\qemu\qemu-system-i386.exe"
"%Q%" -name "Terdate TB" -drive format=raw,file=terdate.img,if=floppy -boot a -m 64
