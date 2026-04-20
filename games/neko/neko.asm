; COLECO NEKO
; Neko for the ColecoVision.

        include "coleco.asm"

; --- Neko game constants ---
NEKO_SPEED      equ 1
NEKO_CLOSE      equ 12
ANIM_RATE       equ 12
TMRAWAKE        equ 40
TMRSTOP         equ 45
TMRSCRATCH      equ 180
TMRYAWN         equ 45

; Neko states
NS_AWAKE        equ 0
NS_STOP         equ 1
NS_SCRATCH      equ 2
NS_YAWN         equ 3
NS_SLEEP        equ 4
NS_RUN_N        equ 5

	org     $8000

	db      $aa,$55			; ColecoVision title screen
	dw      0000			; pointer to sprite name table
	dw      0000			; pointer to sprite order table
	dw      0000			; pointer to working buffer for WR_SPR_NM_TBL
	dw      CONTROLLER_BUFFER	; pointer to controller input areas
	dw      START			; entry point

rst_8:
	reti
	nop
rst_10:
	reti
	nop
rst_18:
	jp      RAND_GEN
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
	jp      NMI

	db      "COLECO NEKO/LOGICK WORKSHOP PRESENTS/2026"

START:
	ld 	sp,StackTop

	; initialize sound
	ld 	b,SoundDataCount
	ld 	hl,SoundAddrs
	call 	SOUND_INIT

	; initialize clock
	ld 	hl,TIMER_TABLE
	ld 	de,TIMER_DATA_BLOCK
	call 	INIT_TIMER

	; set screen mode 2 (aka graphics 2)
	call 	SETSCREEN2

	; enable both joysticks, buttons, keypads
	ld 	hl,$9b9b
	ld 	(CONTROLLER_BUFFER),hl

	; enable timers
	call 	CREATE_TIMERS

	; load all 8 idle neko frames into VRAM (frames 0-7, 1024 bytes)
	ld 	hl,VRAM_SPRGEN
	ld 	de,SPNEKO
	ld 	bc,8*128
	call 	LDIRVM

	; load initial running frames direction N (2 frames, 256 bytes) at VRAM+1024
	ld	hl,VRAM_SPRGEN+1024
	ld	de,SPNEKO+1024
	ld	bc,256
	call	LDIRVM

        ; load both mouse sprite frames at VRAM+1280 (left=160, right=164)
        ld      hl,VRAM_SPRGEN+1280
        ld      de,SPMOUSE
        ld      bc,64
        call    LDIRVM

	; white backdrop (register 7)
	ld 	bc,$070f
	call 	WRITE_REGISTER

	; fill color table: white background for all rows
	ld 	hl,VRAM_COLOR
	ld 	bc,$1800
	ld 	a,$0f
	call 	FILVRM

	; clear name table (all tile 0)
	ld 	hl,VRAM_NAME
	ld 	bc,768
	xor 	a
	call 	FILVRM

MAIN_SCREEN:
        ; read joysticks to clear any false reads
        call    JOYTST

        ; disable interrupts
        call    DISABLE_NMI

	; clear sprite table and push to VRAM
	call 	CLEARSPRITES
	call 	SPRWRT

        ; clear the screen
        call    CLEARPAT

	; enable NMI to drive sprite writes to VDP each frame
	ld 	hl,VDU_WRITES
	call 	SET_VDU_HOOK
	call 	ENABLE_NMI

	; initial neko state and position
	ld	a,79
	ld	(NEKO_Y),a
	ld	a,112
	ld	(NEKO_X),a
	ld	a,NS_SLEEP
	ld	(NEKO_STATE),a
	xor	a
	ld	(NEKO_ANIM),a
	ld	a,ANIM_RATE
	ld	(NEKO_ANIM_TMR),a
	xor	a
	ld	(NEKO_IDLE_TMR),a
	ld	(NEKO_DIR),a
	ld	a,$ff
	ld	(NEKO_RELOAD),a

	; initial mouse position
	ld	a,140
	ld	(MOUSE_Y),a
	ld	a,120
	ld	(MOUSE_X),a
	xor	a
	ld	(MOUSE_ACNT),a
	ld	(MOUSE_FACING),a

	; place initial sprites
	ld	b,128
	call	UPDATE_NEKO_SPRITES

	; mouse sprite (sprite 4 at SPRTBL+16): Y, X, pattern 160, color
	ld	hl,SPRTBL+16
	ld	a,(MOUSE_Y)
	ld	(hl),a
	inc	hl
	ld	a,(MOUSE_X)
	ld	(hl),a
	inc	hl
	ld	(hl),160
	inc	hl
	ld	(hl),COLOR_BLACK

MLOOP:
	ld 	a,(TickTimer)
	call 	TEST_SIGNAL
	or 	a
	jr 	z,MLOOP

	call 	MOVE_NEKO
	call 	MOVE_MOUSE
	jr 	MLOOP

MOVE_NEKO:
	; compute abs center-to-center dx: |(NEKO_X+16) - (MOUSE_X+8)|
	ld	a,(MOUSE_X)
	add	a,8			; mouse center X
	ld	b,a
	ld	a,(NEKO_X)
	add	a,16			; neko center X
	sub	b
	jr	nc,MN_DX_POS
	neg
