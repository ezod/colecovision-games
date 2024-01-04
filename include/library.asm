; ColecoVision Library

; Set address called inside NMI routine
; HL -> hook address
SET_VDU_HOOK:
	ld 	a,$cd
	ld 	(VDU_HOOK),a
	ld 	(VDU_HOOK+1),hl
	ld 	a,$c9
	ld 	(VDU_HOOK+3),a
	ret

; Disable the generation of NMI calls
DISABLE_NMI:
	ld 	a,($73c4)
	and 	$df
DNMI1:
	ld 	c,a
	ld 	b,1
	jp 	$1fd9

; Enable the generation of NMI calls
ENABLE_NMI:
	ld 	a,($73c4)
	or 	$20
	call 	DNMI1
	jp 	$1fdc

; Set the name table to default values
; DE -> VRAM offset
SET_DEF_NAME_TBL:
	ld 	c,VDP_CTRL_PORT
	di
	out 	(c),e
	set 	6,d
	out 	(c),d
	ei
	ld 	c,VDP_DATA_PORT
	ld 	d,3
SDNT1:
	xor 	a
SDNT2:
	out 	(c),a
	nop
	inc 	a
	jp 	nz,SDNT2
	dec 	d
	jp 	nz,SDNT1
	ret

; Uncompress RLE data into VRAM
; HL -> source data
; DE -> VRAM starting location
RLE2VRAM:
	di
	ld 	c,VDP_CTRL_PORT
	out 	(c),e
	set 	6,d
	out 	(c),d
	ei
	ld 	c,VDP_DATA_PORT
RLE2V0:
	ld 	a,(hl)
	inc 	hl
	cp 	$ff
	ret 	z
	bit 	7,a
	jr 	z,RLE2V2
	and 	$7f
	inc 	a
	ld 	b,a
	ld 	a,(hl)
	inc 	hl
RLE2V1:
	out 	(c),a
	nop
	nop
	djnz 	RLE2V1
	jr 	RLE2V0
RLE2V2:
	inc 	a
	ld 	b,a
RLE2V3:
	outi
	jr 	z,RLE2V0
	jp 	RLE2V3

; Uncompress RLE data into RAM
; HL -> source data
; DE -> destination
RLE2RAM:
RLE2R0:
	ld 	a,(hl)
	inc 	hl
	cp 	$ff
	ret 	z
	bit 	7,a
	jr 	z,RLE2R2
	and 	$7f
	inc 	a
	ld 	b,a
	ld 	a,(hl)
	inc 	hl
RLE2R1:
	ld 	(de),a
	inc 	de
	djnz 	RLE2R1
	jr 	RLE2R0
RLE2R2:
	inc 	a
	ld 	b,a
	ldir
	jr 	RLE2R0

; Write to VDP
; B  -> port
; C  -> value
WRTVDP:
	di
	ld 	a,b
	out 	(VDP_CTRL_PORT),a
	ld 	a,c
	or 	$80
	out 	(VDP_CTRL_PORT),a
	ei
	push 	hl
	ld 	a,b
	ld 	b,0
	ld 	hl,$f3df
	add 	hl,bc
	ld 	(hl),a
	pop 	hl
	ret

; Set write to VRAM
; HL -> VRAM address
SETWRT:
	di
	ld 	a,l
	out	(VDP_CTRL_PORT),a
	ld 	a,h
	and 	$3f
	or 	$40
	out 	(VDP_CTRL_PORT),a
	ei
	ret

; Set read to VRAM
; HL -> VRAM Address
SETRD:
	di
	ld 	a,l
	out 	(VDP_CTRL_PORT),a
	ld 	a,h
	and 	$3f
	out 	(VDP_CTRL_PORT),a
	ei
	ret

; Load a block of memory to VRAM
; HL -> VRAM Address
; DE -> RAM Address
; BC -> Length
LDIRVM:
	call 	SETWRT
LLOOP:
	ld 	a,(de)
	out 	(VDP_DATA_PORT),a
	inc 	de
	dec 	bc
	ld 	a,c
	or	b
	cp 	0
	jr 	nz,LLOOP
	ret

; Fill a section of VRAM with value
; HL -> VRAM address
; BC -> length
; A  -> value
FILVRM:
	ld 	e,a
	call 	SETWRT
FLOOP:
	ld 	a,e
	out 	(VDP_DATA_PORT),a
	dec 	bc
	ld 	a,c
	or 	b
	cp 	0
	jr 	nz,FLOOP
	ret

