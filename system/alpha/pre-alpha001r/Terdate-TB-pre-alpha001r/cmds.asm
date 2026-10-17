; ============================================================================
;  cmds.asm - internal commands.
;  A handler gets ESI = text right after the command name, may print through
;  out_* / err_* and reports its result in [cmd_status].
; ============================================================================
section .bss
ch_hide:    resd 1
ch_timeout: resd 1
ch_cs:      resd 1
ch_start:   resd 1
ch_def:     resb 4
ch_set:     resb 40
ch_msg:     resb 130
tm_secs:    resd 1
tm_nobreak: resd 1
section .data
w_on:       db 'on', 0
w_off:      db 'off', 0
w_eof:      db 'eof', 0
w_enabledelayed:  db 'enabledelayedexpansion', 0
w_disabledelayed: db 'disabledelayedexpansion', 0
msg_echo_on:  db 'ECHO is on.', 13, 10, 0
msg_echo_off: db 'ECHO is off.', 13, 10, 0
msg_pause:    db 'Press any key to continue . . . ', 0
msg_ver:      db 13, 10, 'Terdate TB [Version ', TD_VERSION, ']', 13, 10, 0
msg_nolbl:    db 'No batch label specified to GOTO command.', 13, 10, 0
msg_cantfind: db 'The system cannot find the file ', 0
msg_notdef1:  db 'Environment variable ', 0
msg_notdef2:  db ' not defined', 13, 10, 0
msg_wait1:    db 13, 10, 'Waiting for ', 0
msg_wait2:    db ' seconds, press a key to continue ...', 0
msg_toomany:  db 'Too many nested batch files or processes.', 13, 10, 0
msg_help:
    db 'Terdate TB ', TD_VERSION, ' - internal commands:', 13, 10
    db '  ECHO  SET  GOTO  CALL  EXIT  IF  FOR  REM  SHIFT  SETLOCAL  ENDLOCAL', 13, 10
    db '  START  CLS  PAUSE  CHOICE  TIMEOUT  COLOR  TITLE  VER  VOL  HELP', 13, 10
    db '  TYPE  DEL  DIR  TREE  CD  MD  COPY  REN', 13, 10
    db 'Run a batch file by name:  name.bat args   or   CALL :label args', 13, 10, 0

cmd_table:
    dd n_echo,     cmd_echo,     1
    dd n_set,      cmd_set,      1
    dd n_goto,     cmd_goto,     1
    dd n_call,     cmd_call,     1
    dd n_exit,     cmd_exit,     1
    dd n_cls,      cmd_cls,      1
    dd n_pause,    cmd_pause,    1
    dd n_start,    cmd_start,    1
    dd n_setlocal, cmd_setlocal, 1
    dd n_endlocal, cmd_endlocal, 1
    dd n_shift,    cmd_shift,    1
    dd n_title,    cmd_title,    1
    dd n_color,    cmd_color,    0
    dd n_ver,      cmd_ver,      1
    dd n_choice,   cmd_choice,   0
    dd n_timeout,  cmd_timeout,  0
    dd n_help,     cmd_help,     1
    dd n_rem,      cmd_title,    1
    dd n_type,     cmd_type,     0
    dd n_del,      cmd_del,      0
    dd n_erase,    cmd_del,      0
    dd n_tree,     cmd_tree,     0
    dd n_dir,      cmd_dir,      0
    dd n_cd,       cmd_cd,       0
    dd n_chdir,    cmd_cd,       0
    dd n_md,       cmd_md,       0
    dd n_mkdir,    cmd_md,       0
    dd n_copy,     cmd_copy,     0
    dd n_ren,      cmd_ren,      0
    dd n_rename,   cmd_ren,      0
    dd n_vol,      cmd_vol,      1
    dd 0, 0, 0
