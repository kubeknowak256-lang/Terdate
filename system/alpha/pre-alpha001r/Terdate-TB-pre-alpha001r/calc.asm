; ============================================================================
;  calc.asm - SET /A expression evaluator (32-bit signed)
;     ( ) ! ~ - * / % + - << >> & ^ |  = += -= *= /= %= &= ^= |= <<= >>=  ,
;  Variables are read from the environment (undefined = 0).
;  The ex_* routines clobber all registers except EBP/ESP.
; ============================================================================
section .bss
ex_p:       resd 1
ex_err:     resd 1
section .data
msg_div0:   db 'Divide by zero error.', 13, 10, 0
msg_misop:  db 'Missing operator.', 13, 10, 0
msg_misopd: db 'Missing operand.', 13, 10, 0
msg_unbal:  db 'Unbalanced parenthesis.', 13, 10, 0
ex_opchars: db '+-*/%&^|', 0
ex_optab:                               ; level, char1, char2, opcode
    db 0, '|', 0, 8
    db 1, '^', 0, 7
    db 2, '&', 0, 6
    db 3, '<', '<', 9
    db 3, '>', '>', 10
    db 4, '+', 0, 1
    db 4, '-', 0, 2
    db 5, '*', 0, 3
    db 5, '/', 0, 4
    db 5, '%', 0, 5
    db 0xFF
section .text

; ex_eval: ESI = expression -> EAX = value, CF=1 on error (message already printed)
ex_eval:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov [ex_p], esi
    mov dword [ex_err], 0
    call ex_comma
    mov ebx, eax
    cmp dword [ex_err], 0
    jne .bad
    mov esi, [ex_p]
    call skip_sp
    mov al, [esi]
    test al, al
    jz .ok
    cmp al, ')'
    jne .misop
    mov esi, msg_unbal
    call err_puts
    jmp .bad
.misop:
    mov esi, msg_misop
    call err_puts
    jmp .bad
.ok:
    mov eax, ebx
    clc
    jmp .x
.bad:
    xor eax, eax
    stc
.x: pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

ex_skip:                                ; skip blanks at [ex_p] -> AL = next char
    mov esi, [ex_p]
    call skip_sp
    mov [ex_p], esi
    mov al, [esi]
    ret

ex_comma:
    call ex_assign
.l: cmp dword [ex_err], 0
    jne .r
    push eax
    call ex_skip
    mov bl, al
    pop eax
    cmp bl, ','
    jne .r
    inc dword [ex_p]
    call ex_assign
    jmp .l
.r: ret

ex_getvar:                              ; ESI = name (zstring) -> EAX = numeric value (0 if undefined)
    call strlen
    mov ecx, eax
    call env_get
    test eax, eax
    jz .zero
    mov esi, eax
    call parse_sint
    jnc .r
.zero:
    xor eax, eax
.r: ret

ex_apply:                               ; EDX = opcode, EAX = left, EBX = right -> EAX
    cmp edx, 1
    je .add
    cmp edx, 2
    je .sub
    cmp edx, 3
    je .mul
    cmp edx, 4
    je .div
    cmp edx, 5
    je .mod
    cmp edx, 6
    je .and
    cmp edx, 7
    je .xor
    cmp edx, 8
    je .or
    mov ecx, ebx
    cmp edx, 9
    je .shl
    sar eax, cl
    ret
.shl:
    shl eax, cl
    ret
.add:
    add eax, ebx
    ret
.sub:
    sub eax, ebx
    ret
.mul:
    imul eax, ebx
    ret
.div:
    test ebx, ebx
    jz .dz
    cdq
    idiv ebx
    ret
.mod:
    test ebx, ebx
    jz .dz
    cdq
    idiv ebx
    mov eax, edx
    ret
.and:
    and eax, ebx
    ret
.xor:
    xor eax, ebx
    ret
.or:
    or eax, ebx
    ret
.dz:
    mov dword [ex_err], 1
    mov esi, msg_div0
    call err_puts
    xor eax, eax
    ret

; ex_assign: "name = expr", "name += expr" ... or a plain expression
ex_assign:
    push ebp
    mov ebp, esp
    sub esp, 112                        ; [ebp-80..] identifier, [ebp-96..] number text
    mov esi, [ex_p]
    call skip_sp
    mov al, [esi]
    cmp al, '_'
    je .idstart
    mov ah, al
    or ah, 0x20
    cmp ah, 'a'
    jb .noassign
    cmp ah, 'z'
    ja .noassign
.idstart:
    lea edi, [ebp-80]
    xor ecx, ecx
.id:
    mov al, [esi+ecx]
    call is_alnum
    jnc .ide
    cmp ecx, 60
    jae .ide
    mov [edi+ecx], al
    inc ecx
    jmp .id
.ide:
    mov byte [edi+ecx], 0
    add esi, ecx
    call skip_sp
    mov al, [esi]
    mov ah, [esi+1]
    cmp al, '='
    jne .compound
    cmp ah, '='
    je .noassign
    xor edx, edx
    inc esi
    jmp .rhs
.compound:
    cmp ah, '='
    jne .shiftop
    mov edi, ex_opchars
    xor edx, edx
