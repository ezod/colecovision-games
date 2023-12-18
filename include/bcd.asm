; BCD Library

; Convert binary to BCD
; A  -> binary number [0..99]
; A  <- BCD numer [00h..99h]
BIN2BCD:
	push	BC
	ld	B,10
	ld	C,-1
DIV10:
	inc	C
	sub	B
	jr	NC,DIV10
	add	A,B
	ld	B,A
	ld	A,C
	add	A,A
	add	A,A
	add	A,A
	add	A,A
	or	B
	pop	BC
	ret
