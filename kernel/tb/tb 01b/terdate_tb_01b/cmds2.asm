; ============================================================================
;  cmds2.asm - file system commands: TYPE DEL TREE DIR CD MD COPY REN VOL
; ============================================================================
section .bss
tr_files:   resd 1
tr_ascii:   resd 1
tr_plen:    resd 1
tr_bar:     resd 1
tr_mid:     resd 1
tr_last:    resd 1
tr_prefix:  resb 160
dir_files:  resd 1
dir_dirs:   resd 1
dir_bytes:  resd 1
section .data
msg_syn2:   db 'The syntax of the command is incorrect.', 13, 10, 0
msg_couldnot: db 'Could Not Find C:', 0
msg_exists1: db 'A subdirectory or file ', 0
msg_exists2: db ' already exists.', 13, 10, 0
msg_copied: db '        1 file(s) copied.', 13, 10, 0
msg_vol1:   db ' Volume in drive C is TERDATE', 13, 10
            db ' Volume Serial Number is 7D14-1026', 13, 10, 0
msg_tree1:  db 'Folder PATH listing for volume TERDATE', 13, 10
            db 'Volume serial number is 7D14-1026', 13, 10, 0
msg_dirof:  db ' Directory of C:', 0
msg_dirtag: db '    <DIR>          ', 0
msg_nofiles: db ' File(s)', 0
msg_nodirs:  db ' Dir(s)', 0
msg_bytes:  db ' bytes', 13, 10, 0
tr_a_bar:   db '|   ', 0
tr_a_mid:   db '+---', 0
tr_a_last:  db '\---', 0
tr_u_bar:   db 0xB3, '   ', 0
tr_u_mid:   db 0xC3, 0xC4, 0xC4, 0xC4, 0
tr_u_last:  db 0xC0, 0xC4, 0xC4, 0xC4, 0
tr_blank:   db '    ', 0
section .text

; ---- TYPE ---------------------------------------------------------------------------------
cmd_type:
    push ebx
    xor ebx, ebx
.next:
    WSPTR edi, WS_TMP1
    call get_token
    jz .done
    push esi
    WSPTR esi, WS_TMP1
    call fs_resolve
    pop esi
    test eax, eax
    jz .nofile
    test dword [eax+FE_FLAGS], FF_DIR
    jnz .denied
    push esi
    mov ecx, [eax+FE_LEN]
    mov esi, [eax+FE_DATA]
    call out_write
    pop esi
    inc ebx
    jmp .next
.nofile:
    mov esi, msg_nofile
    call err_puts
    mov dword [cmd_status], 1
    jmp .x
.denied:
    mov esi, msg_denied
    call err_puts
    mov dword [cmd_status], 1
    jmp .x
.done:
    test ebx, ebx
    jnz .x
    mov esi, msg_syn2
    call err_puts
    mov dword [cmd_status], 1
.x: pop ebx
    ret

; ---- DEL / ERASE --------------------------------------------------------------------------
cmd_del:
    push ebx
    xor ebx, ebx
.next:
    WSPTR edi, WS_TMP1
    call get_token
    jz .done
    WSPTR eax, WS_TMP1
    cmp byte [eax], '/'
    je .next
    inc ebx
    push esi
    WSPTR esi, WS_TMP1
    call fs_resolve
    pop esi
    test eax, eax
    jz .nf
    test dword [eax+FE_FLAGS], FF_DIR
    jnz .denied
    call fs_delete
    jmp .next
.nf:
    push esi
    mov esi, msg_couldnot
    call err_puts
    mov esi, fs_nbuf
    call err_puts
    call err_crlf
    pop esi
    mov dword [cmd_status], 1
    jmp .next
.denied:
    push esi
    mov esi, msg_denied
    call err_puts
    pop esi
    mov dword [cmd_status], 1
    jmp .next
.done:
    test ebx, ebx
    jnz .x
    mov esi, msg_syn2
    call err_puts
    mov dword [cmd_status], 1
.x: pop ebx
    ret

; ---- CD / CHDIR ---------------------------------------------------------------------------
cmd_cd:
    WSPTR edi, WS_TMP1
    call get_token
    jnz .have
    mov al, 'C'
    call out_putc
    mov al, ':'
    call out_putc
    push esi
    mov esi, cwd
    call out_puts
    pop esi
    call out_crlf
    ret
.have:
    WSPTR eax, WS_TMP1
    cmp word [eax], '/d'
    jne .go
    cmp byte [eax+2], 0
    jne .go
    WSPTR edi, WS_TMP1
    call get_token
    jz .r
