!zone xVDC_POINTER {
.HEIGHT    = 11
.LMB_CLICK = 1
.RMB_CLICK = 2

xPointerEnable = *
   lda #$ff
   sta .mouseOn
   ldx #1
   jsr vdcRead
   sta ._displaywidth
   ;** choose narrow or wide cursor image
   ;   based on width of the display
   cmp #41
   bcc +
   lda #<bmCursorWideL
   ldy #>bmCursorWideL
   sta bmCursor+0
   sty bmCursor+1
   lda #<bmCursorWideR
   ldy #>bmCursorWideR
   sta bmCursorExt+0
   sty bmCursorExt+1
+  jsr aceConMouse
   lda syswork+0
   ldy syswork+1
   sta .mouseX+0
   sty .mouseX+1
   lda syswork+2
   ldy syswork+3
   sta .mouseY+0
   sty .mouseY+1
   jmp .displayCursor
.mouseOn !byte 0
.mouseX !word 0
.mouseY !word 0
.cursorX !word 0
.cursorY !word 0
.mouseButtons !byte 0

xPointerPoll = *        ;() : .Z=button up/down
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
xPointerLoc = *         ;(.X=zp loc) : X,Y as two words in zero page
   ldy #0
-  cpy #4
   beq +
   lda .cursorX,y
   sta $00,x
   inx
   iny
   jmp -
+  rts
xPointerUpdate = *
   jsr xPointerPoll
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
   sta ._mousework
   lda .cursorX+0
   lsr ._mousework
   ror
   lsr ._mousework
   ror
   lsr ._mousework
   ror
   pha
   tax                  ;.X = draw x>>3
   lda bmCursor+0
   ldy bmCursor+1
   jsr .xorDrawCursor
   pla
   tax
   inx
   ldy bmCursorExt+1
   beq .displayCursor
   lda bmCursorExt+0
   jsr .xorDrawCursor
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
   sta ._mousework
   lda .cursorX+0
   lsr ._mousework
   ror
   lsr ._mousework
   ror
   lsr ._mousework
   ror
   pha
   tax                  ;.X = draw x>>3
   lda bmCursor+0
   ldy bmCursor+1
   jsr .xorDrawCursor
   pla
   tax
   inx
   ldy bmCursorExt+1
   bne +
   rts
+  lda bmCursorExt+0
   ;fall-through
.xorDrawCursor = *   ;(.AY=cursor_bitmap, .X=x_pos/8)
   cpx ._displaywidth
   bcc +
   rts
+  stx ._mousework
   sta zp
   sty zp+1
   ;determine how many rows of cursor will fit
   lda .cursorY+1
   ora .cursorY+0
   bne +
   lda #.HEIGHT
   sta ._cursor_rows
   jmp ++
+  ldx #$06    ;R6=display height
   jsr vdcRead
   asl
   asl
   asl         ;assume 8-pixels tall chars
   sbc .cursorY
   cmp #.HEIGHT
   bcs +
   sta ._cursor_rows
   jmp ++
+  lda #.HEIGHT
   sta ._cursor_rows
   ;convert cursor x/y to bitmap addr
++ lda #0
   sta ._mousework+1
   ldy .cursorY
   beq +
-  lda ._mousework
   clc
   adc ._displaywidth
   sta ._mousework
   lda ._mousework+1
   adc #0
   sta ._mousework+1
   dey
   bne -
   ;read and xor (_mousework+0 -> bmTemp)
+  lda ._mousework
   sta ._mousework+2
   ldy ._mousework+1
   sty ._mousework+3
   jsr vdcAddrWrite16
   ldy #255
   sty ._rowcount
-  inc ._rowcount
   ldy ._rowcount
   cpy ._cursor_rows
   beq +
   jsr vdcRamRead
   eor (zp),y
   sta bmTemp,y
   lda ._mousework
   clc
   adc ._displaywidth
   sta ._mousework
   lda ._mousework+1
   adc #0
   sta ._mousework+1
   tay
   lda ._mousework
   jsr vdcAddrWrite16
   jmp -
   ;write bitmap back
+  lda ._mousework+2
   ldy ._mousework+3
   jsr vdcAddrWrite16
   ldy #255
   sty ._rowcount
-  inc ._rowcount
   ldy ._rowcount
   cpy ._cursor_rows
   beq +
   lda bmTemp,y
   jsr vdcRamWrite
   lda ._mousework+2
   clc
   adc ._displaywidth
   sta ._mousework+2
   lda ._mousework+3
   adc #0
   sta ._mousework+3
   tay
   lda ._mousework+2
   jsr vdcAddrWrite16
   jmp -
+  rts
._mousework !fill 4,0
._cursor_rows !byte 0
._rowcount !byte 0
._displaywidth !byte 0

;** cursor sprite defs
bmCursorNarrow:
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
bmCursorWideL:
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
bmCursorWideR:
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

bmCursor !word bmCursorNarrow
bmCursorExt !word $0000
bmTemp !fill .HEIGHT,0
}
