; ============================================================================
;  simple.asm - executing one simple command
;     redirection (> >> < 2> 2>&1 nul), delayed expansion, internal command
;     table, running other .bat files by name, output helpers
; ============================================================================
section .bss
rd_dst0:    resd 1
num_buf:    resb 16
section .data
w_nul:      db 'nul', 0
ext_bat:    db '.bat', 0
ext_cmd:    db '.cmd', 0
msg_notrec1: db "'", 0
msg_notrec2: db "' is not recognized as an internal or external command,", 13, 10
             db 'operable program or batch file.', 13, 10, 0
msg_nopath: db 'The system cannot find the path specified.', 13, 10, 0
msg_nofile: db 'The system cannot find the file specified.', 13, 10, 0
msg_denied: db 'Access is denied.', 13, 10, 0
section .text

; ---- output helpers (honour > redirection) -----------------------------------------
out_putc:                               ; AL, registers preserved
    cmp dword [out_mode], OUT_CON
    je con_putc
    cmp dword [out_mode], OUT_NUL
    je .r
    push edx
    mov edx, [out_ent]
    call fs_append_byte
    pop edx
.r: ret

err_putc:                               ; AL, registers preserved
    push edx
    mov edx, [err_mode]
    cmp edx, ERR_NUL
    je .r
    cmp edx, ERR_OUT
    je .out
    cmp edx, ERR_FILE
    je .file
    call con_putc
    jmp .r
.out:
    call out_putc
    jmp .r
.file:
    mov edx, [err_ent]
    call fs_append_byte
.r: pop edx
    ret

out_puts:                               ; ESI string
    push esi
    push eax
.l: mov al, [esi]
    test al, al
    jz .d
    call out_putc
    inc esi
    jmp .l
.d: pop eax
    pop esi
    ret

err_puts:                               ; ESI string
    push esi
    push eax
.l: mov al, [esi]
    test al, al
    jz .d
    call err_putc
    inc esi
    jmp .l
.d: pop eax
    pop esi
    ret

out_write:                              ; ESI data, ECX length
    push esi
    push ecx
    push eax
.l: test ecx, ecx
    jz .d
    mov al, [esi]
    call out_putc
    inc esi
    dec ecx
    jmp .l
.d: pop eax
    pop ecx
    pop esi
    ret

out_crlf:
    push eax
    mov al, 13
    call out_putc
    mov al, 10
    call out_putc
    pop eax
    ret

err_crlf:
    push eax
    mov al, 13
    call err_putc
    mov al, 10
    call err_putc
    pop eax
    ret

out_dec:                                ; EAX signed number
    push edi
    push esi
    mov edi, num_buf
    call itoa
    mov esi, num_buf
    call out_puts
    pop esi
    pop edi
    ret

; ---- redirection -------------------------------------------------------------------
; rd_target: ESI = text after the operator, EDX = destination -> ESI advanced
rd_target:
    push edi
    push ebx
    push ecx
    call skip_sp
    mov edi, edx
    xor ebx, ebx
    mov ecx, 120
.l: mov al, [esi]
    test al, al
    jz .e
    test ebx, ebx
    jnz .q
    cmp al, ' '
    je .e
    cmp al, 9
    je .e
    cmp al, '<'
    je .e
    cmp al, '>'
    je .e
    cmp al, '"'
    jne .cp
    mov ebx, 1
    inc esi
    jmp .l
.q: cmp al, '"'
    jne .cp
    xor ebx, ebx
    inc esi
    jmp .l
.cp:
    test ecx, ecx
    jz .sk
    mov [edi], al
    inc edi
    dec ecx
.sk:
    inc esi
    jmp .l
.e: mov byte [edi], 0
    pop ecx
    pop ebx
    pop edi
    ret

; rd_parse: ESI = source command text, EDI = destination (command without redirections,
; '^' escapes removed) -> EAX = RF_* flags; targets stored in WS_RDOUT/RDERR/RDIN
rd_parse:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    xor ebx, ebx
    mov [rd_dst0], edi
    WSPTR eax, WS_RDOUT
    mov byte [eax], 0
    WSPTR eax, WS_RDERR
    mov byte [eax], 0
    WSPTR eax, WS_RDIN
    mov byte [eax], 0
.loop:
    mov al, [esi]
    test al, al
    jz .end
    cmp al, '"'
    je .quote
    cmp al, '^'
    je .caret
    cmp al, '>'
    je .gt
    cmp al, '<'
    je .lt
    mov [edi], al
    inc edi
    inc esi
    jmp .loop
.quote:
    mov [edi], al
    inc edi
    inc esi
.q2:
    mov al, [esi]
    test al, al
    jz .end
    mov [edi], al
    inc edi
    inc esi
    cmp al, '"'
    jne .q2
    jmp .loop
.caret:
    inc esi
    mov al, [esi]
    test al, al
    jz .end
    mov [edi], al
    inc edi
    inc esi
    jmp .loop
.lt:
    inc esi
    or ebx, RF_IN
    WSPTR edx, WS_RDIN
    call rd_target
    jmp .loop
