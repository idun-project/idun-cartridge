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

!eof
┌────────────────────────────────────────────────────────────────────────┐
│                        TERMS OF USE: MIT License                       │
├────────────────────────────────────────────────────────────────────────┤
│ Copyright (c) 2020 Brian Holdsworth                                    │
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