.go:
    WSPTR esi, WS_TMP1
    call fs_resolve
    test eax, eax
    jz .nopath
    test dword [eax+FE_FLAGS], FF_DIR
    jz .nopath
    mov esi, fs_nbuf
    mov edi, cwd
    call strcpy
.r: ret
.nopath:
    mov esi, msg_nopath
    call err_puts
    mov dword [cmd_status], 1
    ret

; ---- MD / MKDIR ---------------------------------------------------------------------------
cmd_md:
    WSPTR edi, WS_TMP1
    call get_token
    jz .syn
    WSPTR esi, WS_TMP1
    call fs_resolve
    test eax, eax
    jnz .exists
    cmp byte [fs_nbuf], 0
    je .nopath
    mov esi, fs_nbuf
    call fs_mkparents
    mov esi, fs_nbuf
    call fs_ensure_dir
    ret
.exists:
    mov esi, msg_exists1
    call err_puts
    WSPTR esi, WS_TMP1
    call err_puts
    mov esi, msg_exists2
    call err_puts
    mov dword [cmd_status], 1
    ret
.nopath:
    mov esi, msg_nopath
    call err_puts
    mov dword [cmd_status], 1
    ret
.syn:
    mov esi, msg_syn2
    call err_puts
    mov dword [cmd_status], 1
    ret

; ---- COPY src dst -------------------------------------------------------------------------
cmd_copy:
    push ebx
    WSPTR edi, WS_TMP1
    call get_token
    jz .syn
    WSPTR edi, WS_TMP2
    call get_token
    jz .syn
    push esi
    WSPTR esi, WS_TMP1
    call fs_resolve
    pop esi
    test eax, eax
    jz .nofile
    test dword [eax+FE_FLAGS], FF_DIR
    jnz .nofile
    mov ebx, eax                        ; source entry
    WSPTR esi, WS_TMP2
    call fs_resolve
    mov ecx, eax                        ; destination entry (0 = new file)
    cmp byte [fs_nbuf], 0
    je .nopath
    WSPTR edi, WS_PATH1
    mov esi, fs_nbuf
    call strcpy                         ; EAX = end of the copy
    test ecx, ecx
    jz .create
    cmp ecx, ebx
    je .denied
    test dword [ecx+FE_FLAGS], FF_DIR
    jz .create                          ; overwrite an existing file
    mov edi, eax                        ; destination is a directory: append \name
    cmp byte [eax-1], '\'
    je .nosep
    mov byte [edi], '\'
    inc edi
.nosep:
    lea esi, [ebx+FE_PATH]
    mov edx, esi
.ls:
    mov al, [esi]
    test al, al
    jz .lsd
    inc esi
    cmp al, '\'
    jne .ls
    mov edx, esi
    jmp .ls
.lsd:
    mov esi, edx
    call strcpy
.create:
    WSPTR esi, WS_PATH1
    call strlen
    cmp eax, 46
    ja .nopath
    WSPTR esi, WS_PATH1
    call fs_create
    test eax, eax
    jz .nopath
    mov edx, eax
    mov ecx, [ebx+FE_LEN]
    mov esi, [ebx+FE_DATA]
    call fs_append
    mov esi, msg_copied
    call out_puts
    jmp .x
.denied:
    mov esi, msg_denied
    jmp .err
.nofile:
    mov esi, msg_nofile
    jmp .err
.nopath:
    mov esi, msg_nopath
    jmp .err
.syn:
    mov esi, msg_syn2
.err:
    call err_puts
    mov dword [cmd_status], 1
.x: pop ebx
    ret

; ---- REN old new --------------------------------------------------------------------------
cmd_ren:
    push ebx
    WSPTR edi, WS_TMP1
    call get_token
    jz .syn
    WSPTR edi, WS_TMP2
    call get_token
    jz .syn
    push esi
    WSPTR esi, WS_TMP1
    call fs_resolve
    pop esi
    test eax, eax
    jz .nofile
    test dword [eax+FE_FLAGS], FF_DIR
    jnz .denied
    mov ebx, eax
    WSPTR esi, WS_TMP2
.chk:
    mov al, [esi]
    test al, al
    jz .ok
    cmp al, '\'
    je .syn
    cmp al, ':'
    je .syn
    cmp al, '/'
    je .syn
    inc esi
    jmp .chk
.ok:
    lea esi, [ebx+FE_PATH]
    WSPTR edi, WS_PATH1
    call fs_parent
    mov esi, edi
    call strlen
    add edi, eax
    cmp eax, 1
    je .nosep
    mov byte [edi], '\'
    inc edi
.nosep:
    WSPTR esi, WS_TMP2
    call strcpy
    WSPTR esi, WS_PATH1
    call strlen
    cmp eax, 46
    ja .nofile
    WSPTR esi, WS_PATH1
    call fs_lookup
    test eax, eax
    jnz .denied
    WSPTR esi, WS_PATH1
    lea edi, [ebx+FE_PATH]
    call strcpy
    jmp .x
