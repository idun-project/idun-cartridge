;'mode' cmd: change video and character set settings
;
;Copyright© 2020 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Change video text & graphics modes. Also change loaded
; character set.
;
; ex.
; mode 80 - set 80 column text mode
; mode 40 - set 40 column text mode
; mode vdc 1 - set VDC graphics mode #1
; mode vdc 3 32 24 - set VDC graphics mode #3 with X Y dimensions
; mode vic 2 - set VIC graphics mode #2
; mode 80 cbm - switch to CBM character set and 80 columns
;
;@see usemsg

!source "sys/acehead.asm"
!source "sys/acemacro.asm"
!source "sys/toolhead.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

columns = $02
rows    = $03
digit   = $04
itoa    = $05   ;(4)
argnum  = $09
dbgmode = $0a
con_x   = $0b
con_y   = $0c
attrIdx = $0d
colPtr  = $0e   ;(2)
;VIC/VDC graphics mode
vicm    = $10
vdcm    = $11

!source "toolx/vdc/core.asm"

main = *
   ;** init zp vars
   lda #255
   sta vicm
   lda #0
   sta vdcm
   lda toolWinRegion+1
   sta columns
   cmp #80
   beq +
   lda #0
   sta vicm
   lda #255
   sta vdcm
+  lda #0
   sta argnum
   sta dbgmode
   ;default to current rows
   lda toolWinRegion+0
   sta rows
-  inc argnum
   lda argnum
   cmp aceArgc
   bcc +
   jmp doPrintMode
+  jsr nextArg
   jmp -
   nextArg = *
   ldy #0
   jsr getarg
   ldx #0
-  ldy #0
   lda argsus,x
   beq numericArg
+  lda (zp),y
   cmp argsus,x
   beq +
   txa
   clc
   adc #4
   tax
   jmp -
+  inx
   iny
   lda (zp),y
   cmp argsus,x
   beq +
   inx
   inx
   inx
   jmp -
+  inx
   lda argsus,x
   sta zp+0
   inx
   lda argsus,x
   sta zp+1
   jmp (zp)
   numericArg = *
   jsr numarg
   bcc +
   jmp doUsageMsg
+  ldx vicm
   bmi +
   jmp setVicMode
+  ldx vdcm
   bmi +
   jmp setVgrMode
+  rts

   doPrintMode = *
   bit dbgmode
   bpl debugModeOff
   jsr doTestPattern
   bcs printModeCont
   jsr initHotkeys
-  jsr aceConGetkey
   jsr toolKeysHandler
   jmp -
   debugModeOff = *
   lda vdcm
   beq printModeCont
   lda vicm
   beq printModeCont
   rts
   printModeCont = *
   jsr termHotkeys
   jsr saveModeParams
   jsr aceWinMax
   jsr aceWinSize
   sta rows
   stx columns
   jsr toolWinRestore
   jsr restoreModeParams
   lda #TRUE
   jsr toolStatEnable
   lda rows
   sta itoa
   ldx columns
   cpx #80
   bne +
   lda #<vdc
   ldy #>vdc
   jsr puts
   jmp ++
+  lda #<vic
   ldy #>vic
   jsr puts
++ lda #0
   sta itoa+1
   sta itoa+2
   sta itoa+3
   ldx #itoa
   jsr putnum
   lda #<mode
   ldy #>mode
   jsr puts
   rts
vdc   !pet "VDC 80x",0
vic   !pet "VIC-II 40x",0
mode  !pet " active",chrCR,0

   exitDebug = *
   lda #<debug_file
   ldy #>debug_file
   sta zp
   sty zp+1
   lda vdcm
   bmi +
   jsr vdcDumpRegs
+  lda vicm
   bmi +
   ;TODO
   ;jsr vicDumpRegs
+  jsr aceGrExit
   jsr printModeCont
   lda #0
   ldy #0
   jmp aceProcExit
