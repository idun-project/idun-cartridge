;ACE-64 kernel VIC bitmapped 80-column screen driver code

;NOTE: this driver _CANNOT_ be used in C128 mode.  It also cannot be compiled
;      simultaneously with the VDC driver since the 8-bit chrset is under I/O.

;vic memory layout: $c400=chars, $cc00=color, $d000=charset4bit, $e000=bitmap

seCharAddr = $0000  ;logical addr
seBackAddr = $c400
seBitmapAddr = $e000
seColorAddr = $cc00
seCharset4bit = $d800
seRowInc = 80
seRowPhysInc = 320
seRowColorInc = 40

seBackColor !byte 0

seStartup = *
   rts
   
seShutdown = *
   lda vic+$11
   and #%00011111
   sta vic+$11
   lda #$16
   sta vic+$18
   lda $dd00
   and #%11111100
   ora #%00000011
   sta $dd00
   rts

seActivate = *
   bit aceSoft80Allocated
   bmi +
   sec
   rts
+  jsr seActivateHardware
   lda #25
   ldx #80
   sta winRows
   sta winMaxRows
   stx winCols
   stx winMaxCols
   stx winRowInc
   lda #<seCharAddr
   ldy #>seCharAddr
   sta winCharAddr+0
   sty winCharAddr+1
   sta winStartAddr+0
   sty winStartAddr+1
   lda #0
   sta winStartRow
   sta winStartCol
   ldx #7
-  lda configBuf+$b8,x
   sta winPalette,x
   dex
   bpl -
   rts

seActivateHardware = *
   lda vic+$11
   and #%01111111
   ora #%00100000
   sta vic+$11
   lda #$38
   sta vic+$18
   lda $dd00
   and #%11111100
   sta $dd00
   rts

seVicbitWork !byte 0

seRgbi2vicbit = *  ;.A=color
   pha
   and #$0f
   tax
   lda seRgbi2vicTab,x
   asl
   asl
   asl
   asl
   sta seVicbitWork
   pla
   lsr
   lsr
   lsr
   lsr
   tax
   lda seRgbi2vicTab,x
   ora seVicbitWork
   rts

seRgbi2vic = *
   and #$0f
   tax
   lda seRgbi2vicTab,x
   rts
seRgbi2vicTab !byte 0,11,6,14,5,13,12,3,2,10,8,4,9,7,15,1

seVic2rgbi = *
   and #$0f
   tax
   lda seVic2rgbiTab,x
   rts
seVic2rgbiTab !byte 0,15,8,7,11,4,2,13,10,12,9,1,6,5,3,14

seAddBack = *
   clc
   lda syswork+1
   adc #>seBackAddr
   sta syswork+1
   rts

seAddBitmap = *
   lda syswork+1
   asl syswork+0
   rol
   asl syswork+0
   rol
   clc
   adc #>seBitmapAddr
   sta syswork+1
   rts

seAddColor = *
   lda syswork+1
   lsr
   ror syswork+0
   clc
   adc #>seColorAddr
   sta syswork+1
   rts

seWinPos = *
   jsr seMult80
   clc
   lda syswork+0
   adc winStartAddr+0
   sta syswork+0
   lda syswork+1
   adc winStartAddr+1
   sta syswork+1
   rts

sePosBitmap = *
   jsr seMult320
   clc  ;add four times the 80x25-style start of screen
   lda winStartAddr+0
   ldy winStartAddr+1
   sty sePos320start+1
   asl
   rol sePos320start+1
   asl
   rol sePos320start+1
   clc
   adc syswork+0
   sta syswork+0
   lda syswork+1
   adc sePos320start+1
   sta syswork+1
   sePosAdd = *  ;add start addr of bitmap
   clc
   lda syswork+0
   adc #<seBitmapAddr
   sta syswork+0
   lda syswork+1
   adc #>seBitmapAddr
   sta syswork+1
   rts
sePos320start !byte 0,0

seMult320 = * ;( .A=row, .X=col ) : (sw+0)=(row*80+col)*4
   jsr seMult80
   asl syswork+0
   rol syswork+1
   asl syswork+0
   rol syswork+1
   rts

seMult80 = *  ;( .A=row, .X=col ) : (sw+0)=row*80+col, .X:unch
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

sePutWhich   !byte 0
sePutLen     !byte 0
sePutColor   !byte 0
sePutAddr    !byte 0,0 ;+
sePutStrPtr  !byte 0,0 ;+
seFillChar   !byte 0 ;+
seFieldLen   !byte 0 ;+
sePutAttrib  !byte 0
seRvsXorLhs  !byte 0
seRvsXorRhs  !byte 0
seRvsXorBoth !byte 0
seUnderFlag  !byte 0

seWinPut = *
   ;** initialize
   sta sePutWhich
   stx sePutLen
   sty sePutColor
   ldx #6
-  lda syswork+0,x
   sta sePutAddr,x
   dex
   bpl -
   lda sePutWhich
   and #$20
   bne +
   lda #$00
   sta sePutAttrib
+  lda #$00
   sta seRvsXorLhs
   sta seRvsXorRhs
   sta seRvsXorBoth
   bit sePutAttrib
   bvc +
   lda #$f0
   sta seRvsXorLhs
   lda #$0f
   sta seRvsXorRhs
   lda #$ff
   sta seRvsXorBoth
+  ldx #$00
   lda sePutAttrib
   and #$20
   beq +
   ldx #$ff
+  stx seUnderFlag
   lda #bkRam0
   sta bkSelect
   bit sePutWhich
   bmi +
   jmp seWinPutColor
   ;** put into backing screen
+  jsr seAddBack
   ldy sePutLen
   beq +
   dey
-  lda (syswork+2),y
   sta (syswork+0),y
   dey
   bpl -
+  ldy sePutLen
   cpy seFieldLen
   beq +
   lda seFillChar
-  sta (syswork+0),y
   iny
   cpy syswork+5 ;seFieldLen
   bcc -
   ;** echo to bitmap: initialize
+  lda syswork+0
   ldy syswork+1
   sta syswork+2    ;(sw+2)=backAddr
   sty syswork+3
   lda sePutAddr+1
   sta syswork+1
   jsr seAddBitmap  ;(sw+0)=bitmapAddr
   lda sePutLen
   sta syswork+4    ;sw+4=put length
   lda seFieldLen
   sta syswork+5    ;sw+5=chars left
   beq seWinPutColor
   ;** echo to bitmap: leading rhs char
   lda syswork+2
   and #1
   beq +++
   jsr seEchoLeadRhs
   inc syswork+2
   bne +
   inc syswork+3
+  clc
   lda syswork+0
   adc #4
   sta syswork+0
   bcc +
   inc syswork+1
+  dec syswork+5
   lda syswork+4
   beq +++
   dec syswork+4
   ;** echo to bitmap: even body
+++lda syswork+5
   beq seWinPutColor
   cmp #2
   bcc seWinPutTrail
   and #$fe
   tax
   lda seFillChar
   cmp winChrSpace
   bne +
   lda sePutAttrib
   and #%01100000
   bne +
   sec
   lda syswork+5
   sbc syswork+4
   cmp #3
   bcc +
   clc
   lda syswork+4
   adc #1
   and #$fe
   tax
+  txa
   beq +
   jsr seEchoBody
   ;** echo to bitmap: even space fill
+  lda syswork+5
   cmp #2
   bcc seWinPutTrail
   and #$fe
   jsr seEchoSpaceFill
   ;** echo to bitmap: trailing lhs char
   seWinPutTrail = *
   lda syswork+5
   beq seWinPutColor
   jsr seEchoTrailLhs
   ;** echo to bitmap: finish

   ;** put colors
   seWinPutColor = *
   bit sePutWhich
   bvc seWinPutExit
   lda sePutAddr+0
   ldy sePutAddr+1
   sta syswork+0
   sty syswork+1
   jsr seAddColor
   lda sePutAttrib
   and #$10
   beq +
   lda sePutColor
   cmp configBuf+$b8+0
   bne +
   lda configBuf+$b8+1
   sta sePutColor
+  lda sePutColor
   jsr seRgbi2vicbit
   pha
   lda seFieldLen
   clc
   adc #1
   lsr
   tay
   lda seFieldLen
   beq +
   and #$01
   bne +
   lda sePutAddr+0
   and #$01
   beq +
   iny
+  pla
   cpy #0
   beq +
   dey
-  sta (syswork+0),y
   dey
   bpl -
+  nop

   ;** exit
   seWinPutExit = *
   lda #bkACE
   sta bkSelect
   ldx #6
-  lda sePutAddr,x
   sta syswork+0,x
   dex
   bpl -
   rts

seEchoLeadRhs = *  ;( (sw+0)=bmAddr, (sw+2)=backAddr )
   lda syswork+0
   and #$f8
   sta syswork+0
   jsr seEchoSingleLocate
   ldy #7
-  lda (syswork+6),y
   and #$0f
   sta syswork+8
   lda (syswork+0),y
   and #$f0
   ora syswork+8
   eor seRvsXorRhs
   sta (syswork+0),y
   dey
   bpl -
   bit seUnderFlag
   bpl +
   ldy #7
   lda (syswork+0),y
   ora #$0f
   sta (syswork+0),y
+  lda syswork+0
   ora #$04
   sta syswork+0
   rts
   
seEchoTrailLhs = *  ;( (sw+0)=bmAddr, (sw+2)=backAddr )
   jsr seEchoSingleLocate
   ldy #7
-  lda (syswork+6),y
   and #$f0
   sta syswork+8
   lda (syswork+0),y
   and #$0f
   ora syswork+8
   eor seRvsXorLhs
   sta (syswork+0),y
   dey
   bpl -
   bit seUnderFlag
   bpl +
   ldy #7
   lda (syswork+0),y
   ora #$f0
   sta (syswork+0),y
+  rts

seEchoSingleLocate = *  ;( (sw+2)=backAddr ) : (sw+6)=imageAddr
   ldy #0
   lda (syswork+2),y
   sty syswork+7
   ldx #3
-  asl
   rol syswork+7
   dex
   bne -
   sta syswork+6
   clc
   lda syswork+7
   adc #>seCharset4bit
   sta syswork+7
   rts

seEchoCount !byte 0

seEchoBody = *  ;( (sw+0)=bmAddr++, (sw+2)=backAddr++, .A=chars, syswork+5-- )
   sta seEchoCount
   sec
   lda syswork+5
   sbc seEchoCount
   sta syswork+5
   lsr seEchoCount
-- ldy #0
   lda (syswork+2),y
   sty syswork+7
   sty syswork+9
   asl
   rol syswork+7
   asl
   rol syswork+7
   asl
   rol syswork+7
   sta syswork+6
   lda syswork+7
   adc #>seCharset4bit
   sta syswork+7
   ldy #1
   lda (syswork+2),y
   asl
   rol syswork+9
   asl
   rol syswork+9
   asl
   rol syswork+9
   sta syswork+8
   lda syswork+9
   adc #>seCharset4bit
   sta syswork+9
   ldy #7
-  lda (syswork+6),y
   and #$f0
   sta syswork+4  ;temp
   lda (syswork+8),y
   and #$0f
   ora syswork+4
   eor seRvsXorBoth
   sta (syswork+0),y
   dey
   bpl -
   bit seUnderFlag
   bpl +
   ldy #7
   lda #$ff
   sta (syswork+0),y
+  clc
   lda syswork+0
   adc #8
   sta syswork+0
   bcc +
   inc syswork+1
+  clc
   lda syswork+2
   adc #2
   sta syswork+2
   bcc +
   inc syswork+3
+  dec seEchoCount
   bne --
   rts

seEchoSpaceFill = * ;( (sw+0)=bmAddr++, (sw+2)=backAd++, .A=chars, syswork+5--)
   sta seEchoCount
   ldy #0
   asl
   asl
   bcc +
   iny
+  sta syswork+6
   sty syswork+7
   jsr seQuickFill
   sec
   lda syswork+5
   sbc seEchoCount
   sta syswork+5
   clc
   lda syswork+2
   adc seEchoCount
   sta syswork+2
   bcc +
   inc syswork+3
+  clc
   lda syswork+0
   adc syswork+6
   sta syswork+0
   lda syswork+1
   adc syswork+7
   sta syswork+1
   rts

seQuickFill = *  ;( (sw+0)=addr, (sw+6)=bytes:0-511 )
   ldx syswork+1
   lda syswork+7
   beq +
   ldy #0
   lda #$00
-  sta (syswork+0),y
   iny
   sta (syswork+0),y
   iny
   bne -
   inc syswork+1
+  lda #$00
   ldy syswork+6
   beq ++
   dey
   beq +
-  sta (syswork+0),y
   dey
   bne -
+  sta (syswork+0),y
++ stx syswork+1
   rts

seWinGet = *
   jmp notImp

seWinCopyDest   !byte 0,0  ;from (sw+0)
seWinCopySource !byte 0,0  ;from (sw+2)

seWinCopyRow = *
   ldx #3
-  lda syswork+0,x
   sta seWinCopyDest,x
   dex
   bpl -
   bit winScrollMask
   bvc +
   ;** copy color row
   jsr seAddColor
   lda syswork+3
   lsr
   ror syswork+2
   clc
   adc #>seColorAddr
   sta syswork+3
   lda winCols
   lsr
   ldy #0
   jsr seQuickCopy
   ldx #3
-  lda seWinCopyDest,x
   sta syswork+0,x
   dex
   bpl -
+  bit winScrollMask
   bmi +
   rts
   ;** copy bitmap row
+  jsr seAddBitmap
   lda syswork+3
   asl syswork+2
   rol
   asl syswork+2
   rol
   clc
   adc #>seBitmapAddr
   sta syswork+3
   lda winCols
   ldy #0
   asl
   asl
   bcc +
   iny
+  jsr seQuickCopy
   ldx #3
-  lda seWinCopyDest,x
   sta syswork+0,x
   dex
   bpl -
   ;** copy back-store row
   jsr seAddBack
   clc
   lda syswork+3
   adc #>seBackAddr
   sta syswork+3
   lda winCols
   ldy #0
   jsr seQuickCopy
   lda seWinCopyDest+1
   ldx seWinCopySource+1
   sta syswork+1
   stx syswork+3
   rts

seFastScDir !byte 0

seFastScroll = *  ;if window is entire screen width
   sta seFastScDir
   lda winCols
   cmp #80
   beq +
-  sec
   rts
+  bit seFastScDir
   bmi +
   jmp -

   ;** scroll color
+  bit winScrollMask
   bvc +
   jsr seFastScrollLen80 ;set length
   lsr syswork+9
   ror syswork+8
   lda winScrollRows  ;set source
   ldx #0
   jsr seWinPos
   jsr seAddColor
   lda syswork+0
   ldy syswork+1
   sta syswork+2
   sty syswork+3
   lda #0           ;set dest
   ldx #0
   jsr seWinPos
   jsr seAddColor
   jsr seFastScrollDo  ;do scroll

   ;** scroll bitmap
+  bit winScrollMask
   bpl seFastScrollFinish
   sec                 ;set length
   lda winRows
   sbc winScrollRows
   ldx #0
   jsr seMult320
   lda syswork+0
   ldy syswork+1
   sta syswork+8
   sty syswork+9
   lda winScrollRows   ;set source
   ldx #0
   jsr sePosBitmap
   lda syswork+0
   ldy syswork+1
   sta syswork+2
   sty syswork+3
   lda #0              ;set dest
   ldx #0
   jsr sePosBitmap
   jsr seFastScrollDo  ;do scroll

   ;** scroll backing chars
   jsr seFastScrollLen80 ;set length
   lda winScrollRows  ;set source
   ldx #0
   jsr seWinPos
   jsr seAddBack
   lda syswork+0
   ldy syswork+1
   sta syswork+2
   sty syswork+3
   lda #0           ;set dest
   ldx #0
   jsr seWinPos
   jsr seAddBack
   jsr seFastScrollDo  ;do scroll

   ;** blank screen bottom
   seFastScrollFinish = *
   bit seFastScDir
   bmi +
   lda #0
   jmp ++
+  sec
   lda winRows
   sbc winScrollRows
++ ldx #0
   jsr seWinPos
   rts

seFastScrollLen80 = *  ;( winRows, winScrollRows ) : (sw+8)=scrollLen80
   sec
   lda winRows
   sbc winScrollRows
   ldx #0
   jsr seMult80
   lda syswork+0
   ldy syswork+1
   sta syswork+8
   sty syswork+9
   rts

seFastScrollDo = *
   bit seFastScDir
   bmi +
   ldx #1
-  lda syswork+0,x
   ldy syswork+2,x
   sta syswork+2,x
   sty syswork+0,x 
   dex
   bpl -
+  lda syswork+8    ;do scroll
   ldy syswork+9
   ;fall-through

seQuickCopy = *  ;( (sw+0)=dest++, (sw+2)=source++, .AY=len )
   sta syswork+8
   sty syswork+9
   ;** set up soft copy
   lda #bkRam0
   sta bkSelect
   lda syswork+2
   ldy syswork+3
   sta seFsFrom+1
   sty seFsFrom+2
   lda syswork+0
   ldy syswork+1
   sta seFsTo+1
   sty seFsTo+2
   ldy syswork+9
   beq +
   ldx #0
   ;** copy
seFsFrom  lda $ffff,x
seFsTo    sta $ffff,x
   inx
   bne seFsFrom
   inc seFsFrom+2
   inc seFsTo+2
   dey
   bne seFsFrom
   ;** copy last page
+  ldx #5
-  lda seFsFrom,x
   sta seCopyLast,x
   dex
   bpl -
   ldx #0
   cpx syswork+8
   beq +
   seCopyLast = *
   lda $ffff,x
   sta $ffff,x
   inx
   cpx syswork+8
   bne seCopyLast
   ;** finish
+  lda #bkACE
   sta bkSelect
   rts

seCursorFlash     !byte $00  ;$00=inactive, $ff=active
seCursorState     !byte 0     ;$00=flashOff, $ff=flashOn
seCursorCountdown !byte 0
seCursorMaxCntdn  !byte 20
seCursorJiffies   !byte 20
seCursorAddr      !byte 0,0
seCursorHeight    !byte 8

seWinCursor = *
   tax
   cpx #0
   beq seCursorOff
   lda seCursorJiffies
   cpx #$fa
   bne +
   lsr
+  sta seCursorMaxCntdn
   jsr seAddBitmap
   lda syswork+0
   ldy syswork+1
   sta seCursorAddr+0
   sty seCursorAddr+1
   lda #0
   sta seCursorState
   lda #1
   sta seCursorCountdown
   jsr seIrqCursorEnter
   lda #$ff
   sta seCursorFlash
   rts

seCursorOff = *
   lda #0
   sta seCursorFlash
   lda seCursorAddr+0
   ldy seCursorAddr+1
   sta syswork+0
   sty syswork+1
   lda seCursorState
   beq +
   lda #1
   sta seCursorCountdown
   jsr seIrqCursorEnter
+  rts

seIrqWork = $a0
seCursorMask !byte 0

seIrqCursor = *
   bit seCursorFlash
   bmi seIrqCursorEnter
-  rts
   seIrqCursorEnter = *
   dec seCursorCountdown
   bne -
   lda scpuMrMode
   pha
   lda seCursorMaxCntdn
   sta seCursorCountdown
   lda seCursorAddr+0
   ldy seCursorAddr+1
   and #%11111000
   sta seIrqWork+0
   sty seIrqWork+1
   ldx #$f0
   lda seCursorAddr+0
   and #%00000111
   beq +
   ldx #$0f
+  stx seCursorMask
   lda #bkRam0
   sta bkSelect
   ldx seCursorHeight
   ldy #7
-  lda (seIrqWork),y
   eor seCursorMask
   sta (seIrqWork),y
   dey
   dex
   bne -
   lda #bkACE
   sta bkSelect
   lda seCursorState
   eor #$ff
   sta seCursorState
   pla
   clc
   rts

seWinOption = *
   ;** 1.screen color
+  dex
   bne ++
   bcc +
   jsr seRgbi2vic
   sta vic+$21
+  lda vic+$21
   jsr seVic2rgbi
   clc
   rts
   ;** 2.border color
++ dex
   bne ++
   php
   sei
   bcc +
   jsr seRgbi2vic
   sta vic+$20
+  lda vic+$20
   jsr seVic2rgbi
   plp
   clc
   rts
++ jmp notImp
