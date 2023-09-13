; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)
;
; Kernel console driver: high level I/O & keyboard

conWinStart    !byte 0,0
conWinRows     !byte 0
conWinCols     !byte 0
conLineAddr    !byte 0,0
conCurRow      !byte 0
conCurCol      !byte 0
conWinStartRow !byte 0
conWinStartCol !byte 0
conWinDataEnd  = *
conRowInc      !byte 0,0

conPutMask     !byte $80  ;$80=char,$40=color,$20=extattr
conCharColor   !byte $0e
conExtAttr     !byte $00  ;extended attrs:$80=alt,$40=rvs,$20=ul,$10=blink
conFillColor   !byte $0e
conFillAttr    !byte $00
conCursorColor !byte $07
conIgnoreCtrl  !byte $00
conIgnoreShift !byte $00
conPrescrollOverride !byte $00

keylineNext  = keylineBuf+0  ;(3)
keylinePrev  = keylineBuf+3  ;(3)
keylineLen   = keylineBuf+6  ;(1)
keylineFlags = keylineBuf+7  ;(1)
keyline      = keylineBuf+8  ;(248)
keylineMax   = 248

keylinePtr   !byte 0
keylinePos   !byte 0
keylineCount !byte 0

!if computer-64 {
   shiftValue = $d3
} else {
   shiftValue = $28d
}

conInitLineNum !byte 0
conHistbufScanPtr !fill 4,0
conHistbufReplacePtr !fill 4,0
conInitPrev = syswork+4

;Defined in toolbox
joykeyCapture      = $7f ;(1) $80=capture keyb, $40=capture joys, $c0=capture both

conInit = *
   lda #0
   sta keylineCount
   jsr keyscanInit
   lda #aceMemNull
   sta conHistbufScanPtr+3
   sta conHistbufReplacePtr+3
   sta conInitPrev+3
   lda #$00
   sta conInitPrev+0
   lda configBuf+$cb
   bne +
   jmp conWinInit
+  sta conInitLineNum

   conInitNext = *
   lda conInitLineNum
   bne +
   jmp conInitCleanHist
+  lda #$fa
   sta allocProcID
   lda #1
   ldx #$00  ;xxx go for the slow
   ldy #$ff
   jsr kernPageAlloc
   bcs conInitCleanHist
   ;** check first line
   lda conHistbufReplacePtr+3
   cmp #aceMemNull
   bne +
   ldx #3
-  lda mp,x
   sta conHistbufReplacePtr,x
   dex
   bpl -
   ;** initialize line
+  ldx #2
-  lda conHistbufReplacePtr+1,x
   sta keylineNext,x
   lda conInitPrev+1,x
   sta keylinePrev,x
   lda mp+1,x
   sta conInitPrev+1,x
   dex
   bpl -
   lda #0
   sta keylineLen
   sta keylineFlags
   ;** store new line
   lda #<keylineBuf
   ldy #>keylineBuf
   sta zp+0
   sty zp+1
   lda #9
   ldy #0
   jsr stash
   ;** link previous line's next pointer
   ldx #2
-  lda keylinePrev,x
   sta mp+1,x
   dex
   bpl -
   lda #$00
   sta mp+0
   ldx #conInitPrev+1
   ldy #3
   jsr zpstore
   ;** go on to next line
   dec conInitLineNum
   jmp conInitNext

   conInitCleanHist = *
   lda conHistbufReplacePtr+3
   cmp #aceMemNull
   beq conWinInit
   ;** link first line's prev ptr to last line
   ldx #3
-  lda conHistbufReplacePtr,x
   sta mp,x
   dex
   bpl -
   lda #$03
   sta mp+0
   ldx #conInitPrev+1
   ldy #3
   jsr zpstore
   ;xx fall through

conWinInit = *
   jsr conWinParms
   jmp conCls

conWinParms = *
   jsr kernWinSize
   sta conWinRows
   stx conWinCols
   lda syswork+0
   ldx syswork+1
   sta conWinStartRow
   stx conWinStartCol
   lda syswork+2
   ldy syswork+3
   sta conWinStart+0
   sty conWinStart+1
   lda syswork+4
   ldy #0
   sta conRowInc+0
   sty conRowInc+1
   rts

conCls = *
   lda #$c0
   ldx #" "
   ldy conFillColor
   jsr kernWinCls
   jsr conHome
   rts

conShutdown = *
   rts

conWinChangeCallback = *
   jsr conWinParms
   jmp conHome
   rts

conHome = *
   lda conWinStart+0
   ldy conWinStart+1
   sta conLineAddr+0
   sty conLineAddr+1
   lda #0
   sta conCurRow
   sta conCurCol
   rts

conPutSave !byte 0

kernConPutchar = *
conPutchar = *  ;( .A=char )
   cmp #chrCR
   bne +
   jmp conNewline
+  cmp #chrCLS
   beq conCls
   cmp #chrTAB
   bne +
   jmp conTab
+  cmp #chrBS
   bne +
   jmp conBackspace
+  cmp #chrBEL
   bne +
   jmp conBell
+  cmp #chrVT
   bne +
   jmp conCtrlDown
+  cmp #chrBOL
   bne conPutcharLit
   jmp conReturnOnly

kernConPutlit = *
   conPutcharLit = *  ;( .A=char )
   sta conPutSave
   lda conCurCol
   cmp conWinCols
   bcc +
   jsr conNewline
+  clc
   lda conLineAddr+0
   adc conCurCol
   sta syswork+0
   lda conLineAddr+1
   adc #0
   sta syswork+1
   lda #<conPutSave
   ldy #>conPutSave
   sta syswork+2
   sty syswork+3
   ldx #1
   stx syswork+5
   lda conExtAttr
   sta syswork+6
   lda conPutMask
   ldy conCharColor
   jsr kernWinPut
   inc conCurCol
   rts

conGetCursorAddr = *
   clc
   lda conLineAddr+0
   adc conCurCol
   sta syswork+0
   lda conLineAddr+1
   adc #0
   sta syswork+1
   rts

conSynchCursor = *
   lda conCurCol
   cmp conWinCols
   bcc +
   jsr conNewline
+  rts

conNewline = *
   lda conIgnoreCtrl
   bmi +
   lda conIgnoreShift
   bmi +
-  lda shiftValue
   and #$0f
   cmp #$04
   beq -
   lda scrollFreeze
   bne -
+  lda #0
   sta conCurCol
   inc conCurRow
   lda conCurRow
   cmp conWinRows
   bcs +
   clc
   lda conLineAddr+0
   adc conRowInc+0
   sta conLineAddr+0
   lda conLineAddr+1
   adc conRowInc+1
   sta conLineAddr+1
   clc
   rts
+  dec conCurRow
   jsr conScroll
   clc
   rts

conScroll = *
   bit conIgnoreCtrl
   bmi ++
   bit conIgnoreShift
   bmi ++
   ldx #1
   lda shiftValue
   and #%11
   cmp #%11
   beq +
   ldx #2
+  stx scrollCountdown
-  lda shiftValue
   and #%10
   beq ++
   cli
   lda scrollCountdown
   bne -
++ lda #" "
   sta syswork+4
   lda conFillAttr
   sta syswork+6
   lda conPutMask
   ora #$08
   ldx #1
   ldy conFillColor
   jsr kernWinScroll
   rts

conTab = *
   lda conCurCol
   and #7
   sta syswork+0
   sec
   lda #8
   sbc syswork+0
   clc
   adc conCurCol
   cmp conWinCols
   bcc +
   lda conWinCols
+  sta conCurCol
   rts

conReturnOnly = *
   lda #0
   sta conCurCol
   rts

conBell = *
   lda #$15
   sta $d418
   ldy #$09
   ldx #$00
   sty $d405
   stx $d406
   lda #$30
   sta $d401
   lda #$20
   sta $d404
   lda #$21
   sta $d404
   rts

;*** aceConWrite( (zp)=buf, .AY=writeLength ) **zw gets modified**

