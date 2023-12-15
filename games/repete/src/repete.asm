; RE-PETE
; A Simon clone for ColecoVision.

	include "../../../include/coleco.asm"

	org $8000

	db $aa,$55			; ColecoVision title screen
	dw $0000			; pointer to sprite name table
	dw $0000			; pointer to sprite order table
	dw $0000			; pointer to working buffer for WR_SPR_NM_TBL
	dw CONTROLLER_BUFFER		; pointer to controller input areas
	dw START			; entry point

rst_8:
	reti
	nop
rst_10:
	reti
	nop
rst_18:
	jp RAND_GEN
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

	jp NMI

	db "RE-PETE/ /2023"

START:
	; set stack pointer
	ld SP,StackTop

	; initialize sound
	ld B,SoundDataCount		; max number of active voices+effects
	ld HL,SoundAddrs
	call SOUND_INIT

	; initialize clock
	ld HL,TIMER_TABLE
	ld DE,TIMER_DATA_BLOCK
	call INIT_TIMER

	; set screen mode 0,0 (16x16 sprites)
	call SETSCREEN0

	; enable both joysticks, buttons, keypads
	ld HL,$9b9b
	ld (CONTROLLER_BUFFER),HL

	; seed random numbers
	ld HL,1967
	call SEED_RANDOM

	; enable timers
	call CREATE_TIMERS

MAIN_SCREEN:
	; read joysticks to clear any false reads
	call JOYTST

	; initial seed random with the time that has passed
	LD HL,(TIME)
	call SEED_RANDOM

	; disable interrupts
	call DISABLE_NMI

	; clean up in case the game left anything on screen
	;call CLEARSPRITES
	;call SPRWRT

	; clear the screen
	;call CLEARPAT

	; load the character set
	call LOAD_CHR_SET

	; set up main screen layout
	ld HL,VRAM_NAME
	ld DE,SCREEN_LAYOUT
	ld BC,24*32
	call LDIRVM

	ld HL,VDU_WRITES
	call SET_VDU_HOOK
	call ENABLE_NMI

MLOOP:
	; check that a base tick has occurred
	; ensures consistent movement speed between 50 & 60 hz systems
	ld A,(TickTimer)
	call TEST_SIGNAL
	or A
	jr Z,MLOOP
	call COMPUTER_TURN
	call PLAYER_TURN
	jr MLOOP

COMPUTER_TURN:
	; increment CCOUNT
	ld A,(CCOUNT)
	inc A
	ld (CCOUNT),A
	; display low digit of CCOUNT
	call BIN2BCD
	and $0f
	ld HL,VRAM_NAME+15*32+16
	ld BC,1
	call FILVRM
	; display hight digit of CCOUNT
	ld A,(CCOUNT)
	call BIN2BCD
	srl a
	srl a
	srl a
	srl a
	ld HL,VRAM_NAME+15*32+15
	ld BC,1
	call FILVRM
	; TODO: add one random item to pattern
	; TODO: play back pattern
	ret

PLAYER_TURN:
	; monitor controller
	call JOYDIR
	ld HL,PSTATE
	cp (HL)
	jr Z,PLAYER_TURN
	; change player state
	ld (PSTATE),A
	call UPDATE_PSTATE
	ld A,(PSTATE)
	or A
	jr NZ,PLAYER_TURN
	; released, update count
	ld A,(PCOUNT)
	inc A
	ld (PCOUNT),A
	; TODO: check input against pattern, reset CCOUNT and end turn if wrong
	; end turn if pattern complete
	ld HL,CCOUNT
	cp (HL)
	jr NZ,PLAYER_TURN
PLAYER_TURN_END:
	; reset count and return
	ld A,0
	ld (PCOUNT),A
	ret

UPDATE_PSTATE:
	ld A,(PSTATE)
	bit 0,A
	jr Z,NUP
	; up / green
	ld DE,TILESET_COL_N+(VALUE_G+1)*22
	call LOAD_COL
	ret
NUP:
	bit 1,A
	jr Z,NRIGHT
	; right / red
	ld DE,TILESET_COL_N+(VALUE_R+1)*22
	call LOAD_COL
	ret
NRIGHT:
	bit 2,A
	jr Z,NDOWN
	; down / blue
	ld DE,TILESET_COL_N+(VALUE_B+1)*22
	call LOAD_COL
	ret
NDOWN:
	bit 3,A
	jr Z,NLEFT
	; left / yellow
	ld DE,TILESET_COL_N+(VALUE_Y+1)*22
	call LOAD_COL
	ret
NLEFT:
	; clear
	ld DE,TILESET_COL_N
	call LOAD_COL
	ret

LOAD_CHR_SET:
	; load patterns
	ld HL,0
	ld DE,TILESET_PAT
	ld BC,TILESET_SIZE*8
	call LDIRVM
	; load white color
	ld HL,VRAM_COLOR
	ld A,$f0
	ld BC,10
	call FILVRM
	ld DE,TILESET_COL_N
	call LOAD_COL
	ret

LOAD_COL:
	ld HL,VRAM_COLOR+10
	ld BC,22
	call LDIRVM
	ret

VDU_WRITES:
	ret

TILESET_SIZE:		equ 253
VALUE_G:		equ 0
VALUE_Y:		equ 1
VALUE_R:		equ 2
VALUE_B:		equ 3

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
	db 120,204,204,056,204,204,120,000 ; 008 - 8
	db 120,204,204,124,012,024,112,000 ; 009 - 9
	db 000,000,000,000,000,000,000,000 ; 010
	; logo text tiles
	db 063,127,255,255,248,240,240,240 ; 002
	db 252,254,255,255,031,015,015,015 ; 003
	db 063,127,255,255,248,240,255,255 ; 004
	db 252,254,255,255,031,015,255,255 ; 005
	db 000,000,000,000,000,000,063,063 ; 006
	db 000,000,000,000,000,000,252,252 ; 007
	db 063,127,255,255,240,240,255,255 ; 008
	db 252,254,255,255,015,015,255,255 ; 009
	db 255,255,255,255,003,003,003,003 ; 010
	db 255,255,255,255,192,192,192,192 ; 011
	db 240,240,240,240,240,240,240,240 ; 012
	db 255,255,240,248,255,255,127,063 ; 013
	db 255,255,000,000,255,255,255,255 ; 014
	db 063,063,000,000,000,000,000,000 ; 015
	db 252,252,000,000,000,000,000,000 ; 016
	db 255,255,240,240,240,240,240,240 ; 017
	db 254,252,000,000,000,000,000,000 ; 018
	db 003,003,003,003,003,003,001,000 ; 019
	db 192,192,192,224,255,255,255,255 ; 020
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	; green tiles
	db 000,000,000,000,000,003,031,255 ; 021
	db 000,000,000,000,063,255,255,255 ; 022
	db 000,000,015,255,255,255,255,255 ; 023
	db 000,063,255,255,255,255,255,255 ; 024
	db 031,255,255,255,255,255,255,255 ; 025
	db 255,255,255,255,255,255,255,255 ; 026
	db 248,255,255,255,255,255,255,255 ; 027
	db 000,252,255,255,255,255,255,255 ; 028
	db 000,000,240,255,255,255,255,255 ; 029
	db 000,000,000,192,252,255,255,255 ; 030
	db 000,000,000,000,000,192,248,255 ; 031
	db 000,000,000,000,000,000,003,015 ; 032
	db 000,000,001,007,063,255,255,255 ; 033
	db 007,063,255,255,255,255,255,255 ; 034
	db 224,252,255,255,255,255,255,255 ; 035
	db 000,000,128,224,252,255,255,255 ; 036
	db 000,000,000,000,000,000,192,240 ; 037
	db 000,000,003,007,031,127,255,127 ; 038
	db 063,255,255,255,255,255,255,255 ; 039
	db 252,255,255,255,255,255,255,255 ; 040
	db 000,000,192,224,248,254,255,254 ; 041
	db 063,015,007,003,000,000,000,000 ; 042
	db 255,255,255,255,255,127,063,015 ; 043
	db 255,255,255,255,255,254,252,240 ; 044
	db 252,240,224,192,000,000,000,000 ; 045
	db 007,003,000,000,000,000,000,000 ; 046
	db 255,255,255,127,063,015,007,003 ; 047
	db 255,255,255,254,252,240,224,192 ; 048
	db 224,192,000,000,000,000,000,000 ; 049
	db 255,127,063,015,007,001,000,000 ; 050
	db 255,255,255,255,255,255,255,127 ; 051
	db 255,255,255,255,255,255,255,252 ; 052
	db 255,255,255,255,248,192,000,000 ; 053
	db 255,255,240,000,000,000,000,000 ; 054
	db 254,000,000,000,000,000,000,000 ; 055
	db 127,000,000,000,000,000,000,000 ; 056
	db 255,255,015,000,000,000,000,000 ; 057
	db 255,255,255,255,031,003,000,000 ; 058
	db 255,255,255,255,255,255,255,063 ; 059
	db 255,255,255,255,255,255,255,254 ; 060
	db 255,254,252,240,224,128,000,000 ; 061
	db 031,015,007,000,000,000,000,000 ; 062
	db 240,192,000,000,000,000,000,000 ; 063
	db 015,003,000,000,000,000,000,000 ; 064
	db 248,240,224,000,000,000,000,000 ; 065
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	db 255,255,255,255,255,255,255,255 ; 000
	; yellow tiles
	db 000,000,000,000,000,003,007,015 ; 066
	db 000,000,000,000,000,192,224,240 ; 067
	db 000,000,000,000,001,003,007,015 ; 068
	db 031,063,127,255,255,255,255,255 ; 069
	db 252,254,255,255,255,255,255,255 ; 070
	db 000,000,000,192,224,240,252,254 ; 071
	db 000,000,000,000,000,001,003,007 ; 072
	db 255,255,255,255,255,255,255,255 ; 073
	db 000,192,224,240,252,254,255,255 ; 074
	db 000,000,000,000,000,000,000,192 ; 075
	db 007,015,031,031,063,063,127,255 ; 076
	db 224,240,252,254,255,255,255,255 ; 077
	db 000,000,000,000,128,192,224,248 ; 078
	db 000,001,001,003,003,003,007,007 ; 079
	db 252,254,252,248,240,224,192,128 ; 080
	db 015,015,015,031,031,031,063,063 ; 081
	db 255,254,254,252,252,248,240,240 ; 082
	db 063,063,127,127,127,127,127,127 ; 083
	db 224,224,224,192,192,192,128,128 ; 084
	db 128,128,000,000,000,000,000,000 ; 085
	db 000,000,000,000,000,000,128,128 ; 086
	db 127,127,127,127,127,127,063,063 ; 087
	db 128,128,192,192,192,224,224,224 ; 088
	db 063,063,031,031,031,015,015,015 ; 089
	db 240,240,248,252,252,254,254,255 ; 090
	db 007,007,003,003,003,001,001,000 ; 091
	db 128,192,224,240,248,252,254,252 ; 092
	db 255,127,063,063,031,031,015,007 ; 093
	db 255,255,255,255,254,252,240,224 ; 094
	db 248,224,192,128,000,000,000,000 ; 095
	db 007,003,001,000,000,000,000,000 ; 096
	db 255,255,255,255,255,127,063,031 ; 097
	db 255,255,254,252,240,224,192,000 ; 098
	db 192,000,000,000,000,000,000,000 ; 099
	db 015,007,003,001,000,000,000,000 ; 100
	db 255,255,255,255,255,255,254,252 ; 101
	db 254,252,240,224,192,000,000,000 ; 102
	db 015,007,003,000,000,000,000,000 ; 103
	db 240,224,192,000,000,000,000,000 ; 104
	db 255,255,255,255,255,255,255,255 ; 000
	; red tiles
	db 000,000,000,000,000,003,007,015 ; 105
	db 000,000,000,000,000,192,224,240 ; 106
	db 000,000,000,003,007,015,063,127 ; 107
	db 063,127,255,255,255,255,255,255 ; 108
	db 248,252,254,255,255,255,255,255 ; 109
	db 000,000,000,000,128,192,224,240 ; 110
	db 000,000,000,000,000,000,000,003 ; 111
	db 000,003,007,015,063,127,255,255 ; 112
	db 255,255,255,255,255,255,255,255 ; 113
	db 000,000,000,000,000,128,192,224 ; 114
	db 000,000,000,000,001,003,007,031 ; 115
	db 007,015,063,127,255,255,255,255 ; 116
	db 224,240,248,248,252,252,254,255 ; 117
	db 063,127,063,031,015,007,003,001 ; 118
	db 000,128,128,192,192,192,224,224 ; 119
	db 255,127,127,063,063,031,015,015 ; 120
	db 240,240,240,248,248,248,252,252 ; 121
	db 007,007,007,003,003,003,001,001 ; 122
	db 252,252,254,254,254,254,254,254 ; 123
	db 001,001,000,000,000,000,000,000 ; 124
	db 000,000,000,000,000,000,001,001 ; 125
	db 001,001,003,003,003,007,007,007 ; 126
	db 254,254,254,254,254,254,252,252 ; 127
	db 015,015,031,063,063,127,127,255 ; 128
	db 252,252,248,248,248,240,240,240 ; 129
	db 001,003,007,015,031,063,127,063 ; 130
	db 224,224,192,192,192,128,128,000 ; 131
	db 031,007,003,001,000,000,000,000 ; 132
	db 255,255,255,255,127,063,015,007 ; 133
	db 255,254,252,252,248,248,240,224 ; 134
	db 003,000,000,000,000,000,000,000 ; 135
	db 255,255,127,063,015,007,003,000 ; 136
	db 255,255,255,255,255,254,252,248 ; 137
	db 224,192,128,000,000,000,000,000 ; 138
	db 127,063,015,007,003,000,000,000 ; 139
	db 255,255,255,255,255,255,127,063 ; 140
	db 240,224,192,128,000,000,000,000 ; 141
	db 015,007,003,000,000,000,000,000 ; 142
	db 240,224,192,000,000,000,000,000 ; 143
	db 255,255,255,255,255,255,255,255 ; 000
	; blue tiles
	db 000,000,000,000,000,007,015,031 ; 144
	db 000,000,000,000,000,000,192,240 ; 145
	db 000,000,000,000,000,000,003,015 ; 146
	db 000,000,000,000,000,224,240,248 ; 147
	db 000,000,001,007,015,063,127,255 ; 148
	db 127,255,255,255,255,255,255,255 ; 149
	db 252,255,255,255,255,255,255,255 ; 150
	db 000,000,192,248,255,255,255,255 ; 151
	db 000,000,000,000,000,240,255,255 ; 152
	db 000,000,000,000,000,000,000,254 ; 153
	db 000,000,000,000,000,000,000,127 ; 154
	db 000,000,000,000,000,015,255,255 ; 155
	db 000,000,003,031,255,255,255,255 ; 156
	db 063,255,255,255,255,255,255,255 ; 157
	db 254,255,255,255,255,255,255,255 ; 158
	db 000,000,128,224,240,252,254,255 ; 159
	db 000,000,000,000,000,000,003,007 ; 160
	db 003,007,015,063,127,255,255,255 ; 161
	db 255,255,255,255,255,255,255,255 ; 162
	db 192,224,240,252,254,255,255,255 ; 163
	db 000,000,000,000,000,000,192,224 ; 164
	db 000,000,000,000,003,007,015,063 ; 165
	db 015,063,127,255,255,255,255,255 ; 166
	db 240,252,254,255,255,255,255,255 ; 167
	db 000,000,000,000,192,224,240,252 ; 168
	db 127,255,127,031,007,003,000,000 ; 169
	db 255,255,255,255,255,255,255,063 ; 170
	db 255,255,255,255,255,255,255,252 ; 171
	db 254,255,254,248,224,192,000,000 ; 172
	db 015,003,000,000,000,000,000,000 ; 173
	db 255,255,255,063,007,001,000,000 ; 174
	db 255,255,255,255,255,255,063,007 ; 175
	db 255,255,255,255,255,255,252,224 ; 176
	db 255,255,255,252,224,128,000,000 ; 177
	db 240,192,000,000,000,000,000,000 ; 178
	db 255,031,003,000,000,000,000,000 ; 179
	db 255,255,255,063,003,000,000,000 ; 180
	db 255,255,255,255,255,015,000,000 ; 181
	db 255,255,255,255,255,255,063,000 ; 182
	db 255,255,255,255,255,255,255,031 ; 183
	db 255,255,255,255,255,255,255,248 ; 184
	db 255,255,255,255,255,255,252,000 ; 185
	db 255,255,255,255,255,240,000,000 ; 186
	db 255,255,255,252,192,000,000,000 ; 187
	db 255,248,192,000,000,000,000,000 ; 188

TILESET_COL_N:
	db $c0,$c0,$c0,$c0,$c0,$c0
	db $a0,$a0,$a0,$a0,$a0
	db $60,$60,$60,$60,$60
	db $40,$40,$40,$40,$40,$40

TILESET_COL_G:
	db $30,$30,$30,$30,$30,$30
	db $a0,$a0,$a0,$a0,$a0
	db $60,$60,$60,$60,$60
	db $40,$40,$40,$40,$40,$40

TILESET_COL_Y:
	db $c0,$c0,$c0,$c0,$c0,$c0
	db $b0,$b0,$b0,$b0,$b0
	db $60,$60,$60,$60,$60
	db $40,$40,$40,$40,$40,$40

TILESET_COL_R:
	db $c0,$c0,$c0,$c0,$c0,$c0
	db $a0,$a0,$a0,$a0,$a0
	db $90,$90,$90,$90,$90
	db $40,$40,$40,$40,$40,$40

TILESET_COL_B:
	db $c0,$c0,$c0,$c0,$c0,$c0
	db $a0,$a0,$a0,$a0,$a0
	db $60,$60,$60,$60,$60
	db $50,$50,$50,$50,$50,$50

SCREEN_LAYOUT:
	db 010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010 ; 000
	db 010,010,010,010,010,010,010,010,010,010,080,081,082,083,084,085,085,086,087,088,089,090,010,010,010,010,010,010,010,010,010,010 ; 001
	db 010,010,010,010,010,010,010,091,092,093,085,085,085,085,085,085,085,085,085,085,085,085,094,095,096,010,010,010,010,010,010,010 ; 002
	db 010,010,010,010,010,010,097,098,085,085,085,085,085,085,085,085,085,085,085,085,085,085,085,085,099,100,010,010,010,010,010,010 ; 003
	db 010,010,010,010,128,129,101,102,085,085,085,085,085,085,085,085,085,085,085,085,085,085,085,085,103,104,168,169,010,010,010,010 ; 004
	db 010,010,010,130,131,132,133,105,106,085,085,085,085,085,085,085,085,085,085,085,085,085,085,107,108,170,171,172,173,010,010,010 ; 005
	db 010,010,134,131,135,135,135,136,137,109,110,111,112,113,114,010,010,115,116,117,118,119,120,174,175,176,176,176,172,177,010,010 ; 006
	db 010,010,138,135,135,135,135,135,139,140,121,122,010,010,010,010,010,010,010,010,123,124,178,179,176,176,176,176,176,180,010,010 ; 007
	db 010,141,135,135,135,135,135,135,135,142,010,010,010,010,010,010,010,010,010,010,010,010,181,176,176,176,176,176,176,176,182,010 ; 008
	db 010,143,135,135,135,135,135,135,144,010,010,010,010,010,010,010,010,010,010,010,010,010,010,183,176,176,176,176,176,176,184,010 ; 009
	db 010,145,135,135,135,135,135,135,146,010,010,010,010,010,010,010,010,010,010,010,010,010,010,185,176,176,176,176,176,176,186,010 ; 010
	db 010,135,135,135,135,135,135,135,147,011,012,013,014,015,016,017,018,013,014,019,020,013,014,187,176,176,176,176,176,176,176,010 ; 011
	db 010,135,135,135,135,135,135,135,148,021,010,022,023,024,025,026,027,022,023,028,029,022,023,188,176,176,176,176,176,176,176,010 ; 012
	db 010,149,135,135,135,135,135,135,150,010,010,010,010,010,010,010,010,010,010,010,010,010,010,189,176,176,176,176,176,176,190,010 ; 013
	db 010,151,135,135,135,135,135,135,152,010,010,010,010,010,010,010,010,010,010,010,010,010,010,191,176,176,176,176,176,176,192,010 ; 014
	db 010,153,135,135,135,135,135,135,135,154,010,010,010,010,010,010,010,010,010,010,010,010,193,176,176,176,176,176,176,176,194,010 ; 015
	db 010,010,155,135,135,135,135,135,156,157,208,209,010,010,010,010,010,010,010,010,210,211,195,196,176,176,176,176,176,197,010,010 ; 016
	db 010,010,158,159,135,135,135,160,161,212,213,214,215,216,217,010,010,218,219,220,221,222,223,198,199,176,176,176,200,201,010,010 ; 017
	db 010,010,010,162,159,163,164,224,225,226,226,226,226,226,226,226,226,226,226,226,226,226,226,227,228,202,203,200,204,010,010,010 ; 018
	db 010,010,010,010,165,166,229,230,226,226,226,226,226,226,226,226,226,226,226,226,226,226,226,226,231,232,205,206,010,010,010,010 ; 019
	db 010,010,010,010,010,010,233,234,226,226,226,226,226,226,226,226,226,226,226,226,226,226,226,226,235,236,010,010,010,010,010,010 ; 020
	db 010,010,010,010,010,010,010,237,238,239,226,226,226,226,226,226,226,226,226,226,226,226,240,241,242,010,010,010,010,010,010,010 ; 021
	db 010,010,010,010,010,010,010,010,010,010,243,244,245,246,247,226,226,248,249,250,251,252,010,010,010,010,010,010,010,010,010,010 ; 022
	db 010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010,010 ; 023

bounce:
	db 081h, 054h, 010h, 002h, 023h, 007h
	db $90 ; end
	dw $0000

SoundDataCount:		equ 7
Len_SoundDataArea:	equ 10*SoundDataCount+1 	; 7 data areas
SoundAddrs:
	dw bounce,SoundDataArea				; 1 ball bounce sound
	dw 0,0

	include "../../../include/bcd.asm"
	include "../../../include/library.asm"

END:	equ $

	org RAMSTART

PSTATE:		ds 1
PCOUNT:		ds 1
CCOUNT:		ds 1
CPATRN:		ds 64

SoundDataArea:
	ds Len_SoundDataArea
