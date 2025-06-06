!zone xVicGfx

;constants
VIC_GRMODE_MAX = 4
vic            = $d000
ColorAddr      = $cc00
xVicScreenAddr = ColorAddr
BitmapAddr     = $e000

;current graphics mode vars
.GrMode    !byte 0
.BmRows    !byte 0
.BmCols    !byte 0
.BmCol     !byte 0
.BmRow     !byte 0
.BmEnable  !byte %00110000
.BmLine25  !byte %01111111
GrOpFlags = syswork+15
GrTemp    = syswork+14
GrSor     = syswork+12

; This represents the _canonical_ VIC-II graphics modes, as defined
; by the specific register values for each standard mode.

; Mode 0: standard 40 column text mode with color attributes (25 rows)
; Mode 1: lores (320x200), monochrome bitmap
; Mode 2: lores (320x200), split screen monochrome bitmap/text
; Mode 3: lores color (160x200), multi-color bitmap
; Mode 4: lores color (160x200), split screen multi-color bitmap/text

; _Important_: Only switches any mode TO or FROM MODE 0.
xVicGrMode = *  ;(.A=mode): .X=cols, .Y=rows
   sta .GrMode
   cmp #0
   bne +
   jmp .textRestore
+  ldy #200
   sty .BmRows       ;Commodore VIC=II 200 lines
   jsr aceMiscSysType
   bpl +
   ldy #192          ;BUT limit to 192 lines on C128
   sty .BmRows       ; (protects $FFxx memory)
   lda #%01110111
   sta .BmLine25     ;24 rows
   lda #%00110100
   sta .BmEnable     ;reset scroll
   lda #<VicBank128
   ldy #>VicBank128
   sta VicMemoryBank+1
   sty VicMemoryBank+2
+  lda .BmRows       ;mouse limits need setting
   sec
   sbc #1
   ldy #0
   sta aceMouseLimitY
   sty aceMouseLimitY+1
   lda #<319
   ldy #>319
   sta aceMouseLimitX
   sty aceMouseLimitX+1
   sei               ;setup bitmap mode
   jsr .ActivateHardware
   cli
   lda #0
   jsr VicGrFill     ;clear bitmap
   lda .BmRows
   lsr
   lsr
   lsr
   tay
   ldx #40
   clc
   rts

.ActivateHardware = *
   lda vic+$30
   sta $0a37
   lda #$00
   sta vic+$30       ;1 MHz mode
   lda .BmEnable    ;bitmap mode on; reset scroll
   ora vic+$11
   and .BmLine25
   sta vic+$11
   lda .GrMode
   cmp #3
   bcc +
   lda #%00010000    ;multicolor mode on
   ora vic+$16
   sta vic+$16
+  lda #$38          ;bitmap memory setup
   sta vic+$18
   lda $dd00
   and #%11111100
   sta $dd00
   rts

VicMemoryBank = * ;(.CS RAM0, .CC=App)
   jmp VicBank64
VicBank128:
   lda #$3f    ;bkRAM0
   bcs +
   lda #$0e    ;bkApp
+  sta $ff00
   rts
VicBank64:
   lda #$30    ;bkRAM0
   bcs +
   lda #$36    ;bkApp
+  sta $01
   rts

VicGrFill = *  ;(.A = fill value)
   ;init bitmap
   tax
   lda #<BitmapAddr
   ldy #>BitmapAddr
   sta syswork+0
   sty syswork+1
   txa
   ldx #$1e
   ldy #0
-  sta (syswork+0),y
   iny
   bne -
   inc syswork+1
   dex
   bne -
   ;only clear last 8 lines for C64
   ldy .BmRows
   cpy #200
   bne +
   ldy #0
-  sta (syswork+0),y
   iny
   bne -
   inc syswork+1
   ldy #63
-  sta (syswork+0),y
   dey
   bpl -
+  rts

xVicColor = *    ;(.A=fgd/bkg - sets all color cells & border)
   ldy #0
-  sta ColorAddr+0,y
   sta ColorAddr+256,y
   sta ColorAddr+512,y
   sta ColorAddr+768,y
   iny
   bne -
   and #$0f
   sta vic+$20
   rts

;Get the pixel extents of current bitmap.
; - Call ONLY after setting mode with xVicGrMode.
;RETURNS: .X,.Y = x/8, y/8 pixel extents
;         syswork+0 = VIC-II bitmap addr
;         syswork+2 = VIC-II color addr
xVicGrExtents = *
   lda #<BitmapAddr
   ldy #>BitmapAddr
   sta syswork+0
   sty syswork+1
   lda #<ColorAddr
   ldy #>ColorAddr
   sta syswork+2
   sty syswork+3
   lda .BmRows
   lsr
   lsr
   lsr
   tay
   ldx #40
   rts

xVicGrOp = *  ;( .A=opflags, .X=X, (sw+0)=Y, .Y=cols, (sw+2)=rows, sw+4=interlv,
   ;**           sw+5=fillval, (sw+6)=sPtr, (sw+8)=dPtr, (sw+10)=mPtr )
   ;**           <all syswork arguments can change>
   ;** opflags: $80=get, $40=put, $20=copy, $10=fill,$8=mask,$4=and,$2=xor,$1=or
   sta GrOpFlags
   stx .BmCol
   sty .BmCols
   clc
   tya
   adc syswork+4
   sta syswork+4
   lda syswork+0
   sta .BmRow
   lsr
   lsr
   lsr
   ldx #0
   jsr .Mult320
   lda .BmRow
   and #$07
   clc
   adc syswork+0
   sta syswork+0
   bcc +
   inc syswork+1