.gt:
    mov edx, 1
    cmp edi, [rd_dst0]
    je .gt1
    mov al, [edi-1]
    cmp al, '1'
    je .hd
    cmp al, '2'
    jne .gt1
.hd:
    lea ecx, [edi-1]
    cmp ecx, [rd_dst0]
    je .hdok
    mov ah, [ecx-1]
    cmp ah, ' '
    je .hdok
    cmp ah, 9
    jne .gt1
.hdok:
    movzx edx, al
    sub edx, '0'
    dec edi
.gt1:
    inc esi
    cmp byte [esi], '>'
    jne .noapp
    inc esi
    cmp edx, 1
    jne .noapp
    or ebx, RF_APPEND
.noapp:
    cmp byte [esi], '&'
    jne .file
    inc esi
    mov al, [esi]
    inc esi
    cmp edx, 2
    jne .loop
    cmp al, '1'
    jne .loop
    or ebx, RF_ERR2OUT
    jmp .loop
.file:
    cmp edx, 2
    je .err
    or ebx, RF_OUT
    WSPTR edx, WS_RDOUT
    call rd_target
    jmp .loop
.err:
    or ebx, RF_ERR
    WSPTR edx, WS_RDERR
    call rd_target
    jmp .loop
.end:
    mov byte [edi], 0
    mov eax, ebx
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; rd_file_open: ESI = raw target, EDX = append flag -> EAX = entry (0 = nul), CF=1 on error
rd_file_open:
    push ebx
    push esi
    push edi
    mov ebx, edx
    mov edi, w_nul
    call stricmp
    je .nul
    WSPTR edi, WS_PATH1
    call fs_norm
    jc .bad
    WSPTR esi, WS_PATH1
    test ebx, ebx
    jz .trunc
    call fs_open_append
    jmp .res
.trunc:
    call fs_create
.res:
    test eax, eax
    jz .bad
    clc
    jmp .x
.nul:
    xor eax, eax
    clc
    jmp .x
.bad:
    stc
.x: pop edi
    pop esi
    pop ebx
    ret

; rd_open: EAX = RF_* flags -> sets out/err/in state; CF=1 on failure (message printed)
rd_open:
    push ebx
    push edx
    push esi
    push edi
    mov ebx, eax
    test ebx, RF_IN
    jz .noin
    WSPTR esi, WS_RDIN
    WSPTR edi, WS_PATH1
    call fs_norm
    jc .nofile
    WSPTR esi, WS_PATH1
    call fs_lookup
    test eax, eax
    jz .nofile
    test dword [eax+FE_FLAGS], FF_DIR
    jnz .nofile
    mov [in_ent], eax
.noin:
    test ebx, RF_OUT
    jz .noout
    WSPTR esi, WS_RDOUT
    xor edx, edx
    test ebx, RF_APPEND
    jz .o1
    inc edx
.o1:
    call rd_file_open
    jc .nopath
    test eax, eax
    jnz .ofile
    mov dword [out_mode], OUT_NUL
    jmp .noout
.ofile:
    mov [out_ent], eax
    mov dword [out_mode], OUT_FILE
.noout:
    test ebx, RF_ERR2OUT
    jz .e1
    mov dword [err_mode], ERR_OUT
.e1:
    test ebx, RF_ERR
    jz .ok
    WSPTR esi, WS_RDERR
    xor edx, edx
    call rd_file_open
    jc .nopath
    test eax, eax
    jnz .efile
    mov dword [err_mode], ERR_NUL
    jmp .ok
.efile:
    mov [err_ent], eax
    mov dword [err_mode], ERR_FILE
.ok:
    clc
    jmp .x
.nofile:
    mov esi, msg_nofile
    call con_puts
    stc
    jmp .x
.nopath:
    mov esi, msg_nopath
    call con_puts
    stc
.x: pop edi
    pop esi
    pop edx
    pop ebx
    ret

; ---- one simple command ------------------------------------------------------------
; exec_simple: ESI = start, EDI = end (exclusive)
exec_simple:
    push ebp
    mov ebp, esp
    sub esp, 48
    push ebx
    push esi
    push edi
    mov ecx, edi
    sub ecx, esi
    cmp ecx, CMD_SIZE-8
    jbe .c1
    mov ecx, CMD_SIZE-8
.c1:
    WSPTR edi, WS_CMD2
    push edi
    rep movsb
    mov byte [edi], 0
    pop esi
    WSPTR edi, WS_CMD
    call rd_parse
    mov [ebp-24], eax
    WSPTR esi, WS_CMD
    cmp byte [delayed], 0
    je .nd
    WSPTR edi, WS_CMD2
    mov ecx, CMD_SIZE-8
    call expand_delayed
    WSPTR esi, WS_CMD2
.nd:
    call skip_sp
    mov [ebp-36], esi
    mov eax, [out_mode]
    mov [ebp-4], eax
    mov eax, [out_ent]
    mov [ebp-8], eax
    mov eax, [err_mode]
    mov [ebp-12], eax
    mov eax, [err_ent]
    mov [ebp-16], eax
    mov eax, [in_ent]
    mov [ebp-20], eax
    mov eax, [ebp-24]
    call rd_open
    jc .fail
    mov esi, [ebp-36]
    call dispatch
    jmp .restore
