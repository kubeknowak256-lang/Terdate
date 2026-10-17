; ============================================================================
;  expand.asm - batch variable expansion
;     %VAR%  %VAR:~2,5%  %VAR:old=new%  %0..%9  %*  %~dp0  %%   (percent)
;     !VAR!  !VAR:~2,5!  !VAR:old=new!                         (delayed)
;  Output goes through exp_putc, which silently stops at the buffer limit.
; ============================================================================
section .bss
vr_buf:     resb 512
exp_lim:    resd 1
am_buf:     resb 64
am_tmp:     resb 200
section .data
empty_str:  db 0
section .text

exp_putc:                               ; AL -> [EDI], EDI++
    cmp edi, [exp_lim]
    jae .f
    mov [edi], al
    inc edi
.f: ret

exp_puts:                               ; ESI string -> EDI (ESI ends on the NUL)
.l: mov al, [esi]
    test al, al
    jz .d
    call exp_putc
    inc esi
    jmp .l
.d: ret

parse_sint:                             ; ESI -> EAX signed, ESI advanced, CF=1 when no number
    push ebx
    xor ebx, ebx
    cmp byte [esi], '-'
    jne .p
    inc ebx
    inc esi
    jmp .n
.p: cmp byte [esi], '+'
    jne .n
    inc esi
.n: call parse_num
    jc .none
    test ebx, ebx
    jz .ok
    neg eax
.ok:
    clc
    pop ebx
    ret
.none:
    xor eax, eax
    stc
    pop ebx
    ret

; var_expand: ESI = "name" or "name:modifier" (length ECX, not terminated), EDI = dest
;  appends the value to EDI (EDI advances)
var_expand:
    push ebx
    push esi
    push ebp
    cmp ecx, 500
    jbe .l1
    mov ecx, 500
.l1:
    push edi
    mov edi, vr_buf
    rep movsb
    mov byte [edi], 0
    pop edi
    mov esi, vr_buf
    xor ebp, ebp
.sp:
    mov al, [esi]
    test al, al
    jz .sd
    cmp al, ':'
    je .colon
    inc esi
    jmp .sp
.colon:
    mov byte [esi], 0
    lea ebp, [esi+1]
.sd:
    mov ecx, esi
    sub ecx, vr_buf
    mov esi, vr_buf
    call env_get
    mov esi, eax
    test esi, esi
    jnz .have
    mov esi, empty_str
.have:
    test ebp, ebp
    jnz .mod
    call exp_puts
    jmp .x
.mod:
    cmp byte [ebp], '~'
    je .substr
    jmp .replace

; ---- %var:~start,length% -------------------------------------------------------
.substr:
    inc ebp
    call strlen
    mov ebx, eax                        ; EBX = length of the value
    push esi
    mov esi, ebp
    call parse_sint
    mov edx, eax                        ; EDX = start
    xor ecx, ecx
    xor ebp, ebp                        ; EBP = "length given" flag
    cmp byte [esi], ','
    jne .nolen
    inc esi
    call parse_sint
    mov ecx, eax
    mov ebp, 1
.nolen:
    pop esi
    test edx, edx
    jns .s1
    add edx, ebx
    jns .s1
    xor edx, edx
.s1:
    cmp edx, ebx
    jbe .s2
    mov edx, ebx
.s2:
    mov eax, ebx
    sub eax, edx                        ; characters remaining after start
    test ebp, ebp
    jz .cnt
    test ecx, ecx
    jns .cl
    add ecx, ebx
    sub ecx, edx
    jns .cl
    xor ecx, ecx
.cl:
    cmp ecx, eax
    jbe .out
.cnt:
    mov ecx, eax
.out:
    add esi, edx
.cp:
    test ecx, ecx
    jz .x
    mov al, [esi]
    call exp_putc
    inc esi
    dec ecx
    jmp .cp

; ---- %var:old=new% ---------------------------------------------------------------
.replace:
    mov edx, ebp
.fe:
    mov al, [edx]
    test al, al
    jz .noeq
    cmp al, '='
    je .eq
    inc edx
    jmp .fe
.noeq:
    call exp_puts
    jmp .x
