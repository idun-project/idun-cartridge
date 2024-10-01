appInitialize = *
   ;require VDC
   jsr aceMiscSysType
   cmp #$80
   beq +
-  jmp exit
+  lda #3      ;VDC graphics Mode 3
   ldx #0
   ldy #0
   jsr xGrMode
   bcs -
   jsr xGrDblBuffer
   lda #0
   ldy #5
   jsr xGrClear
   ; ;use green pen
   ; ldx #$1a
   ; lda #$50
   ; jsr vdcWrite
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