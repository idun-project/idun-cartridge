doNothing = *
   rts
appInitialize = *
   ; Remember initial screen size
   jsr aceWinSize
   stx initSize
   ; Check screen in use
   jsr aceMiscSysType
   cmp #%10001000
   beq vdcMode
   lda #0
   ldx #40
   jsr aceWinScreen  ;40-col vic screen
   ; fall-through; setup vic mode
   lda #$f0
   sta chrPage1
   lda #$e8
   sta chrPage2
   lda aceVic40Page
   sta scrPage
   jmp contInit
   vdcMode = *
   ldx #$19
   jsr vdcRead
   ora #$10
   jsr vdcWrite      ;pixel double width
   ldx #$01
   lda #$28
   jsr vdcWrite      ;40 column mode
   lda #$20
   sta chrPage1
   lda #$40
   sta chrPage2
   lda #$00
   sta scrPage
   contInit = *
   jsr blankChrs
   ; Clear screen/color memory
   lda #$c0
   ldx #$ff    ;chr($ff) is a blank space
   ldy #$0f
   jsr aceWinCls
   lda chrPage1
   sta activePage
   ; Init the cube display area
   lda #<FIRST_TILE_OFFS
   sta scrPtr
   lda scrPage
   clc
   adc #>FIRST_TILE_OFFS
   sta scrPtr+1
   lda scrPage
   bne +
   jsr vdcMemStart
+  ldx #0
   ldy #0
-  lda scrPage
   bne +
   ; scrPage==$00 -> vdc display
   txa
   jsr vdcMemWrite
   jmp initDisplayCont
   ; otherwise, vic display
+  txa
   sta (scrPtr),y
   initDisplayCont = *
   inx
   cpx #252
   beq +
   iny
   cpy #18
   bne -
   ldy #0
   lda scrPtr
   clc
   adc #TILE_STRIDE
   sta scrPtr
   lda scrPtr+1
   adc #0
   sta scrPtr+1
   lda scrPage
   bne -
   jsr vdcMemStart
   jmp -
+  rts
   blankChrs = *
   lda chrPage1
   clc
   adc #>2040
   jsr +
   lda chrPage2
   clc
   adc #>2040
+  sta scrPtr+1
   lda #<2040
   sta scrPtr
   lda scrPage
   bne +
   jsr vdcMemStart
+  lda #0
   ldy #7
-  ldx scrPage
   bne +
   jsr vdcMemWrite
   dey
   bpl -
   rts
+  sta (scrPtr),y
   dey
   bpl -
   rts

appRunLoop = *
   jsr aceConStopkey
   bcs exit
   rts
   exit = *
   lda __luaFd
   jsr close
   lda #0
   sta zp
   sta zp+1
   lda #aceRestartApplReset
   jmp aceRestart

;vdc register addresses
vdcSelect = $d600
vdcStatus = $d600
vdcData   = $d601

vdcRead = *  ;( .X=register ) : .A=value
   stx vdcSelect
-  bit vdcStatus
   bpl -
   lda vdcData
   rts

vdcWrite = *  ;( .X=register, .A=value )
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sta vdcData
   rts

vdcMemStart = *   ;( scrPtr )
   pha
   tya
   pha
   stx temp
   ldx #$12
   lda scrPtr
   ldy scrPtr+1
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sty vdcData
   inx
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sta vdcData
   pla
   tay
   pla
   ldx temp
   rts
vdcMemWrite = *   ;( .A=value )
   stx temp
   ldx #$1f
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sta vdcData
   ldx temp
   rts

;=== bss ===
macroUserCmds = * ;not used