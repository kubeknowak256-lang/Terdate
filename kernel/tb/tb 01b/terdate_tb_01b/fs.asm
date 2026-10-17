; ============================================================================
;  fs.asm - tiny RAM file system
;  Files embedded at build time (data.asm) are registered at start-up as
;  read-only; the first write copies them to the heap (copy on write).
;  Paths are stored normalised: "\dir\file" (no drive letter), compared
;  without regard to case.
; ============================================================================
section .bss
heap_ptr:   resd 1
fs_nbuf:    resb 64                     ; normalised path scratch (fs_resolve)
fs_tmp:     resb 64
cwd:        resb 64                     ; current directory: "\" or "\dir\sub"
fs_b:       resb 4
fn_last:    resd 1
fn_best:    resd 1
section .data
fs_root:    db '\', 0                   ; pseudo entry for the root directory
            times 46 db 0
            dd 0, 0, 0, FF_USED|FF_DIR
section .text

fs_init:
    mov dword [heap_ptr], HEAP_BASE
    mov byte [cwd], '\'
    mov byte [cwd+1], 0
    mov ebx, embedded_files
.next:
    mov esi, [ebx]
    test esi, esi
    jz .done
    mov edx, [ebx+4]
    mov ecx, [ebx+8]
    push ebx
    call fs_register
    pop ebx
    mov eax, [ebx+4]
    add eax, [ebx+8]
    add eax, 3
    and eax, ~3
    mov ebx, eax
    jmp .next
.done:
    ret

heap_alloc:                             ; EAX = size -> EAX = pointer or 0
    push edx
    add eax, 15
    and eax, ~15
    mov edx, [heap_ptr]
    add eax, edx
    cmp eax, HEAP_LIMIT
    ja .fail
    mov [heap_ptr], eax
    mov eax, edx
    pop edx
    ret
.fail:
    xor eax, eax
    pop edx
    ret

; fs_norm: ESI = raw path, EDI = output buffer (64 bytes) -> CF=1 when invalid
fs_norm:
    push ebx
    push esi
    push edi
    mov ebx, edi
    cmp byte [esi+1], ':'
    jne .nodrv
    mov al, [esi]
    call to_upper
    cmp al, 'C'
    jne .bad
    add esi, 2
.nodrv:
    cmp byte [esi], '\'
    je .abs
    cmp byte [esi], '/'
    je .abs
    push esi
    mov esi, cwd
    call strcpy
    pop esi
    mov edi, eax
    jmp .sep
.abs:
    mov byte [edi], '\'
    mov byte [edi+1], 0
    inc edi
.sep:
    cmp byte [esi], '\'
    je .s1
    cmp byte [esi], '/'
    jne .c0
.s1:
    inc esi
    jmp .sep
.c0:
    cmp byte [esi], 0
    je .done
    xor ecx, ecx
.cl:
    mov al, [esi+ecx]
    test al, al
    jz .ce
    cmp al, '\'
    je .ce
    cmp al, '/'
    je .ce
    inc ecx
    jmp .cl
.ce:
    cmp ecx, 1
    jne .nd
    cmp byte [esi], '.'
    jne .nd
    add esi, ecx
    jmp .sep
.nd:
    cmp ecx, 2
    jne .add
    cmp word [esi], '..'
    jne .add
    add esi, 2
    push esi
    mov esi, edi
.pl:
    dec esi
    cmp byte [esi], '\'
    jne .pl
    cmp esi, ebx
    jne .cut
    lea esi, [ebx+1]
.cut:
    mov byte [esi], 0
    mov edi, esi
    pop esi
    jmp .sep
.add:
    mov eax, edi
    sub eax, ebx
    add eax, ecx
    cmp eax, 45
    ja .bad
    lea eax, [ebx+1]
    cmp edi, eax
    je .nosep
    mov byte [edi], '\'
    inc edi
.nosep:
    rep movsb
    mov byte [edi], 0
    jmp .sep
.done:
    clc
    jmp .x
.bad:
    stc
.x: pop edi
    pop esi
    pop ebx
    ret

fs_lookup:                              ; ESI = normalised path -> EAX = entry or 0
    push ebx
    push ecx
    push edi
    cmp byte [esi], '\'
    jne .scan
    cmp byte [esi+1], 0
    jne .scan
    mov eax, fs_root
    jmp .x
.scan:
    mov ebx, FILE_TAB
    mov ecx, MAX_FILES
.l: test dword [ebx+FE_FLAGS], FF_USED
    jz .n
    lea edi, [ebx+FE_PATH]
    call stricmp
    je .found
.n: add ebx, FE_SZ
    dec ecx
    jnz .l
    xor eax, eax
    jmp .x
.found:
    mov eax, ebx
.x: pop edi
    pop ecx
    pop ebx
    ret

