;'koala' app: Simple Koala slideshow viewer
;
;Copyright© 2024 Brian Holdsworth
;
; This is free software, released under the MIT License.
;

!source "sys/acehead.asm"
!source "sys/toolbox.asm"
jmp idunAppInit

;constants
KOA_FILE_SZ = 10003
VIC_II_MODE = 3
FILENM_SIZE = 17

;zp vars
dirFd    = $02 ;(1)
dirPtr   = $03 ;(2)
count    = $05 ;(1)
source   = $06 ;(2)
dest     = $08 ;(2)

showUsageErrMsg = *
;    |1234567890123456789012345678901234567890|
!pet "Usage: showvic.app in directory with",13,10
!pet ".koa image files.",13,10
!pet "No images found. <Press any key>",0

;include VIC-II graphics extension
!source "toolx/vic/core.asm"

currDir: !pet ".:",0
idunAppInit = *
   lda #0
   sta count
   lda #<directory
   ldy #>directory
   sta dirPtr
   sty dirPtr+1
   ;open current directory
   lda #<currDir
   ldy #>currDir
   sta zp
   sty zp+1
   jsr aceDirOpen
   bcc scanImages
   jmp exit
   scanImages = *
   sta dirFd
-  ldx dirFd
   jsr aceDirRead
   beq showKoalas
   bcs showKoalas
   jsr isKoalaImage
   jmp -
   showKoalas = *
   lda dirFd
   jsr aceDirClose
   lda count
   bne +
   jsr showUsageError
   jmp exit
+  lda #<directory
   ldy #>directory
   sta dirPtr
   sty dirPtr+1
   jsr graphicOn
-  jsr showKoaBmap
   bcs +    ;failed to load image
   dec count
   beq +    ;all images shown
   jsr nextDirEntry
   ;wait for keystroke
   jsr aceConGetkey
   cmp #$03    ;STOP?
   bne -
+  jmp quit

isKoalaImage = *
   lda #<KOA_FILE_SZ
   ldy #>KOA_FILE_SZ
   cmp aceDirentBytes+0
   beq +
-  rts
+  cpy aceDirentBytes+1
   bne -
   ldy #FILENM_SIZE-1
-  lda aceDirentName,y
   sta (dirPtr),y
   dey
   bpl -
   inc count
   ;fall-through
nextDirEntry = *
   lda dirPtr
   clc
   adc #FILENM_SIZE
   sta dirPtr
   lda dirPtr+1
   adc #0
   sta dirPtr+1
   rts

quit = *
   jsr graphicOff
exit = *
	lda #0
	sta zp
	sta zp+1
	lda #aceRestartApplReset
	jmp aceRestart
showUsageError = *
   lda #<showUsageErrMsg
   ldy #>showUsageErrMsg
   jsr eputs
   jsr aceConGetkey
   rts

graphicOn = *
   lda #FALSE
   jsr toolStatEnable
   ;lda #VIC_II_MODE
   lda #1
   ldx #0
   ldy #0
   jmp xGrMode

graphicOff = *
   lda #0
   jsr xGrMode
   rts

loadImageFile = *
   lda dirPtr
   ldy dirPtr+1
   sta zp
   sty zp+1
   lda #<(bmapBuffer+KOA_FILE_SZ)
   ldy #>(bmapBuffer+KOA_FILE_SZ)
   iny
   sta zw+0
   sty zw+1
   lda #<bmapBuffer
   ldy #>bmapBuffer
   jmp aceFileBload

showKoaBmap = *
   jsr loadImageFile
   bcc +
   rts
+  jsr _copy_bmp
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
   lda #<xGrBitmapAddr
   ldy #>xGrBitmapAddr
   sta dest
   sty dest+1
   ldy #0
-  lda (source),y
   sta (dest),y
   iny
   bne -
   inc source+1
   inc dest+1
   ldy #0
   lda dest+1
   cmp #>(xGrBitmapAddr+$1f00)
   bne -    ;stop copying at $ff00 to not mess up MMU
+  rts
   _copy_color = *
   ldx #0
-  lda colorData,x
   sta xGrScreenAddr,x
   lda colorData+256,x
   sta xGrScreenAddr+256,x
   lda colorData+512,x
   sta xGrScreenAddr+512,x
   lda colorData+768,x
   sta xGrScreenAddr+768,x
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

* = $7400
directory = *
bmapBuffer= directory+FILENM_SIZE*100
bmapData  = bmapBuffer+2
colorData = bmapData+8000
colorMem  = colorData+1000
bkgdColor = colorMem+1000
bssAppEnd = *

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