.oc:
    mov bl, [edi+edx]
    test bl, bl
    jz .noassign
    cmp bl, al
    je .ocf
    inc edx
    jmp .oc
.ocf:
    inc edx
    add esi, 2
    jmp .rhs
.shiftop:
    cmp al, '<'
    jne .sr
    cmp ah, '<'
    jne .noassign
    cmp byte [esi+2], '='
    jne .noassign
    mov edx, 9
    add esi, 3
    jmp .rhs
.sr:
    cmp al, '>'
    jne .noassign
    cmp ah, '>'
    jne .noassign
    cmp byte [esi+2], '='
    jne .noassign
    mov edx, 10
    add esi, 3
.rhs:
    mov [ex_p], esi
    push edx
    call ex_assign
    pop edx
    cmp dword [ex_err], 0
    jne .ret
    test edx, edx
    jz .store
    mov ebx, eax
    push edx
    lea esi, [ebp-80]
    call ex_getvar
    pop edx
    call ex_apply
    cmp dword [ex_err], 0
    jne .ret
.store:
    mov ebx, eax
    lea edi, [ebp-96]
    call itoa
    lea esi, [ebp-80]
    call strlen
    mov ecx, eax
    lea edx, [ebp-96]
    call env_set
    mov eax, ebx
    jmp .ret
.noassign:
    xor eax, eax
    push dword 0
    call ex_binary
.ret:
    mov esp, ebp
    pop ebp
    ret

; ex_matchop: EAX = level -> EDX = opcode (0 = none); consumes the operator when found
ex_matchop:
    push ebx
    push esi
    push edi
    mov ebx, eax
    call ex_skip
    mov esi, [ex_p]
    mov edi, ex_optab
.l: mov al, [edi]
    cmp al, 0xFF
    je .none
    cmp al, bl
    jne .n
    mov ah, [edi+1]
    cmp ah, [esi]
    jne .n
    mov ah, [edi+2]
    test ah, ah
    jz .hit1
    cmp ah, [esi+1]
    jne .n
    movzx edx, byte [edi+3]
    add dword [ex_p], 2
    jmp .x
.hit1:
    cmp byte [esi+1], '='               ; "+=" etc. belong to ex_assign, not here
    je .none
    movzx edx, byte [edi+3]
    inc dword [ex_p]
    jmp .x
.n: add edi, 4
    jmp .l
.none:
    xor edx, edx
.x: pop edi
    pop esi
    pop ebx
    ret

; ex_binary(level): precedence climbing over levels 0..5, level 6 = unary
ex_binary:
    push ebp
    mov ebp, esp
    mov eax, [ebp+8]
    cmp eax, 6
    jb .rec
    call ex_unary
    pop ebp
    ret 4
.rec:
    inc eax
    push eax
    call ex_binary
.loop:
    cmp dword [ex_err], 0
    jne .done
    push eax
    mov eax, [ebp+8]
    call ex_matchop
    pop eax
    test edx, edx
    jz .done
    push edx
    push eax
    mov eax, [ebp+8]
    inc eax
    push eax
    call ex_binary
    mov ebx, eax
    pop eax
    pop edx
    cmp dword [ex_err], 0
    jne .done
    call ex_apply
    jmp .loop
.done:
    pop ebp
    ret 4

ex_unary:
    call ex_skip
    cmp al, '-'
    jne .nm
    inc dword [ex_p]
    call ex_unary
    neg eax
    ret
.nm:
    cmp al, '+'
    jne .nn
    inc dword [ex_p]
    jmp ex_unary
.nn:
    cmp al, '!'
    jne .nt
    inc dword [ex_p]
    call ex_unary
    test eax, eax
    setz al
    movzx eax, al
    ret
.nt:
    cmp al, '~'
    jne ex_primary
    inc dword [ex_p]
    call ex_unary
    not eax
    ret

ex_primary:
    call ex_skip
    cmp al, '('
    jne .num
    inc dword [ex_p]
    call ex_comma
    cmp dword [ex_err], 0
    jne .r
    push eax
    call ex_skip
    cmp al, ')'
    jne .unbal
    inc dword [ex_p]
    pop eax
.r: ret
.unbal:
    pop eax
    mov dword [ex_err], 1
    mov esi, msg_unbal
    call err_puts
    xor eax, eax
    ret
.num:
    cmp al, '0'
    jb .id
    cmp al, '9'
    ja .id
    mov esi, [ex_p]
    call parse_num
    mov [ex_p], esi
    ret
.id:
    push ebp
    mov ebp, esp
    sub esp, 72
    mov esi, [ex_p]
    mov edi, esp
    xor ecx, ecx
.il:
    mov al, [esi+ecx]
    call is_alnum
    jnc .ie
    cmp ecx, 64
    jae .ie
    mov [edi+ecx], al
    inc ecx
    jmp .il
.ie:
    test ecx, ecx
    jz .missing
    mov byte [edi+ecx], 0
    add esi, ecx
    mov [ex_p], esi
    mov esi, edi
    call ex_getvar
    mov esp, ebp
    pop ebp
    ret
.missing:
    mov esp, ebp
    pop ebp
    mov dword [ex_err], 1
    mov esi, msg_misopd
    call err_puts
    xor eax, eax
    ret
