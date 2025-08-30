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
	lda $00,x
	ldy $01,x
	jsr xVdcRowAddr
	;add offset for column
	ldx #X1
	jsr .column
	clc
	adc CACHEADDR
	sta CACHEADDR
	bcc +
	inc CACHEADDR+1
	;first/partial byte
+	lda X1
	and #$07
	tax
	lda .LEFTFILL,x
	sta CACHEPIXEL
	jsr .setpixbyte
	;full bytes X1(hi)->X2(hi)
	lda #$ff
	sta CACHEPIXEL
	ldx #X1
	jsr .column
	sta VAR
	ldx #X2
	jsr .column
-	cmp VAR
	beq ++
	inc CACHEADDR
	bne +
	inc CACHEADDR+1
+	pha
	jsr .setpixbyte
	inc VAR
	pla
	jmp -
	;last/partial byte
++	lda X2
	and #$07
	tax
	lda .RIGHTFILL,x
	sta CACHEPIXEL
	jsr .setpixbyte
	rts

xVdcVerLine = *		;(Y1,Y2 .X=X zpoff)
	;offset for column
	jsr .column
	pha
	;mask byte
	lda $00,x
	and #$07
	tax
	lda .BITVAL,x
	sta CACHEPIXEL
	;get bitmap addr of row
	lda Y1
	ldy Y1+1
	jsr xVdcRowAddr
	;add column offset
	pla
	clc
	adc CACHEADDR
	sta CACHEADDR
	bcc +
	inc CACHEADDR+1
	;Y1->Y2
+	lda Y1
	sta VAR
	cmp Y2
	bne +
	rts			;don't fall for this trap!
+	nop
-	jsr .setpixbyte
	inc VAR
	lda VAR
	cmp Y2
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
.column:
	lda $0,x
	sta .temp
	lda $1,x
	lsr
	ror .temp
	lsr
	ror .temp
	lsr
	ror .temp
	lda .temp
	rts 

.BITVAL 	!byte 128, 64, 32, 16, 8, 4, 2, 1
.LEFTFILL   !byte $ff,$7f,$3f,$1f,$0f,$07,$03,$01
.RIGHTFILL  !byte $80,$c0,$e0,$f0,$f8,$fc,$fe,$ff
CACHEPOINT	!byte $ff, 0, 0
.temp		!byte 0

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