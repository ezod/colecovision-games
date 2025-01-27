; RE-PETE
; A Simon clone for ColecoVision.

	include "coleco.asm"

	org 	$8000

	db 	$aa,$55			; ColecoVision title screen
	dw 	$0000			; pointer to sprite name table
	dw 	$0000			; pointer to sprite order table
	dw 	$0000			; pointer to working buffer for WR_SPR_NM_TBL
	dw 	CONTROLLER_BUFFER	; pointer to controller input areas
	dw 	START			; entry point

rst_8:
	reti
	nop
rst_10:
	reti
	nop
rst_18:
	jp 	RAND_GEN
rst_20:
	reti
	nop
rst_28:
	reti
	nop
rst_30:
	reti
	nop
rst_38:
	reti
	nop

	jp 	NMI

	db 	"RE-PETE/LOGICK WORKSHOP PRESENTS/2023"

START:
	; set stack pointer
	ld 	sp,StackTop

	; initialize sound
	ld 	b,SoundDataCount
	ld 	hl,SoundAddrs
	call 	SOUND_INIT

	; initialize clock
	ld 	hl,TIMER_TABLE
	ld 	de,TIMER_DATA_BLOCK
	call 	INIT_TIMER

	; set screen mode 0 (aka graphics 1)
	call 	SETSCREEN0

	; enable both joysticks, buttons, keypads
	ld 	hl,$9b9b
	ld 	(CONTROLLER_BUFFER),hl

	; enable timers
	call 	CREATE_TIMERS

MAIN_SCREEN:
	; read joysticks to clear any false reads
	call 	JOYTST

	; initialize counters
	xor 	a
	ld 	(PCOUNT),a
	ld 	(CCOUNT),a
	ld 	(RCOUNT),a
	ld 	(HISCORE),a

	; disable interrupts
	call 	DISABLE_NMI

	; load the character set
	call 	LOAD_CHR_SET

	; set up main screen layout
	ld 	hl,VRAM_NAME
	ld 	de,SCREEN_LAYOUT
	ld 	bc,24*32
	call 	LDIRVM

	ld 	hl,VDU_WRITES
	call 	SET_VDU_HOOK
	call 	ENABLE_NMI

	call 	GAME_START

MLOOP:
	; delay
	ld 	hl,TIMER_LONG
	xor 	a
	call 	REQUEST_SIGNAL
	ld 	(LongTimer),a
MLOOP_DELAY:
	ld 	a,(LongTimer)
	call 	TEST_SIGNAL
	or 	a
	jr 	z,MLOOP_DELAY
	call 	FREE_SIGNAL

	call 	COMPUTER_TURN
	call 	PLAYER_TURN

	jr 	MLOOP

GAME_START:
	ld 	hl,VRAM_NAME+15*32+15
	ld 	de,LAYOUT_ASTERISK
	ld 	bc,2
	call 	LDIRVM
AWAIT_START:
	call 	JOYPAD
	cp 	10
	jr 	nz,AWAIT_START
	; seed random with the time that has passed
	ld 	hl,(TIME)
	call 	SEED_RANDOM
	ret

COMPUTER_TURN:
	; get current pattern address
	ld 	hl,PATTERN
	ld 	a,(CCOUNT)
	ld 	e,a
	ld 	d,0
	add 	hl,de
	; generate a random number 1-4 and store in pattern
	push 	hl
	call 	RND_LFSR
	pop 	hl
	ld 	de,(TIME)
	xor 	e
	and 	$03
	inc	a
	ld 	(hl),a
	; increment CCOUNT
	ld 	a,(CCOUNT)
	inc 	a
	ld 	(CCOUNT),a
	ld 	hl,VRAM_NAME+15*32+16
	call 	DISPLAY_DIGITS
	; initialize playback counter
	xor 	a
	ld 	(RCOUNT),a
COMPUTER_TURN_PLAY:
	; delay
	ld 	hl,TIMER_PAUSE
	xor 	a
	call 	REQUEST_SIGNAL
	ld 	(PauseTimer),a