debug_file !pet "z:mode.debug",0

   scrShiftL = *
   ldx #2
   jsr vdcRead
   clc
   adc #1
   jmp vdcWrite

   scrShiftR = *
   ldx #2
   jsr vdcRead
   sec
   sbc #1
   jmp vdcWrite

   scrShiftU = *
   ldx #7
   jsr vdcRead
   clc
   adc #1
   jmp vdcWrite

   scrShiftD = *
   ldx #7
   jsr vdcRead
   sec
   sbc #1
   jmp vdcWrite

   initHotkeys = *
   ldx #<exitDebug
   ldy #>exitDebug
   lda #HotkeyStop
   jsr toolKeysSet
   ldx #<scrShiftR
   ldy #>scrShiftR
   lda #HotkeyRight
   jsr toolKeysSet
   ldx #<scrShiftL
   ldy #>scrShiftL
   lda #HotkeyLeft
   jsr toolKeysSet
   ldx #<scrShiftU
   ldy #>scrShiftU
   lda #HotkeyUp
   jsr toolKeysSet
   ldx #<scrShiftD
   ldy #>scrShiftD
   lda #HotkeyDown
   jsr toolKeysSet
   rts

   termHotkeys = *
   lda #HotkeyStop
   jsr toolKeysRemove
   lda #HotkeyRight
   jsr toolKeysRemove
   lda #HotkeyLeft
   jsr toolKeysRemove
   lda #HotkeyUp
   jsr toolKeysRemove
   lda #HotkeyDown
   jsr toolKeysRemove
   rts

   saveModeParams = *
   jsr aceConGetpos
   stx con_x
   sta con_y
   rts

   restoreModeParams = *
   lda toolWinScroll+2
   sta syswork+0
   lda toolWinScroll+3
   sta syswork+1
   lda toolWinScroll+0
   ldx toolWinScroll+1
   jsr aceWinSet
   lda con_y
   ldx con_x
   jmp aceConPos

   enableVdc = *
   lda #255
   sta vicm
   lda vdcm
   bpl doVdcGraphics
   inc vdcm
   doVdcGraphics = *
   lda vdcm
   ldx columns
   ldy rows
   jsr xVdcGrMode
   bcc +
   lda #<nonVdcMode
   ldy #>nonVdcMode
   jsr eputs
   jmp die
+  stx columns
   sty rows
   rts
nonVdcMode !pet "Invalid VDC mode",chrCR,0

   enableVic = *
   lda #255
   sta vdcm
   lda vicm
   bpl doVicGraphics
   inc vicm
   doVicGraphics = *
   ldx #$0
   ldy #$0e
   lda vicm
   beq doVicTextMode
   ;TODO Handle VIC-II graphics mode 1-4
   rts

   doVicTextMode = *
   lda #0
   ldx #40
   jmp aceWinScreen

clrbarX !byte 0
clrbarW !byte 0
barColor !byte 0

doTestPattern = *
   lda vdcm
   bne +
   ;no test pattern for text mode?
-  sec
   rts
+  lda vicm
   bne +
   jmp -
   ;disable toolbar
+  lda #FALSE
   jsr toolStatEnable
   ;clear bitmap and attributes
   lda #0
   ldy #0
   jsr xVdcMemClear
   ;choose test based on VDC mode
   lda vdcm
   cmp #3
   bcs +
   ;test pattern for mono bitmap
-  jmp doTestBitmap
+  cmp #7
   beq -
   cmp #5
   bcc +
   ;draw spectrum bars
   jmp doSpectrum
   doColorbars = *
+  lda columns
   lsr
   lsr
   lsr
   sta clrbarW
   lda #0
   sta clrbarX
   lda #$ff
   sta barColor
   jsr setColorbar
-  jsr clrbarRows
   ;top bar
   lda #0
   sta syswork+0
   ldx clrbarX
   ldy clrbarW
   lda #$10
   jsr xVdcGrAttr
   ;bottom bar
   jsr setColorbar
   jsr clrbarRows
   lda syswork+2
   sta syswork+0
   ldx clrbarX
   ldy clrbarW
   lda #$10
   jsr xVdcGrAttr
   lda clrbarX
   clc
   adc clrbarW
   sta clrbarX
   jsr setColorbar
   bne -
   clc
   rts
   setColorbar = *
   inc barColor
   lda barColor
   cmp #17
   bne +
   rts
+  asl
   asl
   asl
   asl
   sta syswork+5
   rts
   clrbarRows = *
   lda rows
   cmp #$20
   bne +
   lsr
+  sta syswork+2
   lda #0
   sta syswork+1
   sta syswork+3
   sta syswork+4
   rts