conWritePtr    = syswork+10
conWriteLength = syswork+12
conWriteTemp   = syswork+14

kernConWrite = *
conWrite = *
   sta conWriteLength+0
   sty conWriteLength+1
   lda zp+0
   ldy zp+1
   sta conWritePtr+0
   sty conWritePtr+1

   conWriteNextChunk = *
   lda #255
   ldx conWriteLength+1
   bne +
   lda conWriteLength+0
   beq conWriteFinish
+  jsr conWriteChunk
   sta conWriteTemp
   clc
   adc conWritePtr+0
   sta conWritePtr+0
   bcc +
   inc conWritePtr+1
+  sec
   lda conWriteLength+0
   sbc conWriteTemp
   sta conWriteLength+0
   bcs +
   dec conWriteLength+1
+  jmp conWriteNextChunk
   
   conWriteFinish = *
   clc
   rts

conWrChkMaxLen !byte 0

conWriteChunk = *  ;( conWritePtr, .A=dataLen ) : .A=dataWritten
   sta conWrChkMaxLen
-  sec
   lda conWinCols
   sbc conCurCol
   bne +
   ldy #0
   lda (conWritePtr),y
   cmp #chrBOL
   beq ++
   cmp #chrBEL
   beq ++
   cmp #chrVT
   beq ++
   cmp #chrCLS
   beq ++
   cmp #chrBS
   beq ++
   jsr conWriteNewline
   ldy #0
   lda (conWritePtr),y
   cmp #chrCR
   bne -
   lda #1
   rts
+  cmp conWrChkMaxLen
   bcs ++
   sta conWrChkMaxLen
++ ldy #0

-- lda (conWritePtr),y
   cmp #$14+1
   bcs ++
-  cpy #0
   bne conWrChkFlush
   cmp #chrCR
   bne +
   jsr conWriteNewline
   lda #1
   rts
+  jsr conPutchar
   lda #1
   rts
++ cmp #147
   beq -
   iny
   cpy conWrChkMaxLen
   bcc --

   conWrChkFlush = *
   sty conWrChkMaxLen
   clc
   lda conLineAddr+0
   adc conCurCol
   sta syswork+0
   lda conLineAddr+1
   adc #0
   sta syswork+1
   lda conWritePtr+0
   ldx conWritePtr+1
   sta syswork+2
   stx syswork+3
   sty syswork+5
   lda conExtAttr
   sta syswork+6
   lda conPutMask
   ldy conCharColor
   ldx syswork+5
   jsr kernWinPut
   clc
   lda conCurCol
   adc conWrChkMaxLen
   sta conCurCol
   lda conWrChkMaxLen
   rts

;*** kernConRead( (zp)=buf, .AY=readMaxLen ) : .AY=(zw)=len, .Z

kernConRead = *
conRead = *
   sta readMaxLen+0
   sty readMaxLen+1
   lda #0
   sta readLength+0
   sta readLength+1
   lda zp+0
   ldy zp+1
   sta readPtr+0
   sty readPtr+1

conReadLoop = *
   lda readLength+0
   cmp readMaxLen+0
   lda readLength+1
   sbc readMaxLen+1
   bcs conReadExit
   jsr keylineGet
   bcs conReadEofExit
   ldy #0
   sta (readPtr),y
   inc readPtr+0
   bne +
   inc readPtr+1
+  inc readLength+0
   bne +
   inc readLength+1
+  cmp #$0d
   beq conReadExit
   jmp conReadLoop

   conReadExit = *
   lda readLength+0
   ldy readLength+1
   sta zw+0
   sty zw+1
   ldx #$ff
   clc
   rts

   conReadEofExit = *
   lda #0
   ldy #0
   sta zw+0
   sty zw+1
   clc
   rts

keylineGet = *  ;( keylinePtr, keylineCount ) : .A=char, .CS=eof
   lda keylineCount
   bne +
   jsr conInput
   bcs ++
+  ldx keylinePtr
   inc keylinePtr
   dec keylineCount
   lda keyline,x
   clc
++ rts

conParmSave !fill 8,0
conParmMp   !fill 4,0
conParmZp   !byte 0,0

; BKH: This is the default no-op Hotkey handler.
conHotkeyNone = *
   sec
   rts
kernConSetHotkeys = * ;( .AY=handler, =$00 if none)
   sta syswork
   tya
   cmp #0
   bne +
   lda #<conHotkeyNone
   ldy #>conHotkeyNone
   sta conHotkeyChecker+1
   sty conHotkeyChecker+2
   rts
+  lda syswork
   sta conHotkeyChecker+1
   sty conHotkeyChecker+2
   rts

conInput = *
   lda #$00
   sta conInputMode
   sta conInputFakeCount
conInputIn = *
   ldx #0
   stx keylinePos
   stx keylineCount
   stx keylinePtr
   ldx #7
-  lda syswork,x
   sta conParmSave,x
   dex
   bpl -
   lda #$00
   sta conHistbufReplacePtr+0
   ldx #3
-  lda conHistbufReplacePtr,x
   sta conHistbufScanPtr,x
   lda mp,x
   sta conParmMp,x
   lda conHistbufReplacePtr,x
   sta mp,x
   dex
   bpl -
   lda #$06
   sta mp+0
   lda #0
   sta syswork
   ldx #syswork
   ldy #1
   jsr zpstore
   lda #$00
   sta mp+0
   ldx #1
-  lda zp,x
   sta conParmZp,x
   dex
   bpl -

   conInNext = *
   jsr conSynchCursor
   ldx conInputFakeCount
   beq +
   ldx conInputFakePos
   lda stringBuffer,x
   inc conInputFakePos
   dec conInputFakeCount
   jmp conInRegular
+  jsr conCursorOn
   jsr conGetkey
   jsr conCursorOff
   ; BKH: Need to check Hotkeys.
   conHotkeyChecker = *
   jsr conHotkeyNone
   bcs +
   jmp conInNext
+  clc
   cmp #chrCR
   bne +
   jmp conInReturn
+  cmp #chrBS  ;backspace
   bne +
   jmp conInBackspace
+  cmp #$03  ;stop
   bne +
   bit conInputMode
   bpl conInNext
   jsr conRestoreParms
   lda #$03
   ldx keylineCount
   sta keyline,x
   inc keylineCount
   sec
   rts
+  cmp #chrCLS  ;clear
   bne +
   jmp conInClear
+  cmp #$e4
   bne +
   ldx keylineCount
   bne +
   jsr conRestoreParms
   lda #$e4
   sec
   rts
+  cmp #$f5  ;ct-u
   bne +
   jmp conInKill
+  cmp #29  ;right
   bne +
   jmp conInRight
+  cmp #157 ;left
   bne +
   jmp conInLeft
+  cmp #$10  ;co-left
   bne +
-  jmp conInBol
+  cmp #$e1  ;ct-a
   beq -
   cmp #$15  ;co-right
   bne +
-  jmp conInEol
+  cmp #$e5  ;ct-e
   beq -
   cmp #$f2  ;ct-r
   bne +
   jmp conInRedisplay
+  cmp #145  ;up
   bne +
   jmp conInPrevLine
+  cmp #17   ;down
   bne +
   jmp conInNextLine
+  cmp #$12  ;rvs
   bne +
   jsr conCtrlScreenRvs
   jmp conInNext
+  cmp #$92  ;rvs off
   bne +
   jsr conCtrlScreenRvsOff
   jmp conInNext

   conInRegular = *
+  ldx keylineCount
   cpx #keylineMax
   bcc +
   jsr conBell
   jmp conInNext
+  pha
   ;** insert space for new char
   inx
   stx keylineCount
-  lda keyline-1,x
   sta keyline,x
   dex
   beq +
   cpx keylinePos
   bcs -
   beq -
+  pla
   ldx keylinePos
   sta keyline,x
   inc keylinePos
   jsr conPutcharLit
   jsr conInSlosh
   jsr conInBackup
   jsr conInSaveLine
   jmp conInNext

