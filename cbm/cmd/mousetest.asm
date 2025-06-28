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

cx       = $02  ;(2) current X/Y
cy       = $04  ;(2)
px       = $06  ;(2) previous X/Y
py       = $08  ;(2)
startX   = $0a  ;(2) start X/Y for draw
startY   = $0c  ;(2)
temp     = $0e  ;(2)
rndfill  = $10  ;(1)

main = *
   ;** gfx mode 1
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
   ldx #cx
   jsr xPtrLoc
   ;startX/Y = cx/Y = px/Y
   ldx #cx-1
-  inx
   lda $00,x
   sta $04,x
   sta $08,x
   cpx #cx+3
   bne -
   lda $dc06
   sta rndfill
   drawloop = *
   jsr xPtrPoll
   beq drawFill
   ldx #cx
   jsr xPtrLoc
   ldx #1
-  lda cx,x
   cmp px,x
   bne +
   lda cy,x
   cmp py,x
   bne +
   dex
   bpl -
   jmp drawloop
+  jsr drawRect
   jmp drawloop
   
   drawFill = *
   lda startY+0
   ldy startY+1
   sta syswork+0
   sty syswork+1
   lda #$00
   sta syswork+4
   lda rndfill
   sta syswork+5
   ;rows = cy - startY
   lda cy+0
   sec
   sbc startY+0
   sta syswork+2
   lda cy+1
   sbc startY+1
   sta syswork+3
   ;cols = (cx - startX) / 8
   lda cx+0
   sec
   sbc startX+0
   sta temp+0
   lda cx+1
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
   jmp mainloop

   drawRect = *
   jsr setUL
   ldx #px
   jsr setLR 
   lda #<UL
   ldy #>UL
   clc
   jsr xRectangle
   ldx #cx
   jsr setLR 
   lda #<UL
   ldy #>UL
   sec
   jsr xRectangle
   ldx #cx
   ldy #3
-  lda $00,x
   sta $04,x
   inx
   dey
   bpl -
   rts

   setUL = *
   lda startX+1
   sta UL
   lda startX
   sta UL+1
   asl UL+1
   rol UL
   asl UL+1
   rol UL
   asl UL+1
   rol UL
   asl UL+1
   rol UL
   asl UL+1
   rol UL
   lda startX
   and #7
   sta UL+1
   lda startY
   sta UL+3
   lda #0
   sta UL+2
   rts
   setLR = *
   lda $01,x
   sta LR
   lda $00,x
   sta LR+1
   asl LR+1
   rol LR
   asl LR+1
   rol LR
   asl LR+1
   rol LR
   asl LR+1
   rol LR
   asl LR+1
   rol LR
   lda $00,x
   and #7
   sta LR+1
   lda $02,x
   sta LR+3
   lda #0
   sta LR+2
   rts
;Vertices for Rectangle
UL !byte   0,0,0,0
LR !byte   0,0,0,0

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