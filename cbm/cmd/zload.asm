; Idun zload, Copyright© 2023 Brian Holdsworth, MIT License.

; This tool is used to launch Z80 native binaries. The binary
; must be built using the "zcc" compiler with the modified run-
; time library for the idun project. For more information check
; out https://github.com/idun-project/idun-zcc.

!source "sys/acehead.asm"
!source "sys/toolhead.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

; Constants
MAXPROG   = 53200    ;max. size Z80 binary
FALSE     = 0x00
bkRam0    = $3f
bkRam1    = $7f
bkApp     = $0e
bkSelect  = $ff00
FETCH     = $02a2
STASH     = $02af
JMPFAR    = $ff71
JSRFAR    = $ff6e
z80Start  = $3000
z80Load   = $3005
zlUsage64 = *
              !pet "Usage: zload <z80program>",chrCR
              !pet "Wake up the Z80!",chrCR,0
zlErrorMsg1   !pet "Error: Z80 programs require a C128",chrCR,0
zlErrorMsg2   !pet "Error: cannot open program file",chrCR,0
zlErrorMsg3   !pet "Error: Z80 load ONLY from virtual devices",chrCR,0
zlErrorMsg4   !pet "Error: unrecognized z80 binary",chrCR,0
zlErrorMsg5   !pet "Error: Z80 binary too big. Max. 52kB.",chrCR,0
argsus = *
!pet "/?"  ;show help
!word doUsageMsg
!byte 0

; Zp Vars
argnum   = 2
loadFd   = 3
loadDev  = 4
loadSz   = 5   ;(2)
testPtr  = 7   ;(2)
byteCnt  = 9
pageCnt  = 10  ;(2)

main = *
   lda #0
   sta argnum
   jsr getNextArg       ;checks for '/?'
   jsr aceMiscSysType
   bmi +
   ; not compatible with C64
   lda #<zlErrorMsg1
   ldy #>zlErrorMsg1
   jsr eputs
   jmp die
   ; get z80 progname
+  lda #1
   ldy #0
   jsr getarg
   bne +
   jmp doUsageMsg
+  jsr loadz80
   bcs +
   jmp startz80
+  jsr eputs
   jmp die
startz80 = *
   ;setup ram bank 01 for launching Z80
   lda #bkRam0
   sta bkSelect
   ldx #$d0    ;copy ram00 ffd0-ffef to ram01
   ldy #$ff
   stx zp
   sty zp+1
   lda #zp
   sta $2aa
   sta $2b9
   ldy #0
-  ldx #bkRam0
   jsr FETCH
   ldx #bkRam1
   jsr STASH
   iny
   cpy #$20
   bne -
   ldy #$02
   lda #$7e    ;modify $ffd2 so ram01 is used for z80
   ldx #bkRam1
   jsr STASH
   lda #bkApp
   sta bkSelect
   ;copy the return from Z80 stub
   lda #<z80ReturnStub
   ldy #>z80ReturnStub
   sta zp
   sty zp+1
   ldy #0
-  lda (zp),y
   sta $1100,y
   iny
   cpy #z80_stub_sz
   bne -
   ;start z80 program
   lda #1
   sta $02     ;BANK = 1
   lda #>z80Start
   sta $03
   lda #<z80Start
   sta $04     ;z80 start addr
   sta $05     ;clear carry
   lda $d030
   sta $a37
   and $fe
   sta $d030   ;switch to 1MHz
   jsr JMPFAR  ;launch Z80 prog
   rts         ;return to shell

;code we execute when returning from Z80 program; copy this to $1100
z80ReturnStub = *
   lda #bkApp
   sta bkSelect
   lda $a37
   sta $d030         ;back to original CPU speed
   cli               ;resume interrupt handler
   jsr aceGrExit     ;reset VDC
   jsr toolWinRestore
   rts
z80_stub_sz = *-z80ReturnStub

loadz80 = *
   ;open file
   lda #"r"
   jsr open
   bcc +
   lda #<zlErrorMsg2    ;error opening file
   ldy #>zlErrorMsg2
   rts
+  sta loadFd
   jsr aceMiscDeviceInfo
   bcs +
   lda #<zlErrorMsg3    ;not a virtual disk
   ldy #>zlErrorMsg3
   rts
+  lda loadFd
   jsr checkHdr
   bcc +
   lda loadFd
   jsr close
   sec
   lda #<zlErrorMsg4    ;unrecognized binary
   ldy #>zlErrorMsg4
   rts
+  ldx loadFd
   jsr aceFileInfo      ;fetch load device/size
   checkZ80Size = *
   cpy #>MAXPROG
   bcc +
   bne +
   cpx #<MAXPROG
   bcc +
   lda #<zlErrorMsg5    ;z80 binary too big
   ldy #>zlErrorMsg5
   sec
   rts
+  lda syswork+2
   sta loadDev
   lda syswork+0
   sta loadSz+0
   lda syswork+1
   sta loadSz+1
   lda #<z80Load
   ldy #>z80Load        ;load prog addr in RAM bank 01
   sta pageCnt+0
   sty pageCnt+1
-  lda loadSz+1
   beq +
   lda #0
   sta byteCnt
   jsr loadRam01
   dec loadSz+1
   jmp -
+  lda loadSz+0
   sta byteCnt
   jsr loadRam01
   lda loadFd
   jmp close

;RAM bank 01 loader code
loadRam01 = *
   ldx pageCnt+0
   ldy pageCnt+1
   stx zp
   sty zp+1
   lda #zp
   sta $2b9
   ;TALK
   lda loadDev
   ora #$40
   sta $de00
   ; SECOND logical filenum
   lda loadFd
   ora #$60
   nop
   nop
   sta $de00
   ldy #0
-  lda $de01
   beq -
   lda $de00
   ldx #bkRam1
   jsr STASH
   iny
   dec byteCnt
   bne -
   inc pageCnt+1
   ;UNTALK
   lda #$5f
   sta $de00
   clc
   rts

;load first bytes from progfile and confirm header
checkHdr = *
   tax
   lda #<testHdr
   ldy #>testHdr
   sta zp
   sty zp+1
   ldy #0
   lda #5
   jsr read    ;read header
   bcc +
   lda #<zlErrorMsg2    ;error reading file
   ldy #>zlErrorMsg2
   rts
+  ;check hdr while copying it to bank 1
   lda #<z80Start
   ldy #>z80Start
   sta testPtr+0
   sty testPtr+1
   lda #testPtr
   sta $2b9
   ldy #0
-  lda testHdr,y
   cmp progHdr,y
   beq +
   sec
   rts
+  ldx #bkRam1
   jsr STASH
   iny
   cpy #5
   bne -
   clc
   rts
progHdr !byte $8d,$02,$ff,$a9,$c3
testHdr !fill 5,$00

doUsageMsg = *
   lda #<zlUsage64
   ldy #>zlUsage64
   jsr eputs
   jmp die

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
   inc argnum
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