doSpectrum = *
   ;fill bitmap with checkered pattern
   lda vdcm
   cmp #6
   bne +
   ;fill even frame (mode 6)
   clc
   jsr xGrExtents
   lda syswork+0
   ldy syswork+1
   jsr vdcAddrWrite16
   ldy #0
-  lda #$55
   jsr vdcRamWrite
   lda #$ff
   ldx #30
   jsr vdcWrite
   iny
   cpy #$52
   bne -
   ;fill odd frame (mode 6)
   lda syswork+4
   ldy syswork+5
   jsr vdcAddrWrite16
   ldy #0
-  lda #$aa
   jsr vdcRamWrite
   lda #$ff
   ldx #30
   jsr vdcWrite
   iny
   cpy #$52
   bne -
   ;fill all attrs (mode 6)
   lda syswork+2
   ldy syswork+3
   jsr vdcAddrWrite16
   ldy #0
-  lda #$00
   jsr vdcRamWrite
   lda #$ff
   ldx #30
   jsr vdcWrite
   iny
   cpy #$52
   bne -
   lda rows
   asl
   sta rows
   lda #<specCol80
   ldy #>specCol80
   jmp contSpectrum
+  cmp #5
   beq +
   sec
   rts
   ;fill line-by-line (mode 5)
+  asl rows
   lda #0
   ldy #0
   jsr vdcAddrWrite16
-  lda #$55
   jsr vdcRamWrite
   lda #$27
   ldx #30
   jsr vdcWrite
   iny
   lda #$aa
   jsr vdcRamWrite
   lda #$27
   ldx #30
   jsr vdcWrite
   iny
   bne -
   lda #<specCol40
   ldy #>specCol40
   contSpectrum = *
   sta colPtr+0
   sty colPtr+1
   lda #0
   sta attrIdx
-  ldx attrIdx
   cpx #56
   bne +
   clc
   rts
+  jsr spectrumDraw
   jmp -
   spectrumDraw = *
   lda #0
   sta specCol
-  lda spectrumAttr,x
   sta syswork+5
   lda #0
   sta syswork+4
   sta syswork+3
   sta syswork+1
   lda specRow
   sta syswork+0
   lda rows
   lsr
   lsr
   sta syswork+2
   ldy specCol
   lda (colPtr),y
   tax
   lda columns
   lsr
   lsr
   lsr
   tay
   lda #$10
   jsr xVdcGrAttr
   inc attrIdx
   inc specCol
   lda specCol
   cmp #7
   beq +
   ldx attrIdx
   jmp -
+  lda rows
   lsr
   lsr
   clc
   adc specRow
   sta specRow
   rts

spectrumAttr:
!byte $1f,$0f,$11,$10,$10,$00,$00
!byte $3f,$2f,$33,$32,$30,$22,$20
!byte $5f,$4f,$55,$54,$50,$44,$40
!byte $7f,$6f,$77,$76,$70,$66,$60
!byte $9f,$8f,$99,$98,$90,$88,$80
!byte $bf,$af,$bb,$ba,$b0,$aa,$a0
!byte $df,$cf,$dd,$dc,$d0,$cc,$c0
!byte $ff,$ef,$ff,$fe,$f0,$ee,$e0
specCol80 !byte 2,12,22,32,42,52,62
specCol40 !byte 1,6,11,16,21,26,31
specRow !byte 0
specCol !byte 0

bitmapTestFile !pet "z:tpat600.pbm",0
bitmapTestFd !byte 0
bitmapBlks !byte 0

doTestBitmap = *
   lda rows
   cmp #25
   bne +
   lda #"2"
   sta bitmapTestFile+6
   jmp contTestBitmap
+  cmp #60
   bne contTestBitmap
   lda #"4"
   sta bitmapTestFile+6
   lda #"8"
   sta bitmapTestFile+7
   contTestBitmap = *
   lda #<bitmapTestFile
   ldy #>bitmapTestFile
   sta zp
   sty zp+1
   lda #"R"
   jsr open
   bcc +
   rts
