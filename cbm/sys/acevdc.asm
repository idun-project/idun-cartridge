; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)
;
; VDC driver
; memory layout: $0000=char,$1000=color,$2000=charset,$3000=altcharset

vdcCharAddr = $0000
vdcColorAddr = $1000
vdcCharsetAddr = $2000
vdcSelect = $d600
vdcStatus = $d600
vdcData = $d601
vdcRowInc = 80

vdcScrRows   !byte 25
vdcScrCols   !byte 80
vdcRegNum    !byte 0
vdcCursorLoc !byte 0,0

vdcStartup = *
   jsr vdcHardwareReset
   jsr vdcFillMode
   jmp +
   vdcReloadInit = *
   ;** charset
   jsr vdcFillMode
   lda #$00
   ldx #0
   jsr vdcLoadCharset
   ;** init hardware
+  jmp vdcWarmReset

vdcHardwareReset = *
   lda configBuf+$c7
   beq +
   lda #$7f
   sta vdcHardData+0 ;R0=$7f for PAL
   lda #$26
   sta vdcHardData+4 ;R4=$26 for PAL
   lda #$20
   sta vdcHardData+7 ;R7=$20 for PAL
+  ldx #0
-  lda vdcHardData,x
   cpx #$1e
   beq +
   cpx #$1f
   beq +
   jsr vdcWrite
+  inx
   cpx #$25
   bcc -
   lda vdcStatus ;vdc version
   and #$07
   ldx #$40
   cmp #1
   bcc +
   ldx #$47
+  txa
   ldx #$19
   jsr vdcWrite
   rts
vdcHardData !byte $7e,$50,$66,$49,$20,$e0,$19,$1d  ;regs $00-$07
            !byte $fc,$e7,$a0,$e7,$00,$00,$00,$00  ;regs $08-$0f
            !byte $00,$00,$00,$00,$10,$00,$78,$e8  ;regs $10-$17
            !byte $20,$47,$00,$00,$2f,$e7,$4f,$20  ;regs $18-$1f
            !byte $09,$60,$7d,$64,$f3              ;regs $20-$24

vdcWarmReset = *
   ldx #5
   clc
   jsr vdcWinOption
   pha
   ldx #1
   clc
   jsr vdcWinOption
   pha
   jsr vdcHardwareReset
   pla
   ldx #1
   sec
   jsr vdcWinOption
   pla
   ldx #5
   sec
   jsr vdcWinOption
   ;** set attributes address
   lda #<vdcColorAddr
   ldy #>vdcColorAddr
   ldx #$14
   jsr vdcWrite16
   ;** cursor height
   lda #8
   ldx #$0b
   jsr vdcWrite
   jsr vdcFillMode
   rts

vdcShutdown = *
   lda #25
   jsr vdcSetRows
   ;** restore charsets
   lda #<$d000
   ldy #>$d000
   jsr vdcGetRomCharset
   lda #$00
   ldx #0
   jsr vdcLoadCharset
   lda #<$d800
   ldy #>$d800
   jsr vdcGetRomCharset
   lda #<$3000
   ldy #>$3000
   ldx #0
   jsr vdcLoadSpecCharset
   ;** restore attributes
   lda #<$800
   ldy #>$800
   ldx #$14
   jsr vdcWrite16
   ;** restore cursor height
   lda #7
   ldx #$0b
   jsr vdcWrite
   ;** default fg/bg colors
   lda #$b0
   ldx #$1a
   jsr vdcWrite
   rts

vdcGetRomCharset = *  ;( .AY=romChrAddr )
   sta syswork+0
   sty syswork+1
   lda #$00
   ldy aceCharSetPage
   sta syswork+2
   sty syswork+3
   php
   sei
   lda #bkCharset
   sta bkSelect
   ldx #8
   ldy #0
-  lda (syswork+0),y
   sta (syswork+2),y
   iny
   bne -
   inc syswork+1
   inc syswork+3
   dex
   bne -
   lda #bkACE
   sta bkSelect
   plp
   rts

chsSource = syswork+0 ;(2)
chsCount  = syswork+2 ;(1)

vdcLoadCharset = *  ;( .A=startChar, .X=charCount )
   stx chsCount
   pha
   lda #<vdcCharsetAddr
   ldy #>vdcCharsetAddr
   jsr vdcAddrWrite16
   pla
   jmp +
   vdcLoadSpecCharset = *
   jsr vdcAddrWrite16
   lda #0
   ldx #0
   stx chsCount
+  ldy #$00
   sty chsSource+1
   ldx #3
-  asl
   rol chsSource+1
   dex
   bne -
   sta chsSource+0
   clc
   lda chsSource+1
   adc aceCharSetPage
   sta chsSource+1
   lda #bkRam0io
   sta bkSelect

   charLoop = *
   lda #$1f
   sta vdcRegNum
   sta vdcSelect
   ldy #0
-- lda (chsSource),y
-  bit vdcStatus
   bpl -
   sta vdcData
   iny
   cpy #8
   bcc --
   lda #$00
   jsr vdcRamWrite
   ldx #$1e
   lda #7
   jsr vdcWrite
   clc
   lda chsSource+0
   adc #8
   sta chsSource+0
   bcc +
   inc chsSource+1
+  dec chsCount
   bne charLoop
   lda #bkACE
   sta bkSelect
   rts

vdcFillMode = *  ;( )
   ldx #$18
   jsr vdcRead
   and #$7f
   jsr vdcWrite
   rts

vdcCopyMode = *  ;( )
   ldx #$18
   jsr vdcRead
   ora #$80
   jsr vdcWrite
   rts
   
vdcRamWrite = *  ;( .A=value )
   ldx #$1f

vdcWrite = *  ;( .X=register, .A=value )
   stx vdcRegNum
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sta vdcData
   rts

vdcAddrWrite16 = *  ;( .AY=value )
   ldx #$12

vdcWrite16 = *  ;( .X=hiRegister, .AY=value )
   stx vdcRegNum
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sty vdcData
   inx
   stx vdcRegNum
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sta vdcData
   rts

vdcRamRead = *  ;( ) : .A=value
   ldx #$1f

vdcRead = *  ;( .X=register ) : .A=value
   stx vdcRegNum
   stx vdcSelect
-  bit vdcStatus
   bpl -
   lda vdcData
   rts

vdcActivate = *  ;( .A=rows, .X=cols )
   sta vdcScrRows
   sta winRows
   sta winMaxRows
   ldx vdcScrCols
   stx winCols
   stx winMaxCols
   stx winRowInc
   jsr vdcSetRows
   lda #<vdcCharAddr
   ldy #>vdcCharAddr
   sta winCharAddr+0
   sty winCharAddr+1
   sta winStartAddr+0
   sty winStartAddr+1
   lda #0
   sta winStartRow
   sta winStartCol
   ldx #7
-  lda configBuf+$b0,x
   sta winPalette,x
   dex
   bpl -
   rts

vdcSetRows = *  ;( .A=rows )
   cmp #25+1
   bcc +
   cmp configBuf+$cf
   bcs vdcVerticalCrossover
+  cmp #30
   bcc +
   lda #30
+  pha
   jsr vdcWarmReset
   pla
   ldx #6
   jsr vdcWrite
   cmp #25+1
   bcc +
   sec
   sbc #26
   tay
   ldx #7
   jsr vdcRead
   clc
   adc vdcVert7Vals,y
   jsr vdcWrite
   lda vdcVert5Vals,y
   ldx #5
   jsr vdcWrite
+  rts
vdcVert7Vals !byte 1,1,2,2,2
vdcVert5Vals !byte 6,4,6,5,1

vdcVerticalCrossover = *  ;( .A=rows ) : .A=vdcReg5, .Y=vdcReg7
   cmp #51
   bcc +
   lda #51
+  pha
   ldy #6
-  lda vdcRegSaveIndex,y
   tax
   lda vdcRegFiftyRows,y
   jsr vdcWrite
   dey
   bpl -
   pla
   ldx #6
   jsr vdcWrite
   tay
   clc
   adc #1
   lsr
   and #%11111110
   clc
   adc #27
   cpy #50
   bcc +
   lda #53
+  ldx #7
   jsr vdcWrite
   rts
vdcRegFiftyRows !byte $80,$38,$ff,$e8,51,$06,$35
vdcRegSaveIndex !byte 0,4,8,9,6,5,7

vdcWinPos = *
   jsr vdcMult80
   clc
   lda syswork+0
   adc winStartAddr+0
   sta syswork+0
   lda syswork+1
   adc winStartAddr+1
   sta syswork+1
   rts

vdcMult80 = *  ;( .A=row:0-255, .X=col ) : (sw+0)=row*80+col, .X:unch
   sta syswork+0
   ldy #0
   sty syswork+1
   asl
   rol syswork+1
   asl
   rol syswork+1
   adc syswork+0
   bcc +
   inc syswork+1
+  asl
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

vdcPutWhich !byte 0
vdcPutColor !byte 0
vdcPutLen   !byte 0

vdcWinPut = *
   sta vdcPutWhich
   sty vdcFillByte
   stx vdcPutLen
   bit vdcPutWhich
   bpl vdcWinPutColor
   lda syswork+0
   ldy syswork+1
   jsr vdcAddrWrite16
   ldy #0
   cpy vdcPutLen
   beq +
   lda #$1f
   sta vdcRegNum
   sta vdcSelect
-- lda (syswork+2),y 
-  bit vdcStatus
   bpl -
   sta vdcData
   iny
   cpy vdcPutLen
   bcc --
+  sec
   lda syswork+5
   sbc vdcPutLen
   beq vdcWinPutColor
   tay
   lda syswork+4
   jsr vdcRamWrite
   dey
   beq vdcWinPutColor
   tya
   ldx #$1e
   jsr vdcWrite

   vdcWinPutColor = *
   bit vdcPutWhich
   bvs +
   clc
   rts
+  lda vdcFillByte
   and #$0f
   sta vdcFillByte
   lda vdcPutWhich
   and #$20
   beq +
   lda syswork+6
   and #$f0
   ora vdcFillByte
   sta vdcFillByte
+  lda syswork+1
   clc
   adc #>vdcColorAddr
   tay
   lda syswork+0
   jsr vdcAddrWrite16
   lda syswork+5
   sta vdcFillCols
   jmp vdcFillGotAddr

vdcFillByte !byte 0
vdcFillCols !byte 0

vdcFill = * ;( (sw+0)=addr, vdcFillByte, vdcFillCols )
   lda syswork+0
   ldy syswork+1
   jsr vdcAddrWrite16
   vdcFillGotAddr = *
   lda vdcFillCols
   beq +
   lda vdcFillByte
   jsr vdcRamWrite
   ldx vdcFillCols
   dex
   beq +
   txa
   ldx #$1e
   jsr vdcWrite
+  clc
   rts

vdcWinGet = *
   brk
   ;%%%

vdcWinCopyInit = *
   jmp vdcCopyMode

vdcWinCopyRow = *
   bit winScrollMask
   bvc +
   clc
   lda winScrollDest+1
   adc #>vdcColorAddr
   tay
   lda winScrollDest+0
   jsr vdcAddrWrite16
   clc
   lda winScrollSource+1
   adc #>vdcColorAddr
   tay
   lda winScrollSource+0
   jsr vdcWinCopyDo
+  bit winScrollMask
   bpl +
   lda winScrollDest+0
   ldy winScrollDest+1
   jsr vdcAddrWrite16
   lda winScrollSource+0
   ldy winScrollSource+1
   vdcWinCopyDo = *
   ldx #$20
   jsr vdcWrite16
   lda winCols
   ldx #$1e
   jmp vdcWrite
+  rts

vdcWinCopyFinish = *
   jmp vdcFillMode

vdcFastScroll = *
   sec
   rts

vdcCursorSave  !byte 0
vdcCursorColor !byte 0

vdcWinCursor = *
   cmp #0
   beq vdcCursorOff
   sta vdcCursorSave
   sty vdcCursorColor
   lda syswork+0
   ldy syswork+1
   sta vdcCursorLoc+0
   sty vdcCursorLoc+1
   ldx #$0e
   jsr vdcWrite16
   ldx #$0a
   jsr vdcRead
   and #$1f
   ldy vdcCursorSave
   cpy #$fa
   bne +
   ora #$40
   jmp ++
+  ora #$60
++ jsr vdcWrite
   jsr vdcSetColorAddr
   jsr vdcRamRead
   sta vdcCursorSave
   jsr vdcSetColorAddr
   lda vdcCursorSave
   and #$f0
   ora vdcCursorColor
   jsr vdcRamWrite
   rts

vdcCursorOff = *
   lda vdcCursorLoc+0
   ldy vdcCursorLoc+1
   sta syswork+0
   sty syswork+1
   ldx #$0a
   jsr vdcRead
   and #$1f
   ora #$20
   jsr vdcWrite
   jsr vdcSetColorAddr
   lda vdcCursorSave
   jsr vdcRamWrite
   rts

vdcSetColorAddr = *  ;( (sw+0)=addr )
   clc
   lda syswork+1
   adc #>vdcColorAddr
   tay
   lda syswork+0
   jmp vdcAddrWrite16

vdcWinOption = *
   ;** 1.screen color
   dex
   bne vdcOptBorder
   bcc +
   ldx #$1a
   jsr vdcWrite
   jmp ++
+  ldx #$1a
   jsr vdcRead
++ clc
   rts
   ;** 2.border color
   vdcOptBorder = *
+  dex
   bne +
   lda #$00
   clc
   rts
   ;** 3.cursor style
+  dex
   bne ++
   bcc +
   nop
+  nop
   clc
   rts
   ;** 4.cursor-blink speed
++ dex
   bne ++
   bcc +
   nop
+  nop
   clc
   rts
   ;** 5.screen rvs
++ dex
   bne vdcOptCpu
   bcc +++
   tay
   ldx #$18
   jsr vdcRead
   cpy #0
   beq +
   ora #%01000000
   jmp ++
+  and #%10111111
++ jsr vdcWrite
+++ldx #$18
   jsr vdcRead
   and #$40
   beq +
   lda #$ff
+  clc
   rts
   ;** 6.cpu speed (ignore)
   vdcOptCpu = *
   dex
   bne +
   jmp notImp
   ;** 7.color palette
+  dex
   bne ++
   bcc +
   nop
+  nop
   clc
   rts
++ jmp notImp

vdcIrqCursor = *
   ;** do nothing
   rts

vdcGrExit = *  ;( )
   jsr vdcWarmReset
   lda #$00
   ldx #0
   jsr vdcLoadCharset
   ;** init hardware
   lda winMaxRows
   ldx winMaxCols
   jsr kernWinScreen
   rts


;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2023 Brian Holdsworth                                    │
;│                                                                        │
;│ Permission is hereby granted, free of charge, to any person obtaining  │
;│ a copy of this software and associated documentation files (the        │
;│ "Software"), to deal in the Software without restriction, including    │
;│ without limitation the rights to use, copy, modify, merge, publish,    │
;│ distribute, sublicense, and/or sell copies of the Software, and to     │
;│ permit persons to whom the Software is furnished to do so, subject to  │
;│ the following conditions:                                              │
;│                                                                        │
;│ The above copyright notice and this permission notice shall be         │
;│ included in all copies or substantial portions of the Software.        │
;│                                                                        │
;│ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND         │
;│ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     │
;│ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. │
;│ IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   │
;│ CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   │
;│ TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      │
;│ SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 │
;└────────────────────────────────────────────────────────────────────────┘