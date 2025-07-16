xVdcDot10:		;(.TP10)
	;check pixel in cache
	lda .TP10+0
	cmp CACHEPOINT+0
	bne +
	lda .TP10+3
	cmp CACHEPOINT+2
	bne +
	lda .TP10+2
	cmp CACHEPOINT+1
	bne +
	;cached
	jmp .plotcache
	;uncached -
	;first, flush cached pix
+	jsr .writepixbyte
	;get bitmap addr of row
	lda .TP10+3
	ldy .TP10+2
	jsr xVdcRowAddr
	;add offset for column
	lda CACHEADDR
	clc
	adc .TP10+0	;Xhi
	sta CACHEADDR
	bcc +
	inc CACHEADDR+1
	;update cached point
+	lda .TP10+0
	sta CACHEPOINT+0
	lda .TP10+2
	sta CACHEPOINT+1
	lda .TP10+3
	sta CACHEPOINT+2
	lda .SET
	beq .clearpoint
	lda CACHEADDR
	ldy CACHEADDR+1
	jsr vdcAddrWrite16
	jsr vdcRamRead
	ldx .TP10+1	;Xlo
	ora .BITVAL,x
	sta CACHEPIXEL
	rts
.clearpoint:
	ldx .TP10+1	;Xlo
	lda .BITVAL,x
	eor #$ff
	sta VAR
	lda CACHEADDR
	ldy CACHEADDR+1
	jsr vdcAddrWrite16
	jsr vdcRamRead
	and VAR
	sta CACHEPIXEL
	rts
.plotcache:
	lda .SET
	beq +
	lda CACHEPIXEL
	ldx .TP10+1
	ora .BITVAL,x
	sta CACHEPIXEL
	jmp ++
+	ldx .TP10+1	;Xlo
	lda .BITVAL,x
	eor #$ff
	and CACHEPIXEL
	sta CACHEPIXEL
++	rts
.writepixbyte:
	lda CACHEADDR+0
	ldy CACHEADDR+1
	jsr vdcAddrWrite16
	lda CACHEPIXEL
	jmp vdcRamWrite

xVdcHorLine = *		;(X1,X2 .X=Y zpoff)
	;get bitmap addr of row
	ldy $00,x
	lda $01,x
	jsr xVdcRowAddr
	;add offset for column
	lda CACHEADDR
	clc
	adc X1+0	;X1hi
	sta CACHEADDR
	bcc +
	inc CACHEADDR+1
	;first/partial byte
+	lda #$ff
	ldx X1+1	;X1lo
	beq +
-	dex
	bmi +
	lsr
	jmp -
+	sta CACHEPIXEL
	jsr .setpixbyte
	;full bytes X1(hi)->X2(hi)
	lda #$ff
	sta CACHEPIXEL
	lda X1
	sta VAR
-	inc CACHEADDR
	bne +
	inc CACHEADDR+1
+	lda VAR
	cmp X2
	beq +
	jsr .setpixbyte
	inc VAR
	jmp -
	;last/partial byte
+	lda #$00
	ldx X2+1	;X2lo
	beq ++
-	dex
	bmi +
	sec
	ror
	jmp -
+	sta CACHEPIXEL
	jsr .setpixbyte
++	rts

xVdcVerLine = *		;(Y1,Y2 .X=X zpoff)
	;offset for column
	lda $00,x	;Xhi
	pha
	;mask byte
	lda $01,x
	tax
	lda .BITVAL,x
	sta CACHEPIXEL
	;get bitmap addr of row
	ldy Y1
	lda Y1+1
	jsr xVdcRowAddr
	;add column offset
	pla
	clc
	adc CACHEADDR
	sta CACHEADDR
	bcc +
	inc CACHEADDR+1
	;Y1->Y2
+	lda Y1+1
	sta VAR
-	jsr .setpixbyte
	inc VAR
	lda VAR
	cmp Y2+1
	bne +
	rts
+	lda CACHEADDR
	clc
	adc vdcDispColumns
	sta CACHEADDR
	lda CACHEADDR+1
	adc #0
	sta CACHEADDR+1
	jmp -
.setpixbyte:
	lda CACHEADDR+0
	ldy CACHEADDR+1
	jsr vdcAddrWrite16
	lda CACHEPIXEL
	ldx .SET
	bne +
	lda #$00
+	jmp vdcRamWrite

.BITVAL 	!byte 128, 64, 32, 16, 8, 4, 2, 1
CACHEPOINT	!byte $ff, 0, 0

!eof
┌────────────────────────────────────────────────────────────────────────┐
│                        TERMS OF USE: MIT License                       │
├────────────────────────────────────────────────────────────────────────┤
│ Copyright (c) 2023 Brian Holdsworth                                    │
│                                                                        │
│ Permission is hereby granted, free of charge, to any person obtaining  │
│ a copy of this software and associated documentation files (the        │
│ "Software"), to deal in the Software without restriction, including    │
│ without limitation the rights to use, copy, modify, merge, publish,    │
│ distribute, sublicense, and/or sell copies of the Software, and to     │
│ permit persons to whom the Software is furnished to do so, subject to  │
│ the following conditions:                                              │
│                                                                        │
│ The above copyright notice and this permission notice shall be         │
│ included in all copies or substantial portions of the Software.        │
│                                                                        │
│ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND         │
│ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     │
│ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. │
│ IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   │
│ CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   │
│ TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      │
│ SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 │
└────────────────────────────────────────────────────────────────────────┘