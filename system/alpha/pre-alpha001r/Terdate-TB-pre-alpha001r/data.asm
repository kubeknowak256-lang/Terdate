; ============================================================================
;  data.asm - files embedded into the boot image (the "disk")
;  To add a file to the virtual disk:  FILE '\path\inside\terdate', 'host/path'
; ============================================================================
%macro FILE 2
    dd %%path, %%data, %%end - %%data
%%path: db %1, 0
%%data: incbin %2
%%end:
    align 4, db 0
%endmacro

embedded_files:
    FILE '\syson.bat',               'syson.bat'
    FILE '\system\terminal.bat',     'system/terminal.bat'
    FILE '\system\sysoff.bat',       'system/sysoff.bat'
    FILE '\system\temp\cd.txt',      'system/temp/cd.txt'
    FILE '\system\temp\log.txt',     'system/temp/log.txt'
    FILE '\programs\calc.bat',       'programs/calc.bat'
    FILE '\programs\clock.bat',      'programs/clock.bat'
    dd 0
