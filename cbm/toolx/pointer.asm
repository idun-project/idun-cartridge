; toolx/pointer - A toolbox extension for tracking and drawing
; the mouse pointer. Works on C64/C128 and 40c/80c displays.
;
;This extension can only be included immediately after toolx/gfx
* = GfxToolxEnd

jmp PtrInit

;Jump table
xPtrEnable:     jmp xVdcPointerEnable  ;(.A=TRUE or FALSE)
xPtrUpdate:     jmp xVdcPointerMove
xPtrPoll:       jmp PtrPoll
xPtrLoc:        jmp PtrLoc
xPtrEvent:      jmp PtrEvent

; Mouse state
mouseOn !byte 0
mouseX !word 0
mouseY !word 0
cursorX !word 0
cursorY !word 0

!source "toolx/vdc/pointer.asm"
!source "toolx/vic/pointer.asm"

!zone xPtr
.mouseButtons !byte 0
; Mouse messages
.LMB_CLICK = 1
.RMB_CLICK = 2

;** cursor sprite defs
CURHEIGHT    = 11
pbmCursorNarrow:
   !byte %11111100
   !byte %11111000
   !byte %11110000
   !byte %10111000
   !byte %00011100
   !byte %00001110
   !byte %00000110
   !byte %00000000
   !byte %00000000
   !byte %00000000
   !byte %00000000   ;11
pbmCursorWideL:
   !byte %11111111
   !byte %11111111
   !byte %11111111
   !byte %11111111
   !byte %11100011
   !byte %00000000
   !byte %00000000
   !byte %00000000
   !byte %00000000
   !byte %00000000
   !byte %00000000   ;11
pbmCursorWideR:
   !byte %11100000
   !byte %10000000
   !byte %10000000
   !byte %11000000
   !byte %11100000
   !byte %11111000
   !byte %00111110
   !byte %00000000
   !byte %00000000
   !byte %00000000
   !byte %00000000   ;11
pbmTemp !fill CURHEIGHT,0

PtrPoll = *        ;() : .Z=button up/down
   bit mouseOn
   bmi +
   rts
+  jsr aceConMouse
   sta .mouseButtons
   lda syswork+0
   ldy syswork+1
   sta mouseX+0
   sty mouseX+1
   lda syswork+2
   ldy syswork+3
   sta mouseY+0
   sty mouseY+1
   jsr xPtrUpdate
   lda .mouseButtons
   cmp #$ff
   rts

PtrLoc = *         ;(.X=zp loc) : X,Y as two words in zero page
   ldy #0
-  cpy #4
   beq +
   lda cursorX,y
   sta $00,x
   inx
   iny
   jmp -
+  rts

PtrEvent = *
   jsr PtrPoll
   ;detect button press
   bne +
   jmp ++
   ;send button event
+  eor #$ee
   cmp #$01
   bne +
   ;LMB
   lda #.LMB_CLICK
   jmp .sendBtnEvt
+  cmp #$10
   bne ++
   ;RMB
   lda #.RMB_CLICK
   jmp .sendBtnEvt
++ lda #$00
   sta .buttonEvt    ;reset event
   rts
.sendBtnEvt = *
   bit .buttonEvt
   bmi ++
   sta .buttonEvt
   lda mouseX+0
   sta .buttonEvt+1
   lda mouseY+0
   sta .buttonEvt+2
   ldx #3
   lda #<.buttonEvt
   ldy #>.buttonEvt
   jsr aceTtyPut
   ;flag message as sent
   lda #$ff
   sta .buttonEvt
++ rts
.buttonEvt !byte 0    ;LMB/RMB
           !byte 0,0  ;X/Y coords

xVicPtr !word xVicPointerEnable,xVicPointerMove
PtrInit = *
    jsr aceMiscSysType
    cmp #WIN_DRIVER_VDC
    bne +
    jmp PtrToolxEnd
+   lda #<xPtrEnable
    ldy #>xPtrEnable
    sta syswork
    sty syswork+1
    ldx #(PtrInit-xVicPtr-1)
    ldy #5
-   lda xVicPtr,x
    sta (syswork),y
    dey
    dex
    lda xVicPtr,x
    sta (syswork),y
    dey
    dey
    dex
    bpl -
PtrToolxEnd = *

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