+  lda .BmCol
   ldy #0
   sty GrTemp
   ldx #3
-  asl
   rol GrTemp
   dex
   bne -
   clc
   adc syswork+0
   sta syswork+0
   lda syswork+1
   adc GrTemp
   sta syswork+1
   jsr .PosAdd
   ;** at this point, we have the screen position in (sw+0)
   lda .BmCols
   bne +
   clc
   rts
.GrOpLoop = *
+  lda syswork+0
   ldy syswork+1
   sta GrSor+0
   sty GrSor+1
   sec
   jsr VicMemoryBank
GrOpGet = *
   bit GrOpFlags
   bpl .GrOpPut
   ldx #0
   ldy #0
-  lda (syswork+0,x)
   sta (syswork+8),y
   clc
   lda syswork+0
   adc #8
   sta syswork+0
   bcc +
   inc syswork+1
+  iny
   cpy .BmCols
   bcc -
   lda GrSor+0
   ldy GrSor+1
   sta syswork+0
   sty syswork+1
.GrOpPut = *
   bit GrOpFlags
   bvc .GrOpCopy
   ldx #0
   ldy #0
   lda GrOpFlags
   and #$0f
   bne .GrOpPutComplex
-  lda (syswork+6),y
   sta (syswork+0,x)
   clc
   lda syswork+0
   adc #8
   sta syswork+0
   bcc +
   inc syswork+1
   ;don't go past $ff00
   lda syswork+1
   cmp #$ff
   bne +
   jmp .GrOpPutFinish
+  iny
   cpy .BmCols
   bcc -
   jmp .GrOpPutFinish

   .GrOpPutComplex = *
-  lda GrOpFlags
   and #$08
   beq +
   ;** mask
   lda (syswork+10),y
   eor #$ff
   and (syswork+0,x)
   sta (syswork+0,x)
   ;** or
+  lda GrOpFlags
   and #$01
   bne +
   lda (syswork+6),y
   ora (syswork+0,x)
   jmp .GrOpPutDo
   ;** xor
+  lda GrOpFlags
   and #$02
   bne +
   lda (syswork+6),y
   eor (syswork+0,x)
   jmp .GrOpPutDo
   ;** and
+  lda (syswork+6),y
   eor #$ff
   and (syswork+0,x)

   .GrOpPutDo = *
   sta (syswork+0,x)
   clc
   lda syswork+0
   adc #8
   sta syswork+0
   bcc +
   inc syswork+1
+  iny
   cpy .BmCols
   bcc -

   .GrOpPutFinish = *
   lda GrSor+0
   ldy GrSor+1
   sta syswork+0
   sty syswork+1
.GrOpCopy = *  ;xx not implemented
   lda GrOpFlags
   and #$20
   beq .GrOpFill
   ldx #0
   ldy #0
   nop
   lda GrSor+0
   ldy GrSor+1
   sta syswork+0
   sty syswork+1
.GrOpFill = *
   lda GrOpFlags
   and #$10
   beq .GrOpContinue
   ldx #0
   ldy #0
-  lda syswork+5
   sta (syswork+0),y
   clc
   lda syswork+0
   adc #8
   sta syswork+0
   bcc +
   inc syswork+1
+  iny
   cpy .BmCols
   bcc -
   lda GrSor+0
   ldy GrSor+1
   sta syswork+0
   sty syswork+1
.GrOpContinue = *
   clc
   jsr VicMemoryBank
   lda syswork+2+0
   bne +
   dec syswork+2+1
+  dec syswork+2+0
   lda syswork+2+0
   ora syswork+2+1
   bne +
   clc
   rts
+  bit GrOpFlags
   bmi +
   clc
   lda syswork+8+0
   adc syswork+4
   sta syswork+8+0
   bcc +
   inc syswork+8+1
+  bit GrOpFlags
   bvc +
   clc
   lda syswork+6+0
   adc syswork+4
   sta syswork+6+0
   bcc +
   inc syswork+6+1
+  lda GrOpFlags
   and #$08
   beq +
   clc
   lda syswork+10+0
   adc syswork+4
   sta syswork+10+0
   bcc +
   inc syswork+10+1
+  inc .BmRow
   lda .BmRow
   and #$07
   beq +
   lda #<1
   ldy #>1
   jmp ++
+  lda #<320-7
   ldy #>320-7
++ clc
   adc syswork+0
   sta syswork+0
   tya
   adc syswork+1
   sta syswork+1
   jmp .GrOpLoop

.Mult320 = * ;( .A=row, .X=col ) : (sw+0)=(row*80+col)*4
   jsr .Mult80
   asl syswork+0
   rol syswork+1
   asl syswork+0
   rol syswork+1
   rts
.Mult80 = *  ;( .A=row, .X=col ) : (sw+0)=row*80+col, .X:unch
   sta syswork+0
   ldy #0
   sty syswork+1
   asl
   asl
   adc syswork+0
   asl
   rol syswork+1
   asl
   rol syswork+1
   asl
   rol syswork+1
   asl
   rol syswork+1
   stx syswork+0
   clc
   adc syswork+0
   bcc +
   inc syswork+1
+  sta syswork+0
   rts
.PosAdd = *  ;add start addr of bitmap
   clc
   lda syswork+0
   adc #<BitmapAddr
   sta syswork+0
   lda syswork+1
   adc #>BitmapAddr
   sta syswork+1
   rts

.textsz !byte 0,0
.textRestore = *
   jsr aceWinSize
   sta .textsz
   stx .textsz+1
   lda #0
   ldx #40
   jsr aceWinScreen
   jsr aceGrExit
   lda .textsz
   ldx .textsz+1
   jmp aceWinScreen

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