conInReturn = *
   jsr conInSaveLine
   lda #0
   sta suppressSaveLine
   jsr conInSlosh
   lda #chrCR
   ldx keylineCount
   sta keyline,x
   inc keylineCount
   jsr conPutchar
   ldx #0
   stx keylinePtr
   lda keylineLen
   beq +
   ldx #3
-  lda conHistbufReplacePtr,x
   sta mp,x
   dex
   bpl -
   lda #<keylineBuf
   ldy #>keylineBuf
   sta zp+0
   sty zp+1
   lda #3
   ldy #0
   jsr fetch
   ldx #2
-  lda keylineNext,x
   sta conHistbufReplacePtr+1,x
   dex
   bpl -
+  jsr conRestoreParms
   lda #chrCR
   clc
   rts

conInClear = *
   jsr conPutchar
   lda #0
   sta keylinePos
   sta keylineCount
   jmp conInNext

conInBackspace = *
   ldx keylinePos
   bne +
   jmp conInNext
+  dec keylinePos
   dec keylineCount
   ldx keylinePos
   jmp +
-  lda keyline+1,x
   sta keyline,x
   inx
+  cpx keylineCount
   bcc -
   jsr conBackspace
   jsr conInSlosh
   pha
   lda #" "
   jsr conPutchar
   pla
   clc
   adc #1
   jsr conInBackup
   jsr conInSaveLine
   jmp conInNext

conInLeft = *
   lda keylinePos
   beq +
   jsr conBackspace
   dec keylinePos
+  jmp conInNext

conInRight = *
   ldx keylinePos
   cpx keylineCount
   beq +
   lda keyline,x
   jsr conPutchar
   inc keylinePos
+  jmp conInNext

conInBol = *
   lda keylinePos
   jsr conInBackup
   lda #0
   sta keylinePos
   jmp conInNext

conInEol = *
   jsr conInSlosh
   lda keylineCount
   sta keylinePos
   jmp conInNext

conInRedisplay = *
   lda keylinePos
   pha
   jsr conInBackup
   lda #0
   sta keylinePos
   jsr conInSlosh
   pla
   sta keylinePos
   sec
   lda keylineCount
   sbc keylinePos
   jsr conInBackup
   jmp conInNext

conInKill = *
   jsr conInKillSub
   jmp conInNext
conInKillCnt !byte 0
conInKillSub = *
   ;** goto beginning of line
   lda keylinePos
   jsr conInBackup
   ;** blank out line
   lda #$ff
   sta conIgnoreCtrl
   lda keylineCount
   sta conInKillCnt
   beq +
-  lda #" "
   jsr conPutchar
   dec conInKillCnt
   bne -
   ;** backup
+  lda keylineCount
   jsr conInBackup
   lda #$00
   sta conIgnoreCtrl
   ;** internal
   lda #0
   sta keylinePos
   sta keylineCount
   rts

conSloshPtr !byte 0

conInSlosh = *  ;( ) : BScount ;slosh out line from keylinePos to keylineCount
   lda #$ff
   sta conIgnoreCtrl
   lda keylinePos
   sta conSloshPtr
-  ldx conSloshPtr
   cpx keylineCount
   bcs +
   lda keyline,x
   jsr conPutcharLit
   inc conSloshPtr
   jmp -
+  lda #$00
   sta conIgnoreCtrl
   sec
   lda keylineCount
   sbc keylinePos
   rts

conBackupCount !byte 0

conInBackup = *  ;( .A=count ) ;backup the cursor .A spaces
   sta conBackupCount
   cmp #0
   beq +
-  lda #chrBS
   jsr conPutchar
   dec conBackupCount
   bne -
+  rts

conRestoreParms = *
   ldx #7
-  lda conParmSave,x
   sta syswork,x
   dex
   bpl -
   ldx #3
-  lda conParmMp,x
   sta mp,x
   dex
   bpl -
   ldx #1
-  lda conParmZp,x
   sta zp,x
   dex
   bpl -
   rts

conInNextLine = *
   ;** locate next scan line
   lda conHistbufReplacePtr+3
   cmp #aceMemNull
   beq +
   jsr conInLineFetchHead
   ldx #2
-  lda conHistbufScanPtr+1,x
   cmp conHistbufReplacePtr+1,x
   bne ++
   dex
   bpl -
+  jmp conInNext
++ ldx #2
-  lda keylineNext,x
   sta conHistbufScanPtr+1,x
   sta mp+1,x
   dex
   bpl -
   jmp +++
   
conInPrevLine = *
   ;** locate previous scan line
   lda conHistbufReplacePtr+3
   cmp #aceMemNull
   beq +
   jsr conInLineFetchHead
   ldx #2
-  lda keylinePrev,x
   cmp conHistbufReplacePtr+1,x
   bne ++
   dex
   bpl -
+  jsr conBell
   jmp conInNext
++ ldx #2
-  lda keylinePrev,x
   sta conHistbufScanPtr+1,x
   sta mp+1,x
   dex
   bpl -
+++lda #$00
   sta mp+0
   ;** undisplay current line
   jsr conInKillSub
   ;** fetch new line
   lda #<256
   ldy #>256
   jsr fetch
   ;** display new line
   lda #0
   sta keylinePos
   lda keylineLen
   sta keylineCount
   jsr conInSlosh
   lda keylineCount
   sta keylinePos
   jmp conInNext

conInLineFetchHead = *
   ldx #3
-  lda conHistbufScanPtr,x
   sta mp,x
   dex
   bpl -
   lda #<keylineBuf
   ldy #>keylineBuf
   sta zp+0
   sty zp+1
   lda #6
   ldy #0
   jsr fetch
   rts

conInSaveLine = *
   lda suppressSaveLine
   beq +
   rts
+  lda conHistbufReplacePtr+3
   cmp #aceMemNull
   bne +
   rts
+  lda keylineCount
   sta keylineLen
   bne +
   rts
+  ldx #3
-  lda conHistbufReplacePtr,x
   sta mp,x
   dex
   bpl -
   lda #$06
   sta mp+0
   lda #<keylineBuf+6
   ldy #>keylineBuf+6
   sta zp+0
   sty zp+1
   clc
   lda keylineCount
   adc #2
   ldy #0
   jsr stash
   lda #$00
   sta mp+0
   rts

conBackspace = *
   dec conCurCol
   bpl +
   ldx conWinCols
   dex
   stx conCurCol
   lda conCurRow
   beq +
   dec conCurRow
   sec
   lda conLineAddr+0
   sbc conRowInc+0
   sta conLineAddr+0
   lda conLineAddr+1
   sbc conRowInc+1
   sta conLineAddr+1
+  rts

conCursorOn = *  ;( )
   jsr conGetCursorAddr
   ldy conCursorColor
   lda #$ff
   jsr kernWinCursor
   rts

conCursorOff = *  ;( )  ;.A preserved
   pha
   jsr conGetCursorAddr
   lda #0
   jsr kernWinCursor
   pla
   rts

kernConColor = *
conColor = *
   sta syswork+15
   and #$80
   beq ++
   lda syswork+15
   and #$40
   beq +
   ora #$e0
+  ora #$80
   sta conPutMask
++ lda syswork+15
   and #$02
   beq +
   stx conCharColor
+  lda syswork+15
   and #$01
   beq +
   sty conCursorColor
+  lda syswork+15
   and #$04
   beq +
   lda syswork+0
   sta conFillColor
+  lda conFillColor
   sta syswork+0
   ldx conCharColor
   ldy conCursorColor
   lda conPutMask
   and #%01000000
   ora #%10110111
   clc
   rts

conGetPaletteColor = *  ;( .X=color ) : .A=color, .X unchanged
   lda winPalette,x
   rts

conScrChangeCallback = *
   lda winPalette+0
   sta conCharColor
   sta conFillColor
   lda winPalette+1
   sta conCursorColor
   jsr conWinInit
   lda conWinRows
   ldx conWinCols
   ldy #0
   stx aceMouseLimitX+0
   sty aceMouseLimitX+1
   sta aceMouseLimitY+0
   sty aceMouseLimitY+1
   ldy #3
