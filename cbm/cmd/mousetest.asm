;Copyright© 2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Source and destination devices may be either native or
; virtual drives, but cannot be the same device.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)
;

!source "sys/acehead.asm"
!source "sys/toolhead.asm"
!source "toolx/gfx.asm"
!source "toolx/pointer.asm"

jmp main

IMAGE_COLS = 2
IMAGE_ROWS = 11

.cursorX     = $02  ;(2)
.cursorY     = $04  ;(2)
startX       = $06  ;(2)
startY       = $08  ;(2)
temp         = $0a  ;(2)
rndfill      = $0c  ;(1)

main = *
   ;** vdc mode 1
   lda #FALSE
   jsr toolStatEnable
   lda #$01
   ldx #$00
   ldy #$00
   jsr xGrMode
   bcs +
   ;** clear bitmap and set colors
   lda #$00
   ldy #$00
   jsr xGrClear
   lda #$10
   jsr xGrSetColor
   ;** enable the mouse
   lda #TRUE
   jsr xPtrEnable
   jmp mainloop
+  rts

   mainloop = *
   jsr checkStop
   jsr xPtrPoll
   beq mainloop
   
   drawstart = *
   ldx #.cursorX
   jsr xPtrLoc
   ;startX/Y = .cursorX/Y
   ldx #.cursorX-1
-  inx
   lda $00,x
   sta $04,x
   cpx #.cursorX+3
   bne -
   lda $dc06
   sta rndfill
   drawloop = *
   jsr xPtrPoll
   beq mainloop
   ldx #.cursorX
   jsr xPtrLoc
   ldx #1
-  lda .cursorX,x
   cmp startX,x
   bne +
   lda .cursorY,x
   cmp startY,x
   bne +
   dex
   bpl -
   jmp drawloop
+  lda startY+0
   ldy startY+1
   sta syswork+0
   sty syswork+1
   lda #$00
   sta syswork+4
   lda rndfill
   sta syswork+5
   ;rows = .cursorY - startY
   lda .cursorY+0
   sec
   sbc startY+0
   sta syswork+2
   lda .cursorY+1
   sbc startY+1
   sta syswork+3
   ;cols = (.cursorX - startX) / 8
   lda .cursorX+0
   sec
   sbc startX+0
   sta temp+0
   lda .cursorX+1
   sbc startX+1
   sta temp+1
   jsr .tempDiv
   tay
   ;.X = startX / 8
   lda startX+1
   sta temp+1
   lda startX+0
   sta temp+0
   jsr .tempDiv
   tax
   lda #$10
   jsr xGrOp
   jmp drawloop
   .tempDiv = *
   lsr temp+1
   ror temp+0
   lsr temp+1
   ror temp+0
   lsr temp+1
   ror temp+0
   lda temp+0
   rts

checkStop = *
   jsr aceConStopkey
   bcs ++
   jsr aceConKeyAvail
   bcc +
   rts
+  jsr aceConGetkey
   cmp #"Q"
   beq ++
   rts
++ lda #FALSE
   jsr xPtrEnable
   jsr aceGrExit
   lda #TRUE
   jsr toolStatEnable
   lda #1
   ldx #0
   jmp aceProcExit

!eof
┌────────────────────────────────────────────────────────────────────────┐
│                        TERMS OF USE: MIT License                       │
├────────────────────────────────────────────────────────────────────────┤
│ Copyright (c) 2025 Brian Holdsworth                                    │
│                                                                        │
│ Permission is hereby granted, free of charge, to any person obtaining  │
│ a copy of this software and associated documentation files (the        │
│ "Software"), to deal in the Software without restriction, including    │
│ without limitation the rights to use, copy, modify, merge, publish,    │
│ distribute, sublicense, and/or sell copies of the Software, and to     │
│ permit persons to whom the Software is furnished to do so, subject to  │
│ the following conditions:                                              │
│                                                                        │
│ The above copyright notice and this permission notice shall be         │
│ included in all copies or substantial portions of the Software.        │
│                                                                        │
│ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND         │
│ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     │
│ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. │
│ IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   │
│ CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   │
│ TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      │
│ SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 │
└────────────────────────────────────────────────────────────────────────┘