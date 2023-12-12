; ColecoVision Library

; Set address called inside NMI routine
; HL = Hook Address
SET_VDU_HOOK:
	ld A,0cdh
	ld (VDU_HOOK),A
	ld (VDU_HOOK+1),HL
	ld A,0c9h
	ld (VDU_HOOK+3),A
	ret

; Disable the generation of NMI calls
DISABLE_NMI:
	ld A,(073c4h)
	and 0dfh
DNMI1:
	ld C,A
	ld B,1
	jp 01fd9h

; Enable the generationo of NMI calls
ENABLE_NMI:
	ld A,(073c4h)
	or 020h
	call DNMI1
	jp 01fdch

; Set the name table to default values
; DE = VRAM Offset
SET_DEF_NAME_TBL:
	ld C,VDP_CTRL_PORT
	di
	out (C),E
	set 6,D
	out (C),D
	ei
	ld C,VDP_DATA_PORT
	ld D,3
SDNT1:
	xor A
SDNT2:
	out (C),A
	nop
	inc A
	jp NZ,SDNT2
	dec D
	jp NZ,SDNT1
	ret

; HL = Source data
; DE = VRam starting location
RLE2VRAM:
	di
	ld C,VDP_CTRL_PORT
	out (C),E
	set 6,D
	out (C),D
	ei
	ld C,VDP_DATA_PORT
RLE2V0:
	ld A,(HL)
	inc HL
	cp 0ffh
	ret Z
	bit 7,A
	jr Z,RLE2V2
	and 07fh
	inc A
	ld B,A
	ld A,(HL)
	inc HL
RLE2V1:
	out (C),A
	nop
	nop
	djnz RLE2V1
	jr RLE2V0
RLE2V2:
	inc A
	ld B,A
RLE2V3:
	outi
	jr Z,RLE2V0
	jp RLE2V3

; Uncompress RLE data into RAM
; HL = Source data
; DE = Destination
RLE2RAM:
RLE2R0:
	ld A,(HL)
	inc HL
	cp 0ffh
	ret Z
	bit 7,A
	jr Z,RLE2R2
	and 07fh
	inc A
	ld B,A
	ld A,(HL)
	inc HL
RLE2R1:
	ld (DE),A
	inc DE
	djnz RLE2R1
	jr RLE2R0
RLE2R2:
	inc A
	ld B,A
	ldir
	jr RLE2R0

; Write to VDP, port in B, value in C
WRTVDP:
	di
	ld A,B
	out (VDP_CTRL_PORT),A
	ld A,C
	or 80h
	out (VDP_CTRL_PORT),A
	ei
	push HL
	ld A,B
	ld B,0
	ld HL,0F3DFh
	add HL,BC
	ld (HL),A
	pop HL
	ret

; Set write to Video Ram
; HL = VRAM Address
SETWRT:
	di
	ld A,L
	out (VDP_CTRL_PORT),A
	ld A,H
	and 3Fh
	or 40h
	out (VDP_CTRL_PORT),A
	ei
	ret
;
; Set read to Video Ram
; HL = VRAM Address
SETRD:
	di
	ld A,L
	out (VDP_CTRL_PORT),A
	ld A,H
	and 3Fh
	out (VDP_CTRL_PORT),A
	ei
	ret

; Load a block of memory to VRAM
; HL = VRAM Address
; DE = RAM Address
; BC = Length
LDIRVM:
	call SETWRT
LLOOP:
	ld A,(DE)
	out (VDP_DATA_PORT),A
	inc DE
	dec BC
	ld A,C
	or B
	cp 0
	jr NZ,LLOOP
	ret

; Fill a section of VRAM with value in A
; HL = VRAM Address
; BC = Length
FILVRM:
	ld E,A
	call SETWRT
FLOOP:
	ld A,E
	out (VDP_DATA_PORT),A
	dec BC
	ld A,C
	or B
	cp 0
	jr NZ,FLOOP
	ret

; Write Sprite positions to VRAM
; - writes sprites in reverse order every 2nd screen refresh
; - this allows for eight sprites per line, with flickering
; - only when there are five or more sprites on a line
SPRWRT:
	ld A,(SPRORDER)
	bit 0,A
	jr NZ,SW1
	; write sprites normal order
	set 0,A
	ld (SPRORDER),A
	ld HL,VRAM_SPRATTR
	ld DE,SPRTBL
	ld BC,80h
	call LDIRVM
	ret
SW1:
	; write sprites reverse order
	res 0,A
	ld (SPRORDER),A
	ld HL,VRAM_SPRATTR
	call SETWRT
	ld IX,SPRTBL+80h-4
	ld C,32
SW2:
	ld A,(IX+0)
	out (VDP_DATA_PORT),A
	ld A,(IX+1)
	out (VDP_DATA_PORT),A
	ld A,(IX+2)
	out (VDP_DATA_PORT),A
	ld A,(IX+3)
	out (VDP_DATA_PORT),A
	dec IX
	dec IX
	dec IX
	dec IX
	dec C
	xor A
	cp C
	jr NZ,SW2
	ret

; Setup Screen 2,2 - Interrupts are disabled
SETSCREEN2:
	ld BC,0002h	;Reg 0: Mode 2
	call WRITE_REGISTER
	ld BC,0206h        ; Name table 1800h
	call WRITE_REGISTER
	ld BC,03ffh        ; Colour table 2000h
	call WRITE_REGISTER
	ld BC,0403h        ; Pattern table 0000h
	call WRITE_REGISTER
	ld BC,0536h        ; Sprite attribute table 1b00h
	call WRITE_REGISTER
	ld BC,0607h        ; Sprite pattern table 3800h
	call WRITE_REGISTER
	ld BC,0700h        ; Base colours
	call WRITE_REGISTER
	ld BC,01c2h	;Reg 1: Mode 2, 16k, no interrupts, 16x16 sprites
	call WRITE_REGISTER
	ret