-  asl aceMouseLimitX+0
   rol aceMouseLimitX+1
   asl aceMouseLimitY+0
   rol aceMouseLimitY+1
   dey
   bne -
   jsr conMouseBounds
   lda conWinRows
   ldx conWinCols
   clc
   rts

kernConPos = *
   cmp conWinRows
   bcc +
-  lda #aceErrInvalidConParms
   sta errno
   sec
   rts
+  cpx conWinCols
   bcs -
   sta conCurRow
   stx conCurCol
   ldx #0
   jsr kernWinPos
   lda syswork+0
   ldy syswork+1
   sta conLineAddr+0
   sty conLineAddr+1
   clc
   rts

kernConGetpos = *
   lda conCurRow
   ldx conCurCol
   clc
   rts

;3-Key Rollover-128 by Craig Bruce 18-Jun-93 from C= Hacking magazine

!if computer-64 {
   newpos = $cc
   keycode = $d4
   prevKeycode = $d5
   xsave = $cd
   mask = $cc
   scanval = $d2
   keymapPtr = $cc
} else {
   newpos = $f5
   keycode = $cb
   prevKeycode = $c5
   xsave = $f6
   mask = $f5
   scanval = $d9
   keymapPtr = $f5
}

extKeyboardFlag   !byte $00
scanrows          !byte 8
extCapsFlag       !byte $00
extCapsPort = $0001
regCapsPort       !byte $40
pk = $d02f
stopKeyRow        !byte 0
rollover = 3
nullKey = $ff
conJoy1           !byte $ff
conJoy2           !byte $ff
; BKH Flag var used to decide whether to forward keypresses and joysticks
conButtonChange   !byte 0 ;$01=Joy1,$02=Joy2,$04=Key

pa = $dc00
pb = $dc01
ddrb = $dc03

conIrqKeyscan = *
   jsr conMouseIrq
   lda scrollCountdown
   beq +
   dec scrollCountdown
+  jsr checkJoystick
   cmp #$ff
   bne noKeyPressed
   jsr keyscan
   bcc noKeyPressed
   lda scanTable+7
   sta stopKeyRow
   jsr selectMouse
   jsr shiftdecode
   jsr keydecode
   jsr keyorder
   bit ignoreKeys
   bmi ++
   lda prevKeys+0
   cmp #nullKey
   beq ++
   sta keycode
   ; BKH: For key forwarding use the raw `keycode` and `shiftValue`.
   ;      Otherwise, interpret the key press using active keyboard map.
   lda #0
   bit joykeyCapture
   bpl +
   lda #$04
   ora conButtonChange
   sta conButtonChange
   rts
+  jmp interpKey

   noKeyPressed = *
   jsr selectMouse
   lda #nullKey
   ldx #rollover-1
-  sta prevKeys,x
   dex
   bpl -
   jsr scanCaps
   lda #0
   sta ignoreKeys
   sta stopKeyRow

++ lda #nullKey
   sta keycode
   sta prevKeycode
   rts

selectMouse = *
   lda #$ff
   sta pk
   lda #$7f  ;selects paddle/mouse A
   sta pa
   rts

keyscanInit = *
   lda #nullKey
   ldx #rollover-1
-  sta prevKeys,x
   dex
   bpl -
   lda #0
   sta ignoreKeys
   ldx #$00
   ldy #8
   lda $d030
   and #$02
   bne +
   ldx #$ff
   ldy #11
+  stx extKeyboardFlag
   sty scanrows
   stx extCapsFlag
!if useC64 {
   bit extCapsFlag
   bpl +
   bit aceSuperCpuFlag
   bpl +
   lda #$00
   sta extCapsFlag  ;SCPU-64 can't read the CAPS key
+  nop
}
   rts

;the idea for the keyscan routine comes from Marko Makela

keyscan = *
   lda #$ff
   sty pa
   sty pk
   sta ddrb
   lda #$fe
   sta mask+0
   lda #$ff
   sta mask+1
   ldy #0
   nextRow = *
   lda mask+0
   sta pa
   lda mask+1
   sta pk
   sec
   rol mask+0
   rol mask+1
   lda #$ff
   sta scanval
   ldx #8
   lda #$fe
-- sta ddrb
   sta pb
   sec
   rol
   pha
-  lda pb
   cmp pb
   bne -
   and scanval
   sta scanval
   pla
   dex
   bne --
   lda #$ff
   sta pa
   sta pk
   lda scanval
   eor #$ff
   sta scanTable,y
   iny
   cpy scanrows
   bcc nextRow
   lda #$00
   sta ddrb
   rts

shiftRows !byte $01,$06,$07,$07,$0a
shiftBits !byte $80,$10,$20,$04,$01
shiftMask !byte $01,$01,$02,$04,$08

shiftdecode = *
   jsr scanCaps
   ldy #4
   bit extKeyboardFlag
   bmi +
   ldy #3
+  nop
-  ldx shiftRows,y
   lda scanTable,x
   and shiftBits,y
   beq +
   lda shiftMask,y
   ora shiftValue
   sta shiftValue
   lda shiftBits,y
   eor #$ff
   and scanTable,x
   sta scanTable,x
+  dey
   bpl -
   rts

scanCaps = *
   lda regCapsPort
   bit extCapsFlag
   bpl +
-  lda extCapsPort
   cmp extCapsPort
   bne -
+  eor #$ff
   and #$40
   lsr
   lsr
   sta shiftValue
   rts

keydecode = *
   ldx #rollover-1
   lda #$ff
-  sta newKeys,x
   dex
   bpl -
   ldy #0
   sty newpos
   ldx #0
   stx keycode

   decodeNextRow = *
   lda scanTable,x
   beq decodeContinue

   ldy keycode
-  lsr
   bcc ++
   pha
   stx xsave
   ldx newpos
   cpx #rollover
   bcs +
   tya
   sta newKeys,x
   inc newpos
+  ldx xsave
   pla
++ iny
   cmp #$00
   bne -

   decodeContinue = *
   clc
   lda keycode
   adc #8
   sta keycode
   inx
   cpx scanrows
   bcc decodeNextRow
   rts

keyorder = *
   ;** remove old keys no longer held
   ldy #0
   nextRemove = *
   lda prevKeys,y
   cmp #$ff
   beq ++
   ldx #rollover-1
-  cmp newKeys,x
   beq +
   dex
   bpl -
   tya
   tax
-  lda prevKeys+1,x
   sta prevKeys+0,x
   inx
   cpx #rollover-1
   bcc -
   lda #$ff
   sta prevKeys+rollover-1
   sta ignoreKeys
+  iny
   cpy #rollover
   bcc nextRemove

   ;** insert new key at front
++ ldy #0
   nextInsert = *
   lda newKeys,y
   cmp #$ff
   beq ++
   ldx #rollover-1
-  cmp prevKeys,x
   beq +
   dex
   bpl -
   pha
   ldx #rollover-2
-  lda prevKeys+0,x
   sta prevKeys+1,x
   dex
   bpl -
   lda #0
   sta ignoreKeys
   pla
   sta prevKeys+0
   ldy #rollover
+  iny
   cpy #rollover
   bcc nextInsert
++ rts

checkJoystick = *
   ldx pa
   cpx conJoy2
   beq +
   stx conJoy2
   lda #$02
   ora conButtonChange
   sta conButtonChange
+  lda #$ff
   sta pa
   sta pk
-  lda pb
   cmp pb
   bne -
   cmp conJoy1
   beq +
   sta conJoy1
   lda #$01
   ora conButtonChange
   sta conButtonChange
   lda conJoy1
+  rts

scanTable  !fill 11,0
newKeys    !fill rollover,0
ignoreKeys !byte 0
prevKeys   !fill rollover+2,0

scrollFreeze    !byte $00
delayCountdown  !byte $00
repeatCountdown !byte $00
scrollCountdown !byte $00