n_echo:     db 'echo', 0
n_set:      db 'set', 0
n_goto:     db 'goto', 0
n_call:     db 'call', 0
n_exit:     db 'exit', 0
n_cls:      db 'cls', 0
n_pause:    db 'pause', 0
n_start:    db 'start', 0
n_setlocal: db 'setlocal', 0
n_endlocal: db 'endlocal', 0
n_shift:    db 'shift', 0
n_title:    db 'title', 0
n_color:    db 'color', 0
n_ver:      db 'ver', 0
n_choice:   db 'choice', 0
n_timeout:  db 'timeout', 0
n_help:     db 'help', 0
n_rem:      db 'rem', 0
n_type:     db 'type', 0
n_del:      db 'del', 0
n_erase:    db 'erase', 0
n_tree:     db 'tree', 0
n_dir:      db 'dir', 0
n_cd:       db 'cd', 0
n_chdir:    db 'chdir', 0
n_md:       db 'md', 0
n_mkdir:    db 'mkdir', 0
n_copy:     db 'copy', 0
n_ren:      db 'ren', 0
n_rename:   db 'rename', 0
n_vol:      db 'vol', 0
section .text

; get_token: ESI = text, EDI = destination (>= 200 bytes)
;  -> ESI past the token, token (quotes removed) at EDI, ZF=1 when empty
get_token:
    push ebx
    push ecx
    call skip_sp
    xor ebx, ebx
    xor ecx, ecx
.l: mov al, [esi]
    test al, al
    jz .e
    test ebx, ebx
    jnz .q
    cmp al, ' '
    je .e
    cmp al, 9
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
    cmp ecx, 190
    jae .sk
    mov [edi+ecx], al
    inc ecx
.sk:
    inc esi
    jmp .l
.e: mov byte [edi+ecx], 0
    test ecx, ecx
    pop ecx
    pop ebx
    ret

hexval:                                 ; AL -> AL = 0..15 or 0xFF
    cmp al, '0'
    jb .bad
    cmp al, '9'
    jbe .d
    or al, 0x20
    cmp al, 'a'
    jb .bad
    cmp al, 'f'
    ja .bad
    sub al, 'a' - 10
    ret
.d: sub al, '0'
    ret
.bad:
    mov al, 0xFF
    ret

; ---- ECHO -----------------------------------------------------------------------------
cmd_echo:
    mov al, [esi]
    test al, al
    jz .state
    cmp al, ' '
    jne .after
    inc esi
    push esi
    call skip_sp
    cmp byte [esi], 0
    pop esi
    je .state
    mov edi, w_on
    call word_is
    je .on
    mov edi, w_off
    call word_is
    je .off
    jmp .print
.after:
    inc esi
.print:
    call out_puts
    call out_crlf
    ret
.state:
    mov esi, msg_echo_on
    cmp byte [echo_on], 0
    jne .sp
    mov esi, msg_echo_off
.sp:
    call out_puts
    ret
.on:
    mov byte [echo_on], 1
    ret
.off:
    mov byte [echo_on], 0
    ret

; ---- SET ------------------------------------------------------------------------------
; set_parse: ESI = text -> EBX = name, ECX = name length, EDX = value (0 when there is no '=')
set_parse:
    push edi
    cmp byte [esi], '"'
    jne .plain
    inc esi
    mov edi, esi
    xor eax, eax
.fq:
    mov cl, [edi]
    test cl, cl
    jz .fqd
    cmp cl, '"'
    jne .nq
    mov eax, edi
.nq:
    inc edi
    jmp .fq
.fqd:
    test eax, eax
    jz .plain
    mov byte [eax], 0
.plain:
    mov ebx, esi
    mov edi, esi
.fe:
    mov al, [edi]
    test al, al
    jz .noeq
    cmp al, '='
    je .eq
    inc edi
    jmp .fe
.eq:
    mov ecx, edi
    sub ecx, ebx
    lea edx, [edi+1]
    pop edi
    ret
.noeq:
    mov ecx, edi
    sub ecx, ebx
    xor edx, edx
    pop edi
    ret

cmd_set:
    call skip_sp
    cmp byte [esi], 0
    je .listall
    cmp byte [esi], '/'
    jne .assign
    mov al, [esi+1]
    or al, 0x20
    cmp al, 'a'
    je .arith
    cmp al, 'p'
    je .prompt
.assign:
    call set_parse
    test ecx, ecx
    jz .syntax
    test edx, edx
    jz .show
    mov esi, ebx
    call env_set
    ret
