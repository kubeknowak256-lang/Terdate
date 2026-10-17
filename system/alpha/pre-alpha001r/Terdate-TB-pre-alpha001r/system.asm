; ============================================================================
;  system.asm - process management ("windows"), boot of \syson.bat, power off
;
;  START runs a script as a new process: the parent's screen, cursor and
;  settings are saved, the child gets a clean screen and a copy of the
;  environment.  The parent is frozen (invisible) until the child exits, then
;  its screen is restored and it carries on after the START command.
; ============================================================================
section .data
path_syson: db '\syson.bat', 0
nm_os:      db 'OS', 0
vl_os:      db 'Terdate_TB', 0
nm_ver:     db 'TD_VERSION', 0
vl_ver:     db TD_VERSION, 0
msg_nosys:  db 'Terdate TB: \syson.bat not found - nothing to boot.', 13, 10, 0
msg_halt:   db 13, 10, 'Terdate TB: all processes ended, system halted.', 13, 10
            db 'It is now safe to turn off the computer.', 13, 10, 0
section .text

sys_main:
    call fs_init
    mov dword [proc_depth], -1
    mov dword [frame_count], 0
    mov dword [cur_frame], 0
    mov dword [errorlevel], 0
    mov dword [out_mode], OUT_CON
    mov dword [err_mode], ERR_CON
    mov dword [in_ent], 0
    mov byte [pending], 0
    mov byte [echo_on], 1
    mov byte [delayed], 0
    mov dword [env_ptr], ENV_BLOCKS
    mov esi, nm_os
    mov ecx, 2
    mov edx, vl_os
    call env_set
    mov esi, nm_ver
    mov ecx, 10
    mov edx, vl_ver
    call env_set
    mov esi, path_syson
    call fs_resolve
    test eax, eax
    jz .nosys
    mov esi, eax
    mov edx, empty_str
    call proc_run
    mov esi, msg_halt
    call con_puts
    call power_off
.hang:
    cli
    hlt
    jmp .hang
.nosys:
    mov esi, msg_nosys
    call con_puts
    jmp .hang

; proc_run: ESI = script file entry, EDX = argument text -> returns when the process ended
proc_run:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    mov ebp, esi
    mov ebx, edx
    mov eax, [proc_depth]
    cmp eax, MAX_PROCS-2
    jg .full
    test eax, eax
    js .noparent
    imul edi, eax, CTX_SIZE             ; save the parent's state
    add edi, PROC_SAVE
    mov ecx, [con_x]
    mov [edi+PC_X], ecx
    mov ecx, [con_y]
    mov [edi+PC_Y], ecx
    movzx ecx, byte [con_attr]
    mov [edi+PC_ATTR], ecx
    movzx ecx, byte [echo_on]
    mov [edi+PC_ECHO], ecx
    movzx ecx, byte [delayed]
    mov [edi+PC_DELAY], ecx
    add edi, PC_CWD
    mov esi, cwd
    call strcpy
    mov eax, [proc_depth]
    mov edi, eax
    shl edi, 12
    add edi, SCR_BUFS
    call con_save
.noparent:
    mov eax, [proc_depth]
    inc eax
    mov [proc_depth], eax
    mov edi, eax
    shl edi, 13
    add edi, ENV_BLOCKS
    test eax, eax
    jz .envdone
    mov esi, [env_ptr]
    call env_copy
.envdone:
    mov [env_ptr], edi
    mov byte [con_attr], 0x07
    call con_cls
    mov byte [echo_on], 1
    mov byte [delayed], 0
    mov esi, ebp
    mov edx, ebx
    call run_script
    mov byte [pending], 0
    mov eax, [proc_depth]
    dec eax
    mov [proc_depth], eax
    js .done
    mov edi, eax                        ; back to the parent
    shl edi, 13
    add edi, ENV_BLOCKS
    mov [env_ptr], edi
    imul edi, eax, CTX_SIZE
    add edi, PROC_SAVE
    mov ecx, [edi+PC_ECHO]
    mov [echo_on], cl
    mov ecx, [edi+PC_DELAY]
    mov [delayed], cl
    lea esi, [edi+PC_CWD]
    mov edi, cwd
    call strcpy
    mov eax, [proc_depth]
    mov esi, eax
    shl esi, 12
    add esi, SCR_BUFS
    call con_restore
    jmp .done
.full:
    mov esi, msg_toomany
    call err_puts
    mov dword [cmd_status], 1
.done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

power_off:                              ; QEMU/Bochs, newer QEMU, VirtualBox
    mov dx, 0x604
    mov ax, 0x2000
    out dx, ax
    mov dx, 0xB004
    mov ax, 0x2000
    out dx, ax
    mov dx, 0x4004
    mov ax, 0x3400
    out dx, ax
    ret
