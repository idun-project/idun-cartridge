doNothing = *
   rts
appInitialize = *
   lda #<doNothing
   ldy #>doNothing
   jsr aceIrqHook
   jsr aceMiscSysType
   cmp #%10001000
   bne +
   lda #3      ;VDC graphics Mode 3
   jmp ++
+  lda #1      ;VIC graphics Mode 1
++ ldx #0
   ldy #0
   jsr xGrMode
   bcs exit
   jsr xGrDblBuffer
   lda #0
   ldy #5
   jsr xGrClear
   lda #$50
   jsr xGrSetColor
   jsr xGrExtents
   tya
   sec
   sbc #6
   asl
   asl
   asl
   sta cubeRows
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

;=== bss ===
macroUserCmds = * ;not used