interpKey = *  ;( keycode )
   lda keycode
   ;** noscroll
   cmp #87      ;noscroll
   beq +
   cmp #63      ;run/stop
   bne interpCaps
   lda shiftValue
   and #%1111
   cmp #4       ;control
   bne interpCaps
   lda keycode
+  cmp prevKeycode
   beq +
   sta prevKeycode
   lda scrollFreeze
   eor #$ff
   sta scrollFreeze
+  rts

   interpCaps = *
   bit extCapsFlag
   bmi interpShifts
   lda keycode
   cmp #63      ;run/stop
   bne interpShifts
   lda shiftValue
   and #%1111
   cmp #2       ;commodore
   bne interpShifts
   lda keycode
   cmp prevKeycode
   beq +
   sta prevKeycode
   lda regCapsPort
   eor #$40
   sta regCapsPort
+  rts

   interpShifts = *
   lda shiftValue
   and #%00011111
   cmp #%00010000
   bne +
   lda #$05
   jmp handleKey  ;caps
+  and #%1111
   tax
   lda shiftPriVec,x
   jmp handleKey

shiftPriVec = *
;          0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
   !byte $00,$01,$02,$06,$03,$03,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04

handleKey = * ;( keycode, .A=shiftTableNum )
   asl
   tax
   lda keycode
   cmp prevKeycode
   beq handleRepeat
   jmp handleOrigKey

handleRepeat = *
   stx xsave
   lda delayCountdown
   beq +
   dec delayCountdown
   beq ++
   rts
+  dec repeatCountdown
   beq ++
-  rts
++ lda configBuf+$c9
   sta repeatCountdown
   lda keybufCount
   bne -
   ldx xsave
   jmp +

handleOrigKey = * ;( .X=shiftTabOff )
   lda configBuf+$c8
   sta delayCountdown
   lda #0
   sta scrollFreeze
+  lda conKeymapIndirect+0,x
   sta keymapPtr+0
   lda conKeymapIndirect+1,x
   sta keymapPtr+1
   ldy keycode
   sty prevKeycode
   lda (keymapPtr),y
   bne storeKey
   rts

keybufHead  !byte 0
keybufTail  !byte 0
keybufCount !byte 0
;IDUN: Double buffer size to support user-defined macros
keybufSize  = 32        ;need power of 2
suppressSaveLine !byte 0
keybufData  !fill keybufSize,0
keybufShift !fill keybufSize,0

kernMiscRobokey = *
   ldx #$ff
   stx suppressSaveLine
storeKey = *  ;( .A=char )
   ldx keybufCount
   cpx #keybufSize
   bcc +
   ;xx ring bell--intr
   rts
+  ldx keybufTail
   sta keybufData,x
   lda shiftValue
   and #$0f
   cmp #$03
   bne +
-  lda shiftValue
   ora #$20
   jmp ++
+  lda keycode
   cmp #64
   bcs -
   lda shiftValue
++ sta keybufShift,x
   inc keybufTail
   lda keybufTail
   and #keybufSize-1
   sta keybufTail
   inc keybufCount
   rts

;*** getkey( ) : .A=keyChar, .X=keyShift

kernConGetkey = *
conGetkey = *
   php
-  cli
   ; BKH: Check if joys/keys forwarded
   bit joykeyCapture    ;$80=capture keys, $40=capture joy
   bpl ++
   sei
   lda conButtonChange
   and #$04
   beq ++
   lda conButtonChange
   and #$fb
   sta conButtonChange
   ; filter command to toggle keys forward OFF
   lda keycode
   cmp #$25 ;"k"
   bne +
   lda shiftValue
   cmp #$02
   bne +
   ; CmdK detected; disable keyboard forwarding
   jsr interpKey
   jmp ++
+  jsr pisvcPutKeyboard
   jmp -
++ cli
   lda keybufCount
   beq -
   sei
   ldy keybufHead
   dec keybufCount
   inc keybufHead
   lda keybufHead
   and #keybufSize-1
   sta keybufHead
   lda keybufData,y
   ldx keybufShift,y
   plp
   rts

;*** conkeyavail( ) : .CC=.Z=keyIsAvailable, .A=availKey[notRemoved], .X=shift
kernConKeyAvail = *
   lda keybufCount
   beq ++
   ldy keybufHead
   lda keybufData,y
   ldx keybufShift,y
   clc
   ldy #$ff
   php
-  ldy #$00
   bit extKeyboardFlag
   bpl +
   ldy #$80
+  plp
   rts
++ lda #$00
   ldx #$00
   sec
   php
   jmp -
   
;*** stopkey( ) : .CC=notPressed

kernConStopkey = *
conStopkey = *
   lda stopKeyRow
   cmp #$80
   beq +
-  clc
   rts
+  lda shiftValue
   and #$0f
   bne -
   lda #0
   sta keybufCount
   sta keybufHead
   sta keybufTail
   sta scrollFreeze
   lda #aceErrStopped
   sta errno
   sec
   rts

conKeymapIndirect = *
   !word conKeymapNormal,conKeymapShift,conKeymapCommodore,conKeymapControl
   !word conKeymapAlternate,conKeymapCaps,conKeymapShiftComm

conKeymapNormal = *
   !byte $14,$0d,$1d,$88,$85,$86,$87,$11  ;row 0
   !byte $33,$57,$41,$34,$5a,$53,$45,$01  ;row 1
   !byte $35,$52,$44,$36,$43,$46,$54,$58  ;row 2
   !byte $37,$59,$47,$38,$42,$48,$55,$56  ;row 3
   !byte $39,$49,$4a,$30,$4d,$4b,$4f,$4e  ;row 4
   !byte $2b,$50,$4c,$2d,$2e,$3a,$40,$2c  ;row 5
   !byte $5c,$2a,$3b,$13,$01,$3d,$5e,$2f  ;row 6
   !byte $31,$5f,$04,$32,$20,$02,$51,$03  ;row 7
   !byte $04,$38,$35,$09,$32,$34,$37,$31  ;row 8
   !byte $1b,$2b,$2d,$0a,$0d,$36,$39,$33  ;row 9
   !byte $08,$30,$2e,$91,$11,$9d,$1d,$00  ;row 10

conKeymapShift = *
   !byte $94,$8d,$9d,$8c,$89,$8a,$8b,$91  ;row 0
   !byte $23,$d7,$c1,$24,$da,$d3,$c5,$01  ;row 1
   !byte $25,$d2,$c4,$26,$c3,$c6,$d4,$d8  ;row 2
   !byte $27,$d9,$c7,$28,$c2,$c8,$d5,$d6  ;row 3
   !byte $29,$c9,$ca,$30,$cd,$cb,$cf,$ce  ;row 4
   !byte $db,$d0,$cc,$dd,$3e,$5b,$5f,$3c  ;row 5
   !byte $dc,$c0,$5d,$93,$01,$3d,$de,$3f  ;row 6
   !byte $21,$df,$04,$22,$20,$02,$d1,$83  ;row 7
   !byte $84,$38,$35,$02,$32,$34,$37,$31  ;row 8
   !byte $1b,$2b,$2d,$07,$8d,$36,$39,$33  ;row 9
   !byte $08,$30,$2e,$16,$17,$06,$0b,$00  ;row 10

conKeymapCommodore = *
   !byte $08,$0d,$16,$8f,$80,$82,$84,$17  ;row 0
   !byte $96,$b7,$a1,$97,$ba,$b3,$a5,$01  ;row 1
   !byte $98,$b2,$a4,$99,$a3,$a6,$b4,$b8  ;row 2
   !byte $9a,$b9,$a7,$9b,$a2,$a8,$b5,$b6  ;row 3
   !byte $29,$a9,$aa,$30,$ad,$ab,$af,$ae  ;row 4
   !byte $2b,$b0,$ac,$2d,$3e,$bb,$a0,$3c  ;row 5
   !byte $bc,$7f,$bd,$93,$01,$bf,$be,$3f  ;row 6
   !byte $81,$bf,$04,$95,$5f,$02,$b1,$03  ;row 7
   !byte $84,$38,$35,$18,$32,$34,$37,$31  ;row 8
   !byte $1b,$2b,$2d,$07,$8d,$36,$39,$33  ;row 9
   !byte $08,$30,$2e,$0c,$0f,$10,$15,$00  ;row 10