fs_resolve:                             ; ESI = raw path -> EAX = entry or 0 (path left in fs_nbuf)
    push edi
    mov edi, fs_nbuf
    call fs_norm
    jc .no
    push esi
    mov esi, fs_nbuf
    call fs_lookup
    pop esi
    pop edi
    ret
.no:
    mov byte [fs_nbuf], 0
    xor eax, eax
    pop edi
    ret

fs_alloc_entry:                         ; -> EAX = zeroed free entry or 0
    push ecx
    push edi
    mov eax, FILE_TAB
    mov ecx, MAX_FILES
.l: cmp dword [eax+FE_FLAGS], 0
    je .f
    add eax, FE_SZ
    dec ecx
    jnz .l
    xor eax, eax
    jmp .x
.f: mov edi, eax
    push eax
    xor eax, eax
    mov ecx, FE_SZ/4
    rep stosd
    pop eax
.x: pop edi
    pop ecx
    ret

fs_parent:                              ; ESI = normalised path, EDI = out -> parent path
    push esi
    push edi
    push ebx
    call strcpy
    mov ebx, edi
    mov esi, eax
.l: dec esi
    cmp byte [esi], '\'
    jne .l
    cmp esi, ebx
    jne .c
    inc esi
.c: mov byte [esi], 0
    pop ebx
    pop edi
    pop esi
    ret

fs_ensure_dir:                          ; ESI = normalised path
    push esi
    push edi
    call fs_lookup
    test eax, eax
    jnz .x
    call fs_alloc_entry
    test eax, eax
    jz .x
    lea edi, [eax+FE_PATH]
    push eax
    call strcpy
    pop eax
    mov dword [eax+FE_FLAGS], FF_USED|FF_DIR
.x: pop edi
    pop esi
    ret

fs_mkparents:                           ; ESI = normalised path: create all parent dirs
    push ebx
    push ecx
    push esi
    push edi
    mov edi, fs_tmp
    call strcpy
    mov ebx, edi
    lea esi, [ebx+1]
.l: mov al, [esi]
    test al, al
    jz .d
    cmp al, '\'
    jne .n
    mov byte [esi], 0
    push esi
    mov esi, ebx
    call fs_ensure_dir
    pop esi
    mov byte [esi], '\'
.n: inc esi
    jmp .l
.d: pop edi
    pop esi
    pop ecx
    pop ebx
    ret

fs_register:                            ; ESI = path, EDX = data, ECX = length (read-only file)
    push ebx
    push edi
    push edx
    push ecx
    mov edi, fs_nbuf
    call fs_norm
    pop ecx
    pop edx
    jc .x
    push edx
    push ecx
    mov esi, fs_nbuf
    call fs_mkparents
    call fs_alloc_entry
    pop ecx
    pop edx
    test eax, eax
    jz .x
    lea edi, [eax+FE_PATH]
    mov esi, fs_nbuf
    push eax
    call strcpy
    pop eax
    mov [eax+FE_DATA], edx
    mov [eax+FE_LEN], ecx
    mov dword [eax+FE_CAP], 0
    mov dword [eax+FE_FLAGS], FF_USED
.x: pop edi
    pop ebx
    ret

fs_cow:                                 ; EAX = entry -> EAX = entry (writable) or 0
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov ebx, eax
    cmp dword [ebx+FE_CAP], 0
    jne .ok
    mov eax, [ebx+FE_LEN]
    add eax, FILE_MIN_CAP
    and eax, ~(FILE_MIN_CAP-1)
    mov ecx, eax
    call heap_alloc
    test eax, eax
    jz .fail
    mov edi, eax
    mov esi, [ebx+FE_DATA]
    mov edx, ecx
    mov ecx, [ebx+FE_LEN]
    rep movsb
    mov [ebx+FE_DATA], eax
    mov [ebx+FE_CAP], edx
.ok:
    mov eax, ebx
    jmp .x
.fail:
    xor eax, eax
.x: pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

fs_create:                              ; ESI = normalised path -> EAX = empty file entry or 0
    push ebx
    push ecx
    push edx
    push esi
    push edi
    call fs_lookup
    test eax, eax
    jnz .exists
    mov edi, fs_tmp
    call fs_parent
    push esi
    mov esi, fs_tmp
    call fs_lookup
    pop esi
    test eax, eax
    jz .fail
    test dword [eax+FE_FLAGS], FF_DIR
    jz .fail
    call fs_alloc_entry
    test eax, eax
    jz .fail
    mov ebx, eax
    lea edi, [ebx+FE_PATH]
    call strcpy
    mov eax, FILE_MIN_CAP
    call heap_alloc
    test eax, eax
    jz .fail
    mov [ebx+FE_DATA], eax
    mov dword [ebx+FE_LEN], 0
    mov dword [ebx+FE_CAP], FILE_MIN_CAP
    mov dword [ebx+FE_FLAGS], FF_USED
    mov eax, ebx
    jmp .x
.exists:
    test dword [eax+FE_FLAGS], FF_DIR
    jnz .fail
    mov dword [eax+FE_LEN], 0
    call fs_cow
    jmp .x
