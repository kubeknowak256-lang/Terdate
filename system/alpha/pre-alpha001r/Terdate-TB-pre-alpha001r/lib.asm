; ============================================================================
;  lib.asm - string / memory / number helpers (32-bit)
;  Convention: only EAX, ECX, EDX are clobbered unless a routine says
;  otherwise. EBX, ESI, EDI, EBP are always preserved.
; ============================================================================

strlen:                                 ; ESI -> EAX
    xor eax, eax
.l: cmp byte [esi+eax], 0
    je .d
    inc eax
    jmp .l
.d: ret

strcpy:                                 ; ESI src, EDI dst -> EAX = dst NUL
    push esi
    push edi
.l: lodsb
    stosb
    test al, al
    jnz .l
    lea eax, [edi-1]
    pop edi
    pop esi
    ret

strcat:                                 ; append ESI to string at EDI -> EAX = new NUL
    push edi
.f: cmp byte [edi], 0
    je .g
    inc edi
    jmp .f
.g: call strcpy
    pop edi
    ret

memcpy:                                 ; ESI src, EDI dst, ECX count
    push esi
    push edi
    rep movsb
    pop edi
    pop esi
    ret

memzero:                                ; EDI, ECX
    push edi
    xor eax, eax
    rep stosb
    pop edi
    ret

to_upper:                               ; AL
    cmp al, 'a'
    jb .r
    cmp al, 'z'
    ja .r
    sub al, 32
.r: ret

to_lower:                               ; AL
    cmp al, 'A'
    jb .r
    cmp al, 'Z'
    ja .r
    add al, 32
.r: ret

stricmp:                                ; ESI, EDI -> ZF=1 when equal (ignore case)
    push esi
    push edi
.l: mov al, [esi]
    call to_upper
    mov ah, al
    mov al, [edi]
    call to_upper
    cmp al, ah
    jne .x
    test al, al
    jz .x
    inc esi
    inc edi
    jmp .l
.x: pop edi
    pop esi
    ret

strcmp:                                 ; ESI, EDI -> ZF=1 when equal
    push esi
    push edi
.l: mov al, [esi]
    cmp al, [edi]
    jne .x
    test al, al
    jz .x
    inc esi
    inc edi
    jmp .l
.x: pop edi
    pop esi
    ret

name_eq:                                ; ESI text, ECX len, EDI zstring -> ZF=1 equal (ignore case)
    push esi
    push edi
    push ecx
.l: test ecx, ecx
    jz .e
    mov al, [esi]
    call to_upper
    mov ah, al
    mov al, [edi]
    call to_upper
    cmp al, ah
    jne .x
    inc esi
    inc edi
    dec ecx
    jmp .l
.e: cmp byte [edi], 0
.x: pop ecx
    pop edi
    pop esi
    ret

skip_sp:                                ; ESI past spaces and tabs
.l: cmp byte [esi], ' '
    je .n
    cmp byte [esi], 9
    jne .d
.n: inc esi
    jmp .l
.d: ret

; parse_num: ESI -> EAX (unsigned), ESI advanced; CF=1 when no digits.
; Accepts decimal and 0x hexadecimal.
parse_num:
    push ebx
    push ecx
    xor eax, eax
    xor ecx, ecx
    cmp byte [esi], '0'
    jne .dec
    mov bl, [esi+1]
    or bl, 0x20
    cmp bl, 'x'
    jne .dec
    add esi, 2
.hex:
    movzx ebx, byte [esi]
    cmp bl, '0'
    jb .end
    cmp bl, '9'
    jbe .hd
    or bl, 0x20
    cmp bl, 'a'
    jb .end
    cmp bl, 'f'
    ja .end
    sub bl, 'a' - 10
    jmp .ha
.hd: sub bl, '0'
.ha: shl eax, 4
    add eax, ebx
    inc ecx
    inc esi
    jmp .hex
.dec:
    movzx ebx, byte [esi]
    sub bl, '0'
    cmp bl, 9
    ja .end
    imul eax, eax, 10
    add eax, ebx
    inc ecx
    inc esi
    jmp .dec
.end:
    test ecx, ecx
    jnz .ok
    stc
    jmp .r
.ok: clc
.r: pop ecx
    pop ebx
    ret

; itoa: EAX signed value, EDI dest -> EDI points at the written NUL
itoa:
    push ebx
    push ecx
    push edx
    mov ebx, 10
    test eax, eax
    jns .pos
    mov byte [edi], '-'
    inc edi
    neg eax
.pos:
    xor ecx, ecx
.d: xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .d
.o: pop edx
    add dl, '0'
    mov [edi], dl
    inc edi
    dec ecx
    jnz .o
    mov byte [edi], 0
    pop edx
    pop ecx
    pop ebx
    ret

; is_alnum: AL -> CF=1 when AL is [A-Za-z0-9_]; AL preserved
is_alnum:
    push eax
    cmp al, '_'
    je .y
    cmp al, '0'
    jb .n
    cmp al, '9'
    jbe .y
    or al, 0x20
    cmp al, 'a'
    jb .n
    cmp al, 'z'
    ja .n
.y: pop eax
    stc
    ret
.n: pop eax
    clc
    ret

strncpy_z:                              ; ESI src, EDI dst, ECX max chars -> EAX = dst NUL (ESI/EDI kept)
    push esi
    push edi
    push ecx
.l: test ecx, ecx
    jz .e
    mov al, [esi]
    test al, al
    jz .e
    mov [edi], al
    inc esi
    inc edi
    dec ecx
    jmp .l
.e: mov byte [edi], 0
    mov eax, edi
    pop ecx
    pop edi
    pop esi
    ret

word_is:                                ; ESI text, EDI word -> ZF=1 when text == word (ignore case), spaces may follow
    push esi
    push edi
.l: mov al, [edi]
    test al, al
    jz .e
    call to_upper
    mov ah, al
    mov al, [esi]
    call to_upper
    cmp al, ah
    jne .x
    inc esi
    inc edi
    jmp .l
.e: call skip_sp
    cmp byte [esi], 0
.x: pop edi
    pop esi
    ret