.denied:
    mov esi, msg_denied
    jmp .err
.nofile:
    mov esi, msg_nofile
    jmp .err
.syn:
    mov esi, msg_syn2
.err:
    call err_puts
    mov dword [cmd_status], 1
.x: pop ebx
    ret

cmd_vol:
    mov esi, msg_vol1
    call out_puts
    ret

; ---- TREE [/F] [/A] [path] ----------------------------------------------------------------
cmd_tree:
    mov dword [tr_files], 0
    mov dword [tr_ascii], 0
    WSPTR edi, WS_TMP1
    mov byte [edi], 0
.p: call skip_sp
    mov al, [esi]
    test al, al
    jz .go
    cmp al, '/'
    jne .path
    mov al, [esi+1]
    or al, 0x20
    cmp al, 'f'
    jne .ta
    mov dword [tr_files], 1
.ta:
    cmp al, 'a'
    jne .adv
    mov dword [tr_ascii], 1
.adv:
    add esi, 2
    jmp .p
.path:
    WSPTR edi, WS_TMP1
    call get_token
    jmp .p
.go:
    mov dword [tr_bar], tr_u_bar
    mov dword [tr_mid], tr_u_mid
    mov dword [tr_last], tr_u_last
    cmp dword [tr_ascii], 0
    je .chars
    mov dword [tr_bar], tr_a_bar
    mov dword [tr_mid], tr_a_mid
    mov dword [tr_last], tr_a_last
.chars:
    WSPTR esi, WS_TMP1
    call fs_resolve
    test eax, eax
    jz .nopath
    test dword [eax+FE_FLAGS], FF_DIR
    jz .nopath
    mov esi, fs_nbuf
    WSPTR edi, WS_PATH2
    call strcpy
    mov esi, msg_tree1
    call out_puts
    mov al, 'C'
    call out_putc
    mov al, ':'
    call out_putc
    WSPTR esi, WS_PATH2
    cmp byte [esi+1], 0
    jne .notroot
    mov al, '.'
    call out_putc
    jmp .rootd
.notroot:
    mov al, [esi]
    test al, al
    jz .rootd
    call to_upper
    call out_putc
    inc esi
    jmp .notroot
.rootd:
    call out_crlf
    mov dword [tr_plen], 0
    mov byte [tr_prefix], 0
    WSPTR esi, WS_PATH2
    call tree_dir
    ret
.nopath:
    mov esi, msg_nopath
    call err_puts
    mov dword [cmd_status], 1
    ret

; tree_dir: ESI = directory (normalised path, must stay valid); prefix in tr_prefix
tree_dir:
    push ebp
    mov ebp, esp
    sub esp, 112
    push ebx
    push esi
    push edi
    mov [ebp-4], esi
    mov dword [ebp-12], 0               ; number of sub directories
    xor edx, edx
.cnt:
    mov esi, [ebp-4]
    call fs_next_child
    test eax, eax
    jz .cntd
    mov edx, [fn_best]
    test dword [eax+FE_FLAGS], FF_DIR
    jz .cnt
    inc dword [ebp-12]
    jmp .cnt
.cntd:
    cmp dword [tr_files], 0
    je .dirs
    mov dword [ebp-16], 0               ; files printed
    xor edx, edx
.fl:
    mov esi, [ebp-4]
    call fs_next_child
    test eax, eax
    jz .fld
    mov edx, [fn_best]
    test dword [eax+FE_FLAGS], FF_DIR
    jnz .fl
    mov [ebp-20], edx
    inc dword [ebp-16]
    mov esi, tr_prefix
    call out_puts
    mov esi, tr_blank
    cmp dword [ebp-12], 0
    je .fb
    mov esi, [tr_bar]
.fb:
    call out_puts
    mov esi, [ebp-20]
    call out_puts
    call out_crlf
    mov edx, [ebp-20]
    jmp .fl
.fld:
    cmp dword [ebp-16], 0
    je .dirs
    mov esi, tr_prefix
    call out_puts
    mov esi, tr_blank
    cmp dword [ebp-12], 0
    je .fb2
    mov esi, [tr_bar]
.fb2:
    call out_puts
    call out_crlf
.dirs:
    mov dword [ebp-16], 0               ; index of the directory
    mov dword [ebp-20], 0