MN_DX_POS:
	ld	c,a			; C = abs(center dx)

	; compute abs center-to-center dy: |(NEKO_Y+16) - (MOUSE_Y+8)|
	ld	a,(MOUSE_Y)
	add	a,8			; mouse center Y
	ld	b,a
	ld	a,(NEKO_Y)
	add	a,16			; neko center Y
	sub	b
	jr	nc,MN_DY_POS
	neg
MN_DY_POS:
	ld	e,a			; E = abs(center dy)

	; check if neko has reached the mouse
	ld	a,c
	cp	NEKO_CLOSE
	jr	nc,MN_CHASE
	ld	a,e
	cp	NEKO_CLOSE
	jp	nc,MN_CHASE
	jp	MN_IDLE

MN_CHASE:
	; brief wakeup pause when transitioning from idle to running
	ld	a,(NEKO_STATE)
	cp	NS_RUN_N
	jr	nc,MN_DO_CHASE		; already running, skip wakeup
	cp	NS_AWAKE
	jr	z,MN_WAKING		; already in wakeup, tick timer
	; was deeper idle: enter wakeup
	ld	a,NS_AWAKE
	ld	(NEKO_STATE),a
	ld	a,TMRAWAKE
	ld	(NEKO_IDLE_TMR),a
MN_WAKING:
	ld	hl,NEKO_IDLE_TMR
	ld	a,(hl)
	or	a
	jr	z,MN_DO_CHASE		; timer expired, begin chase
	dec	a
	ld	(hl),a
	ld	b,0			; awake sprite (pattern base 0)
	call	UPDATE_NEKO_SPRITES
	ret

MN_DO_CHASE:
	; determine x-sign: 0=same, 1=east, 2=west
	ld	a,(NEKO_X)
	ld	b,a
	ld	a,(MOUSE_X)
	cp	b
	ld	d,0
	jr	z,MN_XS_DONE
	jr	c,MN_XS_WEST
	ld	d,1			; east
	jr	MN_XS_DONE
MN_XS_WEST:
	ld	d,2			; west
MN_XS_DONE:

	; determine y-sign: 0=same, 1=south, 2=north
	ld	a,(NEKO_Y)
	ld	b,a
	ld	a,(MOUSE_Y)
	cp	b
	ld	h,0
	jr	z,MN_YS_DONE
	jr	c,MN_YS_NORTH
	ld	h,1			; south
	jr	MN_YS_DONE
MN_YS_NORTH:
	ld	h,2			; north
MN_YS_DONE:

	; diagonal pruning:
	; if abs(dy) > 2*abs(dx) -> pure N/S, clear xsign
	; if abs(dx) > 2*abs(dy) -> pure E/W, clear ysign
	ld	a,c
	add	a,a			; A = 2*abs(dx)
	jr	c,MN_NO_PURENS		; overflow: definitely not pure NS
	cp	e
	jr	nc,MN_NO_PURENS		; 2*abs(dx) >= abs(dy): not pure NS
	ld	d,0			; pure N/S
	jr	MN_DIR_DONE
MN_NO_PURENS:
	ld	a,e
	add	a,a			; A = 2*abs(dy)
	jr	c,MN_DIR_DONE		; overflow: not pure EW
	cp	c
	jr	nc,MN_DIR_DONE
	ld	h,0			; pure E/W
MN_DIR_DONE:

	; direction = DIRMAP[ysign*3 + xsign]
	ld	a,h
	ld	b,a
	add	a,b
	add	a,b			; A = 3*ysign
	add	a,d			; A = 3*ysign + xsign
	ld	hl,DIRMAP
	ld	b,0
	ld	c,a
	add	hl,bc
	ld	a,(hl)			; A = direction 0-7
	ld	b,a

	; if direction changed, schedule VRAM reload via VDU_WRITES
	ld	a,(NEKO_DIR)
	cp	b
	jr	z,MN_NO_RELOAD
	ld	a,b
	ld	(NEKO_DIR),a
	ld	(NEKO_RELOAD),a
MN_NO_RELOAD:

	; move X toward mouse
	ld	a,(NEKO_X)
	ld	b,a
	ld	a,(MOUSE_X)
	cp	b
	jr	z,MN_NO_XMOVE
	jr	c,MN_MOVE_W
	ld	a,b
	add	a,NEKO_SPEED
	jr	c,MN_XMAX
	cp	225
	jr	c,MN_SAVE_X
MN_XMAX:
	ld	a,224
	jr	MN_SAVE_X
MN_MOVE_W:
	ld	a,b
	sub	NEKO_SPEED
	jr	nc,MN_SAVE_X
	xor	a
MN_SAVE_X:
	ld	(NEKO_X),a
MN_NO_XMOVE:

	; move Y toward mouse
	ld	a,(NEKO_Y)
	ld	b,a
	ld	a,(MOUSE_Y)
	cp	b
	jr	z,MN_NO_YMOVE
	jr	c,MN_MOVE_N
	ld	a,b
	add	a,NEKO_SPEED
	jr	c,MN_YMAX
	cp	161
	jr	c,MN_SAVE_Y
MN_YMAX:
	ld	a,160
	jr	MN_SAVE_Y
MN_MOVE_N:
	ld	a,b
	sub	NEKO_SPEED
	jr	nc,MN_SAVE_Y
	xor	a
MN_SAVE_Y:
	ld	(NEKO_Y),a