COMPUTER_TURN_PLAY_DELAY:
	call 	RND_LFSR
	ld 	a,(PauseTimer)
	call 	TEST_SIGNAL
	or 	a
	jr 	z,COMPUTER_TURN_PLAY_DELAY
	call 	FREE_SIGNAL
	; get next pattern pad
	ld 	hl,PATTERN
	ld 	a,(RCOUNT)
	ld 	e,a
	ld 	d,0
	add 	hl,de
	ld 	a,(hl)
	; play the pad in the pattern
	call 	PLAY_PAD
	; delay
	ld 	a,(CCOUNT)
	call 	PATTERN_DELAY
	; stop playing pad
	xor	a
	call 	PLAY_PAD
	; increment playback count
	ld 	a,(RCOUNT)
	inc 	a
	ld 	(RCOUNT),a
	; check if finished pattern
	ld 	hl,CCOUNT
	cp 	(hl)
	jr 	NZ,COMPUTER_TURN_PLAY
	ret

PLAYER_TURN:
	; monitor controller
	call 	JOYDIR
	or 	a
	jr 	z,PLAYER_TURN
	; joystick direction pressed
	call 	JOY2PAD
	; check input against pattern, end turn and reset if wrong
	ld 	b,a
	ld 	hl,PATTERN
	ld 	a,(PCOUNT)
	ld 	e,a
	ld 	d,0
	add 	hl,de
	ld 	a,b
	cp 	(hl)
	jr 	z,PLAYER_TURN_RIGHT
	ld 	b,5
	call 	PLAY_IT
	; check current score against high score
	ld 	a,(CCOUNT)
	dec 	a
	ld 	b,a
	ld 	a,(HISCORE)
	cp 	b
	jr 	nc,PLAYER_TURN_HR
	; save high score
	ld 	a,b
	ld 	(HISCORE),a
	; display high score
	ld 	hl,VRAM_NAME+8*32+18
	call 	DISPLAY_DIGITS
	ld 	hl,VRAM_NAME+8*32+13
	ld 	de,LAYOUT_BEST
	ld 	bc,4
	call 	LDIRVM
PLAYER_TURN_HR:
	; reset counters
	xor 	a
	ld 	(CCOUNT),a
	ld 	(PCOUNT),a
	call 	GAME_START
	ret
PLAYER_TURN_AR1:
	call 	JOYDIR
	or 	a
	jr 	nz,PLAYER_TURN_AR1
	jr 	PLAYER_TURN_END
PLAYER_TURN_RIGHT:
	; play pad if correct
	call 	PLAY_PAD
PLAYER_TURN_AR2:
	call	JOYDIR
	or 	a
	jr 	nz,PLAYER_TURN_AR2
	; joystick released, release the pad
	call 	JOY2PAD
	call 	PLAY_PAD
	; update count
	ld 	a,(PCOUNT)
	inc 	a
	ld 	(PCOUNT),a
	; end turn if pattern complete
	ld 	hl,CCOUNT
	cp 	(hl)
	jr 	nz,PLAYER_TURN
PLAYER_TURN_END:
	; reset count and return
	xor 	a
	ld 	(PCOUNT),a
	ret

PATTERN_DELAY:
	cp 	14
	jr 	nc,PATTERN_DELAY_SHORT
	cp 	6
	jr 	nc,PATTERN_DELAY_MEDIUM
PATTERN_DELAY_LONG:
	ld 	hl,TIMER_LONG
	xor 	a
	call 	REQUEST_SIGNAL
	ld 	(LongTimer),a
PATTERN_DELAY_LONG_T:
	ld 	a,(LongTimer)
	call 	TEST_SIGNAL
	or 	a
	jr 	z,PATTERN_DELAY_LONG_T
	call 	FREE_SIGNAL
	ret
PATTERN_DELAY_MEDIUM:
	ld 	hl,TIMER_MEDIUM
	xor 	a
	call 	REQUEST_SIGNAL
	ld 	(MediumTimer),a
PATTERN_DELAY_MEDIUM_T:
	ld 	a,(MediumTimer)
	call 	TEST_SIGNAL
	or 	a
	jr 	z,PATTERN_DELAY_MEDIUM_T
	call 	FREE_SIGNAL
	ret
PATTERN_DELAY_SHORT:
	ld 	hl,TIMER_SHORT
	xor 	a
	call 	REQUEST_SIGNAL
	ld 	(ShortTimer),a
