;'showvdc' cmd: Simple slideshow image viewer for VDC graphics modes
;
;Copyright© 2022 Brian Holdsworth
;
; This is free software, released under the MIT License.
;
; This command works for specially converted/formatted "*.vdc" image files.
; Such files have a 4-byte prefix like "VDCn", where 'n' is an alphanumeric
; value for the VDC graphics mode needed to display the bitmap correctly.
;
; This command can also load standard monochrome Netpbm files. These have
; filenames like "*.pbm" and also include a prefix that specifies the file
; is a monochrome bitmap and its dimensions. If the dimensions fit in a VDC
; mode handled by the machine (including VRAM limits), then they are rendered.
;

!source "sys/acehead.asm"
!source "sys/toolhead.asm"
!source "sys/acemacro.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

grXextent   = $02  ;(1)
grYextent   = $03  ;(1)
displayRow  = $04  ;(2)
argnum      = $06  ;(1)
temp        = $07  ;(2)
grMode      = $09  ;(1)
bmFiledesc  = $0a  ;(1)
bmLines     = $0b  ;(1)
drawColor   = $0c  ;(1)

displayUsageErrorMsg = *
;    |1234567890123456789012345678901234567890|
!pet "usage: showvdc <img1> [img2..imgN]",chrCR,0

!source "toolx/vdc/core.asm"

main = *
   lda #0
   sta argnum
   sta grMode
   sta bmFiledesc
   ;check for at least one arg
   lda aceArgc
   cmp #2
   bcs getImage
   jmp displayUsageError
   ;get image from arg
   getImage = *
   inc argnum
   ldy #0
   lda argnum
   jsr getarg
   bne +
   jmp exit
   ;text mode/show status
+  lda zp
   sta temp+0
   lda zp+1
   sta temp+1
   lda #FALSE
   jsr toolStatEnable
   ldx #0
   ldy #0
   lda #0
   stx grXextent
   sty grYextent
   sta grMode
   jsr xGrMode
   jsr bitmapImageOpen
   beq getImage
   ;init graphics display
+  ldx grXextent
   ldy grYextent
   lda grMode
   jsr xGrMode
   bcc +
   lda #<displayModeErrorMsg
   ldy #>displayModeErrorMsg
   jmp exit
   ;load/show bitmap part
+  stx grXextent
   sty grYextent
   sty bmLines
   lda #0
   sta displayRow+0
   sta displayRow+1
   ldy #$0e
   jsr xVdcMemClear
   lda drawColor
   jsr setDrawColor
   ;8 bitmap rows per loop
   lda #0
   sta temp+1
   lda grXextent
   asl
   rol temp+1
   asl
   rol temp+1
   asl
   rol temp+1
   sta temp+0
   loadBitmap = *
-  dec bmLines
   bpl +
   jmp loadAttributes
+  jsr bitmapImageRead
   bcc +
   jmp displayBitmapError
+  lda displayRow+0
   sta syswork+0
   lda displayRow+1
   sta syswork+1
   lda #8
   ldy #0
   sta syswork+2
   sty syswork+3
   ldx #0
   stx syswork+4
   ldy grXextent
   lda #$40
   jsr xGrOp
   ;+8 rows
   lda #8
   clc
   adc displayRow+0
   sta displayRow+0
   bcc +
   inc displayRow+1
+  jmp -
   loadAttributes = *
   ;that's all for monochrome bitmaps
   lda grMode
   cmp #7
   beq waitInkey
   cmp #2
   beq waitInkey
   ;load attrs for modes 3-6
   lda #0
   sta displayRow+0
   sta displayRow+1
   sta temp+1
   lda grXextent
   asl
   rol temp+1
   asl
   rol temp+1
   sta temp+0
   lda grYextent
   ldx grMode
   cpx #5
   bne +
   asl
   asl
+  cpx #6
   bne +
   asl
   asl
+  nop
-  sta bmLines
   jsr bitmapImageRead
   bcc +
   jmp displayBitmapError
+  lda displayRow+0
   sta syswork+0
   lda displayRow+1
   sta syswork+1
   lda #4
   ldy #0
   sta syswork+2
   sty syswork+3
   ldx #0
   stx syswork+4
   ldy grXextent
   lda #$40
   jsr xGrAttr
   ;+4 rows
   lda #4
   clc
   adc displayRow+0
   sta displayRow+0
   bcc +
   inc displayRow+1
+  ;-4 rows read
   lda bmLines
   sec
   sbc #4 
   bne -
   waitInkey = *
   jsr aceConGetkey
   cmp #HotkeyStop
   bne +
   jmp quit
+  +cmpASCII "q"
   bne +
   jmp quit
+  cmp #$20
   beq +
   sec
   sbc #"0"
   beq waitInkey
   bcc waitInkey
   cmp #$8
   bcs waitInkey
   jsr modDrawColor
   jmp waitInkey
   ;load next image from arg-list
+  jmp getImage
displayBitmapError = *
   lda argnum
   ldy #0
   jsr getarg
   ldx #stdout
   jsr zpputs
   lda #<displayBitmapErrorMsg
   ldy #>displayBitmapErrorMsg
   jmp exit
displayBitmapErrorMsg !pet ": Failed bitmap load",chrCR,0
displayModeErrorMsg !pet "Failed set VDC mode",chrCR,0
quitMsg !pet "Quit",chrCR,0
quit:
   lda #<quitMsg
   ldy #>quitMsg
   ;fall-through
exit:
   pha
   tya
   pha
   ;restore shell window
   jsr graphicOff
   pla
   tay
   pla
   jsr puts
   lda #0
   ldx #0
   jmp aceProcExit
