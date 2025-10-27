appInitialize = *
   ; Full screen
   lda #0
   ldx #0
   jsr aceWinScreen
   ; Clear screen/color memory
   lda #$c0
   ldx #$ff    ;chr($ff) is a blank space
   ldy #$0f
   jsr aceWinCls
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
   ldx #$00
   lda #$3f
   jsr vdcWrite      ;total columns=63
   ldx #$06
   lda #$19
   jsr vdcWrite      ;screen rows
   ldx #$01
   lda #$28
   jsr vdcWrite      ;40 columns visible
   ldx #$02
   lda #$37
   jsr vdcWrite      ;vert. sync column
   ldx #$16
   lda #$89
   jsr vdcWrite      ;8x8 glyphs
   lda #$20
   sta chrPage1
   lda #$60
   sta chrPage2
   lda #$00
   sta scrPage
   contInit = *
   jsr blankChrs
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
   txa
   jsr vdcMemWrite
   jmp initDisplayCont
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
   jmp vdcBlankChrs
+  lda #0
   ldy #7
-  sta (scrPtr),y
   dey
   bpl -
   rts
   vdcBlankChrs = *
   lda scrPtr
   clc
   adc #<2040
   sta scrPtr
   lda scrPtr+1
   adc #>2040
   sta scrPtr+1
   jsr vdcMemStart
   lda #0
   ldy #15
-  jsr vdcMemWrite
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
   jsr aceGrExit
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
   ;save .A,.X, and .Y
   pha
   tya
   pha
   stx temp
   ;VDC $12/$13 = scrPtr (big-endian!)
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
   ;restore .A,.X, and .Y
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

vdcWriteChrs = * ;( cbDataSz )
   ldx #0
   ldy #7
-  lda mailboxB,x
   jsr vdcMemWrite
   inx
   dec cbDataSz
   beq +
   dey
   bpl -
   jsr +
   jmp -
+  lda #0
   ldy #7
-  jsr vdcMemWrite
   dey
   bpl -
   ldy #7
   rts

;=== bss ===
macroUserCmds = * ;not used