PATTERN_DELAY_SHORT_T:
	ld 	a,(ShortTimer)
	call 	TEST_SIGNAL
	or 	a
	jr 	z,PATTERN_DELAY_SHORT_T
	call 	FREE_SIGNAL
	ret

DISPLAY_DIGITS:
	; display low digit of A
	call 	BIN2BCD
	ld 	e,a
	push 	de
	and 	$0f
	ld 	bc,1
	call 	FILVRM
	; display high digit of A
	pop 	de
	ld 	a,e
	srl 	a
	srl 	a
	srl 	a
	srl 	a
	jr 	nz,DISPLAY_DIGITS_HI
	add 	a,10
DISPLAY_DIGITS_HI:
	dec 	hl
	ld 	bc,1
	call 	FILVRM
	ret

JOY2PAD:
	; green / up
	ld 	b,1
	bit 	0,a
	jr 	nz,JOY2PAD_RET
	; red / right
	inc	b
	bit 	1,a
	jr 	nz,JOY2PAD_RET
	; blue / down
	inc	b
	bit 	2,a
	jr 	nz,JOY2PAD_RET
	; yellow / left
	inc	b
	bit 	3,a
	jr 	nz,JOY2PAD_RET
	ld 	b,0
JOY2PAD_RET:
	ld 	a,b
	ret

PLAY_PAD:
	ld 	de,TILESET_COL_N
	; skip straight to load base color map if joystick neutral (no sound)
	or 	a
	jr 	z,LOAD_COL
	; otherwise, multiply to get the color map address
	ld 	b,a
	push 	bc
	ld	hl,TILESET_COL_N
	ld 	de,22
PLAY_PAD_LOOP:
	add 	hl,de
	djnz 	PLAY_PAD_LOOP
	; load the color map for the pad
	push 	hl
	pop	de
	call 	LOAD_COL
	; play the sound for the pad
	pop 	bc
	call 	PLAY_IT
	ret

LOAD_CHR_SET:
	; load patterns
	ld 	hl,0
	ld 	de,TILESET_PAT
	ld 	bc,TILESET_SIZE*8
	call 	LDIRVM
	; load white color
	ld 	hl,VRAM_COLOR
	ld 	a,$f1
	ld 	bc,10
	call 	FILVRM
	ld 	de,TILESET_COL_N
	call 	LOAD_COL
	ret

LOAD_COL:
	ld 	hl,VRAM_COLOR+10
	ld 	bc,22
	call 	LDIRVM
	ret

VDU_WRITES:
	ret

TIMER_LONG:		equ $002c
TIMER_MEDIUM:		equ $0022
TIMER_SHORT:		equ $0017
TIMER_PAUSE:		equ $0006

TILESET_SIZE:		equ 256

