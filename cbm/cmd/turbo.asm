; Idun Turbo, Copyright© 2026 Brian Holdsworth, MIT License.

; This tool is used to control turbo boost when run on the C64
; Ultimate. 

!source "sys/acehead.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

; Constants
FALSE     = 0x00
TRUE      = 0xff
TURBO_BIT = $d030
MHz !byte 1,2,3,4,6,8,10,12,14,16,20,24,32,40,48,64

; Usage and args
ldUsage !pet "Usage: turbo <on",$dc,"off",$dc,"max>",chrCR,0
argsus = *
!pet "/?"   ;show help
!word doUsageMsg
!pet "on"   ;turbo enable
!word doTurboOn
!pet "of"   ;"off" turbo disable
!word doTurboOff
!pet "ma"   ;"max" turbo max zoomies!
!word doTurboMax
!byte 0

; zp vars
argnum   = $02 ;(1)
utoa     = $03 ;(4)

main = *
   lda #0
   sta argnum
   sta utoa
   sta utoa+1
   sta utoa+2
   sta utoa+3
-  inc argnum
   lda argnum
   cmp aceArgc
   bcs +
   jsr getNextArg
   jmp -
+  clc
   jsr aceTurboCtl
   beq turboNone
   jmp displayMhz
   turboNone = *
   lda #<turboNotAvailable
   ldy #>turboNotAvailable
   jmp puts
   displayMhz = *
   tax
   lda MHz,x
   sta utoa
   ldx #utoa
   jsr putnum
   lda #<displayUnits
   ldy #>displayUnits
   jmp puts
displayUnits !pet " MHz",chrCR,0
turboNotAvailable !pet "Who needs more than 2MHz?",chrCR,0

doUsageMsg = *
   lda #<ldUsage
   ldy #>ldUsage
   jsr eputs
   jmp die

doTurboOn = *
   lda #1
   sta TURBO_BIT
   rts

doTurboOff = *
   lda #0
   sta TURBO_BIT
   rts

doTurboMax = *
   lda #15
   sec
   jsr aceTurboCtl
   jmp doTurboOn

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
getNextArg = *
   ldy #0
   lda argnum
   jsr getarg
   ldx #0
   ldy #0
-  lda argsus,x
   bne +
   rts
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
die = *
   lda #1
   ldx #0
   jmp aceProcExit

;=== bss ===
.localBuf = *

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