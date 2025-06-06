!zone xVdcPointer

xVdcPointerEnable = *
   lda #$ff
   sta mouseOn
   ldx #1
   jsr vdcRead
   sta ._displaywidth
   jsr aceConMouse
   lda syswork+0
   ldy syswork+1
   sta mouseX+0
   sty mouseX+1
   lda syswork+2
   ldy syswork+3
   sta mouseY+0
   sty mouseY+1
   jmp .displayCursor

xVdcPointerMove = *  ;( mouseX, mouseY )
   ldx #1
-  lda mouseX,x
   cmp cursorX,x
   bne +
   lda mouseY,x
   cmp cursorY,x
   bne +
   dex
   bpl -
   rts
+  lda cursorX+1
   sta .mousework
   lda cursorX+0
   lsr .mousework
   ror
   lsr .mousework
   ror
   lsr .mousework
   ror
   pha
   tax                  ;.X = draw x>>3
   lda #<pbmCursorWideL
   ldy #>pbmCursorWideL
   jsr .drawit
   pla
   tax
   inx
   ldy #>pbmCursorWideR
   lda #<pbmCursorWideR
   jsr .drawit
   ;fall-through
.displayCursor = *
   ldx #1
-  lda mouseX,x
   sta cursorX,x
   lda mouseY,x
   sta cursorY,x
   dex
   bpl -
   lda cursorX+1
   sta .mousework
   lda cursorX+0
   lsr .mousework
   ror
   lsr .mousework
   ror
   lsr .mousework
   ror
   pha
   tax                  ;.X = draw x>>3
   lda #<pbmCursorWideL
   ldy #>pbmCursorWideL
   jsr .drawit
   pla
   tax
   inx
   ldy #>pbmCursorWideR
   lda #<pbmCursorWideR
   jmp .drawit
.mousework !fill 4,0

.drawit = *   ;(.AY=cursor_bitmap, .X=x_pos/8)
   cpx ._displaywidth
   bcc +
   rts
+  stx .mousework
   sta zp
   sty zp+1
   ;determine how many rows of cursor will fit
   lda cursorY+1
   ora cursorY+0
   bne +
   lda #CURHEIGHT
   sta ._cursor_rows
   jmp ++
+  ldx #$06    ;R6=display height
   jsr vdcRead
   asl
   asl
   asl         ;assume 8-pixels tall chars
   sbc cursorY
   cmp #CURHEIGHT
   bcs +
   sta ._cursor_rows
   jmp ++
+  lda #CURHEIGHT
   sta ._cursor_rows
   ;convert cursor x/y to bitmap addr
++ lda #0
   sta .mousework+1
   ldy cursorY
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