TILESET_PAT:
	; background tiles
	db 124,198,198,198,198,198,124,000 ; 000 - 0
	db 048,112,048,048,048,048,252,000 ; 001 - 1
	db 120,204,012,056,096,204,252,000 ; 002 - 2
	db 120,204,012,056,012,204,120,000 ; 003 - 3
	db 028,060,108,204,254,012,030,000 ; 004 - 4
	db 252,192,248,012,012,204,120,000 ; 005 - 5
	db 056,096,192,248,204,204,120,000 ; 006 - 6
	db 252,204,012,024,048,048,048,000 ; 007 - 7
	db 120,204,204,120,204,204,120,000 ; 008 - 8
	db 120,204,204,124,012,024,112,000 ; 009 - 9
	db 000,000,000,000,000,000,000,000 ; 010
	; logo text tiles
	db 063,127,255,255,248,240,240,240 ; 011
	db 252,254,255,255,031,015,015,015 ; 012
	db 063,127,255,255,248,240,255,255 ; 013
	db 252,254,255,255,031,015,255,255 ; 014
	db 000,000,000,000,000,000,063,063 ; 015
	db 000,000,000,000,000,000,252,252 ; 016
	db 063,127,255,255,240,240,255,255 ; 017
	db 252,254,255,255,015,015,255,255 ; 018
	db 255,255,255,255,003,003,003,003 ; 019
	db 255,255,255,255,192,192,192,192 ; 020
	db 240,240,240,240,240,240,240,240 ; 021
	db 255,255,240,248,255,255,127,063 ; 022
	db 255,255,000,000,255,255,255,255 ; 023
	db 063,063,000,000,000,000,000,000 ; 024
	db 252,252,000,000,000,000,000,000 ; 025
	db 255,255,240,240,240,240,240,240 ; 026
	db 254,252,000,000,000,000,000,000 ; 027
	db 003,003,003,003,003,003,001,000 ; 028
	db 192,192,192,224,255,255,255,255 ; 029
	; best tiles
	db 249,205,205,241,205,205,249,000 ; 030
	db 243,134,134,227,128,128,247,000 ; 031
	db 223,006,006,134,198,198,134,000 ; 032
	db 128,000,096,096,000,096,096,000 ; 033
	; 2-part asterisk
	db 000,006,003,015,003,006,000,000 ; 034
	db 000,096,192,240,192,096,000,000 ; 035
	; spare
	db 255,255,255,255,255,255,255,255 ; 036
	db 255,255,255,255,255,255,255,255 ; 037
	db 255,255,255,255,255,255,255,255 ; 038
	db 255,255,255,255,255,255,255,255 ; 039
	db 255,255,255,255,255,255,255,255 ; 040
	db 255,255,255,255,255,255,255,255 ; 041
	db 255,255,255,255,255,255,255,255 ; 042
	db 255,255,255,255,255,255,255,255 ; 043
	db 255,255,255,255,255,255,255,255 ; 044
	db 255,255,255,255,255,255,255,255 ; 045
	db 255,255,255,255,255,255,255,255 ; 046
	db 255,255,255,255,255,255,255,255 ; 047
	db 255,255,255,255,255,255,255,255 ; 048
	db 255,255,255,255,255,255,255,255 ; 049
	db 255,255,255,255,255,255,255,255 ; 050
	db 255,255,255,255,255,255,255,255 ; 051
	db 255,255,255,255,255,255,255,255 ; 052
	db 255,255,255,255,255,255,255,255 ; 053
	db 255,255,255,255,255,255,255,255 ; 054
	db 255,255,255,255,255,255,255,255 ; 055
	db 255,255,255,255,255,255,255,255 ; 056
	db 255,255,255,255,255,255,255,255 ; 057
	db 255,255,255,255,255,255,255,255 ; 058
	db 255,255,255,255,255,255,255,255 ; 069
	db 255,255,255,255,255,255,255,255 ; 060
	db 255,255,255,255,255,255,255,255 ; 061
	db 255,255,255,255,255,255,255,255 ; 062
	db 255,255,255,255,255,255,255,255 ; 063
	db 255,255,255,255,255,255,255,255 ; 064
	db 255,255,255,255,255,255,255,255 ; 065
	db 255,255,255,255,255,255,255,255 ; 066
	db 255,255,255,255,255,255,255,255 ; 067
	db 255,255,255,255,255,255,255,255 ; 068
	db 255,255,255,255,255,255,255,255 ; 069
	db 255,255,255,255,255,255,255,255 ; 070
	db 255,255,255,255,255,255,255,255 ; 071
	db 255,255,255,255,255,255,255,255 ; 072
	db 255,255,255,255,255,255,255,255 ; 073
	db 255,255,255,255,255,255,255,255 ; 074
	db 255,255,255,255,255,255,255,255 ; 075
	db 255,255,255,255,255,255,255,255 ; 076
	db 255,255,255,255,255,255,255,255 ; 077
	db 255,255,255,255,255,255,255,255 ; 078
	db 255,255,255,255,255,255,255,255 ; 079
	; green tiles
	db 000,000,000,000,000,003,031,255 ; 080
	db 000,000,000,000,063,255,255,255 ; 081
	db 000,000,015,255,255,255,255,255 ; 082
	db 000,063,255,255,255,255,255,255 ; 083
	db 031,255,255,255,255,255,255,255 ; 084
	db 255,255,255,255,255,255,255,255 ; 085
	db 248,255,255,255,255,255,255,255 ; 086
	db 000,252,255,255,255,255,255,255 ; 087
	db 000,000,240,255,255,255,255,255 ; 088
	db 000,000,000,192,252,255,255,255 ; 089
	db 000,000,000,000,000,192,248,255 ; 090
	db 000,000,000,000,000,000,003,015 ; 091
	db 000,000,001,007,063,255,255,255 ; 092
	db 007,063,255,255,255,255,255,255 ; 093
	db 224,252,255,255,255,255,255,255 ; 094
	db 000,000,128,224,252,255,255,255 ; 095
	db 000,000,000,000,000,000,192,240 ; 096
	db 000,000,003,007,031,127,255,127 ; 097
	db 063,255,255,255,255,255,255,255 ; 098
	db 252,255,255,255,255,255,255,255 ; 099
	db 000,000,192,224,248,254,255,254 ; 100
	db 063,015,007,003,000,000,000,000 ; 101
	db 255,255,255,255,255,127,063,015 ; 102
	db 255,255,255,255,255,254,252,240 ; 103
	db 252,240,224,192,000,000,000,000 ; 104
	db 007,003,000,000,000,000,000,000 ; 105
	db 255,255,255,127,063,015,007,003 ; 106
	db 255,255,255,254,252,240,224,192 ; 107
	db 224,192,000,000,000,000,000,000 ; 108
	db 255,127,063,015,007,001,000,000 ; 109
	db 255,255,255,255,255,255,255,127 ; 110
	db 255,255,255,255,255,255,255,252 ; 111
	db 255,255,255,255,248,192,000,000 ; 112
	db 255,255,240,000,000,000,000,000 ; 113
	db 254,000,000,000,000,000,000,000 ; 114
	db 127,000,000,000,000,000,000,000 ; 115
	db 255,255,015,000,000,000,000,000 ; 116
	db 255,255,255,255,031,003,000,000 ; 117
	db 255,255,255,255,255,255,255,063 ; 118
	db 255,255,255,255,255,255,255,254 ; 119
	db 255,254,252,240,224,128,000,000 ; 120
	db 031,015,007,000,000,000,000,000 ; 121
	db 240,192,000,000,000,000,000,000 ; 122
	db 015,003,000,000,000,000,000,000 ; 123
	db 248,240,224,000,000,000,000,000 ; 124
	db 255,255,255,255,255,255,255,255 ; 125
	db 255,255,255,255,255,255,255,255 ; 126
	db 255,255,255,255,255,255,255,255 ; 127
	; red tiles
	db 000,000,000,000,000,003,007,015 ; 128
	db 000,000,000,000,000,192,224,240 ; 129
	db 000,000,000,003,007,015,063,127 ; 130
	db 063,127,255,255,255,255,255,255 ; 131
	db 248,252,254,255,255,255,255,255 ; 132
	db 000,000,000,000,128,192,224,240 ; 133
	db 000,000,000,000,000,000,000,003 ; 134
	db 000,003,007,015,063,127,255,255 ; 135
	db 255,255,255,255,255,255,255,255 ; 136
	db 000,000,000,000,000,128,192,224 ; 137
	db 000,000,000,000,001,003,007,031 ; 138
	db 007,015,063,127,255,255,255,255 ; 139
	db 224,240,248,248,252,252,254,255 ; 140
	db 063,127,063,031,015,007,003,001 ; 141
	db 000,128,128,192,192,192,224,224 ; 142
	db 255,127,127,063,063,031,015,015 ; 143
	db 240,240,240,248,248,248,252,252 ; 144
	db 007,007,007,003,003,003,001,001 ; 145
	db 252,252,254,254,254,254,254,254 ; 146
	db 001,001,000,000,000,000,000,000 ; 147
	db 000,000,000,000,000,000,001,001 ; 148
	db 001,001,003,003,003,007,007,007 ; 149
	db 254,254,254,254,254,254,252,252 ; 150
	db 015,015,031,063,063,127,127,255 ; 151
	db 252,252,248,248,248,240,240,240 ; 152
	db 001,003,007,015,031,063,127,063 ; 153
	db 224,224,192,192,192,128,128,000 ; 154
	db 031,007,003,001,000,000,000,000 ; 155
	db 255,255,255,255,127,063,015,007 ; 156
	db 255,254,252,252,248,248,240,224 ; 157
	db 003,000,000,000,000,000,000,000 ; 158
	db 255,255,127,063,015,007,003,000 ; 159
	db 255,255,255,255,255,254,252,248 ; 160
	db 224,192,128,000,000,000,000,000 ; 161
	db 127,063,015,007,003,000,000,000 ; 162
	db 255,255,255,255,255,255,127,063 ; 163
	db 240,224,192,128,000,000,000,000 ; 164
	db 015,007,003,000,000,000,000,000 ; 165
	db 240,224,192,000,000,000,000,000 ; 166
	db 255,255,255,255,255,255,255,255 ; 167
	; blue tiles
	db 000,000,000,000,000,007,015,031 ; 168
	db 000,000,000,000,000,000,192,240 ; 169
	db 000,000,000,000,000,000,003,015 ; 170
	db 000,000,000,000,000,224,240,248 ; 171
	db 000,000,001,007,015,063,127,255 ; 172
	db 127,255,255,255,255,255,255,255 ; 173
	db 252,255,255,255,255,255,255,255 ; 174
	db 000,000,192,248,255,255,255,255 ; 175
	db 000,000,000,000,000,240,255,255 ; 176
	db 000,000,000,000,000,000,000,254 ; 177
	db 000,000,000,000,000,000,000,127 ; 178
	db 000,000,000,000,000,015,255,255 ; 179
	db 000,000,003,031,255,255,255,255 ; 180
	db 063,255,255,255,255,255,255,255 ; 181
	db 254,255,255,255,255,255,255,255 ; 182
	db 000,000,128,224,240,252,254,255 ; 183
	db 000,000,000,000,000,000,003,007 ; 184
	db 003,007,015,063,127,255,255,255 ; 185
	db 255,255,255,255,255,255,255,255 ; 186
	db 192,224,240,252,254,255,255,255 ; 187
	db 000,000,000,000,000,000,192,224 ; 188
	db 000,000,000,000,003,007,015,063 ; 189
	db 015,063,127,255,255,255,255,255 ; 190
	db 240,252,254,255,255,255,255,255 ; 191
	db 000,000,000,000,192,224,240,252 ; 192
	db 127,255,127,031,007,003,000,000 ; 193
	db 255,255,255,255,255,255,255,063 ; 194
	db 255,255,255,255,255,255,255,252 ; 195
	db 254,255,254,248,224,192,000,000 ; 196
	db 015,003,000,000,000,000,000,000 ; 197
	db 255,255,255,063,007,001,000,000 ; 198
	db 255,255,255,255,255,255,063,007 ; 199
	db 255,255,255,255,255,255,252,224 ; 200
	db 255,255,255,252,224,128,000,000 ; 201
	db 240,192,000,000,000,000,000,000 ; 202
	db 255,031,003,000,000,000,000,000 ; 203
	db 255,255,255,063,003,000,000,000 ; 204
	db 255,255,255,255,255,015,000,000 ; 205
	db 255,255,255,255,255,255,063,000 ; 206
	db 255,255,255,255,255,255,255,031 ; 207
	db 255,255,255,255,255,255,255,248 ; 208
	db 255,255,255,255,255,255,252,000 ; 209
	db 255,255,255,255,255,240,000,000 ; 210
	db 255,255,255,252,192,000,000,000 ; 211
	db 255,248,192,000,000,000,000,000 ; 212
	db 255,255,255,255,255,255,255,255 ; 213
	db 255,255,255,255,255,255,255,255 ; 214
	db 255,255,255,255,255,255,255,255 ; 215
	; yellow tiles
	db 000,000,000,000,000,003,007,015 ; 216
	db 000,000,000,000,000,192,224,240 ; 217
	db 000,000,000,000,001,003,007,015 ; 218
	db 031,063,127,255,255,255,255,255 ; 219
	db 252,254,255,255,255,255,255,255 ; 220
	db 000,000,000,192,224,240,252,254 ; 221
	db 000,000,000,000,000,001,003,007 ; 222
	db 255,255,255,255,255,255,255,255 ; 223
	db 000,192,224,240,252,254,255,255 ; 224
	db 000,000,000,000,000,000,000,192 ; 225
	db 007,015,031,031,063,063,127,255 ; 226
	db 224,240,252,254,255,255,255,255 ; 227
	db 000,000,000,000,128,192,224,248 ; 228
	db 000,001,001,003,003,003,007,007 ; 229
	db 252,254,252,248,240,224,192,128 ; 230
	db 015,015,015,031,031,031,063,063 ; 231
	db 255,254,254,252,252,248,240,240 ; 232
	db 063,063,127,127,127,127,127,127 ; 233
	db 224,224,224,192,192,192,128,128 ; 234
	db 128,128,000,000,000,000,000,000 ; 235
	db 000,000,000,000,000,000,128,128 ; 236
	db 127,127,127,127,127,127,063,063 ; 237
	db 128,128,192,192,192,224,224,224 ; 238
	db 063,063,031,031,031,015,015,015 ; 239
	db 240,240,248,252,252,254,254,255 ; 240
	db 007,007,003,003,003,001,001,000 ; 241
	db 128,192,224,240,248,252,254,252 ; 242
	db 255,127,063,063,031,031,015,007 ; 243
	db 255,255,255,255,254,252,240,224 ; 244
	db 248,224,192,128,000,000,000,000 ; 245
	db 007,003,001,000,000,000,000,000 ; 246
	db 255,255,255,255,255,127,063,031 ; 247
	db 255,255,254,252,240,224,192,000 ; 248
	db 192,000,000,000,000,000,000,000 ; 249
	db 015,007,003,001,000,000,000,000 ; 250
	db 255,255,255,255,255,255,254,252 ; 251
	db 254,252,240,224,192,000,000,000 ; 252
	db 015,007,003,000,000,000,000,000 ; 253
	db 240,224,192,000,000,000,000,000 ; 254
	db 255,255,255,255,255,255,255,255 ; 255