.show:
    push ebx
    push ecx
    mov esi, [env_ptr]
    xor edi, edi
.sl:
    cmp byte [esi], 0
    je .sd
    push esi
    push ecx
    mov edx, ebx
.cmp:
    test ecx, ecx
    jz .match
    mov al, [esi]
    call to_upper
    mov ah, al
    mov al, [edx]
    call to_upper
    cmp al, ah
    jne .nomatch
    inc esi
    inc edx
    dec ecx
    jmp .cmp
.match:
    pop ecx
    pop esi
    call out_puts
    call out_crlf
    inc edi
    jmp .adv
.nomatch:
    pop ecx
    pop esi
.adv:
    call strlen
    lea esi, [esi+eax+1]
    jmp .sl
.sd:
    pop ecx
    pop ebx
    test edi, edi
    jnz .r
    mov esi, msg_notdef1
    call err_puts
    mov esi, ebx
.pn:
    test ecx, ecx
    jz .pd
    mov al, [esi]
    call err_putc
    inc esi
    dec ecx
    jmp .pn
.pd:
    mov esi, msg_notdef2
    call err_puts
    mov dword [cmd_status], 1
.r: ret
.listall:
    mov esi, [env_ptr]
.la:
    cmp byte [esi], 0
    je .r
    call out_puts
    call out_crlf
    call strlen
    lea esi, [esi+eax+1]
    jmp .la
.syntax:
    mov esi, msg_syntax
    call err_puts
    mov dword [cmd_status], 1
    ret
.arith:
    add esi, 2
    WSPTR edi, WS_TMP1
    xor ecx, ecx
.ac:
    mov al, [esi]
    inc esi
    cmp al, '"'
    je .ac
    cmp ecx, 900
    jae .ad
    mov [edi+ecx], al
    inc ecx
.ad:
    test al, al
    jnz .ac
    WSPTR esi, WS_TMP1
    call ex_eval
    jnc .r
    mov dword [cmd_status], 1
    ret
.prompt:
    add esi, 2
    call skip_sp
    call set_parse
    test ecx, ecx
    jz .syntax
    push ebx
    push ecx
    test edx, edx
    jz .np
    mov esi, edx
    call out_puts
.np:
    WSPTR edi, WS_TMP2
    cmp dword [in_ent], 0
    jne .fromfile
    mov ecx, 255
    call kb_readline
    jmp .got
.fromfile:
    mov esi, [in_ent]
    mov ecx, [esi+FE_LEN]
    mov esi, [esi+FE_DATA]
    xor eax, eax
.fl:
    test ecx, ecx
    jz .fd
    mov dl, [esi]
    inc esi
    dec ecx
    cmp dl, 10
    je .fd
    cmp dl, 13
    je .fl
    cmp eax, 255
    jae .fl
    mov [edi+eax], dl
    inc eax
    jmp .fl
.fd:
    mov byte [edi+eax], 0
.got:
    pop ecx
    pop ebx
    test eax, eax
    jz .empty
    WSPTR edx, WS_TMP2
    mov esi, ebx
    call env_set
    ret
.empty:
    mov dword [cmd_status], 1
    ret

; ---- GOTO / CALL / EXIT ---------------------------------------------------------------
cmd_goto:
    call skip_sp
    cmp byte [esi], ':'
    jne .t
    inc esi
.t: mov edi, pend_label
    xor ecx, ecx
.l: mov al, [esi]
    test al, al
    jz .e
    cmp al, ' '
    je .e
    cmp al, 9
    je .e
    cmp ecx, 62
    jae .sk
    mov [edi+ecx], al
    inc ecx
.sk:
    inc esi
    jmp .l
.e: mov byte [edi+ecx], 0
    test ecx, ecx
    jz .nolabel
    cmp ecx, 3
    jne .go
    mov esi, pend_label
    mov edi, w_eof
    call stricmp
    jne .go
    mov byte [pending], P_EXITB
    ret
.go:
    mov byte [pending], P_GOTO
    ret
.nolabel:
    mov esi, msg_nolbl
    call err_puts
    mov dword [cmd_status], 1
    ret

