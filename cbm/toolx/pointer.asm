;This extension can only be included immediately after toolx/gfx
* = GfxToolxEnd

jmp PtrInit

;Jump table
xPtrEnable:     jmp xVdcPointerEnable
xPtrDraw:       jmp xVdcPointerDraw
xPtrPoll:       jmp PtrPoll
xPtrLoc:        jmp PtrLoc
xPtrEvent:      jmp PtrEvent

!zone xPtr
!source "toolx/vdc/pointer.asm"

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

; Cursor bitmaps
pbmCursor !word pbmCursorNarrow
pbmCursorExt !word $0000
pbmTemp !fill CURHEIGHT,0

; Mouse state
.mouseOn !byte 0
.mouseX !word 0
.mouseY !word 0
.cursorX !word 0
.cursorY !word 0
.mouseButtons !byte 0

; Mouse messages
.LMB_CLICK = 1
.RMB_CLICK = 2

PtrPoll = *        ;() : .Z=button up/down
   bit .mouseOn
   bmi +
   rts
+  jsr aceConMouse
   sta .mouseButtons
   lda syswork+0
   ldy syswork+1
   sta .mouseX+0
   sty .mouseX+1
   lda syswork+2
   ldy syswork+3
   sta .mouseY+0
   sty .mouseY+1
   jsr .moveCursor
   lda .mouseButtons
   cmp #$ff
   rts

PtrLoc = *         ;(.X=zp loc) : X,Y as two words in zero page
   ldy #0
-  cpy #4
   beq +
   lda .cursorX,y
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
   lda .mouseX+0
   sta .buttonEvt+1
   lda .mouseY+0
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

.moveCursor = *  ;( .mouseX, .mouseY )
   ldx #1
-  lda .mouseX,x
   cmp .cursorX,x
   bne +
   lda .mouseY,x
   cmp .cursorY,x
   bne +
   dex
   bpl -
   rts
+  lda .cursorX+1
   sta .mousework
   lda .cursorX+0
   lsr .mousework
   ror
   lsr .mousework
   ror
   lsr .mousework
   ror
   pha
   tax                  ;.X = draw x>>3
   lda pbmCursor+0
   ldy pbmCursor+1
   jsr xPtrDraw
   pla
   tax
   inx
   ldy pbmCursorExt+1
   beq .displayCursor
   lda pbmCursorExt+0
   jsr xPtrDraw
   ;fall-through
.displayCursor = *
   ldx #1
-  lda .mouseX,x
   sta .cursorX,x
   lda .mouseY,x
   sta .cursorY,x
   dex
   bpl -
   lda .cursorX+1
   sta .mousework
   lda .cursorX+0
   lsr .mousework
   ror
   lsr .mousework
   ror
   lsr .mousework
   ror
   pha
   tax                  ;.X = draw x>>3
   lda pbmCursor+0
   ldy pbmCursor+1
   jsr xPtrDraw
   pla
   tax
   inx
   ldy pbmCursorExt+1
   bne +
   rts
+  lda pbmCursorExt+0
   jmp xPtrDraw
.mousework !fill 4,0

PtrInit = *
    jsr aceMiscSysType
    cmp #WIN_DRIVER_VDC
    bne +
    jmp PtrToolxEnd
+   nop         ;TODO support VIC-II pointer
PtrToolxEnd = *