conKeymapControl = *
   !byte $08,$00,$00,$8f,$80,$82,$84,$00  ;row 0
   !byte $1c,$f7,$e1,$9f,$fa,$f3,$e5,$00  ;row 1
   !byte $9c,$f2,$e4,$1e,$e3,$e6,$f4,$f8  ;row 2
   !byte $1f,$f9,$e7,$9e,$e2,$e8,$f5,$f6  ;row 3
   !byte $12,$e9,$ea,$92,$ed,$eb,$ef,$ee  ;row 4
   !byte $2b,$f0,$ec,$2d,$00,$fb,$e0,$00  ;row 5
   !byte $fc,$60,$fd,$00,$00,$ff,$fe,$00  ;row 6
   !byte $90,$ff,$00,$05,$20,$00,$f1,$00  ;row 7
   !byte $84,$8c,$87,$18,$89,$8a,$88,$85  ;row 8
   !byte $1b,$84,$8f,$0a,$00,$8b,$80,$86  ;row 9
   !byte $08,$82,$2e,$16,$17,$19,$1a,$00  ;row 10

conKeymapAlternate = *
   !byte $08,$0d,$1d,$88,$85,$86,$87,$11  ;row 0
   !byte $33,$77,$61,$34,$7a,$73,$65,$00  ;row 1
   !byte $35,$72,$64,$36,$63,$66,$74,$78  ;row 2
   !byte $37,$79,$67,$78,$62,$68,$75,$76  ;row 3
   !byte $39,$69,$6a,$30,$6d,$6b,$6f,$6e  ;row 4
   !byte $2b,$70,$6c,$2d,$2e,$7b,$ba,$2c  ;row 5
   !byte $a9,$60,$7d,$13,$00,$7f,$7e,$2f  ;row 6
   !byte $31,$7f,$04,$32,$20,$02,$71,$03  ;row 7
   !byte $84,$38,$35,$09,$32,$34,$37,$31  ;row 8
   !byte $1b,$2b,$2d,$0a,$0d,$36,$39,$33  ;row 9
   !byte $08,$30,$2e,$91,$11,$9d,$1d,$00  ;row 10

conKeymapCaps = *
   !byte $14,$0d,$1d,$88,$85,$86,$87,$11  ;row 0
   !byte $33,$d7,$c1,$34,$da,$d3,$c5,$01  ;row 1
   !byte $35,$d2,$c4,$36,$c3,$c6,$d4,$d8  ;row 2
   !byte $37,$d9,$c7,$38,$c2,$c8,$d5,$d6  ;row 3
   !byte $39,$c9,$ca,$30,$cd,$cb,$cf,$ce  ;row 4
   !byte $2b,$d0,$cc,$2d,$2e,$3a,$40,$2c  ;row 5
   !byte $5c,$2a,$3b,$13,$01,$3d,$5e,$2f  ;row 6
   !byte $31,$5f,$04,$32,$20,$02,$d1,$03  ;row 7
   !byte $04,$38,$35,$09,$32,$34,$37,$31  ;row 8
   !byte $1b,$2b,$2d,$0a,$0d,$36,$39,$33  ;row 9
   !byte $08,$30,$2e,$91,$11,$9d,$1d,$00  ;row 10

conKeymapShiftComm = *
   !byte $00,$0d,$16,$00,$00,$00,$00,$17  ;row 0
   !byte $33,$0c,$10,$34,$0f,$15,$1b,$00  ;row 1
   !byte $35,$00,$0e,$36,$00,$00,$09,$00  ;row 2
   !byte $37,$18,$84,$38,$06,$04,$00,$00  ;row 3
   !byte $39,$16,$19,$30,$17,$1a,$00,$0b  ;row 4
   !byte $2b,$07,$0a,$2d,$2e,$10,$00,$2c  ;row 5
   !byte $00,$00,$15,$0c,$00,$00,$00,$04  ;row 6
   !byte $31,$1b,$00,$32,$00,$00,$00,$00  ;row 7
   !byte $04,$38,$35,$09,$32,$34,$37,$31  ;row 8
   !byte $1b,$2b,$2d,$0a,$0d,$36,$39,$33  ;row 9
   !byte $00,$30,$2e,$91,$11,$9d,$1d,$00  ;row 10


;This is to be done when we are in the write routine about to scroll the screen
;because we have hit the bottom line of the display.  It is also to be done in
;the context of the data remaining to be printed at the time.  I've changed
;the design a little to quickly go through and count the number of newline
;characters in the buffer and then scroll by that amount.

conLinesToScroll !byte 0
conBytesToScroll !byte 0,0
conScanPtr = syswork+14 ;(2)
conScanLen !byte 0,0
conMaxPrescroll !byte 0
conSoft80NonReu !byte 0

;conWritePtr    = syswork+8
;conWriteLength = syswork+10

conWriteNewline = *
   bit conIgnoreCtrl
   bmi +
   bit conIgnoreShift
   bmi +
   lda shiftValue
   and #$07
   beq +
-  jmp conNewline
+  ldx conCurRow
   inx
   cpx conWinRows
   bcc -

;find maximum prescroll amount;
;if maximum prescroll amount < 2 then never mind;

-  lda scrollFreeze
   bne -
   ldy #$00
   lda configBuf+$ac
   bit winDriver
   bmi conPrescrollBegin
   lda configBuf+$ad
   bvs conPrescrollBegin
   ldy #$ff
   lda configBuf+$ae
   bit aceSuperCpuFlag
   bmi +
   ldx winScrollReuWork+3
   cpx #aceMemNull
   beq conPrescrollBegin
+  lda configBuf+$ab
   ldy #$00
   conPrescrollBegin = *
   sty conSoft80NonReu
   ldx conPrescrollOverride
   beq +
   txa
+  sta conMaxPrescroll
   cmp #2
   bcs +
   jmp conNewline
+  cmp conWinRows
   bcc +
   lda conWinRows
   sta conMaxPrescroll
+  lda #1
   sta conLinesToScroll
   lda #0 ;number of bytes to move cursor up
   ldy #0
   sta conBytesToScroll+0
   sty conBytesToScroll+1
   lda conWritePtr+0
   ldy conWritePtr+1
   sta conScanPtr+0
   sty conScanPtr+1
   lda conWriteLength+0
   ldy conWriteLength+1
   sta conScanLen+0
   sty conScanLen+1

   ;** ignore first char of buffer
   inc conScanPtr+0
   bne +
   inc conScanPtr+1
+  lda conScanLen+0
   bne +
   dec conScanLen+1
+  dec conScanLen+0
   lda conScanLen+0
   ora conScanLen+1
   bne +
   jmp conPrescrollExit

   ;** count the CRs
+  ldy conScanLen+1
   beq +
-  ldy #0
   jsr conCountCrs
   bcs ++
   inc conScanPtr+1
   dec conScanLen+1
   bne -
+  ldy conScanLen+0
   jsr conCountCrs
++ jmp conPrescrollExit

conCountCrs = *  ;( (conScanPtr)=ptr, .Y=bytes, conCrCount ) : conCrCount,.CS=f
   dey
   beq ++
-  lda (conScanPtr),y
   cmp #chrCR
   bne +
   jsr conPrescrollLine
   bcc +
   rts
+  dey
   bne -
++ lda (conScanPtr),y
   cmp #chrCR
   beq +
   clc
   rts
+  jsr conPrescrollLine
   rts

conPrescrollLine = *  ;.CS=maxed
   inc conLinesToScroll
   clc
   lda conBytesToScroll+0
   adc conRowInc+0
   sta conBytesToScroll+0
   bcc +
   inc conBytesToScroll+1
