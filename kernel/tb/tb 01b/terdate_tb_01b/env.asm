; ============================================================================
;  env.asm - environment block ("NAME=value",0 ... ,0), SETLOCAL/ENDLOCAL,
;  dynamic variables (CD, DATE, TIME, RANDOM, ERRORLEVEL, CMDEXTVERSION)
; ============================================================================
section .bss
env_ptr:    resd 1                      ; environment of the running process
sl_depth:   resd 1                      ; setlocal nesting
dyn_buf:    resb 64
section .data
dn_cd:      db 'CD', 0
dn_date:    db 'DATE', 0
dn_time:    db 'TIME', 0
dn_random:  db 'RANDOM', 0
dn_errlvl:  db 'ERRORLEVEL', 0
dn_cmdext:  db 'CMDEXTVERSION', 0
dyn_table:
    dd dn_cd, dv_cd
    dd dn_date, dv_date
    dd dn_time, dv_time
    dd dn_random, dv_random
    dd dn_errlvl, dv_errlvl
    dd dn_cmdext, dv_cmdext
    dd 0, 0
section .text

env_find:                               ; ESI = name, ECX = length -> EAX = "NAME=..." entry or 0
    push ebx
    push edx
    push edi
    mov edi, [env_ptr]
.next:
    cmp byte [edi], 0
    je .nf
    mov ebx, edi
    xor edx, edx
.cmp:
    cmp edx, ecx
    je .eq
    mov al, [esi+edx]
    call to_upper
    mov ah, al
    mov al, [ebx+edx]
    call to_upper
    cmp al, ah
    jne .skip
    inc edx
    jmp .cmp
.eq:
    cmp byte [ebx+edx], '='
    je .found
.skip:
    cmp byte [edi], 0
    je .sk2
    inc edi
    jmp .skip
.sk2:
    inc edi
    jmp .next
.found:
    mov eax, ebx
    jmp .x
.nf:
    xor eax, eax
.x: pop edi
    pop edx
    pop ebx
    ret

env_get:                                ; ESI = name, ECX = length -> EAX = value pointer or 0
    call env_find
    test eax, eax
    jz dyn_get
    add eax, ecx
    inc eax
    ret

dyn_get:                                ; ESI = name, ECX = length -> EAX = value or 0
    push ebx
    push edi
    mov ebx, dyn_table
.l: mov edi, [ebx]
    test edi, edi
    jz .no
    call name_eq
    je .hit
    add ebx, 8
    jmp .l
.hit:
    push esi
    push ecx
    call [ebx+4]
    pop ecx
    pop esi
    jmp .x
.no:
    xor eax, eax
.x: pop edi
    pop ebx
    ret

env_len:                                ; ESI = block -> EAX = bytes including final NUL
    push esi
.e: cmp byte [esi], 0
    je .d
.s: inc esi
    cmp byte [esi], 0
    jne .s
    inc esi
    jmp .e
.d: mov eax, esi
    pop esi
    sub eax, esi
    inc eax
    ret

env_copy:                               ; ESI = source block, EDI = destination block
    push ecx
    push eax
    call env_len
    mov ecx, eax
    call memcpy
    pop eax
    pop ecx
    ret

env_del:                                ; ESI = name, ECX = length
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    call env_find
    test eax, eax
    jz .x
    mov edi, eax
    mov esi, eax
.sc:
    cmp byte [esi], 0
    je .sd
    inc esi
    jmp .sc
.sd:
    inc esi                             ; start of the following entry
    push esi
.e: cmp byte [esi], 0
    je .ed
.e2:
    inc esi
    cmp byte [esi], 0
    jne .e2
    inc esi
    jmp .e
.ed:
    inc esi                             ; include final NUL
    mov ecx, esi
    pop esi
    sub ecx, esi
    rep movsb
.x: pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

env_set:                                ; ESI = name, ECX = length, EDX = value (0 or "" deletes)
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov ebx, edx
    call env_del
    test ebx, ebx
    jz .x
    cmp byte [ebx], 0
    je .x
    mov edi, [env_ptr]
