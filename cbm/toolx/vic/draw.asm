xVicDot10:		;(.TP10)
	;check pixel in cache
	lda .TP10+0
	cmp CACHEPOINT+0
	bne +
	lda .TP10+3
	cmp CACHEPOINT+2
	bne +
	;cached
	jmp .plotcacheV2
	;uncached -flush cached pix
+	jsr .writepixbyteV2
	;get bitmap addr (sw+0)
	lda .TP10+3
	sta TMP+0
	lda #0
	sta TMP+1
	ldx .TP10+0
	ldy #0		;set to zero to get pix addr
	lda #$80	;get op
	jsr xVicGrOp
	lda TMP
	sta CACHEADDR
	lda TMP+1
	sta CACHEADDR+1
	;update cached point
	lda .TP10+0
	sta CACHEPOINT+0
	lda .TP10+3
	sta CACHEPOINT+2
	;PREPARE read from VIC-II RAM
	sei
	sec
	jsr VicMemoryBank
	lda .SET
	beq .clearpointV2
	ldy #0
	lda (TMP),y
	ldx .TP10+1	;Xlo
	ora .BITVAL,x
	sta CACHEPIXEL
-	clc
	jsr VicMemoryBank
	cli
	rts
.clearpointV2:
	ldx .TP10+1	;Xlo
	lda .BITVAL,x
	eor #$ff
	sta VAR
	ldy #0
	lda (TMP),y
	and VAR
	sta CACHEPIXEL
	jmp -
.plotcacheV2:
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
.writepixbyteV2:
	lda CACHEADDR+0
	ldy CACHEADDR+1
	sta TMP
	sty TMP+1
	ldy #0
	lda CACHEPIXEL
	sta (TMP),y
	rts

xVicHorLine = *		;(X1,X2 .X=Y zpoff)
	;get bitmap addr
	lda $01,x
	sta TMP+0
	lda #0
	sta TMP+1
	ldx X1
	ldy #0		;set to zero to get pix addr
	lda #$80	;get op
	jsr xVicGrOp
	lda TMP
	sta CACHEADDR
	lda TMP+1
	sta CACHEADDR+1
	;first/partial byte
	lda #$ff
	ldx X1+1	;X1lo
	beq +
-	dex
	bmi +
	lsr
	jmp -
+	sta CACHEPIXEL
	jsr .setpixbyteV2
	;full bytes X1(hi)->X2(hi)
	lda #$ff
	sta CACHEPIXEL
	lda X1
	sta VAR
-	lda CACHEADDR
	clc
	adc #8
	sta CACHEADDR
	lda CACHEADDR+1
	adc #0
	sta CACHEADDR+1
	lda VAR
	cmp X2
	beq +
	jsr .setpixbyteV2
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
	jsr .setpixbyteV2
++	rts

xVicVerLine = *		;(Y1,Y2 .X=X zpoff)
	;offset for column
	lda $00,x	;Xhi
	sta CACHEADDR
	;mask byte
	lda $01,x
	tax
	lda .BITVAL,x
	sta CACHEPIXEL
	;get bitmap addr
	lda Y1+1
	sta TMP+0
	lda #0
	sta TMP+1
	ldx CACHEADDR
	ldy #0		;set to zero to get pix addr
	lda #$80	;get op
	jsr xVicGrOp
	lda TMP
	sta CACHEADDR
	lda TMP+1
	sta CACHEADDR+1
	;Y1->Y2
	lda Y1+1
	sta VAR
-	jsr .setpixbyteV2
	inc VAR
	lda VAR
	cmp Y2+1
	bne +
	rts
+	lda #$07
	and CACHEADDR
	cmp #$07
	bne +
	lda CACHEADDR
	clc
	adc #<313
	sta CACHEADDR
	lda CACHEADDR+1
	adc #>313
	sta CACHEADDR+1
	jmp -
+	inc CACHEADDR
	bne -
	inc CACHEADDR+1
	jmp -
.setpixbyteV2:
	lda CACHEADDR+0
	ldy CACHEADDR+1
	sta TMP
	sty TMP+1
	ldy #0
	lda #0
	ldx .SET
	beq +
	lda CACHEPIXEL
+	sta (TMP),y
	rts

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