; Write sprite positions to VRAM
; - writes sprites in reverse order every 2nd screen refresh
; - this allows for eight sprites per line, with flickering
; - only when there are five or more sprites on a line
SPRWRT:
	ld 	a,(SPRORDER)
	bit 	0,a
	jr 	nz,SW1
	; write sprites normal order
	set 	0,a
	ld 	(SPRORDER),a
	ld 	hl,VRAM_SPRATTR
	ld 	de,SPRTBL
	ld 	bc,$80
	call 	LDIRVM
	ret
SW1:
	; write sprites reverse order
	res 	0,a
	ld 	(SPRORDER),a
	ld 	hl,VRAM_SPRATTR
	call 	SETWRT
	ld 	ix,SPRTBL+$80-4
	ld 	c,32
SW2:
	ld 	a,(ix+0)
	out 	(VDP_DATA_PORT),a
	ld 	a,(ix+1)
	out 	(VDP_DATA_PORT),a
	ld 	a,(ix+2)
	out 	(VDP_DATA_PORT),a
	ld 	a,(ix+3)
	out 	(VDP_DATA_PORT),a
	dec 	ix
	dec 	ix
	dec 	ix
	dec 	ix
	dec 	c
	xor 	a
	cp 	c
	jr 	nz,SW2
	ret

; Setup Screen 0,0 - Interrupts are disabled
SETSCREEN0:
	ld 	bc,$0000	; reg 0: mode 0
	call	WRITE_REGISTER
	ld 	bc,$0206	; name table 1800h
	call	WRITE_REGISTER
	ld 	bc,$0380	; color table 2000h
	call	WRITE_REGISTER
	ld 	bc,$0400	; pattern table 0000h
	call	WRITE_REGISTER
	ld 	bc,$0536	; sprite attribute table 1b00h
	call	WRITE_REGISTER
	ld 	bc,$0607	; sprite pattern table 3800h
	call	WRITE_REGISTER
	ld 	bc,$0700	; base colors
	call	WRITE_REGISTER
	ld 	bc,$01c2	; reg 1: mode 0, 16k, no interrupts, 16x16 sprites
	call	WRITE_REGISTER
	ret

; Setup Screen 2,2 - Interrupts are disabled
SETSCREEN2:
	ld 	bc,$0002	; reg 0: mode 2
	call	WRITE_REGISTER
	ld 	bc,$0206	; name table 1800h
	call	WRITE_REGISTER
	ld 	bc,$03ff        ; color table 2000h
	call 	WRITE_REGISTER
	ld 	bc,$0403        ; pattern table 0000h
	call 	WRITE_REGISTER
	ld 	bc,$0536	; sprite attribute table 1b00h
	call	WRITE_REGISTER
	ld 	bc,$0607	; sprite pattern table 3800h
	call	WRITE_REGISTER
	ld 	bc,$0700	; base colors
	call	WRITE_REGISTER
	ld 	bc,$01c2	; reg 1: mode 2, 16k, no interrupts, 16x16 sprites
	call	WRITE_REGISTER
	ret

; Test for the press of a joystick button (0 or 1)
; A  <- 255 - fire button pressed
JOYTST:
	call 	POLLER
	ld 	a,(CONTROLLER_BUFFER+FIRE1)
	or 	a
	jr 	z,JOYTST2
	ld 	a,255
	ret
JOYTST2:
	ld 	a,(CONTROLLER_BUFFER+5)
	and 	$40
	ret 	z
	ld 	a,255
	ret

; Test for a press of a keypad button
; A  <-
JOYPAD:
	call 	POLLER
	ld 	a,(CONTROLLER_BUFFER+KEYPAD1)
	ret

; Test for the direction of joystick 0
; A  <-
JOYDIR:
	call 	POLLER
	ld 	a,(CONTROLLER_BUFFER+JOY1)
	ret

; Output a character to the screen nametable
; (HL) -> character to output
PRINTIT:
	xor 	a 			; clear A
	rld   				; rotate left out of (HL) into A
	inc 	a
	out 	(VDP_DATA_PORT),a
	dec 	a
	rld   				; rotate left out of (HL) into A
	inc 	a
	out 	(VDP_DATA_PORT),a
	dec 	a
	rld
	ret

; Clear the sprites from the screen (set Y=209)
CLEARSPRITES:
	ld 	b,$80
	ld 	de,SPRTBL
CS1:
	ld 	a,209
	ld 	(de),a
	inc 	de
	dec 	b
	ld 	a,b
	cp 	0
	jr 	nz,CS1

; Clear the VDP Pattern table (clears screen)
CLEARPAT:
	ld 	hl,VRAM_NAME
	ld 	bc,768
	xor 	a
	call 	FILVRM
	ret

