; ============================================================================
;  Terdate TB  -  Terdate Bootloader
;  boot.asm    -  Stage 1: 512-byte boot sector (16-bit real mode)
;
;  The BIOS loads this sector to 0000:7C00. It reads the loader image
;  (load.bin, see load.asm) from the following sectors into 0000:8000 and
;  jumps to it. Works with floppy and hard-disk images (CHS or INT 13h EDD).
;
;  build:  nasm -f bin boot.asm -o boot.bin
; ============================================================================
bits 16
org 0x7C00

LOAD_SEG    equ 0x0800                  ; loader goes to 0800:0000 = 0000:8000
LOAD_ADDR   equ 0x8000

boot_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    cld
    mov [boot_drive], dl

    mov si, msg_boot
    call print

    ; ---- hard disk: try INT 13h extensions (LBA) --------------------------
    cmp dl, 0x80
    jb .chs
    mov ah, 0x41
    mov bx, 0x55AA
    int 0x13
    jc .chs
    cmp bx, 0xAA55
    jne .chs
    test cl, 1
    jz .chs
    mov byte [use_edd], 1
    jmp .load

    ; ---- otherwise ask the BIOS for the CHS geometry ------------------------
.chs:
    mov dl, [boot_drive]
    mov ah, 0x08
    xor di, di
    int 0x13
    jc .load                            ; keep defaults (18 sectors, 2 heads)
    and cl, 0x3F
    jz .load
    mov [sec_per_track], cl
    inc dh
    mov [heads], dh

    ; ---- read first loader sector, validate header ------------------------
.load:
    xor ax, ax
    mov es, ax
    mov word [lba], 1
    mov word [dst_seg], LOAD_SEG
    call read_one
    mov ax, LOAD_SEG
    mov es, ax
    cmp dword [es:3], 'TDLD'
    jne bad_loader
    mov eax, [es:7]                     ; loader image size in bytes
    shr eax, 9
    mov cx, ax                          ; total loader sectors
    dec cx
.more:
    jcxz .done
    inc word [lba]
    add word [dst_seg], 0x20            ; next 512 bytes
    push cx
    call read_one
    pop cx
    dec cx
    jmp .more
.done:
    mov dl, [boot_drive]
    jmp 0x0000:LOAD_ADDR

; ---------------------------------------------------------------------------
; read_one: read sector [lba] to [dst_seg]:0 (all registers preserved)
; ---------------------------------------------------------------------------
read_one:
    pusha
    mov byte [tries], 5
.try:
    mov ax, [dst_seg]
    mov es, ax
    xor bx, bx
    cmp byte [use_edd], 0
    jne .edd
    mov ax, [lba]
    xor dx, dx
    movzx si, byte [sec_per_track]
    div si                              ; ax = track, dx = sector-1
    inc dx
    mov cl, dl
    xor dx, dx
    movzx si, byte [heads]
    div si                              ; ax = cylinder, dx = head
    mov ch, al
    shl ah, 6
    or cl, ah
    mov dh, dl
    mov dl, [boot_drive]
    mov ax, 0x0201
    int 0x13
    jnc .ok
    jmp .fail
.edd:
    mov ax, [dst_seg]
    mov [dap+6], ax
    mov ax, [lba]
    mov [dap+8], ax
    mov si, dap
    mov dl, [boot_drive]
    mov ah, 0x42
    int 0x13
    jnc .ok
.fail:
    xor ax, ax
    mov dl, [boot_drive]
    int 0x13                            ; reset controller
    dec byte [tries]
    jnz .try
    mov si, msg_disk
    jmp fatal
.ok:
    popa
    ret

bad_loader:
    mov si, msg_noload
fatal:
    call print
.halt:
    cli
    hlt
    jmp .halt

print:
    lodsb
    test al, al
    jz .d
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp print
.d: ret

msg_boot    db 'Terdate TB pre-alpha001r - loading system...', 13, 10, 0
msg_disk    db 13, 10, 'Terdate TB: disk read error', 13, 10, 0
msg_noload  db 13, 10, 'Terdate TB: loader image not found', 13, 10, 0

boot_drive  db 0
use_edd     db 0
sec_per_track db 18
heads       db 2
tries       db 0
lba         dw 0
dst_seg     dw 0
dap:        db 16, 0
            dw 1, 0, 0                  ; count, offset, segment (patched)
            dq 0                        ; LBA (low word patched)

    times 510-($-$$) db 0
    dw 0xAA55
