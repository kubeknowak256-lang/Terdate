; ============================================================================
;  interp.asm - batch interpreter core
;
;  A "frame" is one running script (or one CALL :label level).  run_frame
;  reads logical lines (several physical lines when a ( block spans lines),
;  expands %variables% for the whole block at once (like cmd.exe) and then
;  executes the text with exec_seq / exec_cmd / exec_if / exec_for.
;  goto / exit never unwind the stack directly: they set [pending] and every
;  loop checks it.
; ============================================================================
section .bss
cur_frame:   resd 1
frame_count: resd 1
errorlevel:  resd 1
cmd_status:  resd 1
proc_depth:  resd 1
out_mode:    resd 1
out_ent:     resd 1
err_mode:    resd 1
err_ent:     resd 1
in_ent:      resd 1
pending:     resb 1
echo_on:     resb 1
delayed:     resb 1
             resb 1
pend_label:  resb 64
section .data
w_rem:       db 'rem', 0
w_if:        db 'if', 0
w_for:       db 'for', 0
w_do:        db 'do', 0
w_in:        db 'in', 0
w_else:      db 'else', 0
w_not:       db 'not', 0
w_errorlevel: db 'errorlevel', 0
w_defined:   db 'defined', 0
w_exist:     db 'exist', 0
w_equ:       db 'EQU', 0
w_neq:       db 'NEQ', 0
w_lss:       db 'LSS', 0
w_leq:       db 'LEQ', 0
w_gtr:       db 'GTR', 0
w_geq:       db 'GEQ', 0
msg_syntax:  db 'The syntax of the command is incorrect.', 13, 10, 0
msg_nopipe:  db 'Pipes (|) are not supported in this version.', 13, 10, 0
msg_nolabel: db 'The system cannot find the batch label specified - ', 0
section .text

%macro WSPTR 2                          ; reg, offset -> reg = workspace pointer + offset
    mov %1, [cur_frame]
    mov %1, [%1+FR_WS]
    add %1, %2
%endmacro

; ---- frames -------------------------------------------------------------------
frame_new:                              ; -> EAX = new zeroed frame or 0
    push ebx
    push ecx
    push edx
    push edi
    mov ebx, [frame_count]
    cmp ebx, MAX_FRAMES
    jae .fail
    inc dword [frame_count]
    imul edi, ebx, FRAME_SZ
    add edi, FRAME_TAB
    mov edx, edi
    xor eax, eax
    mov ecx, FRAME_SZ/4
    rep stosd
    imul eax, ebx, WS_SIZE
    add eax, FRAME_WS_BASE
    mov [edx+FR_WS], eax
    add eax, WS_SCR
    mov [edx+FR_SCRP], eax
    lea edi, [edx+FR_ARGV]
    mov ecx, 10
    mov eax, empty_str
    rep stosd
    mov [edx+FR_ARGALL], eax
    mov [edx+FR_PATH], eax
    mov eax, edx
    jmp .x
.fail:
    xor eax, eax
.x: pop edi
    pop edx
    pop ecx
    pop ebx
    ret

frame_free:
    dec dword [frame_count]
    ret

; frame_setargs: EAX = frame, ESI = argument text, EDX = %0 text, EDI = script path
frame_setargs:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    mov ebx, eax
    mov ebp, edi
    push esi
    push edx
    mov edi, ebx
    sub edi, FRAME_TAB
    shl edi, 3
    add edi, FRAME_ARGS
    mov edx, edi                        ; EDX = argument area
    pop esi
    mov ecx, 63
    mov [ebx+FR_ARGV], edi
    call strncpy_z
    lea edi, [edx+ARG_PATHOFS]
    mov [ebx+FR_PATH], edi
    mov esi, ebp
    mov ecx, 63
    call strncpy_z
    lea edi, [edx+ARG_ALLOFS]
    mov [ebx+FR_ARGALL], edi
    pop esi
    mov ecx, 415
    call strncpy_z
    lea esi, [edx+ARG_ALLOFS]
    lea edi, [edx+ARG_TOKOFS]
    lea ebp, [edx+ARG_SIZE-2]
    mov ecx, 1
.tk:
    mov al, [esi]
    test al, al
    jz .done
    cmp al, ' '
    je .sk
    cmp al, 9
    je .sk
    cmp al, ','
    je .sk
    cmp al, ';'
    je .sk
    cmp al, '='
    je .sk
    cmp ecx, 10
    jae .done
    mov [ebx+FR_ARGV+ecx*4], edi
    xor edx, edx
.cp:
    mov al, [esi]
    test al, al
    jz .te
    test edx, edx
    jnz .inq
    cmp al, ' '
    je .te
    cmp al, 9
    je .te
    cmp al, ','
    je .te
    cmp al, ';'
    je .te
    cmp al, '='
    je .te
    cmp al, '"'
    jne .put
    mov edx, 1
    jmp .put
.inq:
    cmp al, '"'
    jne .put
    xor edx, edx
.put:
    cmp edi, ebp
    jae .skp
    mov [edi], al
    inc edi
.skp:
    inc esi
    jmp .cp
.te:
    mov byte [edi], 0
    inc edi
    inc ecx
    jmp .tk
.sk:
    inc esi
    jmp .tk
.done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; ---- reading script lines ------------------------------------------------------
; read_phys_line: EDI = dest, ECX = capacity -> CF=1 at EOF, else EDI = end (NUL written)
read_phys_line:
    push ebx
    push esi
    mov ebx, [cur_frame]
    mov esi, [ebx+FR_PC]
    cmp esi, [ebx+FR_END]
    jae .eof
.l: cmp esi, [ebx+FR_END]
    jae .done
    mov al, [esi]
    inc esi
    cmp al, 10
    je .done
    cmp al, 13
    je .l
    test ecx, ecx
    jz .l
    mov [edi], al
    inc edi
    dec ecx
    jmp .l
.done:
    mov byte [edi], 0
    mov [ebx+FR_PC], esi
    clc
    jmp .x
.eof:
    stc
.x: pop esi
    pop ebx
    ret

; match_word: ESI text, EDI keyword -> ZF=1 when text starts with the keyword
; (ignoring case) and the next character is a delimiter
match_word:
    push esi
    push edi
.l: mov al, [edi]
    test al, al
    jz .end
    call to_upper
    mov ah, al
    mov al, [esi]
    call to_upper
    cmp al, ah
    jne .x
    inc esi
    inc edi
    jmp .l
.end:
    mov al, [esi]
    test al, al
    jz .yes
    cmp al, ' '
    je .yes
    cmp al, 9
    je .yes
    cmp al, '/'
    je .yes
    cmp al, '('
    je .yes
    cmp al, ')'
    je .yes
    cmp al, '&'
    je .yes
    cmp al, '|'
    je .yes
    cmp al, '<'
    je .yes
    cmp al, '>'
    je .yes
    cmp al, ','
    je .yes
    cmp al, ';'
    je .yes
    cmp al, '='
    je .yes
    cmp al, '.'
    je .yes
    cmp al, '"'
    je .yes
    cmp al, 10
    je .yes
    test al, al                         ; not a delimiter: ZF=0
    jmp .x
.yes:
    xor eax, eax                        ; ZF=1
.x: pop edi
    pop esi
    ret

; paren_scan: ESI = physical line, EDX = depth at start -> EAX = depth at end.
; A '(' only opens a block at the start of a command or after if/for/do/else.
paren_scan:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov ecx, 2                          ; bit0 quote, bit1 command start, bit2 keyword seen
.l: mov al, [esi]
    test al, al
    jz .end
    test ecx, 1
    jz .nq
    cmp al, '"'
    jne .adv
    and ecx, ~1
    jmp .adv
.nq:
    cmp al, '"'
    jne .n1
    or ecx, 1
    and ecx, ~2
    jmp .adv
.n1:
    cmp al, '^'
    jne .n2
    inc esi
    cmp byte [esi], 0
    je .end
    and ecx, ~2
    jmp .adv
.n2:
    cmp al, '('
    jne .n3
    test ecx, 6
    jz .adv
    inc edx
    mov ecx, 2
    jmp .adv
.n3:
    cmp al, ')'
    jne .n4
    test edx, edx
    jz .adv
    dec edx
    and ecx, ~2
    jmp .adv
.n4:
    cmp al, '&'
    je .sep
    cmp al, '|'
    je .sep
    cmp al, ' '
    je .adv
    cmp al, 9
    je .adv
    test ecx, 2
    jz .notfirst
    mov edi, w_rem
    call match_word
    je .end
    mov edi, w_if
    call match_word
    je .kw
    mov edi, w_for
    call match_word
    je .kw
    jmp .skipword
.notfirst:
    mov edi, w_do
    call match_word
    je .kw
    mov edi, w_else
    call match_word
    je .kw
    jmp .skipword
.kw:
    or ecx, 4
.skipword:
    and ecx, ~2
.sw:
    inc esi
    mov al, [esi]
    test al, al
    jz .end
    cmp al, ' '
    je .l
    cmp al, 9
    je .l
    cmp al, '('
    je .l
    cmp al, ')'
    je .l
    cmp al, '&'
    je .l
    cmp al, '|'
    je .l
    cmp al, '"'
    je .l
    cmp al, '^'
    je .l
    jmp .sw
.sep:
    mov ecx, 2
.adv:
    inc esi
    jmp .l
.end:
    mov eax, edx
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; read_logical: next logical line of the current frame -> WS_CMD; CF=1 at end of script
read_logical:
    push ebx
    push esi
    push edi
    push ebp
    WSPTR ebp, WS_CMD
.first:
    mov edi, ebp
    mov ecx, CMD_SIZE-8
    call read_phys_line
    jc .eof
    mov esi, ebp
    call skip_sp
    mov al, [esi]
    test al, al
    jz .first
    cmp al, ':'
    je .first
    mov edi, w_rem
    call match_word
    je .first
    mov esi, ebp
    xor edx, edx
    call paren_scan
    mov edx, eax
.more:
    test edx, edx
    jz .done
    mov esi, ebp
    call strlen
    lea edi, [ebp+eax]
    mov ecx, CMD_SIZE-10
    sub ecx, eax
    jbe .done
    mov byte [edi], 10
    inc edi
    mov byte [edi], 0
    mov esi, edi
    push esi
    call read_phys_line
    pop esi
    jc .done
    call paren_scan
    mov edx, eax
    jmp .more
.done:
    clc
    jmp .x
.eof:
    stc
.x: pop ebp
    pop edi
    pop esi
    pop ebx
    ret

; find_label: ESI = label name -> CF=0 and EAX = start of the line after the label
find_label:
    push ebx
    push ecx
    push edx
    push edi
    push ebp
    mov ebx, [cur_frame]
    mov edi, esi
    mov ebp, [ebx+FR_SCRIPT]
.line:
    cmp ebp, [ebx+FR_END]
    jae .nf
    mov esi, ebp
.ws:
    mov al, [esi]
    cmp al, ' '
    je .w
    cmp al, 9
    jne .chk
.w: inc esi
    jmp .ws
.chk:
    cmp al, ':'
    jne .next
    inc esi
    xor ecx, ecx
.tk:
    lea edx, [esi+ecx]
    cmp edx, [ebx+FR_END]
    jae .te
    mov al, [esi+ecx]
    test al, al
    jz .te
    cmp al, ' '
    je .te
    cmp al, 9
    je .te
    cmp al, 13
    je .te
    cmp al, 10
    je .te
    inc ecx
    jmp .tk
.te:
    test ecx, ecx
    jz .next
    call name_eq
    jne .next
.skipline:
    cmp ebp, [ebx+FR_END]
    jae .found
    mov al, [ebp]
    inc ebp
    cmp al, 10
    jne .skipline
.found:
    mov eax, ebp
    clc
    jmp .x
.next:
    cmp ebp, [ebx+FR_END]
    jae .nf
    mov al, [ebp]
    inc ebp
    cmp al, 10
    jne .next
    jmp .line
.nf:
    stc
.x: pop ebp
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

; ---- running a frame -------------------------------------------------------------
; run_frame: EAX = prepared frame; runs it to completion.  Only P_EXITP survives.
run_frame:
    push ebx
    push esi
    push edi
    push ebp
    mov ebx, eax
    mov eax, [cur_frame]
    mov [ebx+FR_PARENT], eax
    mov [cur_frame], ebx
    mov eax, [sl_depth]
    mov [ebx+FR_SLD], eax
.next:
    call read_logical
    jc .done
    WSPTR esi, WS_CMD
    WSPTR edi, WS_STMT
    mov ecx, STMT_SIZE
    call expand_pct
    WSPTR esi, WS_STMT
    mov edx, 1
    xor ecx, ecx
    call exec_seq
    mov al, [pending]
    test al, al
    jz .next
    cmp al, P_GOTO
    jne .p2
    mov byte [pending], 0
    mov esi, pend_label
    call find_label
    jc .nolabel
    mov [ebx+FR_PC], eax
    jmp .next
.nolabel:
    mov esi, msg_nolabel
    call err_puts
    mov esi, pend_label
    call err_puts
    call err_crlf
    mov dword [errorlevel], 1
    jmp .done
.p2:
    cmp al, P_EXITB
    jne .done
    mov byte [pending], 0
.done:
.sl:
    mov eax, [sl_depth]
    cmp eax, [ebx+FR_SLD]
    jbe .sd
    call do_endlocal
    jmp .sl
.sd:
    mov eax, [ebx+FR_PARENT]
    mov [cur_frame], eax
    pop ebp
    pop edi
    pop esi
    pop ebx
    ret

; run_script: ESI = file entry, EDX = argument text -> runs the script as a new frame
run_script:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    mov ebp, esi
    mov ebx, edx
    call frame_new
    test eax, eax
    jz .x
    mov ecx, [ebp+FE_DATA]
    mov [eax+FR_SCRIPT], ecx
    mov [eax+FR_PC], ecx
    add ecx, [ebp+FE_LEN]
    mov [eax+FR_END], ecx
    push eax
    mov esi, ebx
    lea edi, [ebp+FE_PATH]
    mov edx, edi
    call frame_setargs
    pop eax
    call run_frame
    call frame_free
.x: pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---- statement execution ---------------------------------------------------------
; scan_simple_end: ESI = start, ECX = in_block -> EDI = end of the simple command
scan_simple_end:
    push esi
    push edx
    xor edx, edx
.l: mov al, [esi]
    test al, al
    jz .end
    cmp al, 10
    je .end
    test edx, edx
    jnz .inq
    cmp al, '"'
    je .toq
    cmp al, '^'
    je .esc
    cmp al, '&'
    je .end
    cmp al, '|'
    je .end
    cmp al, ')'
    jne .nx
    test ecx, ecx
    jnz .end
.nx:
    inc esi
    jmp .l
.esc:
    inc esi
    cmp byte [esi], 0
    je .end
    inc esi
    jmp .l
.toq:
    mov edx, 1
    inc esi
    jmp .l
.inq:
    cmp al, '"'
    jne .nx
    xor edx, edx
    jmp .nx
.end:
    mov edi, esi
    pop edx
    pop esi
    ret

print_prompt:
    push eax
    push esi
    mov al, 'C'
    call con_putc
    mov al, ':'
    call con_putc
    mov esi, cwd
    call con_puts
    mov al, '>'
    call con_putc
    pop esi
    pop eax
    ret

echo_cmdline:                           ; ESI = start, EDI = end
    push eax
    push esi
    push edi
.t: cmp edi, esi
    jbe .p
    cmp byte [edi-1], ' '
    je .t1
    cmp byte [edi-1], 9
    jne .p
.t1:
    dec edi
    jmp .t
.p: call print_prompt
.c: cmp esi, edi
    jae .e
    mov al, [esi]
    inc esi
    cmp al, 10
    jne .pc
    mov al, 13
    call con_putc
    mov al, 10
.pc:
    call con_putc
    jmp .c
.e: mov al, 13
    call con_putc
    mov al, 10
    call con_putc
    pop edi
    pop esi
    pop eax
    ret

; exec_seq: ESI = text, EDX = do_exec, ECX = in_block
;  executes commands joined by & && || and newlines -> ESI at the terminator
exec_seq:
    push ebp
    mov ebp, esp
    sub esp, 24
    push ebx
    push edi
    mov [ebp-4], edx
    mov [ebp-8], ecx
    mov dword [ebp-12], 1               ; allowed by && / ||
    mov dword [ebp-16], 1               ; last command succeeded
.next:
    mov al, [esi]
    cmp al, ' '
    je .sk
    cmp al, 9
    je .sk
    cmp al, 10
    je .sk
    jmp .go
.sk:
    inc esi
    jmp .next
.go:
    test al, al
    jz .out
    cmp al, ')'
    jne .cmd
    cmp dword [ebp-8], 0
    jne .out
.cmd:
    mov edx, [ebp-4]
    and edx, [ebp-12]
    mov [ebp-20], edx
    test edx, edx
    jz .noecho
    cmp dword [ebp-8], 0
    jne .noecho
    cmp byte [echo_on], 0
    je .noecho
    cmp byte [esi], '@'
    je .noecho
    push esi
    xor edx, edx
    xor ecx, ecx
    call exec_cmd
    mov edi, esi
    pop esi
    call echo_cmdline
.noecho:
    mov edx, [ebp-20]
    mov ecx, [ebp-8]
    call exec_cmd
    cmp byte [pending], 0
    jne .out
    cmp dword [ebp-20], 0
    je .nostat
    xor eax, eax
    cmp dword [cmd_status], 0
    sete al
    mov [ebp-16], eax
.nostat:
    mov dword [ebp-12], 1
.sp:
    mov al, [esi]
    cmp al, ' '
    je .sp1
    cmp al, 9
    jne .sep
.sp1:
    inc esi
    jmp .sp
.sep:
    cmp al, '&'
    jne .nb
    cmp byte [esi+1], '&'
    jne .one
    add esi, 2
    mov eax, [ebp-16]
    mov [ebp-12], eax
    jmp .next
.one:
    inc esi
    jmp .next
.nb:
    cmp al, '|'
    jne .next
    cmp byte [esi+1], '|'
    jne .pipe
    add esi, 2
    mov eax, [ebp-16]
    xor eax, 1
    mov [ebp-12], eax
    jmp .next
.pipe:
    push esi
    mov esi, msg_nopipe
    call err_puts
    pop esi
    mov dword [errorlevel], 1
    mov dword [cmd_status], 1
.fe:
    cmp byte [esi], 0
    je .out
    inc esi
    jmp .fe
.out:
    pop edi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; exec_cmd: ESI = text, EDX = do_exec, ECX = in_block -> ESI after the command
exec_cmd:
    push ebp
    mov ebp, esp
    sub esp, 8
    push edi
    mov [ebp-4], edx
    mov [ebp-8], ecx
.again:
    call skip_sp
    cmp byte [esi], '@'
    jne .nat
    inc esi
    jmp .again
.nat:
    mov al, [esi]
    cmp al, '('
    je .block
    cmp al, ':'
    je .rest
    mov edi, w_if
    call match_word
    je .if
    mov edi, w_for
    call match_word
    je .for
    mov edi, w_rem
    call match_word
    je .rest
    jmp .simple
.rest:
    cmp byte [esi], 0
    je .done
    cmp byte [esi], 10
    je .done
    inc esi
    jmp .rest
.block:
    inc esi
    mov edx, [ebp-4]
    mov ecx, 1
    call exec_seq
    cmp byte [esi], ')'
    jne .done
    inc esi
    jmp .done
.if:
    add esi, 2
    mov edx, [ebp-4]
    mov ecx, [ebp-8]
    call exec_if
    jmp .done
.for:
    add esi, 3
    mov edx, [ebp-4]
    mov ecx, [ebp-8]
    call exec_for
    jmp .done
.simple:
    mov ecx, [ebp-8]
    call scan_simple_end
    cmp dword [ebp-4], 0
    je .skip
    push esi
    call exec_simple
    pop esi
.skip:
    mov esi, edi
.done:
    pop edi
    mov esp, ebp
    pop ebp
    ret

; if_token: ESI = source, EDI = dest, EDX = 1 to stop at "==" -> ESI advanced
if_token:
    push edi
    push ebx
    push ecx
    xor ebx, ebx
    mov ecx, 1000
.l: mov al, [esi]
    test al, al
    jz .e
    cmp al, 10
    je .e
    test ebx, ebx
    jnz .q
    cmp al, ' '
    je .e
    cmp al, 9
    je .e
    test edx, edx
    jz .nq
    cmp al, '='
    jne .nq
    cmp byte [esi+1], '='
    je .e
.nq:
    cmp al, '"'
    jne .cp
    mov ebx, 1
    jmp .cp
.q: cmp al, '"'
    jne .cp
    xor ebx, ebx
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

strip_quotes:                           ; ESI -> EDI without '"' characters
    push esi
    push edi
.l: mov al, [esi]
    inc esi
    cmp al, '"'
    je .l
    mov [edi], al
    inc edi
    test al, al
    jnz .l
    pop edi
    pop esi
    ret

str_num:                                ; ESI -> CF=0, EAX when the whole string is a number
    push esi
    call parse_sint
    jc .no
    cmp byte [esi], 0
    jne .no
    pop esi
    clc
    ret
.no:
    pop esi
    stc
    ret

; if_compare: EBX = operator (0 '==', 1 EQU .. 6 GEQ), EDX = ignore case -> EAX = 0/1
if_compare:
    push esi
    push edi
    push ebp
    push ecx
    mov ebp, edx
    WSPTR esi, WS_TMP1
    WSPTR edi, WS_TMP2
    test ebx, ebx
    jnz .rel
    test ebp, ebp
    jz .cs
    call stricmp
    jmp .eqr
.cs:
    call strcmp
.eqr:
    mov eax, 0
    jne .r
    inc eax
    jmp .r
.rel:
    call str_num
    jc .str
    mov ecx, eax
    push esi
    mov esi, edi
    call str_num
    pop esi
    jc .str
    cmp ecx, eax
    mov eax, 0
    je .have
    jl .neg
    mov eax, 1
    jmp .have
.str:
    call fs_cmpci
    mov eax, 0
    je .have
    jb .neg
    mov eax, 1
    jmp .have
.neg:
    mov eax, -1
.have:
    xor ecx, ecx
    cmp ebx, 1
    je .equ
    cmp ebx, 2
    je .neq
    cmp ebx, 3
    je .lss
    cmp ebx, 4
    je .leq
    cmp ebx, 5
    je .gtr
    test eax, eax
    setge cl
    jmp .fin
.equ:
    test eax, eax
    sete cl
    jmp .fin
.neq:
    test eax, eax
    setne cl
    jmp .fin
.lss:
    test eax, eax
    setl cl
    jmp .fin
.leq:
    test eax, eax
    setle cl
    jmp .fin
.gtr:
    test eax, eax
    setg cl
.fin:
    movzx eax, cl
.r: pop ecx
    pop ebp
    pop edi
    pop esi
    ret

; exec_if: ESI = text after "if", EDX = do_exec, ECX = in_block -> ESI after the command
exec_if:
    push ebp
    mov ebp, esp
    sub esp, 24
    push ebx
    push edi
    mov [ebp-4], edx
    mov [ebp-8], ecx
    mov dword [ebp-12], 0               ; /i
    mov dword [ebp-16], 0               ; not
.opts:
    call skip_sp
    cmp byte [esi], '/'
    jne .nsl
    mov al, [esi+1]
    or al, 0x20
    cmp al, 'i'
    jne .nsl
    mov dword [ebp-12], 1
    add esi, 2
    jmp .opts
.nsl:
    mov edi, w_not
    call match_word
    jne .cond
    add esi, 3
    xor dword [ebp-16], 1
    jmp .opts
.cond:
    mov edi, w_errorlevel
    call match_word
    je .errlvl
    mov edi, w_defined
    call match_word
    je .defined
    mov edi, w_exist
    call match_word
    je .exist
    WSPTR edi, WS_TMP1
    mov edx, 1
    call if_token
    call skip_sp
    xor ebx, ebx
    cmp word [esi], '=='
    jne .w1
    add esi, 2
    jmp .op2
.w1:
    inc ebx
    mov edi, w_equ
    call match_word
    je .opw
    inc ebx
    mov edi, w_neq
    call match_word
    je .opw
    inc ebx
    mov edi, w_lss
    call match_word
    je .opw
    inc ebx
    mov edi, w_leq
    call match_word
    je .opw
    inc ebx
    mov edi, w_gtr
    call match_word
    je .opw
    inc ebx
    mov edi, w_geq
    call match_word
    je .opw
    jmp .syntax
.opw:
    add esi, 3
.op2:
    call skip_sp
    WSPTR edi, WS_TMP2
    xor edx, edx
    call if_token
    mov edx, [ebp-12]
    call if_compare
    jmp .have
.errlvl:
    add esi, 10
    call skip_sp
    call parse_sint
    jc .syntax
    xor ecx, ecx
    cmp [errorlevel], eax
    setge cl
    mov eax, ecx
    jmp .have
.defined:
    add esi, 7
    call skip_sp
    mov ebx, esi
    xor ecx, ecx
.dl:
    mov al, [esi+ecx]
    test al, al
    jz .de
    cmp al, ' '
    je .de
    cmp al, 9
    je .de
    cmp al, 10
    je .de
    inc ecx
    jmp .dl
.de:
    add esi, ecx
    push esi
    mov esi, ebx
    call env_get
    pop esi
    xor ecx, ecx
    test eax, eax
    setnz cl
    mov eax, ecx
    jmp .have
.exist:
    add esi, 5
    call skip_sp
    WSPTR edi, WS_TMP1
    xor edx, edx
    call if_token
    push esi
    WSPTR esi, WS_TMP1
    WSPTR edi, WS_TMP2
    call strip_quotes
    WSPTR esi, WS_TMP2
    call fs_resolve
    pop esi
    xor ecx, ecx
    test eax, eax
    setnz cl
    mov eax, ecx
.have:
    xor eax, [ebp-16]
    mov [ebp-20], eax
    call skip_sp
    mov edx, [ebp-4]
    test eax, eax
    jnz .t1
    xor edx, edx
.t1:
    mov ecx, [ebp-8]
    call exec_cmd
    cmp byte [pending], 0
    jne .out
    call skip_sp
    mov edi, w_else
    call match_word
    jne .out
    add esi, 4
    mov edx, [ebp-4]
    cmp dword [ebp-20], 0
    je .e1
    xor edx, edx
.e1:
    mov ecx, [ebp-8]
    call exec_cmd
    jmp .out
.syntax:
    push esi
    mov esi, msg_syntax
    call err_puts
    pop esi
    mov dword [errorlevel], 1
    mov dword [cmd_status], 1
    mov ecx, [ebp-8]
    call scan_simple_end
    mov esi, edi
.out:
    pop edi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; skip_sep: ESI past spaces, tabs, commas and semicolons
skip_sep:
.l: mov al, [esi]
    cmp al, ' '
    je .n
    cmp al, 9
    je .n
    cmp al, ','
    je .n
    cmp al, ';'
    jne .d
.n: inc esi
    jmp .l
.d: ret

; exec_for: ESI = text after "for", EDX = do_exec, ECX = in_block
;   for %v in (a b c) do cmd        for /l %v in (start,step,end) do cmd
exec_for:
    push ebp
    mov ebp, esp
    sub esp, 64
    push ebx
    push edi
    mov [ebp-4], edx
    mov [ebp-8], ecx
    mov dword [ebp-32], 0
    call skip_sp
    cmp byte [esi], '/'
    jne .var
    mov al, [esi+1]
    or al, 0x20
    cmp al, 'l'
    jne .syntax
    mov dword [ebp-32], 1
    add esi, 2
    call skip_sp
.var:
    cmp byte [esi], '%'
    jne .syntax
    mov al, [esi+1]
    test al, al
    jz .syntax
    mov [ebp-12], al
    add esi, 2
    call skip_sp
    mov edi, w_in
    call match_word
    jne .syntax
    add esi, 2
    call skip_sp
    cmp byte [esi], '('
    jne .syntax
    inc esi
    mov [ebp-16], esi
    xor ecx, ecx
.fl:
    mov al, [esi]
    test al, al
    jz .syntax
    test ecx, ecx
    jnz .fq
    cmp al, '"'
    jne .f2
    mov ecx, 1
    jmp .fn
.f2:
    cmp al, ')'
    je .fd
    jmp .fn
.fq:
    cmp al, '"'
    jne .fn
    xor ecx, ecx
.fn:
    inc esi
    jmp .fl
.fd:
    mov [ebp-20], esi
    inc esi
    call skip_sp
    mov edi, w_do
    call match_word
    jne .syntax
    add esi, 2
    call skip_sp
    mov [ebp-24], esi
    xor edx, edx
    mov ecx, [ebp-8]
    call exec_cmd
    mov [ebp-28], esi
    cmp dword [ebp-4], 0
    je .out
    mov ebx, [cur_frame]
    mov eax, [ebx+FR_SCRP]
    mov [ebp-36], eax
    mov edx, [ebx+FR_WS]
    add edx, WS_SCR + SCR_AREA
    sub edx, eax
    shr edx, 1
    cmp edx, 128
    jb .syntax
    mov [ebp-40], edx
    add eax, edx
    mov [ebx+FR_SCRP], eax
    cmp dword [ebp-32], 0
    jne .lmode
    mov eax, [ebp-16]
    mov [ebp-44], eax
.il:
    mov esi, [ebp-44]
.is:
    cmp esi, [ebp-20]
    jae .loopdone
    mov al, [esi]
    cmp al, ' '
    je .is1
    cmp al, 9
    je .is1
    cmp al, ','
    je .is1
    cmp al, ';'
    jne .itok
.is1:
    inc esi
    jmp .is
.itok:
    WSPTR edi, WS_MISC
    xor ecx, ecx
.ic:
    cmp esi, [ebp-20]
    jae .ie
    mov al, [esi]
    test ecx, ecx
    jnz .iq
    cmp al, ' '
    je .ie
    cmp al, 9
    je .ie
    cmp al, ','
    je .ie
    cmp al, ';'
    je .ie
    cmp al, '"'
    jne .icp
    mov ecx, 1
    jmp .icp
.iq:
    cmp al, '"'
    jne .icp
    xor ecx, ecx
.icp:
    mov [edi], al
    inc edi
    inc esi
    jmp .ic
.ie:
    mov byte [edi], 0
    mov [ebp-44], esi
    call .run
    cmp byte [pending], 0
    jne .loopdone
    jmp .il
.lmode:
    mov esi, [ebp-16]
    call skip_sep
    call parse_sint
    jc .lbad
    mov [ebp-48], eax
    call skip_sep
    call parse_sint
    jc .lbad
    mov [ebp-52], eax
    call skip_sep
    call parse_sint
    jc .lbad
    mov [ebp-56], eax
.ll:
    mov eax, [ebp-52]
    test eax, eax
    jz .loopdone
    js .lneg
    mov eax, [ebp-48]
    cmp eax, [ebp-56]
    jg .loopdone
    jmp .lgo
.lneg:
    mov eax, [ebp-48]
    cmp eax, [ebp-56]
    jl .loopdone
.lgo:
    WSPTR edi, WS_MISC
    mov eax, [ebp-48]
    call itoa
    call .run
    cmp byte [pending], 0
    jne .loopdone
    mov eax, [ebp-52]
    add [ebp-48], eax
    jmp .ll
.lbad:
.loopdone:
    mov ebx, [cur_frame]
    mov eax, [ebp-36]
    mov [ebx+FR_SCRP], eax
    mov esi, [ebp-28]
    jmp .out

.run:                                   ; run the body once, %v replaced by the text in WS_MISC
    push esi
    push edi
    mov edi, [ebp-36]
    mov esi, [ebp-24]
    mov ecx, [ebp-40]
    dec ecx
    lea edx, [edi+ecx]
.r1:
    cmp esi, [ebp-28]
    jae .r9
    mov al, [esi]
    cmp al, '%'
    jne .r2
    mov ah, [esi+1]
    cmp ah, [ebp-12]
    jne .r2
    add esi, 2
    push esi
    WSPTR esi, WS_MISC
.r3:
    mov al, [esi]
    test al, al
    jz .r4
    cmp edi, edx
    jae .r4
    mov [edi], al
    inc edi
    inc esi
    jmp .r3
.r4:
    pop esi
    jmp .r1
.r2:
    cmp edi, edx
    jae .r5
    mov [edi], al
    inc edi
.r5:
    inc esi
    jmp .r1
.r9:
    mov byte [edi], 0
    mov esi, [ebp-36]
    mov edx, 1
    xor ecx, ecx
    call exec_cmd
    pop edi
    pop esi
    ret

.syntax:
    push esi
    mov esi, msg_syntax
    call err_puts
    pop esi
    mov dword [errorlevel], 1
    mov dword [cmd_status], 1
    mov ecx, [ebp-8]
    call scan_simple_end
    mov esi, edi
.out:
    pop edi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
