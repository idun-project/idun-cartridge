; toolx/gfx - A toolbox extension for drawing graphics on the C64
; and C128. Works with 40c and 80c displays.
;
;This extension can only be included immediately after the Toolbox,
;meaning either sys/toolbox.asm, or sys/toolhead.asm must precede it.
* = aceToolboxEnd

jmp GfxInit
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

; Jump table
xGrMode:        jmp xVdcGrMode
xGrExtents:     jmp xVdcGrExtents
xGrOp:          jmp xVdcGrOp
xGrAttr:        jmp xVdcGrAttr
xGrClear:       jmp xVdcMemClear
xGrSetColor:	jmp xVdcColor
xGrDblBuffer:   jmp xVdcDblBuffer
xGrBufswap:     jmp xVdcBufswap
xPoint:			jmp xVdcDot10
xPlot:          jmp GfxPlot
xPolygon:       jmp GfxPolygon

!source "toolx/vdc/core.asm"
!source "toolx/vic/core.asm"
!zone xGfx

;ZP vars
TMP  = syswork+0	;(2)    
VAR  = syswork+2	;(2)
;16-bit X,Y
X1	 = syswork+4
Y1 	 = syswork+6
X2   = syswork+8
Y2   = syswork+10
;POINT is a 10-bit X,Y coord
;!byte 0,0,0,0 = Xhi (7), Xlo (3), Yhi(2), Ylo (8)
Points = syswork+12	;(2) a POINT list ptr

!source "toolx/vdc/draw.asm"
!source "toolx/vic/draw.asm"

;working POINT var
.TP10 !byte 0,0,0,0
;pixel set/reset flag
.SET !byte 0
;bresenham algo vars
.DX  !byte 0,0	;diff X
.DY  !byte 0,0	;diff Y
.SX  !byte 0,0	;step X
.SY  !byte 0,0	;step Y
.ERR !byte 0,0	;error

; CMP16
;   Signed 16-bit CMP
;
;                      (BCC/BCS)      (BEQ/BNE)      (BMI/BPL)
;   If val1 = val2 : Carry =  SET   Zero =  SET   Negative = CLEAR
;   If val1 > val2 : Carry =  SET   Zero = CLEAR  Negative = CLEAR
;   If val1 < val2 : Carry = CLEAR  Zero = CLEAR  Negative =  SET
!macro CMP16 val1, val2 {
	lda val2
	ldy val2+1
	sta syswork+0
	sty syswork+1
	ldy val1
	lda val1+1
	jsr Scmp16
}
Scmp16 = *
	sec
	sbc syswork+1	;compare Hi
	bvc +
	eor #$80
+	bmi ScmpLT
	bvc +
	eor #$80		;restore .Z
+	bne ScmpGT
	tya 			;compare Lo
	sbc syswork+0
	beq +
	bcc ScmpLT
	lda #1
+	rts
	ScmpLT = *
	lda #$ff
	rts
	ScmpGT = *
	sec
	rts

; SBC16
!macro SBC16 res, val1, val2 {
	sec
	lda val1
	sbc val2
	sta res
	lda val1+1
	sbc val2+1
	sta res+1
}

; NEG16
!macro NEG16 res, val {
	lda val+1
	eor #$ff
	sta res+1
	lda val
	eor #$ff
	clc
	adc #1
	sta res
	lda res+1
	adc #0
	sta res+1
}


