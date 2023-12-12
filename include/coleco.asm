; ColecoVision

; PORTS
; video display processor
VDP_DATA_PORT:				equ 0beh
VDP_CTRL_PORT:				equ 0bfh
; sound generator
SND_PORT:				equ 0ffh	; write only
; game controller
GC_STROBE_SET:				equ 080h	; write only
GC_STROBE_RESET:			equ 0c0h	; write only
GC_CONTROLLER1:				equ 0fch	; read only
GC_CONTROLLER2:				equ 0ffh	; read only

; VIDEO MODES
SCRMODE_STD:				equ 00h
SCRMODE_TXT:				equ 10h
SCRMODE_MC:				equ 08h
SCRMODE_BMP:				equ 02h
SCRMODE_BMP_TXT:			equ 12h
SCRMODE_BMP_MC:				equ 0ah
SCRMODE_BMP_TXT_MC:			equ 1ah

; TMS9918A COLORS
COLOR_TRANSPARENT:			equ 00h
COLOR_BLACK:				equ 01h
COLOR_GREEN:				equ 02h
COLOR_LIGHT_GREEN:			equ 03h
COLOR_BLUE:				equ 04h
COLOR_LIGHT_BLUE:			equ 05h
COLOR_DARK_RED:				equ 06h
COLOR_CYAN:				equ 07h
COLOR_RED:				equ 08h
COLOR_LIGHT_RED:			equ 09h
COLOR_YELLOW:				equ 0ah
COLOR_LIGHT_YELLOW:			equ 0bh
COLOR_DARK_GREEN:			equ 0ch
COLOR_MAGENTA:				equ 0dh
COLOR_GRAY:				equ 0eh
COLOR_WHITE:				equ 0fh

; BIOS JUMP TABLE
; misc calls
ADD816:					equ $01b1	; add 8-bit value to 16-bit value
BOOT_UP:				equ $0000	; reset console
DECLSN:					equ $0190
DECMSN:					equ $019b
DISPLAY_LOGO:				equ $1319
MSNTOLSN:				equ $01a6
POWER_UP:				equ $006e
RAND_GEN:				equ $1ffd	; output: 16-bit result in RAND_NUM, HL, A=L
RAND_NUM:				equ $73c8	; 2-byte output of last call to RAND_GEN
; video-related calls
FILL_VRAM:				equ $1f82
GAME_OPT:				equ $1f7c
GET_VRAM:				equ $1fbb
INIT_SPR_NM_TBL:			equ $1fc1
INIT_TABLE:				equ $1fb8
LOAD_ASCII:				equ $1f7f
MODE_1:					equ $1f85
PUT_VRAM:				equ $1fbe
READ_REGISTER:				equ $1fdc
READ_VRAM:				equ $1fe2
WRITE_REGISTER:				equ $1fd9
WRITE_VRAM:				equ $1fdf
WR_SPR_NM_TBL:				equ $1fc4
; object routines
ACTIVATE:				equ $1ff7
CALC_OFFSET:				equ $08c0
GET_BKGRND:				equ $0898
INIT_WRITER:				equ $1fe5
PUT_FRAME:				equ $080b
PUTOBJ:					equ $1ffa
PUTSEMI:				equ $06ff
PUT_MOBILE:				equ $0a87
PUT0SPRITE:				equ $08df
PUT1SPRITE:				equ $0955
PUTCOMPLEX:				equ $0ea2
PX_TO_PTRN_POS:				equ $07e8
SET_UP_WRITE:				equ $0623
WRITER:					equ $1fe8
; graphics primitives
ENLARGE:				equ $1f73
REFLECT_HORIZONTAL:			equ $1f6d
REFLECT_VERTICAL:			equ $1f6a
ROTATE_90:				equ $1f70
; timer related calls
FREE_SIGNAL:				equ $1fca
INIT_TIMER:				equ $1fc7
REQUEST_SIGNAL:				equ $1fcd
TEST_SIGNAL:				equ $1fd0
TIME_MGR:				equ $1fd3
AMERICA:				equ $0069
; music/sound-related calls
PLAY_IT:				equ $1ff1	; B=song number
PLAY_SONGS:				equ $1f61	; call during interrupt (early)
SOUND_INIT:				equ $1fee	; B=concurrent voices+effects, HL=song table
SOUND_MAN:				equ $1ff4	; call during interrupt (late)
TURN_OFF_SOUND:				equ $1fd6	; no sounds
; controller-related calls and settings
CONT_READ:				equ $113d
CONTROLLER_INIT:			equ $1105
CONTROLLER_SCAN:			equ $1f76
DECODER:				equ $1f79
POLLER:					equ $1feb
UPDATE_SPINNER:				equ $1f88
; controller debounce routines
JOY_DBNCE:				equ $12b9
FIRE_DBNCE:				equ $1289
ARM_DBNCE:				equ $12e9
KBD_DBNCE:				equ $1250
; to be added together for CONTROLLER_MAP +0 (P1), +1 (P2)
CONTROLLER_ENABLE:			equ 80h
KEYPAD_ENABLE:				equ 10h
ARM_BUTTON_ENABLE:			equ 8
JOYSTICK_ENABLE:			equ 2
FIRE_BUTTON_ENABLE:			equ 1
; controller table offsets
PLAYER1:				equ 0		; settings (above)
PLAYER2:				equ 1
FIRE1:					equ 2		; fire button 1 (40h=yes, 0=no)
JOY1:					equ 3		; 1=N, 2=E, 4=S, 8=W, etc.
SPIN1:					equ 4		; counter
ARM1:					equ 5		; arm button 1 (40h=yes, 0=no)
KEYPAD1:				equ 6		; 0-9, '*'=10, '#'=11
FIRE2:					equ 7
JOY2:					equ 8
SPIN2:					equ 9
ARM2:					equ 10
KEYPAD2:				equ 11

StackTop:				equ $739f	; top of stack
SPRITE_NAME:				equ $7030	; pointer to sprite name table (32 sprites * 4 bytes)
SPRITE_ORDER:				equ $7080	; pointer to sprite order table (32 sprites)
WORK_BUFFER:				equ $70a0	; pointer to graphics work area (~300h max usage)

; SYSTEM VALUES
; vram default tables
VRAM_PATTERN:				equ $0000
VRAM_NAME:				equ $1800
VRAM_SPRATTR:				equ $1b00
VRAM_COLOR:				equ $2000
VRAM_SPRGEN:				equ $3800