; Test for the press of a joystick button (0 or 1)
; A = 255 - fire button pressed
JOYTST:
	call POLLER
	ld A,(CONTROLLER_BUFFER+FIRE1)
	or A
	jr Z,JOYTST2
	ld A,255
	ret
JOYTST2:
	ld A,(CONTROLLER_BUFFER+5)
	and 040h
	ret Z
	ld A,255
	ret

; Test for a press of a keypad button
JOYPAD:
	call POLLER
	ld A,(CONTROLLER_BUFFER+KEYPAD1)
	ret
;
; Test for the direction of joystick 0
; Result: A
JOYDIR:
	call POLLER
	ld A,(CONTROLLER_BUFFER+JOY1)
	ret
;
; Play a sound, protects the calling routine from common registers being changed
; B = Sound to play
SOUND:
	push IX
	push IY
	push HL
	push DE
	call PLAY_IT
	pop DE
	pop HL
	pop IY
	pop IX
	ret

; Output a character to the screen nametable
; (HL) contains the character to output
PRINTIT:
	xor A ; clear A
	rld   ; rotate left out of (HL) into A
	inc A
	out (VDP_DATA_PORT),A
	dec A
	rld   ; rotate left out of (HL) into A
	inc A
	out (VDP_DATA_PORT),A
	dec A
	rld
	ret

; Clear the sprites from the screen (set Y=209)
CLEARSPRITES:
	ld B,80h
	ld DE,SPRTBL
CS1:
	ld A,209
	ld (DE),A
	inc DE
	dec B
	ld A,B
	cp 0
	jr NZ,CS1

; Clear the VDP Pattern table (clears screen)
CLEARPAT:
	ld HL,VRAM_NAME
	ld BC,768
	xor A
	call FILVRM
	ret

; Create and enable standard timers
CREATE_TIMERS:
	ld HL,(AMERICA)	;How long a second is
	sra L
	ld H,0
	ld A,1	;set to repeating
	call REQUEST_SIGNAL
	ld (HalfSecTimer),A		;Happens once per half second
	ld HL,(AMERICA)	;How long a second is
	sra L
	sra L
	ld H,0
	ld A,1	;set to repeating
	call REQUEST_SIGNAL
	ld (QtrSecTimer),A		;Happens once per quarter second
	ld HL,1
	ld A,1	;set to repeating
	call REQUEST_SIGNAL
	ld (TickTimer),A		;Happens once per tick
	ret

;   Seed Random numbers
;   Seed in HL
SEED_RANDOM:
	ld (SEED),HL
	rr H
	rl L
	ld (SEED+2),HL
	ret

;   Generate a random number, based on the initial Seed
;   value.
RND:
	push HL
	push BC
	push DE
	ld DE,(SEED+2)
	ld HL,(SEED)
	ld B,5
RLP1:
	rr H
	rl L
	rr D
	rl E
	djnz RLP1
	ld B,3
RLP2:
	push DE
	ld DE,(SEED)
	or A
	sbc HL,DE
	ex DE,HL
	pop HL
	djnz RLP2
	ld (SEED),HL
	ld (SEED+2),DE
	ld A,E
	or H
	pop DE
	pop BC
	pop HL
	ret

; NMI routine
; - updates a time counter,
; - plays any songs
; - writes in memory sprite table to VDU
; - calls user defined hook - for other writes
; - update the time counters
NMI:
	push AF
	push BC
	push DE
	push HL
	push IX
	push IY
	ex AF,AF'
	push AF
	exx
	push BC
	push DE
	push HL
	; update our time counter
	ld HL,(TIME)
	dec HL
	ld (TIME),HL
	;Now we can safely call any OS7 calls
	call PLAY_SONGS	;Update active music
	call SOUND_MAN	;Prepare for next go at music
	; write sprite table
	call SPRWRT
	ld A,(VDU_HOOK)
	cp 0cdh
	jr NZ,NMI2
	call VDU_HOOK
NMI2:
	call TIME_MGR

;Now restore everything
	pop HL
	pop DE
	pop BC
	exx
	pop AF
	ex AF,AF'
	pop IY
	pop IX
	pop HL
	pop DE
	pop BC

	call READ_REGISTER	;Side effect allows another NMI to happen

	pop AF

	retn	;Non maskable interrupt used for:
		;music, processing timers, sprite motion processing

; Set origin in Coleco RAM area
	org $7000 ; fit common items before the BIOS RAM usage area

TickTimer:		ds 1 ; Signal that 3 frames has elapsed
HalfSecTimer:		ds 1 ; Signal that 1/2 second has elapsed
QtrSecTimer:		ds 1 ; Signal that 1/4 second has elapsed
TIME:			ds 2
SEED:			ds 4
CONTROLLER_BUFFER:	ds 12	;Pointer to hand controller input area
MOVDLY:			ds 10      ; Up to 10 movement timers

	org $7030 ; avoid Coleco BIOS RAM usage area

; Sprite positions
SPRTBL:			ds 80h
SPRORDER:		ds 1 ; flag to indicate the current sprite write direction
TIMER_TABLE:		ds 16	;Pointer to timers table (16 timers)
TIMER_DATA_BLOCK:	ds 58	;Pointer to timers table for long timers
                            ;4 bytes * 16 longer than 3 sec timers
VDU_HOOK: 		ds 4 ; NMI VDU Delayed writes hook

RAMSTART: 		equ $ ; Setup where game specific values can start