cmd_call:
    call skip_sp
    cmp byte [esi], ':'
    je .label
    xor eax, eax
    jmp run_external
.label:
    inc esi
    WSPTR edi, WS_PATH1
    mov byte [edi], ':'
    inc edi
    xor ecx, ecx
.lt:
    mov al, [esi]
    test al, al
    jz .le
    cmp al, ' '
    je .le
    cmp al, 9
    je .le
    cmp ecx, 60
    jae .lsk
    mov [edi+ecx], al
    inc ecx
.lsk:
    inc esi
    jmp .lt
.le:
    mov byte [edi+ecx], 0
    call skip_sp
    mov ebx, esi
    WSPTR esi, WS_PATH1
    inc esi
    call find_label
    jc .nolabel
    mov ebp, eax
    call frame_new
    test eax, eax
    jz .toomany
    mov edx, [cur_frame]
    mov ecx, [edx+FR_SCRIPT]
    mov [eax+FR_SCRIPT], ecx
    mov ecx, [edx+FR_END]
    mov [eax+FR_END], ecx
    mov [eax+FR_PC], ebp
    push eax
    mov esi, ebx
    WSPTR edx, WS_PATH1
    mov edi, [cur_frame]
    mov edi, [edi+FR_PATH]
    call frame_setargs
    pop eax
    call run_frame
    call frame_free
    ret
.nolabel:
    mov esi, msg_nolabel
    call err_puts
    WSPTR esi, WS_PATH1
    inc esi
    call err_puts
    call err_crlf
    mov dword [cmd_status], 1
    ret
.toomany:
    mov esi, msg_toomany
    call err_puts
    mov dword [cmd_status], 1
    ret

cmd_exit:
    call skip_sp
    mov bl, P_EXITP
    cmp byte [esi], '/'
    jne .num
    mov al, [esi+1]
    or al, 0x20
    cmp al, 'b'
    jne .num
    add esi, 2
    mov bl, P_EXITB
    call skip_sp
.num:
    mov [pending], bl
    mov al, [esi]
    cmp al, '-'
    je .p
    cmp al, '0'
    jb .r
    cmp al, '9'
    ja .r
.p: call parse_sint
    jc .r
    mov [errorlevel], eax
.r: ret

; ---- START: run another script in its own "window" -------------------------------------
cmd_start:
    call skip_sp
    cmp byte [esi], '"'
    jne .sw
    mov edi, esi
    inc edi
.f: mov al, [edi]
    test al, al
    jz .sw
    cmp al, '"'
    je .fe
    inc edi
    jmp .f
.fe:
    inc edi
    push esi
    mov esi, edi
    call skip_sp
    cmp byte [esi], 0
    mov edi, esi
    pop esi
    je .sw                              ; only one quoted word: it is the command
    mov esi, edi                        ; skip the window title
.sw:
    call skip_sp
    cmp byte [esi], '/'
    jne .cmd
    mov al, [esi+1]
    or al, 0x20
    push eax
.sk:
    mov al, [esi]
    test al, al
    jz .skd
    cmp al, ' '
    je .skd
    inc esi
    jmp .sk
.skd:
    pop eax
    cmp al, 'd'
    jne .sw
    WSPTR edi, WS_TMP1
    call get_token
    jmp .sw
.cmd:
    WSPTR edi, WS_PATH1
    call get_token
    jz .none
    call skip_sp
    mov ebx, esi
    WSPTR esi, WS_PATH1
    call find_script
    test eax, eax
    jz .nf
    mov esi, eax
    mov edx, ebx
    mov dword [out_mode], OUT_CON
    mov dword [err_mode], ERR_CON
    mov dword [in_ent], 0
    call proc_run
    ret
.none:
    ret
.nf:
    mov esi, msg_cantfind
    call err_puts
    WSPTR esi, WS_PATH1
    call err_puts
    mov al, '.'
    call err_putc
    call err_crlf
    mov dword [cmd_status], 1
    ret

; ---- SETLOCAL / ENDLOCAL / SHIFT ------------------------------------------------------
cmd_setlocal:
    push esi
    call do_setlocal
    pop esi