displayUsageError = *
   lda #<displayUsageErrorMsg
   ldy #>displayUsageErrorMsg
   jmp exit

bitmapImageOpen = *     ;(temp=filename): grMode, .ZS=error
   lda bmFiledesc
   jsr close
   lda temp+0
   sta zp
   lda temp+1
   sta zp+1
   lda #"B"
   jsr open
   bcc +
   jmp displayBitmapError
+  sta bmFiledesc
   ;read 3-byte header
   lda #3
   ldy #0
   jsr bmGetData
   bcc +
   jmp displayBitmapError
+  jsr bmHeaderVdc
   bne +
   jsr bmHeaderPbm
   bne +
   jmp displayBitmapError
+  rts
   bmGetData = *
   ldx #<bmBuffer
   stx zp
   ldx #>bmBuffer
   stx zp+1
   ldx bmFiledesc
   jmp read

bmHeaderVdc = *
   ldx #3
-  dex
   bmi +
   lda VdcHeaderStr,x
   cmp bmBuffer,x
   beq -
   jmp ++
+  lda #$e0
   sta drawColor
   ;next byte should be vdc mode
   lda #1
   ldy #0
   jsr bmGetData
   lda bmBuffer
   sec
   sbc #"0"
   sta grMode
   rts
++ lda #0
   sta grMode
   rts
VdcHeaderStr !text "VDC"

bmHeaderPbm = *
   ldx #3
-  dex
   bmi +
   lda PbmHeaderStr,x
   cmp bmBuffer,x
   beq -
   jmp pbmModeNone
   ;check if 800x600 (VDC mode 7)
+  lda #8
   ldy #0
   jsr bmGetData
   ldx #8
-  dex
   bmi pbmMode7
   lda PbmSizeStr,x
   cmp bmBuffer,x
   beq -
   ;check width <= 640
   lda bmBuffer
   cmp #$36
   beq +
   bcs pbmModeNone
   jmp pbmMode2
+  lda bmBuffer+1
   cmp #$34
   beq pbmMode2
   bcs pbmModeNone
   pbmMode2 = *
   jsr parseBmSize
   lda #2
   ldy #102
   cpy grYextent
   bcs +
   sty grYextent
   jmp +
   pbmMode7 = *
   lda #7
+  ldy #$0e
   sty drawColor
   sta grMode
   rts
   pbmModeNone = *
   lda #0
   sta grMode
   rts
PbmHeaderStr !text "P4",10
PbmSizeStr !text "800 600",10

parseBmSize = *
   ldx #0
   jsr parseDigits
   lda temp+0
   and #$07
   sta widthRemainder
   lda temp+1
   lsr
   ror temp+0
   lsr
   ror temp+0
   lsr
   ror temp+0
   lda widthRemainder
   beq +
   inc temp+0
+  lda temp+0
   sta grXextent
   ldx #4
   jsr parseDigits
   lda temp+1
   lsr
   ror temp+0
   lsr
   ror temp+0
   lsr
   ror temp+0
   lda temp+0
   sta grYextent
   rts
parseDigits = *
   lda bmBuffer,x
   jsr digitTimesTen
   sta temp+0
   lda #0
   sta temp+1
   inx
   lda bmBuffer,x
   cmp #10
   beq +
   jsr tempTimesTen
   lda bmBuffer,x
   jsr digitTimesTen
   clc
   adc temp+0
   sta temp+0
   lda temp+1
   adc #0
   sta temp+1
   inx
   lda bmBuffer,x
   cmp #10
   beq +
   sec
   sbc #$30
   clc
   adc temp+0
   sta temp+0
   lda temp+1
   adc #0
   sta temp+1
+  rts
digitTimesTen = *
   sec
   sbc #$30
   sta digitTemp
   asl
   asl
   clc
   adc digitTemp
   asl
   rts
tempTimesTen = *
   lda temp+0
   asl
   rol temp+1
   asl
   rol temp+1
   adc temp+0
   bcc +
   inc temp+1
+  asl
   rol temp+1
   sta temp+0
   rts
digitTemp !byte 0,0
widthRemainder !byte 0

bitmapImageRead = *
   lda temp+0
   ldy temp+1
   jsr bmGetData
   lda #<bmBuffer
   ldy #>bmBuffer
   sta syswork+6
   sty syswork+7
   rts

setDrawColor = *  ;(.A=fg/bg color)
   sta drawColor
   ldx #$1a
   jmp vdcWrite

modDrawColor = *  ;(.A=new color)
   pha
   lda drawColor
   cmp #$0f
   bcs +
   pla
   asl
   asl
   asl
   asl
   jmp setDrawColor
+  pla
   jmp setDrawColor

graphicOff = *
   jsr aceGrExit
   jsr toolWinRestore
   lda #TRUE
   jsr toolStatEnable
   rts

;******** standard library ********
eputs = *
   ldx #stderr
   jmp fputs
puts = *
   ldx #stdout
fputs = *
   sta zp
   sty zp+1
zpputs = *
   ldy #$ff
-  iny
   lda (zp),y
   bne -
   tya
   ldy #0
   jmp write

putchar = *
   ldx #stdout
putc = *
   sta putcBuffer
   lda #<putcBuffer
   ldy #>putcBuffer
   sta zp
   sty zp+1
   lda #1
   ldy #0
   jmp write
putcBuffer !byte 0

getarg = *
   sty zp+1
   asl
   rol zp+1
   clc
   adc aceArgv+0
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
   rts

bss      = *
bmBuffer = *

;===the end===

;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2021 Brian Holdsworth                                    │
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