; Create and enable standard timers
CREATE_TIMERS:
	ld 	hl,(AMERICA)		; how long a second is
	sra 	l
	ld 	h,0
	ld 	a,1			; set to repeating
	call 	REQUEST_SIGNAL
	ld 	(HalfSecTimer),a	; once per half second
	ld 	hl,(AMERICA)		; how long a second is
	sra 	l
	sra 	l
	ld 	h,0
	ld 	a,1			; set to repeating
	call 	REQUEST_SIGNAL
	ld 	(QtrSecTimer),a		; once per quarter second
	ld 	hl,1
	ld 	a,1			; set to repeating
	call 	REQUEST_SIGNAL
	ld 	(TickTimer),a		; happens once per tick
	ret

; Seed random number generator
; HL -> seed
SEED_RANDOM:
	ld 	(SEED),hl
	rr 	h
	rl 	l
	ld 	(SEED+2),hl
	rr 	h
	rl 	l
	ld 	(SEED+4),hl
	rr 	h
	rl 	l
	ld 	(SEED+6),hl
	ret

; Generate a random number
; A  <- random number
RND:
	push 	hl
	push 	bc
	push	de
	ld	de,(SEED+2)
	ld	hl,(SEED)
	ld 	b,5
RLP1:
	rr 	h
	rl 	l
	rr 	d
	rl 	e
	djnz 	RLP1
	ld	b,3
RLP2:
	push 	de
	ld 	de,(SEED)
	or 	a
	sbc 	hl,de
	ex 	de,hl
	pop 	hl
	djnz 	RLP2
	ld 	(SEED),hl
	ld 	(SEED+2),de
	ld 	a,e
	or 	h
	pop 	de
	pop 	bc
	pop 	hl
	ret

; Generate a random number (linear feedback shift register)
; A  <- random number
RND_LFSR:
	ld 	hl,(SEED+4)
	ld 	e,(hl)
	inc 	hl
	ld 	d,(hl)
	inc 	hl
	ld 	c,(hl)
	inc 	hl
	ld 	a,(hl)
	ld 	b,a
	rl 	e
	rl 	d
	rl 	c
	rla
	rl 	e
	rl 	d
	rl 	c
	rla
	rl 	e
	rl 	d
	rl 	c
	rla
	ld 	h,a
	rl 	e
	rl 	d
	rl 	c
	rla
	xor	b
	rl 	e
	rl 	d
	xor 	h
	xor 	c
	xor 	d
	ld 	hl,SEED+6
	ld 	de,SEED+7
	ld 	bc,7
	lddr
	ld 	(de),a
	ret

; NMI routine
; - updates a time counter,
; - plays any songs
; - writes in memory sprite table to VDU
; - calls user defined hook - for other writes
; - update the time counters
NMI:
	push 	af
	push 	bc
	push 	de
	push 	hl
	push 	ix
	push 	iy
	ex 	af,af'
	push 	af
	exx
	push 	bc
	push 	de
	push 	hl
	; update our time counter
	ld 	hl,(TIME)
	dec 	hl
	ld 	(TIME),hl
	; now we can safely call any OS7 calls
	call 	PLAY_SONGS	; update active music
	call 	SOUND_MAN	; prepare for next go at music
	; write sprite table
	call 	SPRWRT
	ld 	a,(VDU_HOOK)
	cp 	$cd
	jr 	nz,NMI2
	call 	VDU_HOOK
NMI2:
	call 	TIME_MGR
	; now restore everything
	pop	hl
	pop 	de
	pop 	bc
	exx
	pop 	af
	ex 	af,af'
	pop 	iy
	pop 	ix
	pop 	hl
	pop 	de
	pop 	bc
	call 	READ_REGISTER	; side effect allows another NMI to happen
	pop af
	retn	; non-maskable interrupt used for:
		; music, processing timers, sprite motion processing

; set origin in Coleco RAM area
	org 	$7000 		; fit common items before the BIOS RAM usage area

TickTimer:		ds 1 	; signal that 3 frames has elapsed
HalfSecTimer:		ds 1 	; signal that 1/2 second has elapsed
QtrSecTimer:		ds 1 	; signal that 1/4 second has elapsed
TIME:			ds 2
SEED:			ds 8
CONTROLLER_BUFFER:	ds 12	; pointer to hand controller input area
MOVDLY:			ds 10	; up to 10 movement timers

	org 	$7030 		; avoid Coleco BIOS RAM usage area

; sprite positions
SPRTBL:			ds $80
SPRORDER:		ds 1 	; flag to indicate the current sprite write direction
TIMER_TABLE:		ds 16	; pointer to timers table (16 timers)
TIMER_DATA_BLOCK:	ds 58	; pointer to timers table for long timers
                            	; 4 bytes * 16 longer than 3 sec timers
VDU_HOOK: 		ds 4 	; NMI VDU delayed writes hook

RAMSTART: 		equ $ 	; start of game-specific RAM