.fail:
    xor eax, eax
.x: pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

fs_open_append:                         ; ESI = normalised path -> EAX = entry or 0
    push esi
    call fs_lookup
    test eax, eax
    jz .new
    test dword [eax+FE_FLAGS], FF_DIR
    jnz .fail
    call fs_cow
    pop esi
    ret
.new:
    call fs_create
    pop esi
    ret
.fail:
    xor eax, eax
    pop esi
    ret

fs_append:                              ; EDX = entry, ESI = data, ECX = length
    push eax
    push ebx
    push ecx
    push esi
    push edi
    mov ebx, edx
    mov eax, [ebx+FE_LEN]
    add eax, ecx
    cmp eax, [ebx+FE_CAP]
    jbe .copy
    push ecx
    mov ecx, [ebx+FE_CAP]
    add ecx, ecx
    cmp ecx, eax
    jae .g1
    mov ecx, eax
.g1:
    add ecx, 4095
    and ecx, ~4095
    mov eax, ecx
    call heap_alloc
    test eax, eax
    jz .oom
    mov edi, eax
    push esi
    mov esi, [ebx+FE_DATA]
    mov edx, ecx
    mov ecx, [ebx+FE_LEN]
    rep movsb
    pop esi
    mov [ebx+FE_DATA], eax
    mov [ebx+FE_CAP], edx
    pop ecx
.copy:
    mov eax, ecx
    mov edi, [ebx+FE_DATA]
    add edi, [ebx+FE_LEN]
    rep movsb
    add [ebx+FE_LEN], eax
    jmp .x
.oom:
    pop ecx
.x: pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

fs_append_byte:                         ; EDX = entry, AL = byte (registers preserved)
    push ecx
    push esi
    mov [fs_b], al
    mov esi, fs_b
    mov ecx, 1
    call fs_append
    pop esi
    pop ecx
    ret

fs_delete:                              ; EAX = entry
    cmp eax, fs_root
    je .r
    mov dword [eax+FE_FLAGS], 0
.r: ret

fs_cmpci:                               ; ESI vs EDI -> flags as CMP (JA = esi greater), ignore case
    push eax                            ; EAX is preserved (callers keep a pointer in it)
    push esi
    push edi
.l: mov al, [esi]
    call to_upper
    mov ah, al
    mov al, [edi]
    call to_upper
    cmp ah, al
    jne .x
    test al, al
    jz .x
    inc esi
    inc edi
    jmp .l
.x: pop edi
    pop esi
    pop eax
    ret

fs_child_of:                            ; EDI = entry, ESI = dir path, EBP = dir path length
    push ecx                            ; -> EAX = pointer to child name or 0
    push esi
    push edx
    lea edx, [edi+FE_PATH]
    cmp ebp, 1
    je .root
    mov ecx, ebp
.cmp:
    mov al, [esi]
    call to_upper
    mov ah, al
    mov al, [edx]
    call to_upper
    cmp al, ah
    jne .no
    inc esi
    inc edx
    dec ecx
    jnz .cmp
    cmp byte [edx], '\'
    jne .no
    inc edx
    jmp .nm
.root:
    cmp byte [edx], '\'
    jne .no
    inc edx
.nm:
    cmp byte [edx], 0
    je .no
    mov eax, edx
.sc:
    mov cl, [eax]
    test cl, cl
    jz .ok
    cmp cl, '\'
    je .no
    inc eax
    jmp .sc
.ok:
    mov eax, edx
    jmp .x
.no:
    xor eax, eax
.x: pop edx
    pop esi
    pop ecx
    ret

; fs_next_child: ESI = directory path, EDX = previous child name (or 0)
;  -> EAX = next child entry in alphabetical order, or 0
fs_next_child:
    push ebx
    push ecx
    push esi
    push edi
    push ebp
    mov [fn_last], edx
    mov dword [fn_best], 0
    call strlen
    mov ebp, eax
    xor ebx, ebx
    mov ecx, MAX_FILES
    mov edi, FILE_TAB
.l: test dword [edi+FE_FLAGS], FF_USED
    jz .n
    call fs_child_of
    test eax, eax
    jz .n
    mov edx, [fn_last]
    test edx, edx
    jz .nolast
    push esi
    push edi
    mov esi, eax
    mov edi, edx
    call fs_cmpci
    pop edi
    pop esi
    jbe .n
.nolast:
    mov edx, [fn_best]
    test edx, edx
    jz .take
    push esi
    push edi
    mov esi, eax
    mov edi, edx
    call fs_cmpci
    pop edi
    pop esi
    jae .n
.take:
    mov ebx, edi
    mov [fn_best], eax
.n: add edi, FE_SZ
    dec ecx
    jnz .l
    mov eax, ebx
    pop ebp
    pop edi
    pop esi
    pop ecx
    pop ebx
    ret
