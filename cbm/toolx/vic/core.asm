!zone xVic {

;constants
VIC_GRMODE_MAX = 4
vic            = $d000
ColorAddr      = $cc00
BitmapAddr     = $e000
bkACE          = $0e
bkRam0         = $3f
bkSelect       = $ff00

;current graphics mode vars
GrMode    !byte 0
BmRows    !byte 0
BmCols    !byte 0
BmCol     !byte 0
BmRow     !byte 0
BmColor   !byte 0
GrOpFlags = syswork+15
GrTemp    = syswork+14
GrSor     = syswork+12

; This represents the _canonical_ VIC-II graphics modes, as defined
; by the specific register values for each standard mode. Many
; variations _can be_ acheived with other VDC register settings.

; Mode 0: standard 40 column text mode with color attributes (25 rows)
; Mode 1: lores (320x200), monochrome bitmap
; Mode 2: lores (320x200), split screen monochrome bitmap/text
; Mode 3: lores color (160x200), multi-color bitmap
; Mode 4: lores color (160x200), split screen multi-color bitmap/text

; _Important_: Only switches any mode TO or FROM MODE 0.
xVicGrMode = *  ;(.A=mode, .X=border clr .Y=fg clr): .A=cols,syswork+0=rows
   sta GrMode
   cmp #0
   bne +
   jmp aceGrExit
+  sei
   sty BmColor
   txa
   jsr Rgbi2vic
   sta vic+$20
   jsr ActivateHardware
   lda BmColor
   jsr Rgbi2vicbit
   ldy #0
-  sta ColorAddr+0,y
   sta ColorAddr+256,y
   sta ColorAddr+512,y
   sta ColorAddr+768,y
   iny
   bne -
   lda #$00
   jsr GrFill
   lda #<200
   ldy #>200
   sta syswork+0
   sty syswork+1
   lda #40
   cli
   rts

ActivateHardware = *
   lda GrMode
   cmp #2
   bcs +
   lda #%00100000
   jmp ++
+  lda #%01100000
++ ora vic+$11
   and #%01111111
   sta vic+$11
   lda #$38
   sta vic+$18
   lda $dd00
   and #%11111100
   sta $dd00
   rts

GrFill = *
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
   sta (syswork+0),y
   iny
   bne -
   inc syswork+1
   dex
   bne -
;    ldy #63
; -  sta (syswork+0),y
;    dey
;    bpl -
   rts

xVicGrOp = *  ;( .A=opflags, .X=X, (sw+0)=Y, .Y=cols, (sw+2)=rows, sw+4=interlv,
   ;**           sw+5=fillval, (sw+6)=sPtr, (sw+8)=dPtr, (sw+10)=mPtr )
   ;**           <all syswork arguments can change>
   ;** opflags: $80=get, $40=put, $20=copy, $10=fill,$8=mask,$4=and,$2=xor,$1=or
   sta GrOpFlags
   stx BmCol
   sty BmCols
   clc
   tya
   adc syswork+4
   sta syswork+4
   lda syswork+0
   sta BmRow
   lsr
   lsr
   lsr
   ldx #0
   jsr Mult320
   lda BmRow
   and #$07
   clc
   adc syswork+0
   sta syswork+0
   bcc +
   inc syswork+1
+  lda BmCol
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
   jsr PosAdd
   ;** at this point, we have the screen position in (sw+0)
   lda BmCols
   bne +
   clc
   rts
GrOpLoop = *
+  lda syswork+0
   ldy syswork+1
   sta GrSor+0
   sty GrSor+1
   lda #bkRam0
   sta bkSelect
GrOpGet = *
   bit GrOpFlags
   bpl GrOpPut
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
   cpy BmCols
   bcc -
   lda GrSor+0
   ldy GrSor+1
   sta syswork+0
   sty syswork+1
GrOpPut = *
   bit GrOpFlags
   bvc GrOpCopy
   ldx #0
   ldy #0
   lda GrOpFlags
   and #$0f
   bne GrOpPutComplex
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
   jmp GrOpPutFinish
+  iny
   cpy BmCols
   bcc -
   jmp GrOpPutFinish

   GrOpPutComplex = *
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
   jmp GrOpPutDo
   ;** xor
+  lda GrOpFlags
   and #$02
   bne +
   lda (syswork+6),y
   eor (syswork+0,x)
   jmp GrOpPutDo
   ;** and
+  lda (syswork+6),y
   eor #$ff
   and (syswork+0,x)

   GrOpPutDo = *
   sta (syswork+0,x)
   clc
   lda syswork+0
   adc #8
   sta syswork+0
   bcc +
   inc syswork+1
+  iny
   cpy BmCols
   bcc -

   GrOpPutFinish = *
   lda GrSor+0
   ldy GrSor+1
   sta syswork+0
   sty syswork+1
GrOpCopy = *  ;xx not implemented
   lda GrOpFlags
   and #$20
   beq GrOpFill
   ldx #0
   ldy #0
   nop
   lda GrSor+0
   ldy GrSor+1
   sta syswork+0
   sty syswork+1
GrOpFill = *
   lda GrOpFlags
   and #$10
   beq GrOpContinue
   ldx #0
   ldy #0
-  lda #$00
   sta (syswork+0,x)
   clc
   lda syswork+0
   adc #8
   sta syswork+0
   bcc +
   inc syswork+1
+  iny
   cpy BmCols
   bcc -
   lda GrSor+0
   ldy GrSor+1
   sta syswork+0
   sty syswork+1
GrOpContinue = *
   lda #bkACE
   sta bkSelect
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
+  inc BmRow
   lda BmRow
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
   jmp GrOpLoop

VicbitWork !byte 0
Rgbi2vicbit = *  ;.A=color
   pha
   and #$0f
   tax
   lda Rgbi2vicTab,x
   asl
   asl
   asl
   asl
   sta VicbitWork
   pla
   lsr
   lsr
   lsr
   lsr
   tax
   lda Rgbi2vicTab,x
   ora VicbitWork
   rts
Rgbi2vic = *
   and #$0f
   tax
   lda Rgbi2vicTab,x
   rts
Rgbi2vicTab !byte 0,11,6,14,5,13,12,3,2,10,8,4,9,7,15,1

Mult320 = * ;( .A=row, .X=col ) : (sw+0)=(row*80+col)*4
   jsr Mult80
   asl syswork+0
   rol syswork+1
   asl syswork+0
   rol syswork+1
   rts
Mult80 = *  ;( .A=row, .X=col ) : (sw+0)=row*80+col, .X:unch
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
PosAdd = *  ;add start addr of bitmap
   clc
   lda syswork+0
   adc #<BitmapAddr
   sta syswork+0
   lda syswork+1
   adc #>BitmapAddr
   sta syswork+1
   rts
}  ;end xVic

!ifndef xGrMode {
   xGrMode = xVicGrMode
   xGrOp = xVicGrOp
   xGrClear = GrFill
   xGrBitmapAddr = BitmapAddr
   xGrScreenAddr = ColorAddr
}
