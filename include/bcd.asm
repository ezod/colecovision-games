; BCD Library

; Convert binary to BCD
; A  -> binary number [0..99]
; A  <- BCD numer [00h..99h]
BIN2BCD:
	push	bc
	ld	b,10
	ld	c,-1
DIV10:
	inc	c
	sub	b
	jr	nc,DIV10
	add	a,b
	ld	b,a
	ld	a,c
	add	a,a
	add	a,a
	add	a,a
	add	a,a
	or	b
	pop	bc
	ret
