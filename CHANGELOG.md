# Changelog

All notable changes to Terdate, newest first.

## pre-alpha001r (17 Oct 2026)
- First bootable version: Terdate TB, a 32-bit protected-mode kernel.
- Built-in batch interpreter (`IF`, `FOR`, `GOTO`, `CALL`, `SET /A`, `%var%` and `!var!` expansion, redirection).
- RAM file system, VGA text console, PS/2 keyboard, timer and clock.
- Ready-to-boot 1.44 MB image for QEMU.
- Not yet supported: pipes (`|`), wildcards, `FOR /F`, a real disk (files live in RAM).

## rd141026fa (14 Oct 2026)
- System is now stable.
- Commands are case-insensitive.
- System log added (`echo log`, `clear log`).
- New commands: `tree`, `CDS`, `echo vb`, `print`.

## rd131026a (13 Oct 2026)
- First version.
- Commands: `program`, `programl`, `shutdown`, `cls`.
