;'showkoa': Simple Koala image viewer
;
;Copyright© 2024-2025 Brian Holdsworth
;
; This is free software, released under the MIT License.
;

!source "sys/acehead.asm"
!source "sys/toolhead.asm"
!source "toolx/gfx.asm"  ;use VIC gfx routines

jmp init

;constants
KOA_FILE_SZ = 10003
VIC_II_MODE = 3

;zp vars
source   = $02 ;(2)
argnum   = $04 ;(1)
scrnMode = $05 ;(1)
sysType  = $06 ;(1)

showUsageErrMsg = *
;    |1234567890123456789012345678901234567890|
!pet "Usage: showkoa <koa_file> [koa2..koaN]",13,10
contErrMsg = *
!pet "No images found. <Press any key>",13,0
showDisplayErrMsg = *
;    |1234567890123456789012345678901234567890|
!pet "showkoa only for VIC-II 40c display.",13,10,0
showLoadErrMsg !pet ": Fail load Koala format",chrCR,0


currDir: !pet ".:",0
init = *
   lda #0
   sta argnum
   sta scrnMode
   ;check for VIC-II display
   jsr aceMiscSysType
   sta sysType
   cmp #WIN_DRIVER_VDC
   bne +
   jmp showDisplayError
   ;check for at least one arg
+  lda aceArgc
   cmp #2
   bcs +
   beq +
   jmp showUsageError
   ;get image file from args
   nextImageFile = *
+  jsr graphicOn
   inc argnum
   ldy #0
   lda argnum
   jsr getarg
   bne +
   jmp exit
+  jsr showKoala
   bcc +
   jsr showLoadError
+  jsr aceConGetkey
   cmp #$03          ;STOP key?
   beq exit
   jmp nextImageFile
exit = *
   jsr graphicOff
   rts

showKoala = *
   jsr loadImageFile
   bcc +
   rts
+  jsr xGrExtents
   jsr _copy_bmp
   jsr _copy_color
   lda bkgdColor
   sta vic+$21
   clc
   rts
   _copy_bmp = *
   lda #<bmapData
   ldy #>bmapData
   sta source
   sty source+1
   ldy #0
-  lda (source),y
   sta (syswork),y
   iny
   bne -
   inc source+1
   inc syswork+1
   ldy #0
   lda syswork+1
   cmp #$ff
   bne -
   ;avoid writing to $ffxx on C128
   lda sysType
   bmi +
   _copy_bmp_last = *
   lda (source),y
   sta (syswork),y
   iny
   bne _copy_bmp_last
+  rts
   _copy_color = *
   ldx #0
-  lda colorData,x
   sta xVicScreenAddr,x
   lda colorData+256,x
   sta xVicScreenAddr+256,x
   lda colorData+512,x
   sta xVicScreenAddr+512,x
   lda colorData+768,x
   sta xVicScreenAddr+768,x
   lda colorMem,x
   sta $d800,x
   lda colorMem+256,x
   sta $d900,x
   lda colorMem+512,x
   sta $da00,x
   lda colorMem+768,x
   sta $db00,x
   dex
   bne -
   rts

loadImageFile = *
   jsr isKoalaImage
   bcc +
   rts
+  lda #<(bmapBuffer+KOA_FILE_SZ)
   ldy #>(bmapBuffer+KOA_FILE_SZ)
   iny
   sta zw+0
   sty zw+1
   lda #<bmapBuffer
   ldy #>bmapBuffer
   jmp aceFileBload

isKoalaImage = *
   jsr aceFileStat
   cmp #<KOA_FILE_SZ
   beq +
-  sec
   rts
+  cpy #>KOA_FILE_SZ
   bne -
   clc
   rts

showUsageError = *
   lda #<showUsageErrMsg
   ldy #>showUsageErrMsg
   jmp contError
showDisplayError = *
   lda #<showDisplayErrMsg
   ldy #>showDisplayErrMsg
   jsr puts
-  lda #<contErrMsg
   ldy #>contErrMsg
   jmp contError
showLoadError = *
   jsr graphicOff
   jsr zpputs
   lda #<showLoadErrMsg
   ldy #>showLoadErrMsg
   jsr puts
   jmp -
   contError = *
   jsr puts
   jsr aceConGetkey
   rts

graphicOn = *
   lda #VIC_II_MODE
   cmp scrnMode
   beq +
   sta scrnMode
   lda #FALSE
   jsr toolStatEnable
   lda vic+$21
   sta saveBkgd
   lda #VIC_II_MODE
   ldx #0
   ldy #0
   jsr xGrMode
+  rts

graphicOff = *
   lda saveBkgd
   sta vic+$21
   lda scrnMode
   beq +
   lda #0
   sta scrnMode
   jsr aceGrExit
+  lda #TRUE
   jsr toolStatEnable
   jmp toolWinRestore

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

* = $8100
bmapBuffer= *
bmapData  = bmapBuffer+2
colorData = bmapData+8000
colorMem  = colorData+1000
bkgdColor = colorMem+1000
saveBkgd  = bkgdColor+1
bssAppEnd = saveBkgd+1

;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2023-2025 Brian Holdsworth                               │
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