GfxPlot = *	;(.AY=POINT's, .X=count. .CC=clear pixels)
	pha
    lda #1
    bcs +
    lda #0
+   sta .SET
	pla
	cpx #0
	bne +
	rts			;zero points?
+	cpx #1
	bne +
	;plot single point
	jsr .copyTP10
	jmp xPoint
	;plot one or more line segments
+	dex
	stx .pt_count
	sta Points+0
	sty Points+1
-	jsr .origin
	lda Points+0
	clc
	adc #4
	sta Points+0
	lda Points+1
	adc #0
	sta Points+1
	jsr .line
	dec .pt_count
	bne -
	rts
.pt_count !byte 0

GfxPolygon = *
	sta .pts_head
	sty .pts_head+1
	jsr GfxPlot
	;close polygon
	jsr .origin
	lda .pts_head
	ldy .pts_head+1
	sta Points
	sty Points+1
	jmp .line
.pts_head !byte 0,0

.copyTP10 = *	;(.AY=POINT): .TP10=POINT
	sta TMP
	sty TMP+1
	ldy #0
	lda (TMP),y
	sta .TP10+0
	iny
	lda (TMP),y
	sta .TP10+1
	iny
	lda (TMP),y
	sta .TP10+2
	iny
	lda (TMP),y
	sta .TP10+3
	rts
.p10to16 = *		;(.TP10=POINT, .X=zp addr of 16-bit X,Y)
	lda #0
	sta $1,x	;X+1
	lda .TP10+0
	asl
	rol $1,x	;X+1
	asl
	rol $1,x	;X+1
	asl
	rol $1,x	;X+1
	clc
	adc .TP10+1
	sta $0,x	;X+0

	lda .TP10+2
	sta $3,x	;Y+1
	lda .TP10+3
	sta $2,x	;Y+0
	rts
.origin:			;(Points=(POINT))
	;set X1, Y1 from P10b list
	lda Points
	ldy Points+1
	jsr .copyTP10
	ldx #X1
	jmp .p10to16
.line:
	jsr .lineinit
-	lda X1
	ldx X1+1
	ldy Y1
	jsr .lineplot
	jsr .linestep
	lda .SX
	ora .SY
	bne -
	rts
.lineinit:
	;set X2, Y2 from P10b list
	lda Points
	ldy Points+1
	jsr .copyTP10
	ldx #X2
	jsr .p10to16
	; dx = abs(x2 - x1)
	; dy = abs(y2 - y1)
	; sx = x1 < x2 ? 1 : -1
	; sy = y1 < y2 ? 1 : -1
	; err = dx > dy ? dx : -dy
	; dx = dx * 2
	; dy = dy * 2

	; if y1 < y2:
	; 	sy = 1
	; 	dy = y2 - y1
	; else:
	; 	sy = -1
	; 	dy = y1 - y2
	ldx #0
	stx .SY
	stx .SY+1
	+CMP16 Y1, Y2
	beq ++
	bmi +
	dec .SY
	dec .SY+1
	+SBC16 .DY, Y1, Y2
	jmp ++
+	inc .SY
	+SBC16 .DY, Y2, Y1
	; if x1 < x2:
	; 	sx = 1
	; 	dx = x2 - x1
	; else:
	; 	sx = -1
	; 	dx = x1 - x2
++	ldx #0
	stx .SX
	stx .SX+1
	+CMP16 X1, X2
	beq ++
	bmi +
	dec .SX
	dec .SX+1
	+SBC16 .DX, X1, X2
	jmp ++
+	inc .SX
	+SBC16 .DX, X2, X1
	; err = dx > dy ? dx : -dy
++	+CMP16 .DY, .DX
	bmi +
	lda .DX
	sta .ERR
	lda .DX+1
	sta .ERR+1
	jmp ++
+	+NEG16 .ERR, .DY
	; dx = dx * 2
	; dy = dy * 2
++	asl .DX
	rol .DX+1
	asl .DY
	rol .DY+1
	+NEG16 .minusDX, .DX
	rts
.minusDX !byte 0,0
.linestep:
	; err2 = err
	lda .ERR+1
	sta VAR+1
	lda .ERR
	sta VAR
	; if err2 > -dx:
	;   err = err - dy
	;   x = x + sx
	+CMP16 VAR, .minusDX
	bmi +
	beq +
	;sign-extend ERR
	+SBC16 .ERR, .DY, .ERR
	+NEG16 .ERR, .ERR
	lda X1
	clc
	adc .SX
	sta X1
	lda X1+1
	adc .SX+1
	sta X1+1
	+CMP16 X1, X2
	bne +
	lda #0
	sta .SX
	sta .SX+1
	; if err2 < dy:
	;   err = err + dx
	;   y = y + sy
+	+CMP16 VAR, .DY
	bpl +
	lda .ERR
	clc
	adc .DX
	sta .ERR
	lda .ERR+1
	adc .DX+1
	sta .ERR+1
	lda Y1
	clc
	adc .SY
	sta Y1
	lda Y1+1
	adc .SY+1
	sta Y1+1
	+CMP16 Y1, Y2
	bne +
	lda #0
	sta .SY
	sta .SY+1
+	rts
.lineplot:
	stx .TP10+0
	pha
	and #$7
	sta .TP10+1
	pla
	asl
	rol .TP10+0
	asl
	rol .TP10+0
	asl
	rol .TP10+0
	asl
	rol .TP10+0
	asl
	rol .TP10+0
	sty .TP10+3
    jmp xPoint

WIN_DRIVER_VDC      = %10001000
WIN_DRIVER_VIC80    = %01100000
notImpl = *
   lda #aceErrNotImplemented
   sta errno
   sec
   rts

xVicGfx !word xVicGrMode,xVicGrExtents,xVicGrOp,notImpl,VicGrFill,xVicColor,notImpl,notImpl,xVicDot10
GfxInit = *
    jsr aceMiscSysType
    cmp #WIN_DRIVER_VDC
    bne +
    jmp GfxToolxEnd
+   ldx #16
    jsr aceConOption
    and #WIN_DRIVER_VIC80
    bne +
    ; Cannot use Gfx with text mode VIC-II driver on C64
    lda #<xGrMode
    ldy #>xGrMode
    sta syswork
    sty syswork+1
    ldy #26
-   lda #>notImpl
    sta (syswork),y
    dey
    lda #<notImpl
    sta (syswork),y
    dey
    dey
    bpl -
    jmp GfxToolxEnd
+   lda #<xGrMode
    ldy #>xGrMode
    sta syswork
    sty syswork+1
    ldx #(GfxInit-xVicGfx-1)
    ldy #26
-   lda xVicGfx,x
    sta (syswork),y
    dey
    dex
    lda xVicGfx,x
    sta (syswork),y
    dey
    dey
    dex
    bpl -
GfxToolxEnd = *

!eof
┌────────────────────────────────────────────────────────────────────────┐
│                        TERMS OF USE: MIT License                       │
├────────────────────────────────────────────────────────────────────────┤
│ Copyright (c) 2025 Brian Holdsworth                                    │
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