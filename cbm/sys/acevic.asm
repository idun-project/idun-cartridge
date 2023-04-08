; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)
;
; VIC 40-column screen driver code

vicRowInc = 40

vicColorOff  !byte 0
vicInitTemp  !byte 0

vicStartup = *
   jsr vicActivate
   rts

vicShutdown = *
   lda vic+$11
   and #%00011111
   sta vic+$11
   lda $dd00
   and #%11111100
   ora #%00000011
   sta $dd00
   lda #$16
   sta vic+$18
   rts

vicActivate = *
   lda vic+$11
   and #%00011111
   sta vic+$11
   lda aceVic40Page
   asl
   asl
   and #%11110000
   sta vicInitTemp
   lda aceCharSetPage
   lsr
   lsr
   and #%00001111
   ora vicInitTemp
   sta vic+$18
   lda $dd00
   and #%11111100
   sta $dd00
   ;** window parameters
   sec
   lda #$d8
   sbc aceVic40Page
   sta vicColorOff

   lda #25
   ldx #40
   sta winRows
   sta winMaxRows
   stx winCols
   stx winMaxCols
   stx winRowInc
   lda #$00
   ldy aceVic40Page
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

rgbi2vic = *
   and #$0f
   tax
   lda rgbi2vicTab,x
   rts
rgbi2vicTab !byte 0,11,6,14,5,13,12,3,2,10,8,4,9,7,15,1

vic2rgbi = *
   and #$0f
   tax
   lda vic2rgbiTab,x
   rts
vic2rgbiTab !byte 0,15,8,7,11,4,2,13,10,12,9,1,6,5,3,14

vicWinPos = *
   jsr vicMult40
   clc
   lda syswork+0
   adc winStartAddr+0
   sta syswork+0
   lda syswork+1
   adc winStartAddr+1
   sta syswork+1
   rts

vicMult40 = *  ;( .A=row:0-24, .X=col ) : (sw+0)=row*40+col, .X:unch
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
   stx syswork+0
   clc
   adc syswork+0
   bcc +
   inc syswork+1
+  sta syswork+0
   rts

vicPutWhich !byte 0
vicPutLen   !byte 0
vicExtAttr  !byte 0
vicFillByte !byte 0

vicWinPut = *
   bit aceSuperCpuFlag
   bpl +
   sta scpuHwOn
   sta scpuMrAll
   sta scpuHwOff
+  sta vicPutWhich
   sty vicFillByte
   stx vicPutLen
   ldx #$00
   and #$20
   beq +
   ldx syswork+6
+  stx vicExtAttr
   bit vicPutWhich
   bpl vicWinPutColor
   ldy #0
   cpy vicPutLen
   beq ++
-  lda (syswork+2),y
   bit vicExtAttr
   bvc +
   bit winChsetRvsChars
   bpl +
   jsr vicReverseChar
+  sta (syswork+0),y
   iny
   cpy vicPutLen
   bcc -
++ cpy syswork+5
   beq vicWinPutColor
   lda syswork+4
   bit vicExtAttr
   bvc +
   bit winChsetRvsChars
   bpl +
   jsr vicReverseChar
+  nop
-  sta (syswork+0),y
   iny
   cpy syswork+5
   bcc -

   vicWinPutColor = *
   bit vicPutWhich
   bvs +
   jmp vicMirrorOff
+  clc
   lda syswork+1
   adc vicColorOff
   sta syswork+1
   lda vicFillByte
   and #$0f
   tax
   cmp configBuf+$b8+0
   bne vicWinPutGotColor
   lda vicExtAttr
   and #%01110000
   beq vicWinPutGotColor
   and #$40
   beq +
   bit winChsetRvsChars
   bmi +
   ldx configBuf+$b8+4
   jmp vicWinPutGotColor
+  lda vicExtAttr
   and #$20
   beq +
   ldx configBuf+$b8+2
   jmp vicWinPutGotColor
+  lda vicExtAttr
   and #$10
   beq vicWinPutGotColor
   ldx configBuf+$b8+1

   vicWinPutGotColor = * 
   txa
   jsr rgbi2vic
   ldy syswork+5
   dey
   bmi +
-  sta (syswork),y
   dey
   bpl -
+  sec
   lda syswork+1
   sbc vicColorOff
   sta syswork+1
   ;xx fall through

vicMirrorAll = *
   bit aceSuperCpuFlag
   bpl +
   sta scpuHwOn
   sta scpuMrAll
   sta scpuHwOff
+  rts

vicMirrorOff = *
   bit aceSuperCpuFlag
   bpl +
   sta scpuHwOn
   sta scpuMrOff
   sta scpuHwOff
+  clc
   rts

vicWinGet = *
   brk
   ;%%%

vicWinCopyRowSave !byte 0,0

vicWinCopyRow = *
   bit aceSuperCpuFlag
   bpl +
   sta scpuHwOn
   sta scpuMrAll
   sta scpuHwOff
+  bit winScrollMask
   bvc ++
   clc
   lda winScrollDest+1
   sta vicWinCopyRowSave+0
   adc vicColorOff
   sta winScrollDest+1
   clc
   lda winScrollSource+1
   sta vicWinCopyRowSave+1
   adc vicColorOff
   sta winScrollSource+1
   jsr vicWinCopyDo
   bit aceSuperCpuFlag
   bpl +
   jsr vicMirrorAll
+  lda vicWinCopyRowSave+0
   sta winScrollDest+1
   lda vicWinCopyRowSave+1
   sta winScrollSource+1
++ bit winScrollMask
   bpl +

   vicWinCopyDo = *
   lda #bkRam0io
   sta bkSelect
   ldy winCols
   dey
-  lda (winScrollSource),y
   sta (winScrollDest),y
   dey
   bpl -
   lda #bkACE
   sta bkSelect
+  jmp vicMirrorOff

vicCursorChar  !byte 0
vicCursorColor !byte 0
vicCursorFlash !byte $00  ;$00=inactive, $ff=active
vicCursorState !byte 0     ;$00=flashedOff, $ff=flashedOn
vicCursorCountdown !byte 0
vicCursorMaxcount  !byte 0
vicCursorAddr  !byte 0,0

vicWinCursor = *
   jsr vicMirrorAll
   cmp #0
   beq vicCursorOff
   ldx #20
   cmp #$fa
   bne +
   ldx #10
+  stx vicCursorMaxcount
   tya
   jsr rgbi2vic
   sta vicCursorColor
   lda syswork+0
   ldy syswork+1
   sta vicCursorAddr+0
   sty vicCursorAddr+1
   ldx #bkRam0
   stx bkSelect
   ldy #0
   lda (syswork+0),y
   ldx #bkACE
   stx bkSelect
   sta vicCursorChar
   jsr vicSetColorAddr
   ldy #0
   lda (syswork+0),y
   tax
   lda vicCursorColor
   sta (syswork+0),y
   stx vicCursorColor
   jsr vicUnsetColorAddr
   lda #1
   sta vicCursorCountdown
   lda #$00
   sta vicCursorState
   jsr vicIrqCursorEnter
   lda #$ff
   sta vicCursorFlash
   jmp vicMirrorOff

vicCursorOff = *
   lda #$00
   sta vicCursorFlash
   lda vicCursorAddr+0
   ldy vicCursorAddr+1
   sta syswork+0
   sty syswork+1
   ldy #0
   lda vicCursorChar
   sta (syswork+0),y
   jsr vicSetColorAddr
   lda vicCursorColor
   sta (syswork+0),y
   jsr vicUnsetColorAddr
   jmp vicMirrorOff

vicWinOption = *
   ;** 1.screen color
+  dex
   bne ++
   bcc +
   jsr rgbi2vic
   sta vic+$21
+  lda vic+$21
   jsr vic2rgbi
   ldx #1
   clc
   rts
   ;** 2.border color
++ dex
   bne vicWinOptCursor
   bcc +
   jsr rgbi2vic
   sta vic+$20
   jmp ++
+  lda vic+$20
   jsr vic2rgbi
++ ldx #2
   clc
   rts
   ;** 3.cursor style
   vicWinOptCursor = *
   dex
   bne ++
   bcc +
   nop
+  nop
   ldx #3
   clc
   rts
   ;** 4.cursor-blink speed
++ dex
   bne ++
   bcc +
   nop
+  nop
   ldx #4
   clc
   rts
   ;** 5.screen rvs
++ dex
   bne ++
   bcc +
   nop
+  nop
   ldx #5
   clc
   rts
   ;** 6.cpu speed (ignore)
++ dex
   bne +
   jmp notImp
   ;** 7.color palette
+  dex
   bne ++
   bcc +
   nop
+  nop
   ldx #7
   clc
   rts
++ jmp notImp

vicIrqWork = $a0

vicIrqCursor = *
   bit vicCursorFlash
   bmi vicIrqCursorEnter
-  rts
   vicIrqCursorEnter = *
   dec vicCursorCountdown
   bne -
   lda scpuMrMode
   pha
   jsr vicMirrorAll
   lda vicCursorMaxcount
   sta vicCursorCountdown
   lda vicCursorState
   eor #$ff
   sta vicCursorState
   lda vicCursorAddr+0
   ldy vicCursorAddr+1
   sta vicIrqWork+0
   sty vicIrqWork+1
   bit winChsetRvsChars
   bmi +
   jmp vicIrqNonRvsCharCursor
+  ldx #bkRam0
   stx bkSelect
   ldy #0
   lda (vicIrqWork),y
   ldx #bkACE
   stx bkSelect
   jsr vicReverseChar
   sta (vicIrqWork),y
   jmp vicIrqMirrorOff

vicReverseChar = *
   pha
   sec
   sbc #32
   and #%01000000
   bne +
   pla
   sec
   sbc #64
   jmp ++
+  pla
   clc
   adc #64
++ rts

vicIrqNonRvsCharCursor = *
   lda winCharPalette+$1a
   bit vicCursorState
   bmi +
   lda vicCursorChar
+  ldy #0
   sta (vicIrqWork),y

   vicIrqMirrorOff = *
   pla
   bit aceSuperCpuFlag
   bpl +
   sta scpuHwOn
   sta scpuMrMode
   sta scpuHwOff
+  clc
   rts

vicSetColorAddr = *  ;( (sw+0)=addr ) : (sw+0)=colorAddr
   clc
   lda syswork+1
   adc vicColorOff
   sta syswork+1
   rts

vicUnsetColorAddr = *  ;( (sw+0)=colorAddr ) : (sw+0)=addr
   sec
   lda syswork+1
   sbc vicColorOff
   sta syswork+1
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