	include "../../../include/coleco.asm"

	org $8000

	db $aa,$55			; ColecoVision title screen
	dw 0000				; pointer to sprite name table
	dw 0000				; pointer to sprite order table
	dw 0000				; pointer to working buffer for WR_SPR_NM_TBL
	dw 0000				; pointer to controller input areas
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

	db "HELLO WORLD!/ /2023"

START:
	jp BOOT_UP

	include "../../../include/library.asm"

END:	equ $
