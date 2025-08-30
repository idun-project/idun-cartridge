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
   jsr getCursor
   ;startX/Y = cx/Y = px/Y
   ldx #cx-1
-  inx
   lda $00,x
   sta $04,x
   sta $08,x
   cpx #cx+3
   bne -
   jsr setFill
   drawloop = *
   jsr xPtrPoll
   beq drawFill
   ldx #cx
   jsr getCursor
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

   lda Y1+0
   ldy Y1+1
   sta syswork+0
   sty syswork+1
   ;rows = Y2 - Y1
   lda Y2
   sec
   sbc Y1
   sta syswork+2
   lda Y2+1
   sbc Y1+1
   sta syswork+3
   ;cols = (X2 - X1) / 8
   lda X2
   sec
   sbc X1
   sta temp+0
   lda X2+1
   sbc X1+1
   sta temp+1
   jsr .tempDiv
   tay
   ;.X = X1 / 8
   lda X1+1
   sta temp+1
   lda X1+0
   sta temp+0
   jsr .tempDiv
   tax
   lda #$00
   sta syswork+4
   lda rndfill
   sta syswork+5
   lda #$10
   jsr xGrOp
   jmp mainloop

   drawRect = *
   ldx #px
   jsr setRect 
   clc
   jsr xRectangle
   ldx #cx
   jsr setRect
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

   getCursor = *
   txa
   pha
   jsr xPtrLoc
   pla
   tax
   lda $0,x
   sec
   sbc #1
   sta $0,x
   lda $1,x
   sbc #0
   sta $1,x
   rts

   setFill = *
   lda $dc06
   sta rndfill
   jsr aceMiscSysType
   bmi +
   lda $dc04
   sta rndfill
+  rts
   setRect = *
   lda $01,x
   sta X2+1
   lda $00,x
   sta X2
   lda $02,x
   sta Y2
   lda #0
   sta Y2+1
   lda startX+1
   sta X1+1
   lda startX
   sta X1
   lda startY
   sta Y1
   lda #0
   sta Y1+1
   rts

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