.l: call skip_sp
    cmp byte [esi], 0
    je .r
    mov edi, w_enabledelayed
    call match_word
    jne .a
    mov byte [delayed], 1
    add esi, 22
    jmp .l
.a: mov edi, w_disabledelayed
    call match_word
    jne .b
    mov byte [delayed], 0
    add esi, 23
    jmp .l
.b: mov al, [esi]
    test al, al
    jz .r
    cmp al, ' '
    je .l
    inc esi
    jmp .b
.r: ret

cmd_endlocal:
    call do_endlocal
    ret

cmd_shift:
    mov ebx, [cur_frame]
    mov ecx, 1
.l: mov eax, [ebx+FR_ARGV+ecx*4+4]
    mov [ebx+FR_ARGV+ecx*4], eax
    inc ecx
    cmp ecx, 9
    jb .l
    mov dword [ebx+FR_ARGV+9*4], empty_str
    ret

; ---- small commands ----------------------------------------------------------------------
cmd_cls:
    jmp con_cls

cmd_title:
    ret

cmd_pause:
    push esi
    mov esi, msg_pause
    call out_puts
    pop esi
    call kb_getc
    call out_crlf
    ret

cmd_ver:
    mov esi, msg_ver
    call out_puts
    ret

cmd_help:
    mov esi, msg_help
    call out_puts
    ret

cmd_color:
    call skip_sp
    mov al, [esi]
    test al, al
    jz .def
    call hexval
    cmp al, 0xFF
    je .bad
    mov bl, al
    mov al, [esi+1]
    call hexval
    cmp al, 0xFF
    je .one
    shl bl, 4
    or al, bl
    mov bl, al
    jmp .chk
.one:
    mov bl, [esi]
    push ebx
    mov al, bl
    call hexval
    pop ebx
    mov bl, al
.chk:
    mov al, bl
    mov ah, bl
    shr ah, 4
    and al, 15
    cmp al, ah
    je .bad
    mov al, bl
    call con_setattr
    ret
.def:
    mov al, 0x07
    call con_setattr
    ret
.bad:
    mov dword [cmd_status], 1
    ret

; ---- CHOICE [/C chars] [/N] [/CS] [/T secs] [/D char] [/M text] -----------------------------
choice_value:                           ; ESI -> value token in WS_TMP1 (skips ':' and blanks)
    call skip_sp
    cmp byte [esi], ':'
    jne .t
    inc esi
.t: WSPTR edi, WS_TMP1
    call get_token
    ret

cmd_choice:
    mov dword [ch_hide], 0
    mov dword [ch_timeout], -1
    mov dword [ch_cs], 0
    mov byte [ch_def], 0
    mov byte [ch_msg], 0
    mov byte [ch_set], 'Y'
    mov byte [ch_set+1], 'N'
    mov byte [ch_set+2], 0
.p: call skip_sp
    mov al, [esi]
    test al, al
    jz .go
    cmp al, '/'
    jne .skiptok
    mov al, [esi+1]
    or al, 0x20
    add esi, 2
    cmp al, 'n'
    jne .s1
    mov dword [ch_hide], 1
    jmp .p
.s1:
    cmp al, 'c'
    jne .s2
    mov al, [esi]
    or al, 0x20
    cmp al, 's'
    jne .cval
    mov cl, [esi+1]
    test cl, cl
    jz .csf
    cmp cl, ' '
    je .csf
    cmp cl, 9
    jne .cval
.csf:
    mov dword [ch_cs], 1
    inc esi
    jmp .p
.cval:
    call choice_value
    WSPTR edi, WS_TMP1
    mov ecx, 30
    push esi
    mov esi, edi
    mov edi, ch_set
    call strncpy_z
    pop esi
    jmp .p
.s2:
    cmp al, 'd'
    jne .s3
    call choice_value
    WSPTR edi, WS_TMP1
    mov al, [edi]
    mov [ch_def], al
    jmp .p
.s3:
    cmp al, 't'
    jne .s4
    call choice_value
    push esi
    WSPTR esi, WS_TMP1
    call parse_sint
    jc .t0
    mov [ch_timeout], eax
.t0:
    pop esi
    jmp .p