+  sta bitmapTestFd
   ;read/discard .pbm file header
   lda #<.bitmapBuf
   ldy #>.bitmapBuf
   sta zp
   sty zp+1
   lda #11
   ldy #0
   ldx bitmapTestFd
   jsr read
   bcc +
   rts
   ;read bitmap rows in blocks of 8x column bytes
+  lda rows        ;max rows (8x75 = 600 pixel lines)
   sta bitmapBlks
-  dec bitmapBlks
   bpl +
   lda bitmapTestFd
   jmp close
+  lda columns
   ldy #0
   sty itoa
   asl
   rol itoa
   asl
   rol itoa
   asl
   rol itoa
   ldy itoa
   ldx bitmapTestFd
   jsr read
   bcc +
   lda bitmapTestFd
   jmp close
+  jsr dispBitmapBuf
   jmp -

   dispBitmapBuf = *
   lda #0
   sta syswork+1
   sta syswork+3
   sta syswork+4
   ;start row?
   lda rows
   sec
   sbc #1
   sbc bitmapBlks
   sta syswork+0
   asl syswork+0
   rol syswork+1
   asl syswork+0
   rol syswork+1
   asl syswork+0
   rol syswork+1
   ;other params
   lda #8
   sta syswork+2
   lda #<.bitmapBuf
   ldy #>.bitmapBuf
   sta syswork+6
   sty syswork+7
   ldy columns
   ldx #0
   lda #$40
   jmp xVdcGrOp

   setChrStandard = *
   lda #<loadstd
   ldy #>loadstd
   jsr puts
   lda #<stdfont
   ldy #>stdfont
   jmp setChrContinue
stdfont !pet "z:chrset-standard",0
loadstd !pet "Loading Standard font...",0

   setChrCommodore = *
   lda #<loadcbm
   ldy #>loadcbm
   jsr puts
   lda #<cbmfont
   ldy #>cbmfont
   jmp setChrContinue
cbmfont !pet "z:chrset-commodore",0
loadcbm !pet "Loading Commodore font...",0

   setChrAnsi = *
   lda #<loadans
   ldy #>loadans
   jsr puts
   lda #<ansfont
   ldy #>ansfont
   jmp setChrContinue
ansfont !pet "z:chrset-ansi",0
loadans !pet "Loading ANSI font...",0

   setChrset = *
   lda argnum
   ldy #0
   jsr getarg
   ldy #2
   ldx #4
-  lda (zp),y
   cmp fontdrv,x
   beq +
   jmp doUsageMsg
+  iny
   inx
   cpx #9
   beq +
   jmp -
+  nop
-  lda (zp),y
   beq +
   sta fontdrv,x
   iny
   inx
   jmp -
+  lda #<loadany
   ldy #>loadany
   jsr puts
   lda #<fontdrv
   ldy #>fontdrv
   jsr puts
   lda #13
   jsr putchar
   lda #<fontdrv
   ldy #>fontdrv
   jmp setChrContinue
fontdrv !pet "z:chrset-"
anyfont !fill 10,0
loadany !pet "Loading font from ",0

   setChrContinue = *
   sta zp
   sty zp+1
   lda aceMemTop
   sta zw
   lda aceMemTop+1
   sta zw+1
   lda #<.charsetBuf
   ldy #>.charsetBuf
   jsr aceFileBload
   bcc +
   lda #<loaderr
   ldy #>loaderr
   jmp eputs
+  lda #<loadfin
   ldy #>loadfin
   jsr puts
   jmp loadChrset
loadfin !pet "done.",chrCR,0
loaderr !pet "fail!",chrCR,0

   setVicMode = *
   sta vicm
   jmp doVicGraphics

   setVgrMode = *
   sta vdcm
   cmp #0
   bne +
   ;default to current number rows
   lda #80
   sta columns
   lda toolWinRegion+0
   sta rows
   jmp ++
   ;default to mode preset X,Y
+  lda #0
   sta columns
   sta rows
   ;next two args = COLSxROWS
++ inc argnum
   lda argnum
   cmp aceArgc
   beq +
   ldy #0
   jsr getarg
   jsr numarg
   bcs +
   sta columns
   inc argnum
   lda argnum
   cmp aceArgc
   beq +
   ldy #0
   jsr getarg
   jsr numarg
   bcs +
   sta rows
+  jmp doVdcGraphics

   setDebugMode = *
   lda #$ff
   sta dbgmode
   rts

   doUsageMsg = *
