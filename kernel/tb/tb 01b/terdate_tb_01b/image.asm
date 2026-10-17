; Builds the final disk image: boot sector + loader, padded to a 1.44 MB floppy.
incbin "boot.bin"
incbin "load.bin"
times 1474560 - ($ - $$) db 0
