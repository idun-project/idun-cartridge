appInitialize = *
	rts

appRunLoop = *
   jsr aceConStopkey
   bcs exit
   rts
   exit = *
   lda __luafd
   jsr close
   lda #0
   sta zp
   sta zp+1
   lda #aceRestartApplReset
   jmp aceRestart