MN_NO_YMOVE:

	; animation timer
	ld	hl,NEKO_ANIM_TMR
	ld	a,(hl)
	dec	a
	jr	nz,MN_RUN_TMR_SAVE
	ld	(hl),ANIM_RATE
	ld	hl,NEKO_ANIM
	ld	a,(hl)
	xor	1
	ld	(hl),a
	jr	MN_RUN_ANIM
MN_RUN_TMR_SAVE:
	ld	(hl),a
MN_RUN_ANIM:
	; pattern base: 128 (run-A) or 144 (run-B)
	ld	a,(NEKO_ANIM)
	or	a
	ld	b,128
	jr	z,MN_RUN_SPR
	ld	b,144
MN_RUN_SPR:
	ld	a,NS_RUN_N
	ld	(NEKO_STATE),a
	call	UPDATE_NEKO_SPRITES
	ret

MN_IDLE:
	; if running, transition to STOP
	ld	a,(NEKO_STATE)
	cp	NS_RUN_N
	jr	c,MN_IDLE_TICK
	ld	a,NS_STOP
	ld	(NEKO_STATE),a
	ld	a,TMRSTOP
	ld	(NEKO_IDLE_TMR),a

MN_IDLE_TICK:
	ld	hl,NEKO_IDLE_TMR
	ld	a,(hl)
	or	a
	jr	z,MN_IDLE_TRANS
	dec	a
	ld	(hl),a
	jr	MN_IDLE_DISP

MN_IDLE_TRANS:
	ld	a,(NEKO_STATE)
	cp	NS_STOP
	jr	nz,MN_CHK_SCR
	ld	a,NS_SCRATCH
	ld	(NEKO_STATE),a
	ld	a,TMRSCRATCH
	ld	(NEKO_IDLE_TMR),a
	jr	MN_IDLE_DISP
MN_CHK_SCR:
	cp	NS_SCRATCH
	jr	nz,MN_CHK_YWN
	ld	a,NS_YAWN
	ld	(NEKO_STATE),a
	ld	a,TMRYAWN
	ld	(NEKO_IDLE_TMR),a
	jr	MN_IDLE_DISP
MN_CHK_YWN:
	cp	NS_YAWN
	jr	nz,MN_IDLE_DISP
	ld	a,NS_SLEEP
	ld	(NEKO_STATE),a
	xor	a
	ld	(NEKO_IDLE_TMR),a

MN_IDLE_DISP:
	; animation timer
	ld	hl,NEKO_ANIM_TMR
	ld	a,(hl)
	dec	a
	jr	nz,MN_IDLE_TMR_SAVE
	ld	(hl),ANIM_RATE
	ld	hl,NEKO_ANIM
	ld	a,(hl)
	xor	1
	ld	(hl),a
	jr	MN_IDLE_PAT
MN_IDLE_TMR_SAVE:
	ld	(hl),a

MN_IDLE_PAT:
	; pattern base for current idle state
	ld	a,(NEKO_STATE)
	cp	NS_STOP
	jr	z,MN_PAT_STOP
	cp	NS_SCRATCH
	jr	z,MN_PAT_SCR
	cp	NS_YAWN
	jr	z,MN_PAT_YWN
	cp	NS_SLEEP
	jr	z,MN_PAT_SLP
	ld	b,0			; awake
	jr	MN_IDLE_SPR
MN_PAT_STOP:
	ld	b,16
	jr	MN_IDLE_SPR
MN_PAT_SCR:
	ld	b,48
	ld	a,(NEKO_ANIM)
	or	a
	jr	z,MN_IDLE_SPR
	ld	b,64
	jr	MN_IDLE_SPR
MN_PAT_YWN:
	ld	b,80
	jr	MN_IDLE_SPR
MN_PAT_SLP:
	ld	b,96
	ld	a,(NEKO_ANIM)
	or	a
	jr	z,MN_IDLE_SPR
	ld	b,112
MN_IDLE_SPR:
	call	UPDATE_NEKO_SPRITES
	ret

DIRMAP:
	; indexed by ysign*3 + xsign
	; ysign: 0=pure EW, 1=south, 2=north
	; xsign: 0=pure NS, 1=east, 2=west
	; values: 0=N 1=NE 2=E 3=SE 4=S 5=SW 6=W 7=NW
	db	0,2,6,4,3,5,0,1,7

UPDATE_NEKO_SPRITES:
	; B = pattern base; writes SPRTBL sprites 0-3 using NEKO_X/NEKO_Y
	ld	hl,SPRTBL
	; TL: Y=NEKO_Y, X=NEKO_X, pattern=B
	ld	a,(NEKO_Y)
	ld	(hl),a
	inc	hl
	ld	a,(NEKO_X)
	ld	(hl),a
	inc	hl
	ld	(hl),b
	inc	hl
	ld	(hl),COLOR_BLACK
	inc	hl
	; BL: Y=NEKO_Y+16, X=NEKO_X, pattern=B+4
	ld	a,(NEKO_Y)
	add	a,16
	ld	(hl),a
	inc	hl
	ld	a,(NEKO_X)
	ld	(hl),a
	inc	hl
	ld	a,b
	add	a,4
	ld	(hl),a
	inc	hl
	ld	(hl),COLOR_BLACK
	inc	hl
	; TR: Y=NEKO_Y, X=NEKO_X+16, pattern=B+8
	ld	a,(NEKO_Y)
	ld	(hl),a
	inc	hl
	ld	a,(NEKO_X)
	add	a,16
	ld	(hl),a
	inc	hl
	ld	a,b
	add	a,8
	ld	(hl),a
	inc	hl
	ld	(hl),COLOR_BLACK
	inc	hl
	; BR: Y=NEKO_Y+16, X=NEKO_X+16, pattern=B+12
	ld	a,(NEKO_Y)
	add	a,16
	ld	(hl),a
	inc	hl
	ld	a,(NEKO_X)
	add	a,16
	ld	(hl),a
	inc	hl
	ld	a,b
	add	a,12
	ld	(hl),a
	inc	hl
	ld	(hl),COLOR_BLACK
	ret

