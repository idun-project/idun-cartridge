appInitialize = *
   rts

appRunLoop = *
!ifndef TOOLBAR {
   jsr aceConStopkey
   bcs +
   rts
+  jmp exit
} else {
   jsr aceConKeyAvail
   bcc +
   rts
+  jsr aceConGetkey
   jsr toolKeysHandler
   lda __main_menu_code
   cmp #HotkeyStop
   bne +
   jmp exit
+  cmp #$20
   bne +
   lda #$c0
   ldx #$20
   ldy toolWinPalette+0
   jsr aceWinCls
   lda #<restartEvt
   ldy #>restartEvt
   ldx #3
   jsr aceTtyPut
   ;remove any pending mailbox request
   lda #0
   sta __mailbox
   sta __mailbox+1
+  rts
}

.MENU_SELECT = $ff
restartEvt !byte .MENU_SELECT,2,$20

   exit = *
   lda __luaFd
   jsr close
   lda #0
   sta zp
   sta zp+1
   lda #aceRestartApplReset
   jmp aceRestart
