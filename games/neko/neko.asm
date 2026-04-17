; COLECO NEKO
; Neko for the ColecoVision.

        include "coleco.asm"

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

	; load first neko frame sprite patterns
	ld 	hl,VRAM_SPRGEN
	ld 	de,SPDATA
	ld 	bc,32*4
	call 	LDIRVM

        ; TODO: load mouse sprite pattern

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

        ; place initial neko sprite
	ld 	hl,SPRTBL
	ld 	(hl),79
	inc 	hl
	ld 	(hl),112
	inc 	hl
	ld 	(hl),0
	inc 	hl
	ld 	(hl),COLOR_BLACK
	inc 	hl
	ld 	(hl),95
	inc 	hl
	ld 	(hl),112
	inc 	hl
	ld 	(hl),4
	inc 	hl
	ld 	(hl),COLOR_BLACK
	inc 	hl
	ld 	(hl),79
	inc 	hl
	ld 	(hl),128
	inc 	hl
	ld 	(hl),8
	inc 	hl
	ld 	(hl),COLOR_BLACK
	inc 	hl
	ld 	(hl),95
	inc 	hl
	ld 	(hl),128
	inc 	hl
	ld 	(hl),12
	inc 	hl
	ld 	(hl),COLOR_BLACK

	; initial neko position and direction
	ld 	a,112
	ld 	(NEKO_X),a
	ld 	a,1
	ld 	(NEKO_DX),a


MLOOP:
	ld 	a,(TickTimer)
	call 	TEST_SIGNAL
	or 	a
	jr 	z,MLOOP

	call 	MOVE_NEKO
	jr 	MLOOP

MOVE_NEKO:
	; check direction and move one pixel
	ld 	a,(NEKO_DX)
	or 	a
	jp 	m,MN_LEFT
	; moving right: bounce at X=224 (right edge of 32-wide sprite)
	ld 	a,(NEKO_X)
	cp 	224
	jr 	nc,MN_BOUNCE
	inc 	a
	ld 	(NEKO_X),a
	jr 	MN_UPDATE
MN_LEFT:
	; moving left: bounce at X=0
	ld 	a,(NEKO_X)
	or 	a
	jr 	z,MN_BOUNCE
	dec 	a
	ld 	(NEKO_X),a
	jr 	MN_UPDATE
MN_BOUNCE:
	ld 	a,(NEKO_DX)
	neg
	ld 	(NEKO_DX),a
	ret
MN_UPDATE:
	; write new X positions into the sprite table
	; TL and BL share the same X; TR and BR are 16 pixels to the right
	ld 	a,(NEKO_X)
	ld 	hl,SPRTBL+1		; TL X
	ld 	(hl),a
	ld 	hl,SPRTBL+5		; BL X
	ld 	(hl),a
	add 	a,16
	ld 	hl,SPRTBL+9		; TR X
	ld 	(hl),a
	ld 	hl,SPRTBL+13		; BR X
	ld 	(hl),a
	ret

VDU_WRITES:
	ret

silence:
	db 	$90		; end immediately
	dw 	$0000

SoundDataCount:		equ 7
Len_SoundDataArea:	equ 10*SoundDataCount+1
SoundAddrs:
	dw 	silence,SoundDataArea
	dw 	0,0

SPDATA:
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
NEKO_DX:	ds 1

SoundDataArea:
	ds 	Len_SoundDataArea