MOVE_MOUSE:
	call 	JOYDIR
	or 	a
	jr 	z,MM_STOP

	ld 	b,a

	; ramp up hold counter, cap at 30
	ld 	a,(MOUSE_ACNT)
	cp 	30
	jr 	nc,MM_SPD
	inc 	a
	ld 	(MOUSE_ACNT),a
MM_SPD:
	; derive speed: 0-9=1, 10-19=2, 20-29=3, 30+=4
	ld 	a,(MOUSE_ACNT)
	cp 	30
	jr 	nc,MM_S4
	cp 	20
	jr 	nc,MM_S3
	cp 	10
	jr 	nc,MM_S2
	ld 	c,1
	jr 	MM_XMOVE
MM_S4:	ld 	c,4
	jr 	MM_XMOVE
MM_S3:	ld 	c,3
	jr 	MM_XMOVE
MM_S2:	ld 	c,2

MM_XMOVE:
	; east: move right, clamp at X=240 (right edge of 16-wide sprite)
	bit 	1,b
	jr 	z,MM_WEST
	ld 	a,(MOUSE_X)
	add 	a,c
	jr 	c,MM_XMAX
	cp 	241
	jr 	c,MM_SAVEX
MM_XMAX:
	ld 	a,240
MM_SAVEX:
	ld 	(MOUSE_X),a
	ld	a,1
	ld	(MOUSE_FACING),a	; moving east: right-facing
	jr 	MM_YMOVE

MM_WEST:
	; west: move left, clamp at X=0
	bit 	3,b
	jr 	z,MM_YMOVE
	ld 	a,(MOUSE_X)
	sub 	c
	jr 	nc,MM_SAVEX2
	xor 	a
MM_SAVEX2:
	ld 	(MOUSE_X),a
	xor	a
	ld	(MOUSE_FACING),a	; moving west: left-facing

MM_YMOVE:
	; south: move down, clamp at Y=175 (bottom edge of 16-tall sprite)
	bit 	2,b
	jr 	z,MM_NORTH
	ld 	a,(MOUSE_Y)
	add 	a,c
	jr 	c,MM_YMAX
	cp 	176
	jr 	c,MM_SAVEY
MM_YMAX:
	ld 	a,175
MM_SAVEY:
	ld 	(MOUSE_Y),a
	jr 	MM_UPDATE

MM_NORTH:
	; north: move up, clamp at Y=0
	bit 	0,b
	jr 	z,MM_UPDATE
	ld 	a,(MOUSE_Y)
	sub 	c
	jr 	nc,MM_SAVEY2
	xor 	a
MM_SAVEY2:
	ld 	(MOUSE_Y),a
	jr 	MM_UPDATE

MM_STOP:
	; no direction held: reset acceleration
	xor 	a
	ld 	(MOUSE_ACNT),a

MM_UPDATE:
	; write mouse position and facing into sprite table (sprite 4)
	ld	a,(MOUSE_Y)
	ld	hl,SPRTBL+16
	ld	(hl),a
	inc	hl
	ld	a,(MOUSE_X)
	ld	(hl),a
	inc	hl
	ld	a,(MOUSE_FACING)
	or	a
	ld	a,160			; left-facing
	jr	z,MM_SAVE_PAT
	ld	a,164			; right-facing
MM_SAVE_PAT:
	ld	(hl),a
	ret

VDU_WRITES:
	; load running frames for new direction when NEKO_RELOAD != $ff
	ld	a,(NEKO_RELOAD)
	cp	$ff
	ret	z
	; HL = SPNEKO + 1024 + direction*256 (source)
	ld	h,a
	ld	l,0
	ld	de,SPNEKO+1024
	add	hl,de
	ex	de,hl
	ld	hl,VRAM_SPRGEN+1024
	ld	bc,256
	call	LDIRVM
	ld	a,$ff
	ld	(NEKO_RELOAD),a
	ret

silence:
	db 	$90		; end immediately
	dw 	$0000

SoundDataCount:		equ 7
Len_SoundDataArea:	equ 10*SoundDataCount+1
SoundAddrs:
	dw 	silence,SoundDataArea
	dw 	0,0

SPMOUSE:
        db 000h,000h,000h,000h,004h,009h,002h,030h
        db 029h,02Ah,03Ch,030h,050h,044h,0D9h,0FFh
        db 000h,000h,000h,000h,000h,008h,004h,004h
        db 0E2h,01Ah,009h,065h,085h,082h,0C2h,0FCh
        db 000h,000h,000h,000h,000h,010h,020h,020h
        db 047h,058h,090h,0A6h,0A1h,041h,043h,03Fh
        db 000h,000h,000h,000h,020h,090h,040h,00Ch
        db 094h,054h,03Ch,00Ch,00Ah,022h,09Bh,0FFh

