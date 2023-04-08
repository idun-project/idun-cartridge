;Copyright© 2022 Brian Holdsworth
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

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

IMAGE_COLS = 2
IMAGE_ROWS = 11

cursorX      = $02  ;(2)
cursorY      = $04  ;(2)
startX       = $06  ;(2)
startY       = $08  ;(2)
temp         = $0a  ;(2)
rndfill      = $0c  ;(1)

;use toolbox extensions
!source "toolx/vdc/core.asm"
!source "toolx/vdc/pointer.asm"

main = *
   ;** vdc mode 1
   lda #FALSE
   jsr toolStatEnable
   lda #$01
   ldx #$00
   ldy #$00
   jsr xGrMode
   bcs +
   ;** clear bitmap screen
   lda #$00
   ldy #$00
   jsr xGrClear
   jsr xPointerEnable
   jmp mainloop
+  rts

   mainloop = *
   jsr checkStop
   jsr xPointerPoll
   beq mainloop
   
   drawstart = *
   ldx #cursorX
   jsr xPointerLoc
   ;startX/Y = cursorX/Y
   ldx #cursorX-1
-  inx
   lda $00,x
   sta $04,x
   cpx #cursorX+3
   bne -
   lda $dc06
   sta rndfill
   drawloop = *
   jsr xPointerPoll
   beq mainloop
   ldx #cursorX
   jsr xPointerLoc
   ldx #1
-  lda cursorX,x
   cmp startX,x
   bne +
   lda cursorY,x
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
   ;rows = cursorY - startY
   lda cursorY+0
   sec
   sbc startY+0
   sta syswork+2
   lda cursorY+1
   sbc startY+1
   sta syswork+3
   ;cols = (cursorX - startX) / 8
   lda cursorX+0
   sec
   sbc startX+0
   sta temp+0
   lda cursorX+1
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
++ jsr aceGrExit
   lda #TRUE
   jsr toolStatEnable
   lda #1
   ldx #0
   jmp aceProcExit
