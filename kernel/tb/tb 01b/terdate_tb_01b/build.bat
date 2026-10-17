@echo off
rem Terdate TB build script (needs NASM in PATH)
cd /d "%~dp0"
"C:\Users\nikod\AppData\Local\bin\NASM\nasm.exe" -f bin boot.asm -o boot.bin
if errorlevel 1 goto err
"C:\Users\nikod\AppData\Local\bin\NASM\nasm.exe" -f bin load.asm -o load.bin
if errorlevel 1 goto err
"C:\Users\nikod\AppData\Local\bin\NASM\nasm.exe" -f bin image.asm -o terdate.img
if errorlevel 1 goto err
echo OK: terdate.img built
goto end
:err
echo BUILD FAILED
:end
pause