.e: cmp byte [edi], 0
    je .end
.e2:
    inc edi
    cmp byte [edi], 0
    jne .e2
    inc edi
    jmp .e
.end:
    push esi
    mov esi, ebx
    call strlen
    pop esi
    mov edx, edi
    sub edx, [env_ptr]
    add edx, ecx
    add edx, eax
    add edx, 3
    cmp edx, ENV_SIZE
    ja .x
    rep movsb
    mov byte [edi], '='
    inc edi
    mov esi, ebx
    call strcpy
    lea edi, [eax+1]
    mov byte [edi], 0
.x: pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---- SETLOCAL / ENDLOCAL -----------------------------------------------------
do_setlocal:
    push eax
    push ecx
    push esi
    push edi
    mov eax, [sl_depth]
    cmp eax, MAX_SL
    jae .x
    imul edi, eax, SL_SLOT
    add edi, SL_STACK
    movzx ecx, byte [delayed]
    mov [edi], ecx
    mov esi, [env_ptr]
    call env_len
    mov [edi+4], eax
    add edi, 16
    call env_copy
    inc dword [sl_depth]
.x: pop edi
    pop esi
    pop ecx
    pop eax
    ret

do_endlocal:
    push eax
    push ecx
    push esi
    push edi
    mov eax, [sl_depth]
    test eax, eax
    jz .x
    dec eax
    mov [sl_depth], eax
    imul esi, eax, SL_SLOT
    add esi, SL_STACK
    mov ecx, [esi]
    mov [delayed], cl
    mov ecx, [esi+4]
    add esi, 16
    mov edi, [env_ptr]
    rep movsb
.x: pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ---- dynamic variables ---------------------------------------------------------
put2:                                   ; EAX (0..99) -> two digits at EDI
    push edx
    push ecx
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [edi], al
    add dl, '0'
    mov [edi+1], dl
    add edi, 2
    pop ecx
    pop edx
    ret

put4:                                   ; EAX -> four digits at EDI
    push edx
    push ecx
    xor edx, edx
    mov ecx, 100
    div ecx
    push edx
    call put2
    pop eax
    call put2
    pop ecx
    pop edx
    ret

dv_cd:
    mov edi, dyn_buf
    mov byte [edi], 'C'
    mov byte [edi+1], ':'
    add edi, 2
    mov esi, cwd
    call strcpy
    mov eax, dyn_buf
    ret

dv_date:
    call rtc_read
    mov edi, dyn_buf
    mov eax, [rtc_year]
    call put4
    mov byte [edi], '-'
    inc edi
    mov eax, [rtc_mon]
    call put2
    mov byte [edi], '-'
    inc edi
    mov eax, [rtc_day]
    call put2
    mov byte [edi], 0
    mov eax, dyn_buf
    ret

dv_time:
    call rtc_read
    mov edi, dyn_buf
    mov eax, [rtc_hour]
    cmp eax, 10
    jae .two
    mov byte [edi], ' '
    add al, '0'
    mov [edi+1], al
    add edi, 2
    jmp .m
.two:
    call put2
.m: mov byte [edi], ':'
    inc edi
    mov eax, [rtc_min]
    call put2
    mov byte [edi], ':'
    inc edi
    mov eax, [rtc_sec]
    call put2
    mov byte [edi], ','
    inc edi
    mov eax, [ticks]
    xor edx, edx
    mov ecx, 100
    div ecx
    mov eax, edx
    call put2
    mov byte [edi], 0
    mov eax, dyn_buf
    ret

dv_random:
    call rnd_next
    mov edi, dyn_buf
    call itoa
    mov eax, dyn_buf
    ret

dv_errlvl:
    mov eax, [errorlevel]
    mov edi, dyn_buf
    call itoa
    mov eax, dyn_buf
    ret

dv_cmdext:
    mov word [dyn_buf], '2'             ; "2",0
    mov eax, dyn_buf
    ret
