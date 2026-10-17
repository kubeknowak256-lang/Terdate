; ============================================================================
;  console.asm - VGA text console (80x25, hardware 8x16 pixel font)
;  Everything printed is also mirrored to COM1 (handy when running in QEMU
;  with  -serial stdio ).  Nothing here touches the BIOS.
; ============================================================================
section .bss
con_x:      resd 1
con_y:      resd 1
con_attr:   resb 1
ser_ok:     resb 1
section .text

con_init:
    mov byte [con_attr], 0x07
    call ser_init
    call con_cls
    ret

con_cls:
    push eax
    push ecx
    push edi
    movzx eax, byte [con_attr]
    shl eax, 8
    mov al, ' '
    mov edi, VGA_BASE
    mov ecx, SCR_COLS*SCR_ROWS
    rep stosw
    mov dword [con_x], 0
    mov dword [con_y], 0
    call con_cursor
    pop edi
    pop ecx
    pop eax
    ret

con_cursor:                             ; program the hardware cursor
    push eax
    push edx
    mov eax, [con_y]
    imul eax, SCR_COLS
    add eax, [con_x]
    mov edx, 0x3D4
    push eax
    mov al, 0x0F
    out dx, al
    inc edx
    pop eax
    out dx, al
    dec edx
    push eax
    mov al, 0x0E
    out dx, al
    inc edx
    pop eax
    mov al, ah
    out dx, al
    pop edx
    pop eax
    ret

con_putc:                               ; AL = character, all registers preserved
    pushad
    cmp byte [ser_ok], 0
    je .nos
    call ser_putc
.nos:
    mov ebx, [con_x]
    mov ecx, [con_y]
    cmp al, 13
    je .cr
    cmp al, 10
    je .lf
    cmp al, 8
    je .bs
    cmp al, 9
    je .tab
    cmp al, 7
    je .done
    movzx edx, byte [con_attr]
    shl edx, 8
    mov dl, al
    mov eax, ecx
    imul eax, SCR_COLS
    add eax, ebx
    mov [VGA_BASE + eax*2], dx
    inc ebx
    cmp ebx, SCR_COLS
    jb .store
.wrap:
    xor ebx, ebx
    inc ecx
    jmp .chk
.cr:
    xor ebx, ebx
    jmp .store
.lf:
    xor ebx, ebx
    inc ecx
    jmp .chk
.bs:
    test ebx, ebx
    jz .store
    dec ebx
    jmp .store
.tab:
    add ebx, 8
    and ebx, ~7
    cmp ebx, SCR_COLS
    jb .store
    jmp .wrap
.chk:
    cmp ecx, SCR_ROWS
    jb .store
    mov esi, VGA_BASE + SCR_COLS*2      ; scroll one line
    mov edi, VGA_BASE
    mov ecx, (SCR_ROWS-1)*SCR_COLS*2/4
    rep movsd
    movzx eax, byte [con_attr]
    shl eax, 8
    mov al, ' '
    mov edi, VGA_BASE + (SCR_ROWS-1)*SCR_COLS*2
    mov ecx, SCR_COLS
    rep stosw
    mov ecx, SCR_ROWS-1
.store:
    mov [con_x], ebx
    mov [con_y], ecx
    call con_cursor
.done:
    popad
    ret

con_puts:                               ; ESI = string
    push esi
    push eax
.l: lodsb
    test al, al
    jz .d
    call con_putc
    jmp .l
.d: pop eax
    pop esi
    ret

con_puthex32:                           ; EAX
    push eax
    push ecx
    push edx
    mov edx, eax
    mov ecx, 8
.l: rol edx, 4
    mov al, dl
    and al, 15
    add al, '0'
    cmp al, '9'
    jbe .p
    add al, 7
.p: call con_putc
    dec ecx
    jnz .l
    pop edx
    pop ecx
    pop eax
    ret

con_save:                               ; EDI = buffer (needs 4016 bytes)
    push esi
    push ecx
    push edi
    push eax
    mov esi, VGA_BASE
    mov ecx, SCR_BYTES/4
    rep movsd
    mov eax, [con_x]
    stosd
    mov eax, [con_y]
    stosd
    movzx eax, byte [con_attr]
    stosd
    pop eax
    pop edi
    pop ecx
    pop esi
    ret

con_restore:                            ; ESI = buffer written by con_save
    push esi
    push ecx
    push edi
    push eax
    mov edi, VGA_BASE
    mov ecx, SCR_BYTES/4
    rep movsd
    lodsd
    mov [con_x], eax
    lodsd
    mov [con_y], eax
    lodsd
    mov [con_attr], al
    call con_cursor
    pop eax
    pop edi
    pop ecx
    pop esi
    ret

con_setattr:                            ; AL = new attribute, recolours whole screen
    push eax
    push ecx
    push edi
    mov [con_attr], al
    mov edi, VGA_BASE + 1
    mov ecx, SCR_COLS*SCR_ROWS
.l: mov [edi], al
    add edi, 2
    dec ecx
    jnz .l
    pop edi
    pop ecx
    pop eax
    ret

; ---- serial port (debug mirror) ---------------------------------------------
ser_init:
    push eax
    push edx
    mov dx, 0x3FF
    mov al, 0xAE
    out dx, al
    in al, dx
    cmp al, 0xAE
    jne .none
    mov dx, 0x3F9
    xor al, al
    out dx, al
    mov dx, 0x3FB
    mov al, 0x80
    out dx, al
    mov dx, 0x3F8
    mov al, 1
    out dx, al
    inc edx
    xor al, al
    out dx, al
    mov dx, 0x3FB
    mov al, 3
    out dx, al
    mov dx, 0x3FA
    mov al, 0xC7
    out dx, al
    mov dx, 0x3FC
    mov al, 0x0B
    out dx, al
    mov byte [ser_ok], 1
.none:
    pop edx
    pop eax
    ret

ser_putc:                               ; AL, all registers preserved
    push eax
    push ecx
    push edx
    mov ah, al
    mov ecx, 20000
    mov dx, 0x3FD
.w: in al, dx
    test al, 0x20
    jnz .s
    dec ecx
    jnz .w
    jmp .x
.s: mov dx, 0x3F8
    mov al, ah
    out dx, al
.x: pop edx
    pop ecx
    pop eax
    ret