.s4:
    cmp al, 'm'
    jne .p
    call choice_value
    push esi
    WSPTR esi, WS_TMP1
    mov edi, ch_msg
    mov ecx, 120
    call strncpy_z
    pop esi
    jmp .p
.skiptok:
    mov al, [esi]
    test al, al
    jz .go
    cmp al, ' '
    je .p
    inc esi
    jmp .skiptok
.go:
    cmp dword [ch_cs], 0
    jne .nouc
    mov esi, ch_set
.uc:
    mov al, [esi]
    test al, al
    jz .ucd
    call to_upper
    mov [esi], al
    inc esi
    jmp .uc
.ucd:
    mov al, [ch_def]
    call to_upper
    mov [ch_def], al
.nouc:
    cmp byte [ch_msg], 0
    je .nomsg
    mov esi, ch_msg
    call out_puts
.nomsg:
    cmp dword [ch_hide], 0
    jne .wait
    cmp byte [ch_msg], 0
    je .nosp
    mov al, ' '
    call out_putc
.nosp:
    mov al, '['
    call out_putc
    mov esi, ch_set
.pl:
    mov al, [esi]
    test al, al
    jz .ple
    call out_putc
    cmp byte [esi+1], 0
    je .pn
    mov al, ','
    call out_putc
.pn:
    inc esi
    jmp .pl
.ple:
    mov al, ']'
    call out_putc
    mov al, '?'
    call out_putc
.wait:
    mov eax, [ticks]
    mov [ch_start], eax
.w: call kb_poll
    jnc .key
    mov eax, [ch_timeout]
    test eax, eax
    js .idle
    imul edx, eax, 100
    mov eax, [ticks]
    sub eax, [ch_start]
    cmp eax, edx
    jae .timeout
.idle:
    hlt
    jmp .w
.key:
    mov bl, al
    cmp dword [ch_cs], 0
    jne .find
    mov al, bl
    call to_upper
    mov bl, al
.find:
    xor ecx, ecx
.f1:
    mov al, [ch_set+ecx]
    test al, al
    jz .w
    cmp al, bl
    je .found
    inc ecx
    jmp .f1
.timeout:
    xor ecx, ecx
    mov bl, [ch_def]
    test bl, bl
    jz .found
.f2:
    mov al, [ch_set+ecx]
    test al, al
    jz .zero
    cmp al, bl
    je .found
    inc ecx
    jmp .f2
.zero:
    xor ecx, ecx
.found:
    cmp dword [ch_hide], 0
    jne .done
    mov al, [ch_set+ecx]
    call out_putc
    call out_crlf
.done:
    inc ecx
    mov [cmd_status], ecx
    ret

; ---- TIMEOUT /T n [/NOBREAK] ------------------------------------------------------------
cmd_timeout:
    mov dword [tm_secs], 0
    mov dword [tm_nobreak], 0
.p: call skip_sp
    mov al, [esi]
    test al, al
    jz .go
    cmp al, '/'
    jne .num
    mov al, [esi+1]
    or al, 0x20
    add esi, 2
    cmp al, 't'
    jne .nb
    call skip_sp
    call parse_sint
    jc .p
    mov [tm_secs], eax
    jmp .p
.nb:
    cmp al, 'n'
    jne .p
    mov dword [tm_nobreak], 1
.sk:
    mov al, [esi]
    test al, al
    jz .p
    cmp al, ' '
    je .p
    inc esi
    jmp .sk
.num:
    call parse_sint
    jc .go
    mov [tm_secs], eax
    jmp .p
.go:
    mov esi, msg_wait1
    call out_puts
    mov eax, [tm_secs]
    call out_dec
    mov esi, msg_wait2
    call out_puts
    mov eax, [ticks]
    mov [ch_start], eax
.w: cmp dword [tm_nobreak], 0
    jne .nokey
    call kb_poll
    jnc .done
.nokey:
    mov eax, [tm_secs]
    test eax, eax
    js .idle
    imul edx, eax, 100
    mov eax, [ticks]
    sub eax, [ch_start]
    cmp eax, edx
    jae .done
.idle:
    hlt
    jmp .w
.done:
    call out_crlf
    ret
