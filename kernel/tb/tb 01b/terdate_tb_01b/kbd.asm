; ============================================================================
;  kbd.asm - PS/2 keyboard (scan code set 1, US layout), ring buffer, readline
; ============================================================================
section .bss
kb_buf:     resb 64
kb_head:    resd 1
kb_tail:    resd 1
kb_shift:   resb 1
kb_ctrl:    resb 1
kb_caps:    resb 1
kb_ext:     resb 1
section .data
kb_map:
    db 0, 27, '1','2','3','4','5','6','7','8','9','0','-','=', 8, 9
    db 'q','w','e','r','t','y','u','i','o','p','[',']', 13, 0
    db 'a','s','d','f','g','h','j','k','l',';',"'",'`', 0, '\'
    db 'z','x','c','v','b','n','m',',','.','/', 0, '*', 0, ' '
kb_map_sh:
    db 0, 27, '!','@','#','$','%','^','&','*','(',')','_','+', 8, 9
    db 'Q','W','E','R','T','Y','U','I','O','P','{','}', 13, 0
    db 'A','S','D','F','G','H','J','K','L',':','"','~', 0, '|'
    db 'Z','X','C','V','B','N','M','<','>','?', 0, '*', 0, ' '
KB_MAPLEN equ 0x3A
section .text

kb_init:
.f: in al, 0x64                         ; drain the controller output buffer
    test al, 1
    jz .d
    in al, 0x60
    jmp .f
.d: ret

kb_put:                                 ; AL -> ring buffer
    push ebx
    push ecx
    mov ecx, [kb_head]
    mov ebx, ecx
    inc ebx
    and ebx, 63
    cmp ebx, [kb_tail]
    je .full
    mov [kb_buf + ecx], al
    mov [kb_head], ebx
.full:
    pop ecx
    pop ebx
    ret

kb_irq:                                 ; called from the IRQ1 stub
    in al, 0x60
    cmp al, 0xE0
    jne .n1
    mov byte [kb_ext], 1
    ret
.n1:
    mov dl, [kb_ext]
    mov byte [kb_ext], 0
    mov ah, al
    and al, 0x7F
    test ah, 0x80
    jnz .release
    cmp al, 0x2A
    je .shon
    cmp al, 0x36
    je .shon
    cmp al, 0x1D
    je .cton
    cmp al, 0x3A
    je .caps
    test dl, dl
    jnz .extkey
    movzx ebx, al
    cmp ebx, KB_MAPLEN
    jae .done
    cmp byte [kb_shift], 0
    jne .shifted
    mov al, [kb_map + ebx]
    jmp .have
.shifted:
    mov al, [kb_map_sh + ebx]
.have:
    test al, al
    jz .done
    mov ah, al
    or ah, 0x20
    cmp ah, 'a'
    jb .nl
    cmp ah, 'z'
    ja .nl
    cmp byte [kb_caps], 0               ; letters only: caps lock inverts case
    je .noc
    xor al, 0x20
.noc:
    cmp byte [kb_ctrl], 0               ; ctrl+letter -> control code
    je .nl
    and al, 0x1F
.nl:
    call kb_put
.done:
    ret
.shon:
    mov byte [kb_shift], 1
    ret
.cton:
    mov byte [kb_ctrl], 1
    ret
.caps:
    xor byte [kb_caps], 1
    ret
.release:
    cmp al, 0x2A
    je .shoff
    cmp al, 0x36
    je .shoff
    cmp al, 0x1D
    je .ctoff
    ret
.shoff:
    mov byte [kb_shift], 0
    ret
.ctoff:
    mov byte [kb_ctrl], 0
    ret
.extkey:                                ; keypad Enter and keypad /
    cmp al, 0x1C
    jne .e2
    mov al, 13
    jmp kb_put
.e2:
    cmp al, 0x35
    jne .done
    mov al, '/'
    jmp kb_put

kb_poll:                                ; CF=0 and AL = key, or CF=1 when empty
    push ecx
    mov ecx, [kb_tail]
    cmp ecx, [kb_head]
    je .none
    movzx eax, byte [kb_buf + ecx]
    inc ecx
    and ecx, 63
    mov [kb_tail], ecx
    pop ecx
    clc
    ret
.none:
    pop ecx
    stc
    ret

kb_getc:                                ; wait for a key -> AL
.w: call kb_poll
    jnc .g
    hlt
    jmp .w
.g: ret

kb_flush:
.l: call kb_poll
    jnc .l
    ret

; kb_readline: EDI = buffer, ECX = size (including NUL) -> EAX = length. Echoes.
kb_readline:
    push ebx
    push esi
    push ebp
    mov ebx, edi
    mov esi, ecx
    xor ebp, ebp
.loop:
    call kb_getc
    cmp al, 13
    je .enter
    cmp al, 8
    je .bs
    cmp al, 32
    jb .loop
    cmp al, 126
    ja .loop
    lea ecx, [esi-1]
    cmp ebp, ecx
    jae .loop
    mov [ebx+ebp], al
    inc ebp
    call con_putc
    jmp .loop
.bs:
    test ebp, ebp
    jz .loop
    dec ebp
    mov al, 8
    call con_putc
    mov al, ' '
    call con_putc
    mov al, 8
    call con_putc
    jmp .loop
.enter:
    mov byte [ebx+ebp], 0
    mov al, 13
    call con_putc
    mov al, 10
    call con_putc
    mov eax, ebp
    pop ebp
    pop esi
    pop ebx
    ret
