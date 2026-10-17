; ============================================================================
;  Terdate TB  -  Terdate Bootloader
;  load.asm    -  Stage 2: loader + batch interpreter (32-bit protected mode)
;
;  boot.asm loads this image to 0000:8000. It contains:
;    1. a small real-mode stub (memory check, A20, GDT, switch to 32-bit)
;    2. the 32-bit runtime: console, keyboard, timer, RAM file system and the
;       batch interpreter that runs \syson.bat and everything it starts
;    3. the embedded files (the .bat/.txt tree, see data.asm)
;
;  build:  nasm -f bin load.asm -o load.bin
; ============================================================================
%include "config.inc"
bits 16
org LOAD_BASE

section .text align=16
section .bss align=16 nobits
bss_start:
section .text
loader_header:
    jmp strict near rm_start            ; +0  (3 bytes)
    db 'TDLD'                           ; +3  signature checked by boot.asm
    dd image_end - LOAD_BASE                        ; +7  image size in bytes (multiple of 512)

; ---------------------------------------------------------------------------
;  Real-mode stub
; ---------------------------------------------------------------------------
rm_start:
    cli
    cld
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov ax, 0x0003                      ; 80x25 colour text mode (VGA font)
    int 0x10

    mov ax, 0xE801                      ; memory above 1 MB, in KB
    int 0x15
    jc .m88
    test ax, ax
    jnz .e801
    mov ax, cx
    mov bx, dx
.e801:
    movzx eax, ax
    movzx ebx, bx
    shl ebx, 6
    add eax, ebx
    jmp .memok
.m88:
    mov ah, 0x88
    int 0x15
    movzx eax, ax
.memok:
    mov [mem_ext_kb], eax
    cmp eax, MIN_EXT_KB
    jb .nomem

    call enable_a20
    test ax, ax
    jz .noa20

    cli
    lgdt [gdt_desc]
    mov eax, cr0
    or al, 1
    mov cr0, eax
    jmp dword SEL_CODE:pm_entry

.nomem:
    mov si, rm_msg_mem
    jmp rm_fatal
.noa20:
    mov si, rm_msg_a20
rm_fatal:
    call rm_print
.h: cli
    hlt
    jmp .h

rm_print:
    lodsb
    test al, al
    jz .d
    mov ah, 0x0E
    mov bx, 7
    int 0x10
    jmp rm_print
.d: ret

; ---- A20 gate: BIOS, fast port 0x92, keyboard controller ---------------------
; returns AX=1 when A20 is enabled
enable_a20:
    call a20_test
    test ax, ax
    jnz .ok
    mov ax, 0x2401
    int 0x15
    call a20_test
    test ax, ax
    jnz .ok
    in al, 0x92
    or al, 2
    and al, 0xFE
    out 0x92, al
    call a20_test
    test ax, ax
    jnz .ok
    call kbc_wait
    mov al, 0xD1
    out 0x64, al
    call kbc_wait
    mov al, 0xDF
    out 0x60, al
    call kbc_wait
    call a20_test
.ok:
    ret

kbc_wait:
    in al, 0x64
    test al, 2
    jnz kbc_wait
    ret

a20_test:                               ; AX = 1 if memory does not wrap at 1 MB
    push ds
    push es
    push si
    push di
    xor ax, ax
    mov ds, ax
    not ax
    mov es, ax
    mov si, 0x0500
    mov di, 0x0510
    mov al, [ds:si]
    mov ah, [es:di]
    push ax
    mov byte [ds:si], 0x00
    mov byte [es:di], 0xFF
    cmp byte [ds:si], 0xFF
    pop ax
    mov [ds:si], al
    mov [es:di], ah
    mov ax, 0
    je .off
    mov ax, 1
.off:
    pop di
    pop si
    pop es
    pop ds
    ret

rm_msg_mem  db 'Terdate TB: not enough memory (need 8 MB)', 13, 10, 0
rm_msg_a20  db 'Terdate TB: cannot enable A20', 13, 10, 0
mem_ext_kb  dd 0

align 8
gdt:
    dq 0
    dq 0x00CF9A000000FFFF               ; 0x08 code, flat 4 GB
    dq 0x00CF92000000FFFF               ; 0x10 data, flat 4 GB
gdt_end:
gdt_desc:
    dw gdt_end - gdt - 1
    dd gdt

; ---------------------------------------------------------------------------
;  32-bit runtime
; ---------------------------------------------------------------------------
bits 32
pm_entry:
    mov ax, SEL_DATA
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, STACK_TOP
    cld

    mov edi, bss_start                  ; clear .bss
    mov ecx, bss_end
    sub ecx, edi
    xor eax, eax
    rep stosb
    mov edi, ENV_BLOCKS                 ; clear pools above 1 MB
    mov ecx, (HEAP_BASE - ENV_BLOCKS) / 4
    rep stosd

    call idt_init
    call pic_init
    call pit_init
    call con_init
    sti
    call kb_init
    call sys_main                       ; never returns
.h: cli
    hlt
    jmp .h

%include "lib.asm"
%include "idt.asm"
%include "console.asm"
%include "kbd.asm"
%include "timer.asm"
%include "fs.asm"
%include "env.asm"
%include "expand.asm"
%include "interp.asm"
%include "simple.asm"
%include "calc.asm"
%include "cmds.asm"
%include "cmds2.asm"
%include "system.asm"

section .data align=512
%include "data.asm"
align 512, db 0
image_end:

section .bss
bss_end:
