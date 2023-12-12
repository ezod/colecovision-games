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

	db "GAME TEMPLATE/ELECTRIC ADVENTURES/2020"

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

	; set screen mode 2,2 (16x16 sprites)
	call SETSCREEN2

	; enable both joysticks, buttons, keypads
	ld HL,$9b9b
	ld (CONTROLLER_BUFFER),HL

	; seed random numbers
	ld HL,1967
	call SEED_RANDOM

	; enable timers
	call CREATE_TIMERS

	; do all our VRAM setup
	; NMI is currently disabled

	; send the two sprite definitions to the VDP
	ld HL,VRAM_SPRGEN
	ld DE,SPDATA
	ld BC,32*2
	call LDIRVM

	; clear the screen
	call CLEARPAT

	; clear the color table
	ld HL,VRAM_COLOR
	ld BC,$1800
	ld A,$71
	call FILVRM

	; load the character set, make all three sections the same
	ld HL,0

SLOOP:
	ld DE,CHRDAT
	push HL
	ld BC,36*8
	call LDIRVM
	pop HL
	push HL
	ld BC,VRAM_COLOR
	add HL,BC
	; make numbers yellow
	ld BC,88
	ld A,$a1
	call FILVRM
	pop HL
	ld BC,$800
	add HL,BC
	ld A,H
	cp $18
	jr C,SLOOP

MAIN_SCREEN:
	; read joysticks to clear any false reads
	call JOYTST

	; initial seed random numbers with a random number from BIOS
	call RAND_GEN
	call SEED_RANDOM

	; disable interrupts
	call DISABLE_NMI

	; clean up in case the game left anything on screen
	call CLEARSPRITES
	call SPRWRT

	; clear the screen
	call CLEARPAT
	ld HL,VRAM_NAME+12
	ld DE,MESG1
	ld BC,8
	call LDIRVM

	ld HL,VDU_WRITES
	call SET_VDU_HOOK
	call ENABLE_NMI

	; set initial position, color, and shape of ball
	ld HL,$4040
	ld (SPRTBL),HL
	ld HL,$0500
	ld (SPRTBL+2),HL

	; set initial position, color, and shape of the bat
	ld HL,$80a0
	ld (SPRTBL+4),HL
	ld HL,$0604
	ld (SPRTBL+6),HL

	; set initial velocity of ball (dx = 1, dy = 1)
	ld HL,$0101
	ld (BALL),HL

MLOOP:
	; check that a base tick has occurred
	; ensures consistent movement speed between 50 & 60 hz systems
	ld A,(TickTimer)
	call TEST_SIGNAL
	or A
	jr Z,MLOOP

	call MOVE_BALL
	call MOVE_PLAYER
	jr MLOOP

MOVE_PLAYER:
	call JOYDIR
	bit 1,A
	jr Z,NRIGHT
	; move to the right
	ld A,(SPRTBL+5)
	cp 239
	ret Z
	inc A
	ld (SPRTBL+5),A
	ret
NRIGHT:
	bit 3,A
	ret Z
	; move to the left
	ld A,(SPRTBL+5)
	cp 0
	ret Z
	dec A
	ld (SPRTBL+5),A
	ret

MOVE_BALL:
	; change the current y position
	ld A,(SPRTBL)
	ld B,A
	ld A,(BALL)
	add A,B
	ld (SPRTBL),A
	cp 0
	jr NZ,NOTTOP
	; hit the top
	ld A,1
	ld (BALL),A
	ld B,1
	call PLAY_IT
	jr YDONE
NOTTOP:
	cp 175
	jr NZ,YDONE
	ld A,255
	ld (BALL),A
	ld B,1
	call PLAY_IT
YDONE:
	; change the current x position
	ld A,(SPRTBL+1)
	ld B,A
	ld A,(BALL+1)
	add A,B
	ld (SPRTBL+1),A
	cp 0
	jr NZ,NOTLEFT
	; hit the left
	ld A,1
	ld (BALL+1),A
	ld B,1
	call PLAY_IT
	jr XDONE