.eq:
    mov byte [edx], 0
    inc edx                             ; EDX = replacement text
    xor ebx, ebx                        ; EBX = "*old" form
    cmp byte [ebp], '*'
    jne .ns
    inc ebp
    inc ebx
.ns:
    cmp byte [ebp], 0
    jne .go
    call exp_puts
    jmp .x
.go:
    push esi
    mov esi, ebp
    call strlen
    mov ecx, eax                        ; ECX = pattern length
    pop esi
    test ebx, ebx
    jnz .star
.scan:
    cmp byte [esi], 0
    je .x
    call .pm
    jne .copy1
    push esi
    mov esi, edx
    call exp_puts
    pop esi
    add esi, ecx
    jmp .scan
.copy1:
    mov al, [esi]
    call exp_putc
    inc esi
    jmp .scan
.star:
    push esi
.fs:
    cmp byte [esi], 0
    je .nf
    call .pm
    je .fh
    inc esi
    jmp .fs
.fh:
    add esi, ecx
    add esp, 4
    push esi
    mov esi, edx
    call exp_puts
    pop esi
    call exp_puts
    jmp .x
.nf:
    pop esi
    call exp_puts
    jmp .x
.pm:                                    ; ZF=1 when text at ESI starts with pattern EBP
    push esi
    push ebp
.pl:
    mov al, [ebp]
    test al, al
    jz .pe
    call to_upper
    mov ah, al
    mov al, [esi]
    call to_upper
    cmp al, ah
    jne .pe
    inc esi
    inc ebp
    jmp .pl
.pe:
    pop ebp
    pop esi
    ret
.x: pop ebp
    pop esi
    pop ebx
    ret

; expand_pct: ESI = raw text, EDI = destination, ECX = capacity -> EDI = end (NUL written)
expand_pct:
    push ebx
    push esi
    lea eax, [edi+ecx-2]
    mov [exp_lim], eax
.loop:
    mov al, [esi]
    test al, al
    jz .end
    cmp al, '%'
    je .pct
    call exp_putc
    inc esi
    jmp .loop
.end:
    mov byte [edi], 0
    pop esi
    pop ebx
    ret
.pct:
    mov al, [esi+1]
    cmp al, '%'
    jne .p1
    mov al, '%'
    call exp_putc
    add esi, 2
    jmp .loop
.p1:
    cmp al, '0'
    jb .p2
    cmp al, '9'
    ja .p2
    movzx eax, al
    sub eax, '0'
    add esi, 2
    push esi
    mov ebx, [cur_frame]
    mov esi, [ebx+FR_ARGV+eax*4]
    call exp_puts
    pop esi
    jmp .loop
.p2:
    cmp al, '*'
    jne .p3
    add esi, 2
    push esi
    mov ebx, [cur_frame]
    mov esi, [ebx+FR_ARGALL]
    call exp_puts
    pop esi
    jmp .loop
.p3:
    cmp al, '~'
    jne .p4
    call exp_argmod
    jmp .loop
.p4:
    lea edx, [esi+1]
.f: mov al, [edx]
    test al, al
    jz .drop
    cmp al, 10
    je .drop
    cmp al, '%'
    je .pair
    inc edx
    jmp .f
.drop:
    inc esi
    jmp .loop
.pair:
    lea ebx, [esi+1]
    mov ecx, edx
    sub ecx, ebx
    lea esi, [edx+1]
    push esi
    mov esi, ebx
    call var_expand
    pop esi
    jmp .loop

; expand_delayed: same signature as expand_pct, but for !VAR!
expand_delayed:
    push ebx
    push esi
    lea eax, [edi+ecx-2]
    mov [exp_lim], eax
.loop:
    mov al, [esi]
    test al, al
    jz .end
    cmp al, '!'
    je .bang
    call exp_putc
    inc esi
    jmp .loop
.end:
    mov byte [edi], 0
    pop esi
    pop ebx
    ret
.bang:
    lea edx, [esi+1]
.f: mov al, [edx]
    test al, al
    jz .drop
    cmp al, '!'
    je .pair
    inc edx
    jmp .f
.drop:
    inc esi
    jmp .loop
.pair:
    lea ebx, [esi+1]
    mov ecx, edx
    sub ecx, ebx
    lea esi, [edx+1]
    push esi
    mov esi, ebx
    call var_expand
    pop esi
    jmp .loop