SPNEKO:
	db 000h,000h,004h,002h,001h,000h,060h,018h
	db 006h,000h,000h,0F0h,000h,000h,000h,000h
	db 000h,000h,000h,008h,014h,092h,022h,021h
	db 041h,040h,044h,044h,044h,040h,05Ch,020h
	db 000h,000h,000h,000h,000h,000h,000h,001h
	db 002h,002h,003h,006h,007h,000h,000h,000h
	db 010h,00Eh,002h,004h,008h,010h,0D0h,030h
	db 018h,008h,088h,009h,0FFh,000h,000h,000h
	db 000h,000h,000h,008h,014h,024h,022h,042h
	db 0C1h,001h,011h,011h,011h,001h,09Dh,002h
	db 000h,000h,020h,040h,080h,000h,006h,018h
	db 060h,000h,000h,01Eh,000h,000h,000h,000h
	db 004h,038h,020h,011h,00Ah,004h,005h,086h
	db 08Ch,088h,088h,0C8h,07Fh,000h,000h,000h
	db 000h,040h,0A0h,020h,040h,080h,080h,040h
	db 020h,020h,0E0h,030h,0F0h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,008h,014h,012h,022h,021h
	db 041h,040h,044h,044h,044h,040h,05Ch,020h
	db 000h,000h,000h,000h,000h,000h,000h,001h
	db 002h,002h,003h,006h,007h,000h,000h,000h
	db 010h,00Eh,002h,004h,008h,010h,0D0h,030h
	db 018h,008h,088h,009h,0FFh,000h,000h,000h
	db 000h,000h,000h,008h,014h,024h,022h,042h
	db 0C1h,001h,011h,011h,011h,001h,09Dh,002h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 004h,038h,020h,010h,008h,004h,005h,086h
	db 08Ch,088h,088h,0C8h,07Fh,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,080h,040h
	db 020h,020h,0FEh,021h,0FEh,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,007h,004h
	db 004h,002h,002h,002h,002h,001h,001h,000h
	db 000h,000h,00Ch,00Bh,008h,008h,008h,0ECh
	db 018h,000h,000h,000h,010h,008h,000h,09Ch
	db 000h,000h,000h,000h,000h,000h,000h,001h
	db 002h,002h,003h,006h,007h,000h,000h,000h
	db 040h,03Eh,002h,004h,008h,010h,0D0h,030h
	db 018h,008h,088h,009h,0FFh,000h,000h,000h
	db 000h,000h,000h,000h,080h,040h,030h,008h
	db 004h,082h,042h,00Ah,012h,082h,03Ch,044h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 022h,03Eh,022h,062h,002h,00Ch,025h,0C6h
	db 080h,080h,0A0h,0C0h,07Fh,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,080h,040h
	db 020h,03Ch,0E2h,03Ch,0F0h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,03Ch,023h,010h,010h,008h,004h,004h
	db 000h,000h,000h,000h,060h,058h,046h,041h
	db 040h,040h,0C0h,000h,004h,008h,010h,013h
	db 007h,004h,007h,003h,000h,000h,000h,001h
	db 002h,002h,003h,006h,007h,000h,000h,000h
	db 084h,000h,0A0h,006h,0F8h,010h,0D0h,030h
	db 018h,008h,088h,009h,0FFh,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 0C0h,02Ch,01Ah,01Ah,01Ah,01Bh,018h,018h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,080h,040h
	db 018h,02Ch,024h,01Ch,008h,004h,004h,084h
	db 08Ch,088h,089h,0CFh,07Fh,000h,000h,000h
	db 020h,010h,010h,010h,010h,010h,010h,030h
	db 020h,040h,0FEh,001h,0FEh,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,004h,00Ah
	db 009h,008h,008h,008h,004h,004h,004h,004h
	db 000h,000h,000h,000h,004h,00Ah,009h,008h
	db 010h,090h,060h,000h,000h,001h,006h,008h
	db 007h,004h,007h,003h,000h,000h,000h,001h
	db 002h,002h,003h,006h,007h,000h,000h,000h
	db 081h,006h,0A3h,007h,0F9h,010h,0D0h,030h
	db 018h,008h,088h,009h,0FFh,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,080h
	db 040h,020h,010h,010h,008h,008h,008h,010h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 09Fh,018h,0F0h,000h,088h,074h,004h,084h
	db 08Ch,088h,089h,0CFh,07Fh,000h,000h,000h
	db 0C0h,020h,010h,010h,010h,010h,010h,010h
	db 020h,020h,0FEh,001h,0FEh,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,008h,014h,012h,022h,021h
	db 041h,05Ch,042h,049h,072h,042h,042h,022h
	db 000h,000h,000h,000h,000h,000h,000h,001h
	db 002h,002h,003h,006h,007h,000h,000h,000h
	db 011h,00Eh,002h,004h,008h,010h,0D0h,030h
	db 018h,008h,088h,009h,0FFh,000h,000h,000h
	db 000h,000h,000h,008h,014h,024h,022h,042h
	db 0C1h,01Dh,0A1h,089h,047h,041h,041h,042h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 084h,038h,020h,010h,008h,004h,005h,086h
	db 08Ch,088h,088h,0C8h,07Fh,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,080h,040h
	db 020h,020h,0FEh,021h,0FEh,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,0FCh,008h,030h,020h,0FCh,001h,003h
	db 000h,000h,000h,001h,001h,001h,002h,002h
	db 002h,002h,002h,001h,000h,000h,000h,000h
	db 01Eh,064h,084h,008h,008h,008h,008h,005h
	db 004h,002h,001h,000h,0FCh,007h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,03Ch,008h,011h,03Eh,006h,084h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,080h,080h,080h,040h
	db 0FCh,048h,030h,000h,000h,000h,000h,0C0h
	db 031h,008h,002h,0FFh,00Fh,0F9h,000h,000h
	db 060h,050h,028h,018h,018h,01Ch,054h,094h
	db 016h,02Ah,0DAh,032h,026h,0FCh,000h,000h
	db 000h,000h,000h,003h,000h,000h,000h,000h
	db 001h,003h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,0F8h,010h,0A0h,040h,0A0h
	db 000h,0F8h,000h,000h,000h,000h,000h,001h
	db 000h,000h,000h,000h,000h,001h,002h,002h
	db 002h,002h,002h,001h,000h,000h,000h,000h
	db 002h,01Ch,064h,088h,088h,008h,008h,005h
	db 004h,002h,001h,000h,0FCh,007h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,0F8h
	db 010h,020h,0F8h,000h,000h,001h,082h,044h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,080h,040h,040h,040h
	db 07Ch,028h,018h,000h,000h,000h,000h,080h
	db 071h,008h,002h,0FFh,00Fh,0F9h,000h,000h
	db 060h,050h,028h,018h,018h,01Ch,034h,0D4h
	db 016h,02Ah,0DAh,032h,026h,0FCh,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,001h,003h,002h,002h
	db 003h,07Ch,010h,064h,044h,044h,080h,0F8h
	db 080h,044h,078h,060h,0FCh,020h,040h,040h
	db 002h,002h,001h,001h,001h,001h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 080h,000h,000h,000h,000h,000h,080h,060h
	db 01Eh,002h,002h,002h,002h,001h,000h,000h
	db 0C0h,03Eh,008h,026h,022h,022h,001h,01Fh
	db 001h,042h,03Eh,006h,03Fh,004h,002h,002h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,080h,0C0h,040h,040h
	db 001h,000h,000h,000h,000h,000h,001h,006h
	db 078h,040h,040h,040h,040h,080h,000h,000h
	db 040h,040h,080h,080h,080h,080h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,001h,002h,002h,002h,002h,002h,002h
	db 002h,002h,001h,001h,001h,001h,000h,000h
	db 003h,0FCh,0D0h,064h,044h,044h,080h,0F8h
	db 080h,044h,078h,020h,01Ch,000h,080h,0B0h
	db 000h,000h,001h,001h,001h,001h,001h,001h
	db 001h,000h,000h,000h,000h,000h,000h,000h
	db 0C1h,082h,002h,002h,002h,002h,002h,000h
	db 003h,082h,084h,088h,090h,060h,000h,000h
	db 0C0h,03Fh,00Bh,026h,022h,022h,001h,01Fh
	db 001h,042h,03Eh,004h,038h,000h,001h,00Dh
	db 000h,080h,040h,040h,040h,040h,040h,040h
	db 040h,040h,080h,080h,080h,080h,000h,000h
	db 083h,041h,040h,040h,040h,040h,040h,000h
	db 0C0h,041h,021h,011h,009h,006h,000h,000h
	db 000h,000h,080h,080h,080h,080h,080h,080h
	db 080h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,001h,002h,004h,008h,008h,010h,020h
	db 007h,004h,004h,004h,004h,004h,004h,004h
	db 03Eh,0C1h,000h,000h,000h,000h,000h,000h
	db 020h,020h,020h,030h,030h,020h,064h,04Fh
	db 09Ah,093h,060h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,0C0h,041h
	db 043h,0F0h,01Eh,003h,000h,000h,000h,000h
	db 000h,0FFh,078h,025h,022h,021h,020h,000h
	db 000h,000h,000h,000h,001h,001h,001h,001h
	db 000h,080h,040h,0E0h,036h,018h,010h,010h
	db 010h,020h,020h,0C0h,000h,000h,000h,000h
	db 0C3h,022h,032h,022h,024h,064h,0D8h,090h
	db 0B0h,070h,010h,0F0h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,00Eh,009h,009h,004h
	db 000h,000h,000h,001h,03Eh,020h,010h,010h
	db 008h,008h,014h,024h,042h,081h,000h,080h
	db 00Ch,00Ah,032h,040h,040h,040h,040h,087h
	db 088h,090h,090h,0A0h,0C0h,000h,000h,000h
	db 080h,040h,000h,000h,020h,040h,080h,080h
	db 080h,080h,08Fh,090h,090h,090h,090h,060h
	db 000h,000h,0FFh,0B0h,007h,0C0h,0B8h,088h
	db 080h,080h,000h,003h,000h,050h,000h,001h
	db 000h,000h,000h,080h,040h,060h,058h,040h
	db 05Eh,0F2h,0C6h,08Ch,018h,030h,040h,080h
	db 002h,004h,008h,010h,010h,010h,010h,020h
	db 020h,040h,080h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,001h,001h
	db 002h,004h,008h,012h,023h,045h,049h,092h
	db 000h,000h,000h,00Eh,031h,0C0h,000h,000h
	db 000h,000h,000h,001h,000h,000h,000h,000h
	db 0A4h,0C2h,001h,001h,001h,001h,002h,002h
	db 003h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,003h,09Eh,091h,04Eh,0C8h
	db 02Fh,038h,018h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,080h,060h,010h,008h
	db 004h,004h,002h,003h,084h,080h,040h,040h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 00Ch,014h,064h,088h,008h,008h,004h,012h
	db 040h,087h,089h,040h,080h,003h,00Eh,034h
	db 0C8h,090h,0E0h,000h,000h,000h,000h,000h
	db 012h,012h,0C3h,001h,002h,004h,0F8h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,0E0h,090h,098h,044h,022h
	db 011h,008h,008h,008h,010h,010h,010h,010h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,0C0h,038h,006h,001h,000h,000h,000h
	db 010h,020h,020h,0C0h,081h,09Eh,0B7h,0E8h
	db 030h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,008h,030h,0C0h,070h,09Fh,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,001h,002h
	db 00Ch,010h,030h,020h,040h,0C0h,003h,000h
	db 000h,000h,000h,020h,060h,0A0h,020h,020h
	db 030h,008h,024h,024h,024h,002h,0C2h,002h
	db 000h,000h,001h,001h,000h,018h,0F4h,03Bh
	db 004h,003h,000h,000h,000h,000h,000h,000h
	db 004h,078h,080h,080h,0C0h,060h,010h,008h
	db 0C4h,038h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,007h,008h,007h,001h,003h
	db 006h,004h,004h,004h,004h,004h,002h,002h
	db 000h,000h,0E0h,01Ch,007h,0F0h,0C0h,000h
	db 000h,000h,010h,008h,004h,004h,004h,004h
	db 002h,002h,002h,002h,001h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 004h,008h,008h,008h,011h,091h,08Ah,04Ah
	db 04Ch,024h,037h,01Ch,000h,000h,000h,000h
	db 000h,000h,000h,000h,0C0h,020h,010h,008h
	db 007h,00Dh,009h,011h,020h,040h,040h,042h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 018h,028h,048h,088h,008h,008h,008h,024h
	db 042h,0F2h,000h,000h,000h,020h,01Fh,010h
	db 021h,0F2h,08Ch,000h,000h,000h,000h,000h
	db 024h,027h,004h,024h,004h,068h,0D0h,040h
	db 080h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,03Eh,041h,038h,004h
	db 004h,004h,004h,004h,004h,002h,001h,000h
	db 000h,000h,000h,03Fh,040h,038h,089h,072h
	db 01Ch,000h,000h,000h,000h,000h,000h,080h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 060h,010h,008h,008h,004h,004h,002h,001h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,080h,0E0h,090h,020h,060h
	db 090h,008h,005h,006h,004h,008h,030h,040h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,080h,086h,0DAh,062h,022h,024h
	db 040h,040h,000h,071h,009h,081h,040h,030h
	db 08Fh,043h,022h,022h,012h,00Eh,000h,000h
	db 004h,004h,004h,015h,016h,014h,004h,02Ch
	db 018h,0E8h,044h,024h,024h,018h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,001h,001h,001h,002h,002h,002h
	db 001h,002h,002h,002h,002h,002h,01Eh,020h
	db 040h,080h,000h,008h,014h,012h,022h,021h
	db 002h,002h,006h,003h,004h,005h,007h,001h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 041h,040h,040h,040h,0C4h,0C4h,044h,020h
	db 0F0h,03Eh,003h,000h,000h,000h,000h,000h
	db 080h,040h,040h,040h,040h,040h,078h,004h
	db 002h,001h,000h,008h,014h,024h,022h,042h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,080h,040h,040h,020h,020h,020h
	db 0C1h,001h,001h,001h,011h,011h,011h,082h
	db 007h,03Eh,0E0h,000h,000h,000h,000h,000h
	db 020h,020h,030h,060h,090h,0D0h,070h,040h
	db 080h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 031h,05Ah,04Ah,04Ah,086h,086h,080h,080h
	db 080h,080h,040h,048h,094h,092h,0A2h,0A1h
	db 000h,000h,006h,001h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 0C1h,0C0h,0C0h,0C0h,0C4h,0C4h,044h,060h
	db 050h,04Eh,043h,024h,024h,02Ch,018h,000h
	db 086h,04Dh,049h,049h,050h,060h,000h,000h
	db 000h,000h,001h,009h,014h,024h,022h,042h
	db 000h,000h,000h,000h,080h,080h,080h,080h
	db 080h,080h,000h,000h,080h,080h,080h,080h
	db 0C1h,001h,001h,001h,011h,011h,011h,083h
	db 005h,039h,0E1h,012h,012h,01Ah,00Ch,000h
	db 080h,080h,0B0h,0C0h,080h,080h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 018h,014h,012h,011h,010h,010h,010h,024h
	db 000h,000h,000h,000h,003h,004h,008h,010h
	db 0E0h,0B0h,090h,088h,004h,002h,002h,042h
	db 024h,0E4h,020h,024h,020h,016h,00Fh,001h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 042h,04Fh,000h,000h,000h,004h,0F8h,008h
	db 084h,04Fh,031h,000h,000h,000h,000h,000h
	db 000h,000h,007h,038h,0E0h,00Fh,003h,000h
	db 000h,000h,008h,010h,020h,020h,020h,020h
	db 000h,000h,000h,0E0h,010h,0E0h,000h,0C0h
	db 060h,020h,020h,020h,020h,020h,040h,040h
	db 020h,010h,010h,010h,088h,089h,051h,052h
	db 032h,024h,0ECh,038h,000h,000h,000h,000h
	db 040h,040h,040h,040h,080h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,003h,062h,05Ah,04Eh,044h,020h
	db 000h,000h,000h,001h,007h,009h,004h,006h
	db 009h,010h,030h,0E0h,020h,010h,00Ch,002h
	db 020h,020h,020h,0A8h,068h,028h,020h,034h
	db 018h,017h,032h,024h,024h,018h,000h,000h
	db 002h,002h,000h,08Eh,090h,081h,002h,00Ch
	db 0F1h,0C2h,044h,044h,048h,070h,000h,000h
	db 000h,000h,000h,0FCh,002h,01Ch,091h,04Eh
	db 038h,000h,000h,000h,000h,000h,000h,001h
	db 000h,000h,000h,000h,07Ch,082h,01Ch,020h
	db 020h,020h,020h,020h,020h,040h,080h,000h
	db 006h,008h,010h,010h,020h,020h,040h,080h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 030h,028h,026h,011h,010h,010h,020h,048h
	db 000h,000h,000h,000h,001h,006h,008h,010h
	db 020h,020h,040h,0C0h,021h,001h,002h,002h
	db 048h,048h,0C3h,080h,040h,020h,01Fh,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 002h,0E1h,081h,002h,001h,0C0h,070h,02Ch
	db 013h,009h,007h,000h,000h,000h,000h,000h
	db 000h,000h,000h,070h,08Ch,003h,000h,000h
	db 000h,000h,000h,080h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,080h,080h
	db 040h,020h,010h,048h,0C4h,0A2h,092h,049h
	db 000h,000h,000h,0C0h,079h,089h,072h,013h
	db 0F4h,01Ch,018h,000h,000h,000h,000h,000h
	db 025h,043h,080h,080h,080h,080h,040h,040h
	db 0C0h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,004h,006h,005h,004h,004h
	db 00Ch,010h,024h,024h,024h,040h,043h,040h
	db 000h,000h,000h,000h,000h,000h,080h,040h
	db 030h,008h,00Ch,004h,002h,003h,0C0h,000h
	db 020h,01Eh,001h,001h,003h,006h,008h,010h
	db 023h,01Ch,000h,000h,000h,000h,000h,000h
	db 000h,000h,0E0h,000h,000h,018h,02Fh,0DCh
	db 020h,0C0h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,003h,01Ch,060h,080h,000h,000h,000h
	db 000h,000h,000h,007h,009h,011h,022h,044h
	db 088h,010h,010h,010h,008h,008h,008h,008h
	db 000h,000h,010h,00Ch,003h,01Eh,0E1h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 008h,004h,004h,003h,081h,079h,0E5h,013h
	db 00Ch,000h,000h,000h,000h,000h,000h,000h
	db 000h,001h,002h,007h,06Ch,018h,008h,008h
	db 008h,004h,004h,003h,000h,000h,000h,000h
	db 000h,0FFh,01Eh,0A4h,044h,084h,004h,000h
	db 000h,000h,000h,000h,080h,080h,080h,080h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 0C3h,044h,04Ch,044h,024h,026h,01Bh,00Dh
	db 00Dh,00Eh,008h,00Fh,000h,000h,000h,000h
	db 0E0h,020h,020h,020h,020h,020h,020h,020h
	db 07Ch,083h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,080h,040h,020h,010h,010h,008h,004h
	db 000h,000h,000h,000h,000h,000h,003h,082h
	db 0C2h,00Fh,078h,0C0h,000h,000h,000h,000h
	db 004h,004h,004h,00Ch,00Ch,004h,026h,0F2h
	db 059h,0C9h,006h,000h,000h,000h,000h,000h
	db 000h,000h,000h,001h,002h,006h,01Ah,002h
	db 07Ah,04Fh,063h,031h,018h,00Ch,002h,001h
	db 000h,000h,0FFh,00Dh,0E0h,003h,01Dh,011h
	db 001h,001h,000h,0C0h,000h,00Ah,000h,080h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 040h,020h,010h,008h,008h,008h,008h,004h
	db 004h,002h,001h,000h,000h,000h,000h,000h
	db 000h,000h,000h,080h,07Ch,004h,008h,008h
	db 010h,010h,028h,024h,042h,081h,000h,001h
	db 000h,000h,000h,000h,000h,000h,000h,000h
	db 000h,000h,000h,000h,070h,090h,090h,020h
	db 001h,002h,000h,000h,004h,002h,001h,001h
	db 001h,001h,0F1h,009h,009h,009h,009h,006h
	db 030h,050h,04Ch,002h,002h,002h,002h,0E1h
	db 011h,009h,009h,005h,003h,000h,000h,000h

	include "library.asm"

END:	equ $

	org RAMSTART

NEKO_X:		ds 1
NEKO_Y:		ds 1
NEKO_STATE:	ds 1
NEKO_ANIM:	ds 1
NEKO_ANIM_TMR:	ds 1
NEKO_IDLE_TMR:	ds 1
NEKO_DIR:	ds 1
NEKO_RELOAD:	ds 1
MOUSE_X:	ds 1
MOUSE_Y:	ds 1
MOUSE_ACNT:	ds 1
MOUSE_FACING:	ds 1

SoundDataArea:
	ds 	Len_SoundDataArea
