appInitialize = *
   ;require VDC
   jsr aceMiscSysType
   cmp #WIN_DRIVER_VDC
   beq +
-  jmp exit
+  lda #3      ;VDC graphics Mode 3
   ldx #32     ;width in cells (256px)
   ldy #32     ;height in cells (256px)
   jsr xGrMode
   bcs -
   lda #0
   ldy #0
   jsr xGrClear
   rts

appRunLoop = *
   jsr aceConStopkey
   bcs exit
   jmp xPtrEvent
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