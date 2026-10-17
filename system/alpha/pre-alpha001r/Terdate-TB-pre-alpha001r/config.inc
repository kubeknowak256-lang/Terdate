; ============================================================================
;  Terdate TB - shared constants (memory map, structures)
; ============================================================================
%define TD_VERSION      "pre-alpha001r"

LOAD_BASE       equ 0x00008000          ; boot.asm puts load.bin here
STACK_TOP       equ 0x00090000
VGA_BASE        equ 0x000B8000
SCR_COLS        equ 80
SCR_ROWS        equ 25
SCR_BYTES       equ 4000
MIN_EXT_KB      equ 5120                ; RAM above 1 MB that we need
SEL_CODE        equ 0x08
SEL_DATA        equ 0x10

; ---- pools above 1 MB (fixed addresses, zeroed at start-up) -----------------
MAX_PROCS       equ 8                   ; nested "windows" (start)
ENV_SIZE        equ 0x2000
ENV_BLOCKS      equ 0x00100000
MAX_SL          equ 16                  ; nested setlocal levels
SL_SLOT         equ 0x2100              ; +0 flags, +4 env length, +16 env copy
SL_STACK        equ 0x00120000
SCR_SLOT        equ 0x1000
SCR_BUFS        equ 0x00150000
MAX_FRAMES      equ 40
FRAME_SZ        equ 128
FRAME_TAB       equ 0x00160000
ARG_SIZE        equ 0x400
FRAME_ARGS      equ 0x00162000
WS_SIZE         equ 0x6000
FRAME_WS_BASE   equ 0x00170000          ; ends 0x260000
MAX_FILES       equ 128
FE_SZ           equ 64
FILE_TAB        equ 0x00270000
CTX_SIZE        equ 128
PROC_SAVE       equ 0x00272000
HEAP_BASE       equ 0x00300000          ; file data heap (bump allocator)
HEAP_LIMIT      equ 0x00600000
FILE_MIN_CAP    equ 4096

; ---- file table entry -------------------------------------------------------
FE_PATH         equ 0                   ; 48 bytes "\dir\file", NUL terminated
FE_DATA         equ 48
FE_LEN          equ 52
FE_CAP          equ 56                  ; 0 = read-only (embedded) data
FE_FLAGS        equ 60
FF_USED         equ 1
FF_DIR          equ 2

; ---- frame = one running script / call level --------------------------------
FR_SCRIPT       equ 0
FR_END          equ 4
FR_PC           equ 8
FR_SLD          equ 12                  ; setlocal depth at entry
FR_PARENT       equ 16                  ; previous cur_frame
FR_WS           equ 20                  ; workspace pointer
FR_PATH         equ 24                  ; script path (normalised, no drive)
FR_ARGALL       equ 28                  ; %*
FR_ARGV         equ 32                  ; 10 dwords: %0 .. %9
FR_SCRP         equ 72                  ; scratch bump pointer (workspace)
; argument area layout (per frame, ARG_SIZE bytes)
ARG_V0          equ 0                   ; 64 bytes  %0 text
ARG_PATHOFS     equ 64                  ; 64 bytes  script path
ARG_ALLOFS      equ 128                 ; 416 bytes %* text
ARG_TOKOFS      equ 544                 ; 480 bytes tokens

; ---- workspace layout (WS_SIZE per frame) ----------------------------------
WS_STMT         equ 0x0000              ; expanded statement
STMT_SIZE       equ 0x2000
WS_CMD          equ 0x2000              ; raw line / simple command
CMD_SIZE        equ 0x1000
WS_CMD2         equ 0x3000
WS_TMP1         equ 0x4000              ; 1 KB
WS_TMP2         equ 0x4400              ; 1 KB
WS_RDOUT        equ 0x4800              ; redirection targets (128 each)
WS_RDERR        equ 0x4880
WS_RDIN         equ 0x4900
WS_PATH1        equ 0x4980
WS_PATH2        equ 0x4A00
WS_MISC         equ 0x4A80              ; ~1.4 KB
WS_SCR          equ 0x5000              ; 4 KB scratch (for loops)
SCR_AREA        equ 0x1000

; ---- process save record ----------------------------------------------------
PC_X            equ 0
PC_Y            equ 4
PC_ATTR         equ 8
PC_ECHO         equ 12
PC_DELAY        equ 16
PC_CWD          equ 32                  ; 64 bytes

; ---- pending actions (goto / exit) -----------------------------------------
P_NONE          equ 0
P_GOTO          equ 1
P_EXITB         equ 2                   ; leave current frame
P_EXITP         equ 3                   ; leave current process

; ---- output modes -----------------------------------------------------------
OUT_CON         equ 0
OUT_NUL         equ 1
OUT_FILE        equ 2
ERR_CON         equ 0
ERR_NUL         equ 1
ERR_OUT         equ 2                   ; 2>&1
ERR_FILE        equ 3

; ---- redirection flags (exec_simple) ----------------------------------------
RF_OUT          equ 1
RF_APPEND       equ 2
RF_ERR          equ 4
RF_ERR2OUT      equ 8
RF_IN           equ 16
