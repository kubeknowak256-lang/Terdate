; ============================================================================
;  idt.asm - interrupt descriptor table, CPU exception reporting, 8259 PIC
; ============================================================================
section .bss
idt_table:  resb 256*8
ticks:      resd 1                      ; 100 Hz tick counter
section .data
idt_ptr:    dw 256*8-1
            dd idt_table
msg_exc:    db 13, 10, 'Terdate TB: CPU exception ', 0
msg_exc_e:  db ' err=', 0
msg_exc_i:  db ' eip=', 0
section .text

; ---- one stub per CPU exception vector --------------------------------------
%assign i 0
%rep 32
%if (i==8)||(i==10)||(i==11)||(i==12)||(i==13)||(i==14)||(i==17)||(i==21)||(i==29)||(i==30)
isr %+ i:
    push dword i
    jmp isr_common
%else
isr %+ i:
    push dword 0
    push dword i
    jmp isr_common
%endif
%assign i i+1
%endrep

isr_table:
%assign i 0
%rep 32
    dd isr %+ i
%assign i i+1
%endrep

isr_common:
    cli
    mov esi, msg_exc
    call con_puts
    mov eax, [esp]
    call con_puthex32
    mov esi, msg_exc_e
    call con_puts
    mov eax, [esp+4]
    call con_puthex32
    mov esi, msg_exc_i
    call con_puts
    mov eax, [esp+8]
    call con_puthex32
.h: hlt
    jmp .h

; ---- IRQ stubs --------------------------------------------------------------
irq_timer:
    push eax
    inc dword [ticks]
    mov al, 0x20
    out 0x20, al
    pop eax
    iretd

irq_kbd:
    pushad
    call kb_irq
    mov al, 0x20
    out 0x20, al
    popad
    iretd

irq_master:
    push eax
    mov al, 0x20
    out 0x20, al
    pop eax
    iretd

irq_slave:
    push eax
    mov al, 0x20
    out 0xA0, al
    out 0x20, al
    pop eax
    iretd

idt_set_gate:                           ; EAX vector, EDX handler
    push edi
    lea edi, [idt_table + eax*8]
    mov [edi], dx
    mov word [edi+2], SEL_CODE
    mov byte [edi+4], 0
    mov byte [edi+5], 0x8E
    shr edx, 16
    mov [edi+6], dx
    pop edi
    ret

idt_init:
    xor ecx, ecx
.exc:
    mov edx, [isr_table + ecx*4]
    mov eax, ecx
    call idt_set_gate
    inc ecx
    cmp ecx, 32
    jb .exc
    mov ecx, 32
.irq:
    mov eax, ecx
    mov edx, irq_master
    cmp ecx, 40
    jb .g
    mov edx, irq_slave
.g: cmp ecx, 32
    jne .nt
    mov edx, irq_timer
.nt:
    cmp ecx, 33
    jne .sg
    mov edx, irq_kbd
.sg:
    call idt_set_gate
    inc ecx
    cmp ecx, 48
    jb .irq
    lidt [idt_ptr]
    ret

pic_init:
    mov al, 0x11
    out 0x20, al
    out 0x80, al
    out 0xA0, al
    out 0x80, al
    mov al, 0x20
    out 0x21, al
    out 0x80, al
    mov al, 0x28
    out 0xA1, al
    out 0x80, al
    mov al, 4
    out 0x21, al
    out 0x80, al
    mov al, 2
    out 0xA1, al
    out 0x80, al
    mov al, 1
    out 0x21, al
    out 0x80, al
    out 0xA1, al
    out 0x80, al
    mov al, 0xFC                        ; unmask IRQ0 (timer) and IRQ1 (keyboard)
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al
    ret