.dl:
    mov esi, [ebp-4]
    mov edx, [ebp-20]
    call fs_next_child
    test eax, eax
    jz .done
    mov edx, [fn_best]
    mov [ebp-20], edx
    test dword [eax+FE_FLAGS], FF_DIR
    jz .dl
    inc dword [ebp-16]
    xor eax, eax
    mov ecx, [ebp-16]
    cmp ecx, [ebp-12]
    sete al
    mov [ebp-24], eax                   ; last directory?
    mov esi, tr_prefix
    call out_puts
    mov esi, [tr_mid]
    test eax, eax
    jz .pm
    mov esi, [tr_last]
.pm:
    call out_puts
    mov esi, [ebp-20]
    call out_puts
    call out_crlf
    lea edi, [ebp-100]
    mov esi, [ebp-4]
    call strcpy
    mov edi, eax
    cmp byte [eax-1], '\'
    je .ns
    mov byte [edi], '\'
    inc edi
.ns:
    mov esi, [ebp-20]
    call strcpy
    mov eax, [tr_plen]
    mov [ebp-28], eax
    lea edi, [tr_prefix+eax]
    mov esi, tr_blank
    cmp dword [ebp-24], 0
    jne .pp
    mov esi, [tr_bar]
.pp:
    call strcpy
    add dword [tr_plen], 4
    lea esi, [ebp-100]
    call tree_dir
    mov eax, [ebp-28]
    mov [tr_plen], eax
    mov byte [tr_prefix+eax], 0
    jmp .dl
.done:
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; ---- DIR [path] -------------------------------------------------------------------------------
out_decw:                               ; EAX = number, ECX = field width (right aligned)
    push eax
    push ebx
    push edx
    push esi
    push edi
    mov ebx, ecx
    mov edi, num_buf
    call itoa
    mov esi, num_buf
    call strlen
    sub ebx, eax
    jbe .num
.sp:
    mov al, ' '
    call out_putc
    dec ebx
    jnz .sp
.num:
    mov esi, num_buf
    call out_puts
    pop edi
    pop esi
    pop edx
    pop ebx
    pop eax
    ret

print_datetime:                         ; "YYYY-MM-DD  HH:MM"
    push esi
    push edi
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
    mov byte [edi], ' '
    mov byte [edi+1], ' '
    add edi, 2
    mov eax, [rtc_hour]
    call put2
    mov byte [edi], ':'
    inc edi
    mov eax, [rtc_min]
    call put2
    mov byte [edi], 0
    mov esi, dyn_buf
    call out_puts
    pop edi
    pop esi
    ret

cmd_dir:
    WSPTR edi, WS_TMP1
    mov byte [edi], 0
.p: call skip_sp
    mov al, [esi]
    test al, al
    jz .go
    cmp al, '/'
    jne .path
.sk:
    mov al, [esi]
    test al, al
    jz .p
    cmp al, ' '
    je .p
    inc esi
    jmp .sk
.path:
    WSPTR edi, WS_TMP1
    call get_token
    jmp .p
.go:
    WSPTR esi, WS_TMP1
    call fs_resolve
    test eax, eax
    jz .nofile
    test dword [eax+FE_FLAGS], FF_DIR
    jz .nofile
    mov esi, fs_nbuf
    WSPTR edi, WS_PATH2
    call strcpy
    mov esi, msg_vol1
    call out_puts
    call out_crlf
    mov esi, msg_dirof
    call out_puts
    WSPTR esi, WS_PATH2
    call out_puts
    call out_crlf
    call out_crlf
    mov dword [dir_files], 0
    mov dword [dir_dirs], 0
    mov dword [dir_bytes], 0
    xor edx, edx
.l: WSPTR esi, WS_PATH2
    call fs_next_child
    test eax, eax
    jz .totals
    mov edx, [fn_best]
    mov ebx, eax
    push edx
    call print_datetime
    test dword [ebx+FE_FLAGS], FF_DIR
    jz .file
    mov esi, msg_dirtag
    call out_puts
    inc dword [dir_dirs]
    jmp .name
.file:
    mov eax, [ebx+FE_LEN]
    add [dir_bytes], eax
    inc dword [dir_files]
    mov ecx, 18
    call out_decw
    mov al, ' '
    call out_putc
.name:
    pop edx
    mov esi, edx
    call out_puts
    call out_crlf
    jmp .l
.totals:
    mov eax, [dir_files]
    mov ecx, 16
    call out_decw
    mov esi, msg_nofiles
    call out_puts
    mov eax, [dir_bytes]
    mov ecx, 15
    call out_decw
    mov esi, msg_bytes
    call out_puts
    mov eax, [dir_dirs]
    mov ecx, 16
    call out_decw
    mov esi, msg_nodirs
    call out_puts
    call out_crlf
    ret
.nofile:
    mov esi, msg_nofile
    call err_puts
    mov dword [cmd_status], 1
    ret