TILESET_COL_N:
	db $c0,$c0,$c0,$c0,$c0,$c0
	db $60,$60,$60,$60,$60
	db $40,$40,$40,$40,$40,$40
	db $a0,$a0,$a0,$a0,$a0

TILESET_COL_G:
	db $30,$30,$30,$30,$30,$30
	db $60,$60,$60,$60,$60
	db $40,$40,$40,$40,$40,$40
	db $a0,$a0,$a0,$a0,$a0

TILESET_COL_R:
	db $c0,$c0,$c0,$c0,$c0,$c0
	db $90,$90,$90,$90,$90
	db $40,$40,$40,$40,$40,$40
	db $a0,$a0,$a0,$a0,$a0

TILESET_COL_B:
	db $c0,$c0,$c0,$c0,$c0,$c0
	db $60,$60,$60,$60,$60
	db $50,$50,$50,$50,$50,$50
	db $a0,$a0,$a0,$a0,$a0

TILESET_COL_Y:
	db $c0,$c0,$c0,$c0,$c0,$c0
	db $60,$60,$60,$60,$60
	db $40,$40,$40,$40,$40,$40
	db $b0,$b0,$b0,$b0,$b0


SCREEN_LAYOUT:
	db 010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010 ; 000
	db 010,010,010,010,010,010,010,010,010,010,080,081,082,083,084,085,085,086,087,088,089,090,010,010,010,010,010,010,010,010,010,010 ; 001
	db 010,010,010,010,010,010,010,091,092,093,085,085,085,085,085,085,085,085,085,085,085,085,094,095,096,010,010,010,010,010,010,010 ; 002
	db 010,010,010,010,010,010,097,098,085,085,085,085,085,085,085,085,085,085,085,085,085,085,085,085,099,100,010,010,010,010,010,010 ; 003
	db 010,010,010,010,216,217,101,102,085,085,085,085,085,085,085,085,085,085,085,085,085,085,085,085,103,104,128,129,010,010,010,010 ; 004
	db 010,010,010,218,219,220,221,105,106,085,085,085,085,085,085,085,085,085,085,085,085,085,085,107,108,130,131,132,133,010,010,010 ; 005
	db 010,010,222,219,223,223,223,224,225,109,110,111,112,113,114,010,010,115,116,117,118,119,120,134,135,136,136,136,132,137,010,010 ; 006
	db 010,010,226,223,223,223,223,223,227,228,121,122,010,010,010,010,010,010,010,010,123,124,138,139,136,136,136,136,136,140,010,010 ; 007
	db 010,229,223,223,223,223,223,223,223,230,010,010,010,010,010,010,010,010,010,010,010,010,141,136,136,136,136,136,136,136,142,010 ; 008
	db 010,231,223,223,223,223,223,223,232,010,010,010,010,010,010,010,010,010,010,010,010,010,010,143,136,136,136,136,136,136,144,010 ; 009
	db 010,233,223,223,223,223,223,223,234,010,010,010,010,010,010,010,010,010,010,010,010,010,010,145,136,136,136,136,136,136,146,010 ; 010
	db 010,223,223,223,223,223,223,223,235,011,012,013,014,015,016,017,018,013,014,019,020,013,014,147,136,136,136,136,136,136,136,010 ; 011
	db 010,223,223,223,223,223,223,223,236,021,010,022,023,024,025,026,027,022,023,028,029,022,023,148,136,136,136,136,136,136,136,010 ; 012
	db 010,237,223,223,223,223,223,223,238,010,010,010,010,010,010,010,010,010,010,010,010,010,010,149,136,136,136,136,136,136,150,010 ; 013
	db 010,239,223,223,223,223,223,223,240,010,010,010,010,010,010,010,010,010,010,010,010,010,010,151,136,136,136,136,136,136,152,010 ; 014
	db 010,241,223,223,223,223,223,223,223,242,010,010,010,010,010,010,010,010,010,010,010,010,153,136,136,136,136,136,136,136,154,010 ; 015
	db 010,010,243,223,223,223,223,223,244,245,168,169,010,010,010,010,010,010,010,010,170,171,155,156,136,136,136,136,136,157,010,010 ; 016
	db 010,010,246,247,223,223,223,248,249,172,173,174,175,176,177,010,010,178,179,180,181,182,183,158,159,136,136,136,160,161,010,010 ; 017
	db 010,010,010,250,247,251,252,184,185,186,186,186,186,186,186,186,186,186,186,186,186,186,186,187,188,162,163,160,164,010,010,010 ; 018
	db 010,010,010,010,253,254,189,190,186,186,186,186,186,186,186,186,186,186,186,186,186,186,186,186,191,192,165,166,010,010,010,010 ; 019
	db 010,010,010,010,010,010,193,194,186,186,186,186,186,186,186,186,186,186,186,186,186,186,186,186,195,196,010,010,010,010,010,010 ; 020
	db 010,010,010,010,010,010,010,197,198,199,186,186,186,186,186,186,186,186,186,186,186,186,200,201,202,010,010,010,010,010,010,010 ; 021
	db 010,010,010,010,010,010,010,010,010,010,203,204,205,206,207,186,186,208,209,210,211,212,010,010,010,010,010,010,010,010,010,010 ; 022
	db 010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010 ; 023