NOTLEFT:
	cp 239
	jr NZ,XDONE
	ld A,255
	ld (BALL+1),A
	ld B,1
	call PLAY_IT
XDONE:
	ret

VDU_WRITES:
	ret

CHRDAT:
	db 000,000,000,000,000,000,000,000 ; 0  blank
	db 124,198,198,198,198,198,124,000 ; 1  '0'
	db 024,056,120,024,024,024,024,000 ; 2  '1'
	db 124,198,006,004,024,096,254,000 ; 3  '2'
	db 124,198,006,060,006,198,124,000 ; 4  '3'
	db 024,056,088,152,254,024,024,000 ; 5  '4'
	db 254,192,192,252,006,198,124,000 ; 6  '5'
	db 124,198,192,252,198,198,124,000 ; 7  '6'
	db 254,006,012,012,024,024,024,000 ; 8  '7'
	db 124,198,198,124,198,198,124,000 ; 9  '8'
	db 124,198,198,126,006,198,124,000 ; 10 '9'
	db 056,108,198,198,254,198,198,000 ; 11 'A'
	db 252,198,198,252,198,198,252,000 ; 12 'B'
	db 124,230,192,192,192,230,124,000 ; 13 'C'
	db 252,206,198,198,198,206,252,000 ; 14 'D'
	db 254,192,192,248,192,192,254,000 ; 15 'E'
	db 254,192,192,248,192,192,192,000 ; 16 'F'
	db 124,198,192,192,206,198,124,000 ; 17 'G'
	db 198,198,198,254,198,198,198,000 ; 18 'H'
	db 254,056,056,056,056,056,254,000 ; 19 'I'
	db 126,024,024,024,024,216,248,000 ; 20 'J'
	db 198,204,216,240,248,204,198,000 ; 21 'K'
	db 192,192,192,192,192,192,254,000 ; 22 'L'
	db 130,198,238,254,214,198,198,000 ; 23 'M'
	db 134,198,230,214,206,198,194,000 ; 24 'N'
	db 124,238,198,198,198,238,124,000 ; 25 'O'
	db 252,198,198,252,192,192,192,000 ; 26 'P'
	db 124,198,198,198,214,206,124,000 ; 27 'Q'
	db 252,198,198,252,248,204,198,000 ; 28 'R'
	db 124,198,192,124,006,198,124,000 ; 29 'S'
	db 254,056,056,056,056,056,056,000 ; 30 'T'
	db 198,198,198,198,198,238,124,000 ; 31 'U'
	db 198,198,198,238,108,108,056,000 ; 32 'V'
	db 198,198,214,254,124,108,040,000 ; 33 'X'
	db 198,238,124,056,124,238,198,000 ; 34 'Y'
	db 198,238,124,056,056,056,056,000 ; 35 'Z'

MESG1:
	db 030,015,023,026,022,011,030,015 ; TEMPLATE

SPDATA:
	db 003h,00Fh,01Fh,03Fh,07Fh,07Fh,0FFh,0FFh
	db 0FFh,0FFh,07Fh,07Fh,03Fh,01Fh,00Fh,003h
	db 0C0h,0F0h,0F8h,0FCh,0FEh,0FEh,0FFh,0FFh
	db 0FFh,0FFh,0FEh,0FEh,0FCh,0F8h,0F0h,0C0h
	db 000,000,000,000,000,000,000,000
	db 000,000,000,000,000,000,255,255
	db 000,000,000,000,000,000,000,000
	db 000,000,000,000,000,000,255,255

bounce:
	db 081h, 054h, 010h, 002h, 023h, 007h
	db $90 ; end
	dw $0000

SoundDataCount:		equ 7
Len_SoundDataArea:	equ 10*SoundDataCount+1 	; 7 data areas
SoundAddrs:
	dw bounce,SoundDataArea				; 1 ball bounce sound
	dw 0,0

	include "../../../include/library.asm"

END:	equ $

	org RAMSTART

BALL:   ds 2

SoundDataArea:
	ds Len_SoundDataArea
