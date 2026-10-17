; ============================================================================
;  timer.asm - PIT (100 Hz), CMOS real-time clock, pseudo random numbers
; ============================================================================
section .bss
rtc_year:   resd 1
rtc_mon:    resd 1
rtc_day:    resd 1
rtc_hour:   resd 1
rtc_min:    resd 1
rtc_sec:    resd 1
rnd_state:  resd 1
section .text

pit_init:
    mov al, 0x36
    out 0x43, al
    mov ax, 11932                       ; 1193182 Hz / 11932 = ~100 Hz
    out 0x40, al
    mov al, ah
    out 0x40, al
    ret

cmos_read:                              ; AL = register -> AL
    out 0x70, al
    out 0x80, al
    in al, 0x71
    ret

bcd2bin:                                ; AL
    push ecx
    mov cl, al
    shr al, 4
    mov ah, 10
    mul ah                              ; AX = high nibble * 10
    and cl, 15
    add al, cl
    pop ecx
    ret

; rtc_read: fills rtc_year .. rtc_sec (binary)
rtc_read:
    push eax
    push ebx
    push ecx
    push edx
    mov ecx, 100000
.w: mov al, 0x0A                        ; wait until no update is in progress
    call cmos_read
    test al, 0x80
    jz .go
    dec ecx
    jnz .w
.go:
    mov al, 0x0B
    call cmos_read
    mov bl, al                          ; status B (bit1 24h, bit2 binary)
    mov al, 0x00
    call cmos_read
    call .conv
    movzx eax, al
    mov [rtc_sec], eax
    mov al, 0x02
    call cmos_read
    call .conv
    movzx eax, al
    mov [rtc_min], eax
    mov al, 0x04
    call cmos_read
    mov dl, al
    and al, 0x7F
    call .conv
    test bl, 2
    jnz .h24
    test dl, 0x80                       ; 12 hour clock with PM flag
    jz .am
    cmp al, 12
    jae .h24
    add al, 12
    jmp .h24
.am:
    cmp al, 12
    jne .h24
    xor al, al
.h24:
    movzx eax, al
    mov [rtc_hour], eax
    mov al, 0x07
    call cmos_read
    call .conv
    movzx eax, al
    mov [rtc_day], eax
    mov al, 0x08
    call cmos_read
    call .conv
    movzx eax, al
    mov [rtc_mon], eax
    mov al, 0x09
    call cmos_read
    call .conv
    movzx edx, al
    mov al, 0x32
    call cmos_read
    call .conv
    movzx eax, al
    cmp eax, 19
    jb .c20
    cmp eax, 30
    ja .c20
    imul eax, eax, 100
    jmp .yr
.c20:
    mov eax, 2000
.yr:
    add eax, edx
    mov [rtc_year], eax
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
.conv:                                  ; AL BCD -> binary unless status B says binary
    test bl, 4
    jnz .cr
    call bcd2bin
.cr:
    ret

rnd_next:                               ; -> EAX = 0..32767
    push edx
    mov eax, [rnd_state]
    test eax, eax
    jnz .s
    mov eax, [ticks]
    or eax, 0x1234567
.s: mov edx, eax
    shl edx, 13
    xor eax, edx
    mov edx, eax
    shr edx, 17
    xor eax, edx
    mov edx, eax
    shl edx, 5
    xor eax, edx
    mov [rnd_state], eax
    shr eax, 8
    and eax, 0x7FFF
    pop edx
    ret