+  lda conLinesToScroll
   cmp conMaxPrescroll
   rts

conPrescrollExit = *
   bit conSoft80NonReu
   bpl +
   lda conPrescrollOverride
   bne +
-  lda conLinesToScroll
   cmp configBuf+$a4
   bcs +
   jsr conPrescrollLine
   bcs +
   jmp -

+  lda #" "
   sta syswork+4
   lda conFillAttr
   sta syswork+6
   lda conPutMask
   ora #$08
   ldx conLinesToScroll
   ldy conFillColor
   jsr kernWinScroll
   inc conCurRow
   sec
   lda conCurRow
   sbc conLinesToScroll
   sta conCurRow
   sec
   lda conLineAddr+0
   sbc conBytesToScroll+0
   sta conLineAddr+0
   lda conLineAddr+1
   sbc conBytesToScroll+1
   sta conLineAddr+1
   lda #0
   sta conCurCol
   rts

kernConPutctrl = *
conPutctrl = *
   stx conPutctrlParm
   ;** check recognized
   ldx #conPutctrlDispatch-conPutctrlChars-1
-  cmp conPutctrlChars,x
   beq +
   dex
   bpl -
   bmi ++
+  txa
   asl
   tax
   lda conPutctrlDispatch+0,x
   sta syswork+0
   lda conPutctrlDispatch+1,x
   sta syswork+1
   ldx conPutctrlParm
   jmp (syswork+0)
   ;** check color
++ nop
   ;** print regular char
   jmp conPutchar

conPutctrlChars = *
   !byte chrCR,chrCLS,chrTAB,chrBS,chrBEL,chrBOL,chrVT
   !byte $13,$91,$11,$9d,$1d
   !byte $12,$92,$08,$94
   !byte $fe,$e0
   !byte $f0,$f1,$f8
   !byte $e9,$e4,$ec
   !byte $ed,$e7,$f2,$ee
   !byte $f5,$ef,$e2
conPutctrlDispatch = *
   !word conNewline,conCls,conTab,conBackspace,conBell,conReturnOnly,conCtrlDown
   !word conHome,conCtrlUp,conCtrlDown,conCtrlLeft,conCtrlRight
   !word conCtrlRvs,conCtrlRvsOff,conCtrlRub,conCtrlInsert
   !word conCtrlScreenEraseBegToCur,conCtrlScreenEraseCurToEnd
   !word conCtrlLineEraseBegToCur,conCtrlLineEraseCurToEnd,conCtrlLineErase
   !word conCtrlInsertLine,conCtrlDeleteLine,conCtrlPrescrollOverride
   !word conCtrlShiftScroll,conCtrlSynch,conCtrlScreenRvs,conCtrlScreenRvsOff
   !word conCtrlUnderline,conCtrlAttribOff,conCtrlBlink
conPutctrlParm !byte 0

conCtrlUp = * ;$91
   lda conCurRow
   beq +
   dec conCurRow
   sec
   lda conLineAddr+0
   sbc conRowInc+0
   sta conLineAddr+0
   lda conLineAddr+1
   sbc conRowInc+1
   sta conLineAddr+1
   clc
   rts
+  jsr conScrollDown
   clc
   rts

conScrollDown = *
   lda #" "
   sta syswork+4
   lda conFillAttr
   sta syswork+6
   lda conPutMask
   ora #$04
   ldx #1
   ldy conFillColor
   jsr kernWinScroll
   rts

conCtrlDown = * ;$11
   lda conCurCol
   pha
   jsr conNewline
   pla
   sta conCurCol
   rts

conCtrlLeft = * ;$9d
   lda conCurRow
   ora conCurCol
   beq +
   jmp conBackspace
+  jsr conCtrlUp
   ldx conWinCols
   dex
   stx conCurCol
   rts

conCtrlRight = * ;$1d
   inc conCurCol
   lda conCurCol
   cmp conWinCols
   bcc +
   jmp conNewline
+  rts

conCtrlRvs = * ;$12
   lda conExtAttr
   ora #$40
   sta conExtAttr
   rts

conCtrlRvsOff = * ;$92
   lda conExtAttr
   and #$ff-$40
   sta conExtAttr
   rts

conCtrlLineEraseBegToCur = *  ;$f0 (ESC p)
   ldx #0
   ldy conCurCol
   jmp conCtrlLineEraseWork

conCtrlLineEraseCurToEnd = *  ;$f1 (ESC q)
   ldx conCurCol
   ldy conWinCols
   dey
   jmp conCtrlLineEraseWork

conCtrlLineErase = *  ;$f8 (ESC x)
   ldx #0
   ldy conWinCols
   dey

   conCtrlLineEraseWork = *  ;(.X=fromOff, .Y=toOffInclusive)
   stx syswork+0
   iny
   tya
   sec
   sbc syswork+0
   sta syswork+5
   lda conLineAddr+0
   ldy conLineAddr+1
   clc
   adc syswork+0
   bcc +
   iny
+  sta syswork+0
   sty syswork+1
   lda #" "
   sta syswork+4
   lda #$00
   sta syswork+6
   lda conPutMask
   ldx #0
   ldy conFillColor
   jsr kernWinPut
   rts

conCtrlPrescrollOverride = *  ;$ec (ESC l)
   stx conPrescrollOverride
   rts

conCtrlShiftScroll = *  ;$ed (ESC m)
   stx conIgnoreShift
   rts

conCtrlSynch = *  ;$e7 (ESC g)
   jsr conSynchCursor
   rts

conCtrlInsertLine = *  ;$e9 (ESC i)
   jsr conCtrlScreenGetBelow
   clc
   adc #1
   dec syswork+0
   jsr conSubwinSet
   lda conPutMask
   ora #$04
   jmp conCtrlDeleteWork

conCtrlDeleteLine = *  ;$e4 (ESC d)
   jsr conCtrlScreenGetBelow
   clc
   adc #1
   dec syswork+0
   jsr conSubwinSet
   lda conPutMask
   ora #$08
   conCtrlDeleteWork = *
   ldx #" "
   stx syswork+4
   ldx conFillAttr
   stx syswork+6
   ldx #1
   ldy conFillColor
   jsr kernWinScroll
   jsr conSubwinExit
   rts

conCtrlScreenEraseBegToCur = *  ;$ef (ESC o)
   jsr conCtrlLineEraseBegToCur
   lda conWinStartRow
   ldx conWinStartCol
   sta syswork+0
   stx syswork+1
   lda conCurRow
   ldx conWinCols
   jmp conCtrlScreenEraseWork

conCtrlScreenEraseCurToEnd = *  ;$e0 (ESC @)
   jsr conCtrlLineEraseCurToEnd
   jsr conCtrlScreenGetBelow
   conCtrlScreenEraseWork = *
   jsr conSubwinSet
   bcs +
   lda #$00
   sta syswork+6
   lda conPutMask
   ldy conFillColor
   ldx #" "
   jsr kernWinCls
   jsr conSubwinExit
+  rts

conCtrlScreenGetBelow = *  ;( ) : (sw+0)=start_row/col, .AX=size_rows/cols
   sec ;sic
   lda conWinStartRow
   adc conCurRow
   ldx conWinStartCol
   sta syswork+0
   stx syswork+1
   clc ;sic
   lda conWinRows
   sbc conCurRow
   ldx conWinCols
   rts

conSubwinSave !fill conWinDataEnd-conWinStart,0

conSubwinSet = *  ;( ) : .CS=err
   pha
   ldy #conWinDataEnd-conWinStart-1
-  lda conWinStart,y
   sta conSubwinSave,y
   dey
   bpl -
   pla
   jmp kernWinSet

conSubwinExit = *  ;( )
   lda conWinStartRow-conWinStart+conSubwinSave  ;use saved value
   ldx conWinStartCol-conWinStart+conSubwinSave
   sta syswork+0
   stx syswork+1
   lda conWinRows-conWinStart+conSubwinSave
   ldx conWinCols-conWinStart+conSubwinSave
   jsr kernWinSet
   ldx #conWinDataEnd-conWinStart-1
