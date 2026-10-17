Terdate TB  -  pre-alpha001r
============================

Terdate TB is a tiny 32-bit "operating system" whose whole job is to boot and run
batch (.bat) files.  boot.asm is the bootloader; load.asm (plus the other .asm
modules) is a protected-mode runtime with a built-in batch interpreter that runs
\syson.bat first, exactly like a PC would run its startup script.

QUICK START
-----------
  Windows :  run.bat                (needs QEMU, https://www.qemu.org)
  Linux   :  ./run.sh               (qemu-system-i386)
  by hand :  qemu-system-i386 -drive format=raw,file=terdate.img,if=floppy -boot a -m 64

terdate.img is a ready-made 1.44 MB image (works as floppy or hard disk).
To rebuild after editing anything:  build.bat (Windows) or ./build.sh (needs NASM).

BOOT FLOW
---------
  BIOS -> boot.asm (512-byte boot sector, "Terdate TB")
       -> load.asm (stage 2: A20, GDT, 32-bit protected mode, drivers)
       -> \syson.bat -> start \system\terminal.bat -> terminal (programs, log, ...)

FILES
-----
  boot.asm        stage 1, boot sector (16-bit, BIOS CHS/LBA disk read)
  load.asm        stage 2 entry + 32-bit start-up, includes all modules below
  config.inc      memory map and structure offsets
  lib.asm         string / number helpers
  idt.asm         IDT, CPU exception report, PIC
  console.asm     VGA 80x25 text console (hardware 8x16 pixel font) + COM1 mirror
  kbd.asm         PS/2 keyboard (US layout), line input
  timer.asm       PIT 100 Hz, CMOS clock, random numbers
  fs.asm          RAM file system (embedded files are copy-on-write)
  env.asm         environment variables, SETLOCAL/ENDLOCAL, %DATE% %TIME% ...
  expand.asm      %var% !var! %~dp0 %var:~1,3% %var:a=b% expansion
  interp.asm      batch interpreter: lines, blocks ( ), IF/ELSE, FOR, GOTO, CALL
  simple.asm      redirection (> >> < 2>&1 nul), command dispatch, run .bat by name
  calc.asm        SET /A expression evaluator
  cmds.asm        internal commands (ECHO SET GOTO CALL EXIT START CHOICE ...)
  cmds2.asm       file commands (TYPE DEL DIR TREE CD MD COPY REN VOL)
  system.asm      processes ("windows") for START, boot of \syson.bat, power off
  data.asm        the files that make up the virtual disk (see below)
  image.asm       glues boot.bin + load.bin into the 1.44 MB image

  syson.bat                    first script, started by the loader
  system\terminal.bat          the terminal
  system\sysoff.bat            shutdown script
  system\temp\cd.txt, log.txt  runtime files (rewritten every boot, RAM only)
  programs\calc.bat, clock.bat programs started from the terminal

START = "WINDOWS"
-----------------
`start "" file.bat` runs the script in a new full-screen "window".  The script
that issued START is frozen and invisible (it is NOT terminated); when the new
one exits, the old screen comes back and execution continues after START.
Nesting depth: 8 processes.  Each process gets its own copy of the environment.

ADDING YOUR OWN FILES
---------------------
Put the file next to the others, add one line to data.asm and rebuild:
    FILE '\programs\hello.bat', 'programs/hello.bat'
Then run it with  CALL \programs\hello.bat  or  START "" \programs\hello.bat.

BATCH SUPPORT
-------------
  commands : ECHO SET (/P /A) GOTO CALL EXIT (/B) IF FOR (/L) REM SHIFT SETLOCAL
             ENDLOCAL START CLS PAUSE CHOICE TIMEOUT COLOR TITLE VER VOL HELP
             TYPE DEL ERASE DIR TREE CD CHDIR MD MKDIR COPY REN RENAME
  syntax   : labels, :: comments, ( ) blocks, & && ||, ^ escapes, "quotes",
             IF [/I] [NOT] ==, EQU NEQ LSS LEQ GTR GEQ, DEFINED, EXIST, ERRORLEVEL
             ELSE, %0-%9 %* %~1 %~dp0 %~nx0 ..., %% , delayed expansion !var!
             (SETLOCAL ENABLEDELAYEDEXPANSION), echo-on prompt like cmd.exe
  as in cmd.exe: %var% inside a ( ) block is expanded once for the whole block,
             running name.bat without CALL does not return to the caller.
  not yet  : pipes (|), FOR /F /D /R, wildcards, TIME/DATE commands, a real disk
             (the file system lives in RAM: log.txt starts fresh at every boot).

NOTES
-----
 * Tested in QEMU (floppy and hard-disk boot).  Not tested on real hardware.
 * Needs >= 8 MB RAM, a VGA text mode (80x25) and a PS/2 (or emulated) keyboard.
 * The console output is also mirrored to COM1:  qemu ... -serial stdio
 * Shutdown: the terminal command "shutdown" -> sysoff.bat -> ACPI power off.