; exp_argmod: ESI at '%' of "%~[fdpnx]N" -> expands, ESI advanced, EDI dest
exp_argmod:
    push ebx
    push ecx
    push edx
    push ebp
    lea ebx, [esi+2]
    xor ebp, ebp                        ; 1=f 2=d 4=p 8=n 16=x
.m: mov al, [ebx]
    cmp al, '0'
    jb .letter
    cmp al, '9'
    jbe .digit
.letter:
    or al, 0x20
    cmp al, 'f'
    jne .a1
    or ebp, 1
    jmp .nx
.a1:
    cmp al, 'd'
    jne .a2
    or ebp, 2
    jmp .nx
.a2:
    cmp al, 'p'
    jne .a3
    or ebp, 4
    jmp .nx
.a3:
    cmp al, 'n'
    jne .a4
    or ebp, 8
    jmp .nx
.a4:
    cmp al, 'x'
    jne .a5
    or ebp, 16
    jmp .nx
.a5:
    cmp al, 's'
    je .nx
    cmp al, 'a'
    je .nx
    cmp al, 't'
    je .nx
    cmp al, 'z'
    je .nx
    jmp .bad
.nx:
    inc ebx
    jmp .m
.bad:
    inc esi
    jmp .out
.digit:
    movzx ecx, byte [ebx]
    sub ecx, '0'
    lea esi, [ebx+1]
    mov edx, [cur_frame]
    mov eax, [edx+FR_ARGV+ecx*4]
    test ecx, ecx
    jnz .have
    test ebp, 31
    jz .have
    mov eax, [edx+FR_PATH]
.have:
    push esi                            ; resume point
    mov esi, eax
    xor ecx, ecx
.cp:
    mov al, [esi]
    test al, al
    jz .cpd
    inc esi
    cmp al, '"'
    je .cp
    cmp ecx, 190
    jae .cp
    mov [am_tmp+ecx], al
    inc ecx
    jmp .cp
.cpd:
    mov byte [am_tmp+ecx], 0
    pop esi
    test ebp, 31
    jnz .path
    push esi
    mov esi, am_tmp
    call exp_puts
    pop esi
    jmp .out
.path:
    push esi
    mov esi, am_tmp
    push edi
    mov edi, am_buf
    call fs_norm
    pop edi
    jc .raw
    mov ebx, am_buf                     ; EBX = last '\'
    mov esi, am_buf
.ls:
    cmp byte [esi], 0
    je .lsd
    cmp byte [esi], '\'
    jne .ln
    mov ebx, esi
.ln:
    inc esi
    jmp .ls
.lsd:
    lea edx, [ebx+1]                    ; EDX = name start
    xor ecx, ecx                        ; ECX = last '.' in name
    mov esi, edx
.ds:
    cmp byte [esi], 0
    je .dsd
    cmp byte [esi], '.'
    jne .dn
    mov ecx, esi
.dn:
    inc esi
    jmp .ds
.dsd:
    test ebp, 1
    jz .nof
    mov al, 'C'
    call exp_putc
    mov al, ':'
    call exp_putc
    mov esi, am_buf
    call exp_puts
    jmp .pdone
.nof:
    test ebp, 2
    jz .nod
    mov al, 'C'
    call exp_putc
    mov al, ':'
    call exp_putc
.nod:
    test ebp, 4
    jz .nop
    mov esi, am_buf
.pp:
    mov al, [esi]
    call exp_putc
    cmp esi, ebx
    je .ppd
    inc esi
    jmp .pp
.ppd:
.nop:
    test ebp, 8
    jz .non
    mov esi, edx
.pn:
    cmp byte [esi], 0
    je .non
    test ecx, ecx
    jz .pn1
    cmp esi, ecx
    jae .non
.pn1:
    mov al, [esi]
    call exp_putc
    inc esi
    jmp .pn
.non:
    test ebp, 16
    jz .pdone
    test ecx, ecx
    jz .pdone
    mov esi, ecx
    call exp_puts
.pdone:
    pop esi
    jmp .out
.raw:
    mov esi, am_tmp
    call exp_puts
    pop esi
.out:
    pop ebp
    pop edx
    pop ecx
    pop ebx
    ret