-  lda conSubwinSave,x
   sta conWinStart,x
   dex
   bpl -
   rts

conCtrlScreenRvs = *
   ldx #5
   lda #$ff
   sec
   jmp kernWinOption

conCtrlScreenRvsOff = *
   ldx #5
   lda #$00
   sec
   jmp kernWinOption

conCtrlUnderline = *  ;$f5 (ESC U)
   lda conExtAttr
   ora #$20
   sta conExtAttr
   rts

conCtrlBlink = *  ;$e2 (ESC B)
   lda conExtAttr
   ora #$10
   sta conExtAttr
   rts

conCtrlAttribOff = *  ;$ef (ESC O)
   lda conExtAttr
   and #$80
   sta conExtAttr
   rts

conCtrlRub = * ;$08
   rts

conCtrlInsert = * ;$94
   rts

kernConKeyMat = *
   lda zp+0
   ldy zp+1
   sta syswork+0
   sty syswork+1
   ldy #0
-  lda (syswork+0),y
   sta conKeymapNormal+0,y
   iny
   bne -
   inc syswork+1
-  lda (syswork+0),y
   sta conKeymapNormal+256,y
   iny
   bne -
   inc syswork+1
-  lda (syswork+0),y
   sta conKeymapNormal+512,y
   iny
   cpy #104
   bcc -
   clc
   rts

conInputMode      !byte 0
conInputFakeCount !byte 0
conInputFakePos   !byte 0

kernConInput = * ;( (zp)=buf/initstr, .Y=initStrLen ):.Y=len,.CS=excp,.A=fchar
   lda #$ff
   sta conInputMode
   sty conInputFakeCount
   ldy #0
   sty conInputFakePos
-  lda (zp),y
   sta stringBuffer,y
   iny
   cpy conInputFakeCount
   bcc -
   jsr conInputIn
   php
   pha
   dec keylineCount
   ldy #0
   cpy keylineCount
   beq +
-  lda keyline,y
   sta (zp),y
   iny
   cpy keylineCount
   bcc -
+  lda #$00
   sta (zp),y
   sta keylinePos
   sta keylineCount
   sta keylinePtr
   pla
   plp
   rts

conMousePotx    = sid+$19
conMousePoty    = sid+$1a
conMouseOpotx    !byte 0
conMouseOpoty    !byte 0
conMouseNewValue !byte 0
conMouseOldValue !byte 0
conMouseX        !byte 0,0
conMouseY        !byte 0,0
conMouseButtons  !byte 0

kernConMouse = *  ;( ) : .A=buttons:l/r:128/64,(sw+0)=pX,(sw+2)=pY,sw+4=cX,sw+5=cY
   php
   sei
   jsr conMouseBounds
   lda conMouseX+0
   ldy conMouseX+1
   sta syswork+0
   sty syswork+1
   lda conMouseY+0
   ldy conMouseY+1
   sta syswork+2
   sty syswork+3
   lda conMouseButtons
   plp
   clc
   rts

conMouseIrq = *
   lda conMousePotx
   ldy conMouseOpotx
   jsr conMouseMoveCheck
   sty conMouseOpotx
   clc
   adc conMouseX+0
   sta conMouseX+0
   txa
   adc conMouseX+1
   sta conMouseX+1
   lda conMousePoty
   ldy conMouseOpoty
   jsr conMouseMoveCheck
   sty conMouseOpoty
   sec
   eor #$ff
   adc conMouseY+0
   sta conMouseY+0
   txa
   eor #$ff
   adc conMouseY+1
   sta conMouseY+1
   lda conJoy1
   sta conMouseButtons
   rts

conMouseMoveCheck = *
   sty conMouseOldValue
   sta conMouseNewValue
   ldx #0
   sec
   sbc conMouseOldValue
   and #%01111111
   cmp #%01000000
   bcs +
   lsr
   beq ++
   ldy conMouseNewValue
   rts
+  ora #%11000000
   cmp #$ff
   beq ++
   sec
   ror
   ldx #$ff
   ldy conMouseNewValue
   rts
++ lda #0
   rts

conMouseBounds = *
   ldx #0
   jsr +
   ldx #2
+  lda conMouseX+1,x
   bpl +
   lda #$00
   sta conMouseX+0,x
   sta conMouseX+1,x
+  lda conMouseX+0,x
   cmp aceMouseLimitX+0,x
   lda conMouseX+1,x
   sbc aceMouseLimitX+1,x
   bcc +
   lda aceMouseLimitX+0,x
   sbc #1
   sta conMouseX+0,x
   lda aceMouseLimitX+1,x
   sbc #0
   sta conMouseX+1,x
+  rts

kernConJoystick = *
   php
   sei
   lda conJoy1
   ldx conJoy2
   plp
   rts

kernConGamepad = *
   bcc +
   jmp pisvcPutJoystick
+  jmp pisvcGetJoysticks
   
kernConDebugLog = *
   jmp pisvcPutDebugLog

kernConOption = *
   ;** 1.console-put mask
   dex
   bne ++
   bcc +
   and #%11100000
   sta conPutMask
+  lda conPutMask
   clc
   rts
   ;** 2.character color
++ dex
   bne ++
   bcc +
   sta conCharColor
+  lda conCharColor
   clc
   rts
   ;** 3.character attributes
++ dex
   bne ++
   bcc +
   sta conExtAttr
+  lda conExtAttr
   clc
   rts
   ;** 4.fill color
++ dex
   bne ++
   bcc +
   sta conFillColor
+  lda conFillColor
   clc
   rts
   ;** 5.fill attributes
++ dex
   bne ++
   bcc +
   sta conFillAttr
+  lda conFillAttr
   clc
   rts
   ;** 6.cursor color
++ dex
   bne ++
   bcc +
   sta conCursorColor
+  lda conCursorColor
   clc
   rts
   ;** 7.force cursor wrap
++ dex
   bne +
   jsr conSynchCursor
   clc
   rts
   ;** 8.ignore shift keys for scrolling
+  dex
   bne ++
   bcc +
   sta conIgnoreShift
+  lda conIgnoreShift
   clc
   rts
   ;** 9.mouse scaling
++ dex
   bne ++
   bcc +
   nop
+  nop
   clc
   rts
   ;** 10.key-repeat delay
++ dex
   bne ++
   bcc +
   sta configBuf+$c8
+  lda configBuf+$c8
   clc
   rts
   ;** 11.key-repeat rate
++ dex
   bne ++
   bcc +
   sta configBuf+$c9
+  lda configBuf+$c9
   clc
   rts
   ;** 12.prescroll override
++ dex
   bne ++
   bcc +
   sta conPrescrollOverride
+  lda conPrescrollOverride
   clc
   rts
   ;** 13.screensaver timeout
++ dex
   bne ++
   bcc +
   sta configBuf+$86
+  lda configBuf+$86
   clc
   rts
   ;** 14.screensaver tool
++ dex
   bne ++
   bcc +
   rts
+  lda #<(configBuf+$f0)
   ldy #>(configBuf+$f0)
   sta zp
   sty zp+1
   clc
   rts
++ jmp notImp

;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2023 Brian Holdsworth                                    │
;│                                                                        │
;│ Permission is hereby granted, free of charge, to any person obtaining  │
;│ a copy of this software and associated documentation files (the        │
;│ "Software"), to deal in the Software without restriction, including    │
;│ without limitation the rights to use, copy, modify, merge, publish,    │
;│ distribute, sublicense, and/or sell copies of the Software, and to     │
;│ permit persons to whom the Software is furnished to do so, subject to  │
;│ the following conditions:                                              │
;│                                                                        │
;│ The above copyright notice and this permission notice shall be         │
;│ included in all copies or substantial portions of the Software.        │
;│                                                                        │
;│ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND         │
;│ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     │
;│ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. │
;│ IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   │
;│ CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   │
;│ TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      │
;│ SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 │
;└────────────────────────────────────────────────────────────────────────┘