+  lda #<usemsg1
   ldy #>usemsg1
   jsr eputs
   lda #<usemsg2
   ldy #>usemsg2
   jsr eputs
   jmp die
   
loadChrset = *
   lda #<.charsetBuf
   ldx #>.charsetBuf
   sta syswork+0
   stx syswork+1
   ldy #5
   lda (syswork+0),y
   tay
   clc
   lda syswork+0
   adc #8
   bcc +
   inx
+  sta syswork+0
   stx syswork+1
   lda #%11100000
   cpy #$00
   beq +
   ora #%00010000
+  ldx #$00
   ldy #40
   jsr aceWinChrset
   clc
   lda syswork+0
   adc #40
   sta syswork+0
   bcc +
   inc syswork+1
+  lda #%10001010
   ldx #$00
   ldy #0
   jmp aceWinChrset


usemsg1 = *
   !pet "usage: ",chrCR
   !pet "1. mode [40",$dc,"80]",chrCR
   !pet "Set text mode to 40 or 80 columns",chrCR
   !pet "2. mode [vic 0-4",$dc,"vdc 0-7] [X Y]",chrCR
   !pet "Set text/graphics mode of VIC-II or VDC,",chrCR,0
usemsg2 = *
   !pet "with optional X/Y dimension in char cells",chrCR
   !pet "3. mode [std",$dc,"cbm",$dc,"ans]",chrCR
   !pet "Set character set to Standard, CBM or ANSI",chrCR
   !pet "no args: show current text mode setup",chrCR,0
argsus = *
   !pet "/?"  ;show help
   !word doUsageMsg
   !pet "vd"  ;set vdc text mode
   !word enableVdc
   !pet "40"  ;set vic graphic mode
   !word enableVic
   !pet "80"  ;set vdc graphic mode
   !word enableVdc
   !pet "vi"  ;set vic
   !word enableVic
   !pet "st"  ;standard charset
   !word setChrStandard
   !pet "cb"  ;commodore charset
   !word setChrCommodore
   !pet "an"  ;ansi charset
   !word setChrAnsi
   !pet "ch"  ;any chrset-? file
   !word setChrset
   !pet "de"  ;set debug
   !word setDebugMode
   !byte 0


;******** standard library ********
putchar = *
   ldx #stdout
putc = *
   sta putcBuffer
   lda #<putcBuffer
   ldy #>putcBuffer
   sta zp+0
   sty zp+1
   lda #1
   ldy #0
   jmp write
putcBuffer !byte 0
eputs = *
   ldx #stderr
   jmp fputs
puts = *
   ldx #stdout
fputs = *
   sta zp+0
   sty zp+1
zpputs = *
   ldy #$ff
-  iny
   lda (zp),y
   bne -
   tya
   ldy #0
   jmp write
putnum = *
   ldy #<numbuf
   sty zp+0
   ldy #>numbuf
   sty zp+1
   lda #1
   jsr aceMiscUtoa
   lda #<numbuf
   ldy #>numbuf
   jsr puts
   rts
numbuf !fill 11,0

getarg = *
   sty zp+1
   asl
   sta zp+0
   rol zp+1
   clc
   lda aceArgv+0
   adc zp+0
   sta zp+0
   lda aceArgv+1
   adc zp+1
   sta zp+1
   ldy #0
   lda (zp),y
   tax
   iny
   lda (zp),y
   stx zp+0
   sta zp+1
   ora zp+0
   rts
numarg = *
   ldy #0
   sty numeric
-- lda (zp),y
   beq overflow
   cmp #$30
   bcs +
-  sec
   rts
+  cmp #$3a
   bcs -
   and #$0f
   sta digit
   lda numeric
   asl ;x2
   bcs overflow
   asl ;x4
   bcs overflow
   adc numeric ;x5
   bcs overflow
   asl ;x10
   bcs overflow
   adc digit
   bcs overflow
   sta numeric
   iny
   bne --
   overflow = *
   lda numeric
   clc
   rts 
numeric !byte 0

die = *
   lda #1
   ldx #0
   jmp aceProcExit

;=== bss ===
.bitmapBuf = *
.charsetBuf = *

;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2020 Brian Holdsworth                                    │
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