LAYOUT_BEST:
	db 	030,031,032,033

LAYOUT_ASTERISK:
	db 	034,035

green:
	db 	$80,$53,$01,$0f
	db 	$90
	dw 	$0000
red:
	db 	$80,$93,$01,$0f
	db 	$90
	dw 	$0000
blue:
	db 	$80,$a7,$02,$0f
	db 	$90
	dw 	$0000
yellow:
	db 	$80,$fc,$01,$0f
	db 	$90
	dw 	$0000
wrong:
	db 	$80,$ff,$03,$2f
	db 	$90
	dw 	$0000

SoundDataCount:		equ 7
Len_SoundDataArea:	equ 10*SoundDataCount+1 	; 7 data areas
SoundAddrs:
	dw 	green,SoundDataArea
	dw 	red,SoundDataArea+10
	dw 	blue,SoundDataArea+20
	dw 	yellow,SoundDataArea+30
	dw 	wrong,SoundDataArea+40
	dw 	0,0

	include "bcd.asm"
	include "library.asm"

END:			equ $

	org 	RAMSTART

LongTimer:	ds 1
MediumTimer:	ds 1
ShortTimer:	ds 1
PauseTimer:	ds 1
PCOUNT:		ds 1
CCOUNT:		ds 1
RCOUNT:		ds 1
HISCORE:	ds 1
PATTERN:	ds 99

SoundDataArea:
	ds 	Len_SoundDataArea