.fail:
    mov dword [cmd_status], 1
    mov dword [errorlevel], 1
.restore:
    mov eax, [ebp-4]
    mov [out_mode], eax
    mov eax, [ebp-8]
    mov [out_ent], eax
    mov eax, [ebp-12]
    mov [err_mode], eax
    mov eax, [ebp-16]
    mov [err_ent], eax
    mov eax, [ebp-20]
    mov [in_ent], eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

is_name_delim:                          ; AL -> ZF=1 when AL ends a command name
    test al, al
    jz .y
    cmp al, ' '
    je .y
    cmp al, 9
    je .y
    cmp al, '.'
    je .y
    cmp al, '/'
    je .y
    cmp al, '\'
    je .y
    cmp al, '('
    je .y
    cmp al, ':'
    je .y
    cmp al, ','
    je .y
    cmp al, ';'
    je .y
    cmp al, '='
    je .y
    cmp al, '+'
    je .y
    cmp al, '['
    je .y
    cmp al, ']'
    je .y
    cmp al, '"'
    je .y
    cmp al, 13
    je .y
    cmp al, 10
    je .y
    cmp al, 1                           ; ZF=0
    ret
.y: xor eax, eax                        ; ZF=1 (AL becomes 0, caller does not need it)
    ret

; dispatch: ESI = command text -> runs it, sets cmd_status / errorlevel
dispatch:
    push ebx
    push edi
    push ebp
    mov dword [cmd_status], 0
    cmp byte [esi], 0
    je .done
    xor ecx, ecx
.n: mov al, [esi+ecx]
    call is_name_delim
    je .nd
    inc ecx
    jmp .n
.nd:
    test ecx, ecx
    jz .external
    mov ebx, cmd_table
.l: mov edi, [ebx]
    test edi, edi
    jz .external
    call name_eq
    je .hit
    add ebx, 12
    jmp .l
.hit:
    push dword [ebx+8]
    add esi, ecx
    call [ebx+4]
    pop ebp
    mov eax, [cmd_status]
    test ebp, 1
    jz .set
    test eax, eax
    jz .done
.set:
    mov [errorlevel], eax
    jmp .done
.external:
    mov eax, 1                          ; running a .bat by name does not return (like cmd.exe)
    call run_external
.done:
    pop ebp
    pop edi
    pop ebx
    ret

; find_script: ESI = path -> EAX = file entry (tries as given, .bat, .cmd) or 0
find_script:
    push ebx
    push edi
    push esi
    mov ebx, esi
    call fs_resolve
    test eax, eax
    jz .ext
    test dword [eax+FE_FLAGS], FF_DIR
    jz .ok
.ext:
    WSPTR edi, WS_PATH2
    mov esi, ebx
    call strcpy
    mov edi, eax
    mov esi, ext_bat
    call strcpy
    WSPTR esi, WS_PATH2
    call fs_resolve
    test eax, eax
    jz .cmd
    test dword [eax+FE_FLAGS], FF_DIR
    jz .ok
.cmd:
    WSPTR edi, WS_PATH2
    mov esi, ebx
    call strcpy
    mov edi, eax
    mov esi, ext_cmd
    call strcpy
    WSPTR esi, WS_PATH2
    call fs_resolve
    test eax, eax
    jz .no
    test dword [eax+FE_FLAGS], FF_DIR
    jz .ok
.no:
    xor eax, eax
.ok:
    pop esi
    pop edi
    pop ebx
    ret

; run_external: ESI = command text, EAX = 1 to end the calling script afterwards
run_external:
    push ebx
    push ecx
    push edx
    push edi
    push ebp
    mov ebp, eax
    WSPTR edi, WS_PATH1
    xor ecx, ecx
    mov ebx, 100
.t: mov al, [esi]
    test al, al
    jz .te
    test ecx, ecx
    jnz .q
    cmp al, ' '
    je .te
    cmp al, 9
    je .te
    cmp al, '"'
    jne .cp
    mov ecx, 1
    inc esi
    jmp .t
.q: cmp al, '"'
    jne .cp
    xor ecx, ecx
    inc esi
    jmp .t
.cp:
    test ebx, ebx
    jz .sk
    mov [edi], al
    inc edi
    dec ebx
.sk:
    inc esi
    jmp .t
.te:
    mov byte [edi], 0
    push esi
    WSPTR esi, WS_PATH1
    call find_script
    pop edx
    test eax, eax
    jz .nf
    mov esi, edx
    call skip_sp
    mov edx, esi
    mov esi, eax
    call run_script
    test ebp, ebp
    jz .done
    cmp byte [pending], 0
    jne .done
    mov byte [pending], P_EXITB
    jmp .done
.nf:
    mov esi, msg_notrec1
    call err_puts
    WSPTR esi, WS_PATH1
    call err_puts
    mov esi, msg_notrec2
    call err_puts
    mov dword [cmd_status], 9009
.done:
    pop ebp
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret
