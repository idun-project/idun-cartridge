; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)
;
; Kernel window driver: low-level screen-device operations

winCharAddr  !byte 0,0  ;start address of character memory
winStartAddr !byte 0,0  ;start (char) address of current window
winRows      !byte 0  ;number of rows in current window
winCols      !byte 0  ;number of cols in current window
winStartRow  !byte 0  ;absolute start row of current window
winStartCol  !byte 0  ;absolute start col of current window
winMaxRows   !byte 0  ;maximum number of rows for current screen
winMaxCols   !byte 0  ;maximum number of cols for current screen
winRowInc    !byte 0  ;byte increment between successive rows
winTemp      !fill 8,0  ;temporary working storage
winDriversAv !byte 0  ;window drivers available
winPalette   !fill 8,0  ;palette for the current screen
winChrSpace  !byte 0  ;code of the space character
winChsetRvsChars !byte $ff  ;$ff=rvsChars, $00=nonRvsChars
winCharPalette !fill 42,0  ;palette for graphics characters
winScrollReuWork !byte aceMemNull,aceMemNull,aceMemNull,aceMemNull ;reu scroll
winDriver    !byte 0  ;which driver: $80=vdc, $40=vic, $20=soft80(se)

winStartup = *
   lda #$20
   sta winChrSpace
   lda #$00
!if useVdc {
   ora #$80
}
!if useVic {
   ora #$40
}
!if useSoft80 {
   ora #$20
}
   sta winDriversAv
   jsr vdcStartup
   jsr vicStartup
   jsr seStartup
!if useC128 {
   lda #$80
   bit $d7
   bmi +
   lda #$40
+  nop
}
!if useC64 {
   ldx #$40
   lda configBuf+$c0
   and #$c0
   cmp #$c0
   bne +
   ldx #$20
   bit winDriversAv
   bpl +
   ldx #$80
+  txa
}
   sta winDriver
-- lda winDriver
   and winDriversAv
   bne +
-  ror winDriver
   bcs -
   bcc --
+  lda #0
   ldx #0
   jmp kernWinScreen

winShutdown = *
   jsr vdcShutdown
   jsr vicShutdown
   jsr seShutdown
   clc
   rts

kernWinScreen = *
   sta winTemp+0  ;requested rows
   ;** check special sizes
   cpx #0
   bne +
   ldx #80
   bit winDriver
   bvc +
   ldx #40
+  cpx #255
   bne +
   ldx #80
   lda winDriversAv
   and #$a0
   bne +
   ldx #40
+  ldy #25
   sty winTemp+1  ;max rows
   sty winTemp+2  ;default rows
!if useVdc {
   cpx #40+1
   bcc +
   ldy configBuf+$ce
   sty winTemp+1
   ldy configBuf+$a9
   sty winTemp+2
+  nop
}
   lda winTemp+0
   cmp #0
   bne +
   lda winTemp+2
+  cmp #255
   bne +
   lda winTemp+1
   ;** check screen limits
+  sta winTemp+0
   cmp winTemp+1
   beq +
   bcc +
-  lda #aceErrInvalidWindowParms
   sta errno
   sec
   rts
+  cpx #81
   bcs -
   lda winDriversAv
   and #$a0
   bne +
   cpx #41
   bcs -
   ;** set screen
+  ldy #$40
   cpx #40+1
!if useVic {
   bcc +
}
   ldy #$80
!if useVdc {
   jmp +
}
   ldy #$20
+  tya
   ldy winTemp+0
   ;** fall through

winActivate = *  ;( .A=driverCode, .X=columns, .Y=rows ) : .CS=err
   sta winTemp+0
   bit winTemp+0
   bpl +
!if useFastClock {
   jsr winClockFast
}
   tya
   jsr vdcActivate
   jmp winActvCont
+  nop
!if useFastClock {
   jsr winClockSlow
}
   bit winTemp+0
   bvc +
   jsr vicActivate
   jmp winActvCont
+  bit aceSoft80Allocated
   bmi +
   lda #aceErrNoGraphicsSpace
   sta errno
   sec
   rts
+  jsr seActivate
   ;** auxiliary parameters
   winActvCont = *
+  lda winTemp+0
   sta winDriver
   lda winPalette+7
   ldx #1
   sec
   jsr kernWinOption
   lda winPalette+6
   ldx #2
   sec
   jsr kernWinOption
   jsr kernWinMax
   lda #$c0
   ldx winChrSpace
   ldy winPalette+0
   jsr kernWinCls
   jsr conScrChangeCallback  ;con colors, mouse bounds
   jmp kernWinSize

winClockFast = *
   !if useFastClock {
   lda vic+$11
   and #%01101111
   sta vic+$11
   lda #1
   sta vic+$30
   }
   rts

winClockSlow = *
   !if useFastClock {
   lda #0
   sta vic+$30
   lda vic+$11
   and #%01111111
   ora #%00010000
   sta vic+$11
   }
   rts

kernWinMax = *  ;( )
   lda #0
   sta syswork+0
   sta syswork+1
   lda winMaxRows
   ldx winMaxCols
   ;** fall through

kernWinSet = *
   sta winTemp+0
   stx winTemp+1
   cmp #0
   beq +
   cpx #0
   beq kernWinSetBra1
   clc
   adc syswork+0
   cmp winMaxRows
   beq +
   bcc +
kernWinSetBra1:
   lda #aceErrInvalidWindowParms
   sta errno
   sec
   rts
+  clc
   lda winTemp+1
   adc syswork+1
   cmp winMaxCols
   beq +
   bcs kernWinSetBra1
+  lda syswork+0
   ldx syswork+1
   sta winStartRow
   stx winStartCol
   jsr kernWinPos
   sec
   lda syswork+0
   sbc winStartAddr+0
   sta syswork+0
   lda syswork+1
   sbc winStartAddr+1
   sta syswork+1
   clc
   lda syswork+0
   adc winCharAddr+0
   sta winStartAddr+0
   lda syswork+1
   adc winCharAddr+1
   sta winStartAddr+1
   lda winTemp+0
   ldx winTemp+1
   sta winRows
   stx winCols
   jsr conWinChangeCallback  ;window parameters
   lda winStartRow
   ldx winStartCol
   sta syswork+0
   stx syswork+1
   clc
   rts

kernWinSize = *
   lda winStartRow
   ldx winStartCol
   sta syswork+0
   stx syswork+1
   lda winStartAddr+0
   ldy winStartAddr+1
   sta syswork+2
   sty syswork+3
   lda winRowInc
   sta syswork+4
   lda winRows
   ldx winCols
   clc
   rts

winFillMask  = winTemp+0
winFillCount = winTemp+1
winFillColor = winTemp+2

kernWinCls = *
   ;** save volatile arguments
   sta winFillMask
   stx syswork+4
   sty winFillColor
   ;** initialize
   lda winStartAddr+0
   ldy winStartAddr+1
   sta syswork+0
   sty syswork+1
   lda winRows
   sta winFillCount
   winClsInside = *
   lda winCols
   sta syswork+5
   ;** loop body per row
-  lda winFillMask
   ldx #0
   ldy winFillColor
   jsr kernWinPut
   ;** next row and repeat
   clc
   lda syswork+0
   adc winRowInc
   sta syswork+0
   bcc +
   inc syswork+1
+  dec winFillCount
   bne -
   ;** exit
   clc
   rts

kernWinPos = *
   bit winDriver
   bpl +
   jmp vdcWinPos
+  bvc +
   jmp vicWinPos
+  jmp seWinPos

kernWinGrChrPut= *
   pha
   tya
   pha
   ldy syswork+5
   dey
-  lda (syswork+2),y
   tax
   lda winCharPalette,x
   sta (syswork+2),y
   dey
   bpl -
   ldx syswork+5
   pla
   tay
   pla
kernWinPut = *
   ;IDUN: protect from conflicts with Toolbox interrupt screen redraws
   php
   sei
   bit winDriver
   bpl +
   jsr vdcWinPut
   jmp ++
+  bvc +
   jsr vicWinPut
   jmp ++
+  jsr seWinPut
++ plp
   rts

kernWinGet = *
   bit winDriver
   bpl +
   jmp vdcWinGet
+  bvc +
   jmp vicWinGet
+  jmp seWinGet

winScrollRows   !byte 0
winScrollCount  !byte 0
winScrollDest   = syswork+0 ;(2) [dependency: must be sw+0]
winScrollSource = syswork+2 ;(2) [dependency: must not be sw+0]
winScrollFillChar  !byte 0
winScrollFillColor !byte 0
winScrollFillAttr  !byte 0
winScrollMask   = syswork+5 ;(1)
winScrollRowInc = syswork+6 ;(2)
winScrollUpFlag !byte 0

kernWinScroll = *
   and #%11101100
   sta winScrollMask
   lda syswork+4
   sta winScrollFillChar
   lda syswork+6
   sta winScrollFillAttr
   sty winScrollFillColor
   stx winScrollRows
   cpx #0
   bne +
-  clc
   rts
+  cpx winRows
   bcc +
   lda winScrollMask
   ldx winScrollFillChar
   ldy winScrollFillColor
   jmp kernWinCls
+  lda winScrollMask
   and #$04
   beq +
   jsr winScrollDown
+  lda winScrollMask
   and #$08
   beq -
   ;** fall through

winScrollUp = *
   lda winDriver
   and #$20
   beq +
   lda #$80
   jsr seFastScroll
   bcs +
   jmp winScrollClear
+  lda winScrollRows
   ldx #0
   jsr kernWinPos
   lda syswork+0
   ldy syswork+1
   sta winScrollSource+0
   sty winScrollSource+1
   lda winStartAddr+0
   ldy winStartAddr+1
   sta winScrollDest+0
   sty winScrollDest+1
   lda winRowInc
   ldy #0
   sta winScrollRowInc+0
   sty winScrollRowInc+1
   jsr winScrollRange
   jmp winScrollClear

winScrollDown = *
   lda winDriver
   and #$20
   beq +
   lda #$00
   jsr seFastScroll
   bcs +
   jmp winScrollClear
+  clc ;sic
   lda winRows
   sbc winScrollRows
   ldx #0
   jsr kernWinPos
   lda syswork+0
   ldy syswork+1
   sta winScrollSource+0
   sty winScrollSource+1
   sec
   lda winRows
   sbc #1
   ldx #0
   jsr kernWinPos
   sec
   lda #0
   sbc winRowInc
   sta winScrollRowInc+0
   lda #0
   sbc #0
   sta winScrollRowInc+1
   jsr winScrollRange
   lda winStartAddr+0
   ldy winStartAddr+1
   sta winScrollDest+0
   sty winScrollDest+1
   jmp winScrollClear

winScrollRange = *  ;( winScrollSource++, winScrollDest++, winScrollRowInc )
   ;IDUN: protect from conflicts with Toolbox interrupt screen redraws
   php
   sei
   bit winDriver
   bpl +
   jsr vdcWinCopyInit
+  sec
   lda winRows
   sbc winScrollRows
   sta winScrollCount
-  bit winDriver
   bpl +
   jsr vdcWinCopyRow
   jmp +++
+  bvc +
   jsr vicWinCopyRow
   jmp +++
+  jsr seWinCopyRow
+++clc
   lda winScrollSource+0
   adc winScrollRowInc+0
   sta winScrollSource+0
   lda winScrollSource+1
   adc winScrollRowInc+1
   sta winScrollSource+1
   clc
   lda winScrollDest+0
   adc winScrollRowInc+0
   sta winScrollDest+0
   lda winScrollDest+1
   adc winScrollRowInc+1
   sta winScrollDest+1
   dec winScrollCount
   bne -
   bit winDriver
   bpl +
   jsr vdcWinCopyFinish
+  plp
   rts

winScrollClear = *  ;( winScrollDest, winScrollFillChar, winScrollFillColor )
   lda winScrollRows
   sta winFillCount
   lda winScrollFillChar
   sta syswork+4
   lda winScrollFillAttr
   sta syswork+6
   lda winScrollFillColor
   sta winFillColor
   lda winScrollMask
   sta winFillMask
   jmp winClsInside

kernWinCursor = *
   bit winDriver
   bpl +
   jmp vdcWinCursor
+  bvc +
   jmp vicWinCursor
+  jmp seWinCursor

kernWinPalette = *
   ldx #7
-  lda winPalette,x
   sta syswork,x
   dex
   bpl -
   clc
   rts

kernWinChrset = *  ;( .A=flags, (sw+0)=dataAddr, .X=start, .Y=len ) : .A=flags
   ;** flags: $80=put, $40=get, $20=0:chr/1:palette, $10=0:full/1:rvs
   ;**        $08=8-bit, $04=4-bit, $02=main, $01=alternate
   ;** out flags tells what exists, both put&get means ignore full/rvs
   ;** initialize
   sta syswork+4  ;sw+4 = flags
   sty syswork+5  ;sw+5 = len
   sty syswork+12 ;sw+12= len save
   lda syswork+0
   ldy syswork+1
   sta syswork+6  ;(sw+6) = dataAddr
   sty syswork+7
   ;** set up return code
   lda #%00001010
   bit aceSoft80Allocated
   bpl +
   ora #%10000100
+  sta syswork+8  ;sw+8 = exitFlags
   lda syswork+4
   and #$20
   beq +
   jmp winChrsetPalette
   ;** handle regular character definitions
+  txa
   sta syswork+11  ;sw+11 = startChar
   ;** set start-character address
   ldy #0
   sty syswork+3  ;(syswork+2)=chrAddr
   ldx #3
-  asl
   rol syswork+3
   dex
   bne -
   sta syswork+2
   lda syswork+4
   ldx #$80
   and #$0c
   cmp #$04
   bne +
   lda #>seCharset4bit
   bit syswork+8
   bmi ++
   jmp winChrsetExit
+  ldx #$00
   lda aceCharSetPage ;8bit
++ stx syswork+9  ;sw+9 = 4-bit flag
   clc
   adc syswork+3
   sta syswork+3
   ;** copy
   lda #bkRam0
   sta bkSelect
-- ldy #7
-  bit syswork+4
   bpl ++
   lda (syswork+6),y  ;source
   bit syswork+9
   bpl +
   and #$f0
   sta syswork+10
   lsr
   lsr
   lsr
   lsr
   ora syswork+10
+  sta (syswork+2),y  ;char
++ bit syswork+4
   bvc +
   lda (syswork+2),y  ;char
   sta (syswork+6),y  ;source
+  dey
   bpl -
   clc
   lda syswork+2
   adc #8
   sta syswork+2
   bcc +
   inc syswork+3
+  clc
   lda syswork+6
   adc #8
   sta syswork+6
   bcc +
   inc syswork+7
+  dec syswork+5
   bne --
   lda #bkACE
   sta bkSelect
   ;** load 80-col!if necessary {
   !if useVdc {
   bit syswork+4
   bpl winChrsetExit
   lda syswork+0
   pha
   lda syswork+1
   pha
   lda syswork+11
   ldx syswork+12
   jsr vdcLoadCharset
   pla
   sta syswork+1
   pla
   sta syswork+0
   }

   winChrsetExit = *
   ;** set full/rvs flag, exit
   lda syswork+4
   and #$c0
   cmp #$c0
   bne ++
   ldx #$00
   lda syswork+4
   and #$10
   beq +
   ldx #$ff
+  stx winChsetRvsChars
++ lda syswork+8
   and #$7f
   bit winChsetRvsChars
   bpl +
   ora #$10
+  clc
   rts

winChrsetPalette = *  ;( sw+4=flags, .X=startChar, sw+5=len, (sw+6)=dataAddr )
   ldy #0
   cpy syswork+5
   beq winChrsetExit
-  bit syswork+4
   bpl +
   lda (syswork+6),y
   sta winCharPalette,x
+  bit syswork+4
   bvc +
   lda winCharPalette,x
   sta (syswork+6),y
+  inx
   iny
   dec syswork+5
   bne -
   jmp winChrsetExit

kernWinOption = *
   php
   cpx #6
   beq +++
   plp
   bit winDriver
   bpl +
   jmp vdcWinOption
+  bvc +
   jmp vicWinOption
+  jmp seWinOption
   ;** cpu-speed option (units: MHz)
+++plp
   bcc ++
   cmp #2
   bcs +
   jsr winClockSlow
   jmp ++
+  jsr winClockFast
++ nop
!if useFastClock {
   lda vic+$30
} else {
   lda #$00
}
   and #$01
   clc
   adc #1
   clc
   rts

winIrqCursor = *
   bit winDriver
   bpl +
   jmp vdcIrqCursor
+  bvc +
   jmp vicIrqCursor
+  jmp seIrqCursor

kernGrExit = *
   !if useVdc {
   jmp vdcGrExit
   }
   !if useSoft80 {
   jmp seGrExit
   }
   jmp notImp

!if useVdc {
} else {
   vdcStartup = *
   vdcShutdown = *
   vdcActivate = *
   vdcWinPos = *
   vdcWinPut = *
   vdcWinGet = *
   vdcWinCopyInit = *
   vdcWinCopyRow = *
   vdcWinCopyFinish = *
   vdcFastScroll = *
   vdcWinCursor = *
   vdcWinLoadCharset = *
   vdcWinOption = *
   vdcIrqCursor = *
   vdcScreenSave = *
   vdcScreenUnsave = *
   vdcGrExit = *
}
!if useVic {
} else {
   vicStartup = *
   vicShutdown = *
   vicActivate = *
   vicWinPut = *
   vicWinGet = *
   vicWinColor = *
   vicWinPos = *
   vicWinCursor = *
   vicWinCopyRow = *
   vicWinOption = *
   vicIrqCursor = *
   vicScreenSave = *
   vicScreenUnsave = *
}
!if useSoft80 {
} else {
   seStartup = *
   seShutdown = *
   seActivate = *
   seWinPut = *
   seWinGet = *
   seWinColor = *
   seWinPos = *
   seWinCursor = *
   seWinCopyRow = *
   seFastScroll = *
   seWinOption = *
   seIrqCursor = *
   seScreenSave = *
   seScreenUnsave = *
   seGrExit = *
   seCharset4bit = $f800 ;vic screen
}
   jmp notImp


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