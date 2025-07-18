!zone xVicPointer

SPRITE_NUM = 0
SPRITEMASK = 1<<SPRITE_NUM
SPRITE_PTR = $cff8+SPRITE_NUM
SPRITE_DAT = $ca00
SPRITE_IMG = SPRITE_DAT+(SPRITE_NUM*64)

xVicPointerEnable = *
   sta mouseOn
   cmp #TRUE
   beq +
   jmp .hideCursor
+  jsr aceConMouse
   lda syswork+0
   ldy syswork+1
   sta mouseX+0
   sty mouseX+1
   lda syswork+2
   ldy syswork+3
   sta mouseY+0
   sty mouseY+1
   jsr .displayCursor
   ;fall-through
xVicPointerMove = *  ;( mouseX, mouseY )
   lda mouseOn
   bne +
   rts
+  lda mouseX
   sta cursorX
   clc
   adc #25
   sta vic+SPRITE_NUM
   lda mouseX+1
   sta cursorX+1
   adc #0
   cmp #1
   bne +
   ora vic+$10
   jmp ++
+  lda #$fe
   and vic+$10
++ sta vic+$10
   lda mouseY
   sta cursorY
   clc
   adc #54
   sta vic+SPRITE_NUM+1
   rts

.displayCursor = *
   ;copy the sprite image data
   lda #<SPRITE_IMG
   ldy #>SPRITE_IMG
   sta syswork
   sty syswork+1
   ldy #0
   ldx #0
-  lda pbmCursorNarrow,x
   sta (syswork),y
   lda #0
   iny
   sta (syswork),y
   iny
   sta (syswork),y
   iny
   inx
   cpx #CURHEIGHT
   bne -
-  cpy #64
   beq +
   sta (syswork),y
   iny
   jmp -
   ;set the sprite pointer
+  lda #(SPRITE_IMG-$c000)>>6
   sta SPRITE_PTR
   ;enable the sprite
   lda #SPRITEMASK
   ora vic+$15
   sta vic+$15
   ;make cursor white
   lda #$01
   sta vic+$27
   rts

.hideCursor = *
   ;disable the sprite
   lda #$ff
   eor #SPRITEMASK
   and vic+$15
   sta vic+$15
   rts

!eof
┌────────────────────────────────────────────────────────────────────────┐
│                        TERMS OF USE: MIT License                       │
├────────────────────────────────────────────────────────────────────────┤
│ Copyright (c) 2023 Brian Holdsworth                                    │
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