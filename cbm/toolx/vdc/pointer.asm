xVdcPointerEnable = *
   lda #$ff
   sta .mouseOn
   ldx #1
   jsr vdcRead
   sta ._displaywidth
   ;** choose narrow or wide cursor image
   ;   based on width of the display
   cmp #41
   bcc +
   lda #<pbmCursorWideL
   ldy #>pbmCursorWideL
   sta pbmCursor+0
   sty pbmCursor+1
   lda #<pbmCursorWideR
   ldy #>pbmCursorWideR
   sta pbmCursorExt+0
   sty pbmCursorExt+1
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

xVdcPointerDraw = *   ;(.AY=cursor_bitmap, .X=x_pos/8)
   cpx ._displaywidth
   bcc +
   rts
+  stx .mousework
   sta zp
   sty zp+1
   ;determine how many rows of cursor will fit
   lda .cursorY+1
   ora .cursorY+0
   bne +
   lda #CURHEIGHT
   sta ._cursor_rows
   jmp ++
+  ldx #$06    ;R6=display height
   jsr vdcRead
   asl
   asl
   asl         ;assume 8-pixels tall chars
   sbc .cursorY
   cmp #CURHEIGHT
   bcs +
   sta ._cursor_rows
   jmp ++
+  lda #CURHEIGHT
   sta ._cursor_rows
   ;convert cursor x/y to bitmap addr
++ lda #0
   sta .mousework+1
   ldy .cursorY
   beq +
-  lda .mousework
   clc
   adc ._displaywidth
   sta .mousework
   lda .mousework+1
   adc #0
   sta .mousework+1
   dey
   bne -
   ;read and xor (mousework+0 -> pbmTemp)
+  lda .mousework
   sta .mousework+2
   ldy .mousework+1
   sty .mousework+3
   jsr vdcAddrWrite16
   ldy #255
   sty ._rowcount
-  inc ._rowcount
   ldy ._rowcount
   cpy ._cursor_rows
   beq +
   jsr vdcRamRead
   eor (zp),y
   sta pbmTemp,y
   lda .mousework
   clc
   adc ._displaywidth
   sta .mousework
   lda .mousework+1
   adc #0
   sta .mousework+1
   tay
   lda .mousework
   jsr vdcAddrWrite16
   jmp -
   ;write bitmap back
+  lda .mousework+2
   ldy .mousework+3
   jsr vdcAddrWrite16
   ldy #255
   sty ._rowcount
-  inc ._rowcount
   ldy ._rowcount
   cpy ._cursor_rows
   beq +
   lda pbmTemp,y
   jsr vdcRamWrite
   lda .mousework+2
   clc
   adc ._displaywidth
   sta .mousework+2
   lda .mousework+3
   adc #0
   sta .mousework+3
   tay
   lda .mousework+2
   jsr vdcAddrWrite16
   jmp -
+  rts
._cursor_rows !byte 0
._rowcount !byte 0
._displaywidth !byte 0

