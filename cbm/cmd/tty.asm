; Idun TTY, Copyright© 2020 Brian Holdsworth
; This is free software, released under the MIT License.
;
; This application provides a DEC VT100-like console interface.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)

!source "sys/acehead.asm"
!source "sys/acemacro.asm"
!source "sys/toolhead.asm"

* = aceToolAddress
jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

;*** global declarations

modemFd       =  2  ;(1)  ;fd for modem
trptr         =  4  ;(2)  ;pointer to bytes to be translated
trcount       =  6  ;(2)  ;number of bytes to be translated
troutptr      =  8  ;(2)  ;pointer to output bytes from translation
troutcount    = 10  ;(2)  ;number of bytes that have been translated
keycode       = 12  ;(1)  ;keycode of last key struck
escState      = 13  ;(1)  ;current state in ESC sequence
escParm       = 14  ;(1)  ;current parameter index of parm data
escQuesFlag   = 15  ;(1)  ;flag for question-mark char used in ESC seq
keyshift      = 17  ;(1)  ;shift pattern of last key struck
keypadMode    = 38  ;(1)  ;$00=normal, $ff=application
cursorMode    = 39  ;(1)  ;$00=normal, $ff=application
linefeedMode  = 40  ;(1)  ;$00=linefeed, $ff=newline
screenMode    = 41  ;(1)  ;$00=normal, $ff=reversed
autowrapMode  = 42  ;(1)  ;$00=off, $ff=on
extentMode    = 43  ;(1)  ;$00=scroll_region, $ff=full_screen
attribMode    = 44  ;(1)  ;current attrib of cursor
                          ;  ($80=rvs,$40=underline,$20=blink,$10=intensity)
cursorDispMode= 45  ;(1)  ;$00=disable, $ff=enable
cursorSavePos = 46  ;(2)  ;(ACE) row and column of saved cursor
cursorSaveAttr= 48  ;(1)  ;saved attribute of cursor
emulateMode   = 50  ;(1)  ;0=literal,1=glasstty,2=vt100
escChar       = 52  ;(1)  ;current char in esc sequence
charColor     = 53  ;(1)  ;color of characters
cursorSaveColor = 54 ;(1) ;saved color of characters
work          = 96 ;(16) ;lowest-level temporary work area

escParmData:  !fill 24,0     ;accept up to 24 parameters for ESC sequences
readbufLenMax = 256     ;maximum size in bytes
readbufLen:   !word readbufLenMax

;===main===

main = *
   ;** check for a large-enough TPA
   sec
   lda #<bssEnd
   cmp aceMemTop+0
   lda #>bssEnd
   sbc aceMemTop+1
   bcs +
   jmp mainInit
+  lda #<tpaMsg
   ldy #>tpaMsg
   jsr eputs
die = *
   lda #1
   ldx #0
   jmp aceProcExit

tpaMsg = *
   !pet "Insufficient program space to run",13,0

mainInit = *
   ;** initialize variables
   lda #$00
   sta escState
   lda #FALSE
   sta keypadMode
   sta cursorMode
   sta linefeedMode
   sta screenMode
   sta extentMode
   sta cursorSavePos+0
   sta cursorSavePos+1
   sta cursorSaveAttr
   sta attribMode
   sta aceSignalProc
   lda #TRUE
   sta autowrapMode
   sta cursorDispMode
   lda defEmulate
   sta emulateMode
   jsr userkeyInit
   jsr modemOpen
   ldx #0
   jsr RestoreVersion
   lda toolWinPalette+0
   sta charColor
   ;IDUN: Setup hotkeys
   jsr HotKeyInit
   jsr term    ;only returns on terminal quit
   jsr modemClose
   jmp die

modemOpen = *
   ;** open modem file
   lda #1
   ldy #0
   jsr getarg
   ;verify device is correct type (#6)
   jsr aceMiscDeviceInfo
   cpx #6
   bne modemOpenErr
   ldx syswork+1
   stx work+4
   ;send io ctrl message with term size
   jsr getTermsz
   ldx work+4
   lda #<termSzctl
   ldy #>termSzctl
   sta zp
   sty zp+1
   jsr aceFileIoctl
   bcs modemOpenErr
   ;open device
   lda #1
   ldy #0
   jsr getarg
   +ldaSCII "w"
   jsr open
   bcc +
   modemOpenErr = *
   lda #<modemFilenameErr
   ldy #>modemFilenameErr
   jsr eputs
   jmp die
+  sta modemFd
   ;if argument was like "d:cmd", then make
   ;the cmd string the default tool title
   ldy #2
   lda (zp),y
   beq +
   ldx #0
-  sta tooltitle,x
   inx
   cpx #16
   beq +
   iny
   lda (zp),y
   bne -
   ;fill any remainder with spc
-  cpx #16
   beq +
   lda #$20
   sta tooltitle,x
   inx
   jmp -
+  rts
modemFilenameErr: !pet "Cannot open device or process",13,0

getTermsz = *
   ;check for 40 cols
   lda toolWinScroll+1
   cmp #40
   bne +
   lda #"4"
   sta termSzctl+0
   ;set correct lines
+  lda toolWinScroll+0
   sta work+0
   lda #0
   sta work+1
   sta work+2
   sta work+3
   lda #<termSzctl
   clc
   adc #3
   sta zp+0
   lda #>termSzctl
   adc #0
   sta zp+1
   ldx #work
   lda #2
   jmp aceMiscUtoa
termSzctl: !pet "80xYY",0

modemClose = *
   lda modemFd
   jmp close


petToAscTable = *   ;$ff=ignore, $fe=special

          ;0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
   !byte $ff,$ff,$ff,$fe,$fe,$ff,$ff,$fe,$ff,$09,$fe,$ff,$ff,$0d,$ff,$ff ;0
   !byte $ff,$fe,$fe,$fe,$fe,$ff,$ff,$ff,$ff,$ff,$ff,$1b,$fe,$fe,$ff,$ff ;1
   !byte $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2a,$2b,$2c,$2d,$2e,$2f ;2
   !byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3a,$3b,$3c,$3d,$3e,$3f ;3
   !byte $40,$61,$62,$63,$64,$65,$66,$67,$68,$69,$6a,$6b,$6c,$6d,$6e,$6f ;4
   !byte $70,$71,$72,$73,$74,$75,$76,$77,$78,$79,$7a,$5b,$5c,$5d,$5e,$5f ;5
   !byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ;6
   !byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ;7
   !byte $ff,$fe,$ff,$fe,$ff,$fe,$fe,$fe,$fe,$ff,$ff,$ff,$ff,$0d,$ff,$ff ;8
   !byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$ff,$fe,$ff,$ff ;9
   !byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe ;a
   !byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe ;b
   !byte $60,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4a,$4b,$4c,$4d,$4e,$4f ;c
   !byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5a,$7b,$7c,$7d,$7e,$5f ;d
   !byte $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f ;e
   !byte $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1d,$1e,$1f ;f

ascToPetTable = *
          ;0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
   !byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$07,$14,$09,$fe,$fe,$fe,$0a,$ff,$ff ;0
   !byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$ff,$ff,$ff,$ff ;1
   !byte $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2a,$2b,$2c,$2d,$2e,$2f ;2
   !byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3a,$3b,$3c,$3d,$3e,$3f ;3
   !byte $40,$c1,$c2,$c3,$c4,$c5,$c6,$c7,$c8,$c9,$ca,$cb,$cc,$cd,$ce,$cf ;4
   !byte $d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$d8,$d9,$da,$5b,$5c,$5d,$5e,$5f ;5
   !byte $c0,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4a,$4b,$4c,$4d,$4e,$4f ;6
   !byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5a,$db,$dc,$dd,$de,$ff ;7
   !byte $ff,$ff,$ff,$ff,$fe,$fe,$ff,$ff,$fe,$ff,$ff,$ff,$ff,$fe,$ff,$ff ;8
   !byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$ff,$ff,$ff,$ff ;9
   !byte $a0,$a1,$a2,$a3,$a4,$a5,$a6,$a7,$a8,$a9,$aa,$ab,$ac,$ad,$ae,$af ;a
   !byte $b0,$b1,$b2,$b3,$b4,$b5,$b6,$b7,$b8,$b9,$ba,$bb,$bc,$bd,$be,$bf ;b
   !byte $60,$61,$62,$63,$64,$65,$66,$67,$68,$69,$6a,$6b,$6c,$6d,$6e,$6f ;c
   !byte $70,$71,$72,$73,$74,$75,$76,$77,$78,$79,$7a,$7b,$7c,$7d,$7e,$7f ;d
   !byte $e0,$e1,$e2,$e3,$e4,$e5,$e6,$e7,$e8,$e9,$ea,$eb,$ec,$ed,$ee,$ef ;e
   !byte $f0,$f1,$f2,$f3,$f4,$f5,$f6,$f7,$f8,$f9,$fa,$fb,$fc,$fd,$fe,$fe ;f


term = *
   jsr HotClr
   jsr cursorInit
termLoop = *
   lda #0
   ;IDUN: Disable keys/joys forwarding
   ; For now, don't allow any forwarding in console.
   sta joykeyCapture
   sta zw+1
   jsr aceTtyAvail
   sta zw
   beq +
   tax
   lda #<readbuf
   ldy #>readbuf
   jsr aceTtyGet
   bcs +
   jsr cursorOff
   jsr PrintReceivedData
   jsr cursorOn
+  bit aceSignalProc
   bvs termExit
   jsr aceConKeyAvail
   bcs termLoop
   jsr aceConGetkey
   sta keycode
   stx keyshift
   jsr checkKeypadKey
   tax
   lda petToAscTable,x
   cmp #$ff
   beq ++
   cmp #$fe
   bne +
   jsr cursorOff
   lda keycode
   jsr toolKeysHandler
   jsr cursorOn
   jmp ++
+  sta writeChar
   lda #<writeChar
   ldy #>writeChar
   ldx #1
   jsr modemSend
++ bit aceSignalProc
   bvs +
   jmp termLoop

   termExit = *
+  jsr cursorOff
   jsr HotkeyRevert
   jsr toolWinRestore
   rts
writeChar: !byte 1

modemSend = *  ;( .AY=dataptr, .X=len )
   jmp aceTtyPut

cursorFlag: !byte 0

cursorInit = *
cursorOn = *
   lda #$ff
   sta cursorFlag
   jsr aceConGetpos
   cpx toolWinScroll+1
   bcc +
   dex
   ldy #$fa
   sty cursorFlag
+  jsr aceWinPos
   lda cursorFlag
   ldy toolWinPalette+1
   jsr aceWinCursor
   rts

cursorOff = *
   lda #$00
   jsr aceWinCursor
   rts


;=== print received data ===

PrintReceivedData = *  ;( readbuf, (zw)=count )
   lda emulateMode
   cmp #0
   bne +
   jmp PrintWriteLiteral
+  sec
   lda #0
   sbc zw+0
   sta trcount+0  ;makes this incrementable
   lda #0
   sbc zw+1
   sta trcount+1
   lda #<readbuf
   ldy #>readbuf
   sta trptr+0
   sty trptr+1

   printNext = *
   lda trcount+0
   ora trcount+1
   bne .handleEscSeq
   rts

   ;** handle esc sequences
.handleEscSeq:
   lda escState
   beq ++
   ldy #0
   lda (trptr),y
   tax
   lda ascToPetTable,x
   prEscEntry = *
   jsr EscProcess
   inc trptr+0
   bne +
   inc trptr+1
+  inc trcount+0
   bne .handleEscSeq
   inc trcount+1
   bne .handleEscSeq
   rts

   ;** handle regular characters
++ lda #<readbuf
   ldy #>readbuf
   sta troutptr+0
   sty troutptr+1
   lda #0
   sta troutcount+0
   sta troutcount+1
   lda trcount+0
   ora trcount+1
   bne +
   rts
+  ldy #0
-  lda (trptr),y
   tax
   lda ascToPetTable,x
   cmp #$fe
   beq prSpecial
   cmp #$ff
   beq prCont
   prTroutPut = *
   sta (troutptr),y
   inc troutptr+0
   bne +
   inc troutptr+1
+  inc troutcount+0
   bne +
   inc troutcount+1
   prCont = *
+  inc trptr+0
   bne +
   inc trptr+1
+  inc trcount+0
   bne -
   inc trcount+1
   bne -
   jsr PrintFlush
   rts

   prSpecial = *  ;process special character in translation (lf/esc)
   txa
   cmp #$ff
   bne +
   jmp prTroutPut
+  and #$ff ;$7f?
   cmp #$1b  ;ESC
   bne ++
-  ldx emulateMode
   cpx #1
   beq +
   pha
   jsr PrintFlush
   pla
   jmp prEscEntry
+  jmp prTroutPut
++ cmp #$9b  ;VT-CSI
   beq -
   cmp #$84  ;VT-IND
   beq -
   cmp #$8d  ;VT-RI
   beq -
   cmp #$85  ;VT-NEL
   beq -
   cmp #$88  ;VT-HTS
   beq -
   cmp #$0a  ;LF
   beq +
   cmp #$0b  ;VT
   beq +
   cmp #$0c  ;FF
   beq +
   lda #$fe
   jmp prTroutPut
+  lda troutcount+0
   ora troutcount+1
   bne +
   jsr aceConGetpos
   cpx #0
   bne prSpecialLfLit
-  ldy #0
   lda #chrCR
   jmp prTroutPut
+  ldy troutptr+1
   ldx troutptr+0
   bne +
   dey
+  dex
   stx work+0
   sty work+1
   ldy #0
   lda (work+0),y  ;check prev char
   cmp #$0a
   beq +
   cmp #chrCR
   beq -
   jmp prSpecialLfLit
+  lda #chrCR
   sta (work+0),y  ;modify prev char
   jmp prCont

   prSpecialLfLit = * ;literal lf -> crsr down
   jsr PrintFlush
   lda #chrVT
   sta readbuf+0
   lda #1
   ldy #0
   sta troutcount+0
   sty troutcount+1
   jsr PrintFlush
   inc trptr+0
   bne +
   inc trptr+1
+  inc trcount+0
   bne +
   inc trcount+1
+  jmp printNext

PrintFlush = *  ;flush trout buffer
   lda troutcount+0
   ora troutcount+1
   beq +
   lda #<readbuf
   ldy #>readbuf
   sta zp+0
   sty zp+1
   lda troutcount+0
   ldy troutcount+1
   ldx #stdout
   jsr write
   ;lda #$b9
   ;jsr putchar
+  rts

PrintWriteLiteral = *  ;( readbuf, (zw)=count )
   lda zw+0
   ldy zw+1
   sta writelen+0
   sty writelen+1
   lda #<readbuf
   ldy #>readbuf
   sta zp+0
   sty zp+1
-  lda writelen+0
   ora writelen+1
   bne +
   rts
+  ldy #0
   lda (zp),y
   tax
   and #$7f
   cmp #$7f
   beq +
   cmp #$20
   bcs ++
+  txa
   jmp +++
++ lda ascToPetTable,x
+++jsr aceConPutlit
   inc zp+0
   bne +
   inc zp+1
+  sec
   lda writelen+0
   sbc #1
   sta writelen+0
   bcs +
   dec writelen+1
+  jmp -
writelen: !byte 0,0

;=== "hotkey" handlers ===
consoleKeys = *
   !byte HotkeyCmdI,HotkeyCmdQ,HotkeyCmdX,HotkeyCmdZ,HotkeyCmdBackarrow
   !byte HotkeyRight,HotkeyLeft,HotkeyDown,HotkeyUp,HotkeyClr,HotkeyHome
   !byte HotkeyDel,HotkeyStop,0
consoleKeyHandlers = *
   !word HotI,HotQ,HotX,HotZ,HotCoBackarrow
   !word HotRight,HotLeft,HotDown,HotUp,HotClr,HotHome
   !word HotDel,HotStop

consKeyPtr !byte 0
consKeyTmp !byte 0
HotKeyInit = *
   lda #0
   sta consKeyPtr
-  asl
   tax
   lda consoleKeyHandlers,x
   sta consKeyTmp
   inx
   lda consoleKeyHandlers,x
   tay
   ldx consKeyPtr   
   lda consoleKeys,x
   beq +
   ldx consKeyTmp
   jsr toolKeysSet
   inc consKeyPtr
   lda consKeyPtr
   jmp -  
+  rts

HotkeyRevert = *
   lda #0
   sta consKeyPtr
-  ldx consKeyPtr
   lda consoleKeys,x
   beq +
   jsr toolKeysRemove
   inc consKeyPtr
   jmp -
+  rts

HotI = *
   lda #<helpMsg
   ldy #>helpMsg
   sta zp+0
   sty zp+1
   lda #<helpMsgEnd-helpMsg
   ldy #>helpMsgEnd-helpMsg
   ldx #stdout
   jmp write

helpMsg = *
   !pet 13,"The following 'hot keys' are supported:"
   !pet 13,13
   !pet $fe,$ff,"i : help information (also HELP)",13
   !pet $fe,$ff,"q : quit",13
   !pet $fe,$ff,"z : pause terminal flow",13
   !pet $fe,$ff,"_ : compose Hexadecial character",13
   !pet "CLR   : clear screen (nothing sent to modem)",13
   !pet "DEL,HOME,BACKARROW : BS,DEL,_(128) / BS,DEL,ESC(64), "
   !pet $fe,$ff,"x to swap HOME/DEL",13
   !pet "RVS,RVSOFF : reverse screen",13
   !pet "STOP : send CTRL+C",13
helpMsgEnd = *

HotQ = *  ;quit
   lda #TRUE
   sta aceSignalProc
   clc
   rts

HotX = *
   lda txDel
   ldx txHome
   stx txDel
   sta txHome
   clc
   rts

HotZ = *
   ldx #pauseMsg-tooltitle
   jsr RestoreVersion
   jsr CursorGreen
   jsr aceConGetkey
   jsr cursorOff
   ldx #0
   jsr RestoreVersion
   clc
   rts

HotCoBackarrow = *
   lda #0
   jsr Compose
   clc
   rts

HotRight = *
   inx ;3
HotLeft = *
   inx ;2
HotDown = *
   inx ;1
HotUp = *
   nop ;0
   txa
   cmp #4
   bcs +
   bit cursorMode
   bpl +
   clc
   adc #8
+  asl
   asl
   ldy #>cursorPfCodes
   clc
   adc #<cursorPfCodes
   bcc +
   iny
+  ldx #3
   jsr modemSend
   clc
   rts

   cursorPfCodes = *
   !pet 27,"[a_",27,"[b_",27,"[d_",27,"[c_",27,"op_",27,"oq_",27,"or_",27,"os_",27,"oa_",27,"ob_",27,"od_",27,"oc_"

HotClr = *
   lda #chrCLS
   jmp putchar

HotHome = *
   lda #<txHome
   ldy #>txHome
   ldx #1
   jmp modemSend

HotDel = *
   lda #<txDel
   ldy #>txDel
   ldx #1
   jmp modemSend

; HotBackarrow = *
;    lda #<txBackarrow
;    ldy #>txBackarrow
;    ldx #1
;    jmp modemSend

HotStop = *
   lda txStop
   bne +
   clc
   rts
+  lda #<txStop
   ldy #>txStop
   ldx #1
   jmp modemSend

checkKeypadKey = *  ;( .A=keychar, .X=shift ) : .A=keychar
   txa
   and #$20
   bne +
-  lda keycode
   rts
+  bit keypadMode
   bpl -
   ldx #13
-  lda keycode
   cmp keypadKeys,x
   beq +
   dex
   bpl -
   lda keycode
   rts
+  txa
   sta work
   asl
   adc work
   ldy #>keypadCodes
   clc
   adc #<keypadCodes
   bcc +
   iny
+  ldx #3
   jsr modemSend
   lda #$00
   rts
keypadKeys:   !pet "0123456789-+.",chrCR
keypadCodes:  !pet 27,"o",$70,27,"o",$71,27,"o",$72,27,"o",$73,27,"o",$74
              !pet 27,"o",$75,27,"o",$76,27,"o",$77,27,"o",$78,27,"o",$79
              !pet 27,"o",$6d,27,"o",$6c,27,"o",$6e,27,"om"


;===character composition===

composeType:  !byte 0
composeChars: !byte 0,0
composeLen:   !byte 0
composeCode:  !byte 0
composePrompt:!fill 12,0

Compose = *  ;( .A=0:hex/12:iso8859-1 )
   sta composeType
   lda #0
   sta composeLen
   jsr CursorGreen
   jsr ComposePrompt1
   jsr aceConGetkey
   sta composeChars+0
   ldx composeType
   bne +
   jsr ComposeCheckHex
   bcs composeErrorExit
+  inc composeLen
   jsr ComposePrompt1
   jsr aceConGetkey
   sta composeChars+1
   inc composeLen
   ldx composeType
   bne +
   jsr ComposeHex
   jmp ++
+  jsr ComposeIso8859_1
++ bcs composeErrorExit
   jsr ComposePrompt1
   jsr cursorOff
   lda #<composeCode
   ldy #>composeCode
   ldx #1
   jsr modemSend
   rts

   composeErrorExit = *
   jsr cursorOff
   ldx #composeError-tooltitle
   jsr RestoreVersion
   jsr Buzz
   rts

ComposePrompt1 = *  ;( composeLen, composeType )
   ldx #0
   ldy composeType
-  lda hexInPrompt,y
   sta composePrompt,x
   iny
   inx
   cpx #16
   bcc -
   ldx #3
   +ldaSCII " "
-  sta composePrompt+8,x
   dex
   bpl -
   ldx #8
   ldy composeLen
   beq ++
   lda composeChars+0
   sta composePrompt+8
   inx
   cpy #1
   beq ++
   lda composeChars+1
   sta composePrompt+9
   +ldaSCII ":"
   sta composePrompt+$a
   lda composeCode
   and #$7f
   cmp #$20
   php
   lda composeCode
   plp
   bcc +
   cmp #$ff
   beq +
   ldx composeCode
   lda ascToPetTable,x
+  sta composePrompt+$b
   jmp +++
++ +ldaSCII "_"
   sta composePrompt,x
+++lda #<composePrompt
   ldy #>composePrompt
   jmp toolStatTitle

hexInPrompt:     !pet "HexASC:$01:x    "
composeInPrompt: !pet "Compose:xx:x    "
tooltitle:       !pet "VT-100 Console  "
composeError:    !pet "InvalidCode!    "
pauseMsg:        !pet "Flow paused     "
                     ; 0123456789abcdef

CursorGreen = *
   jsr aceConGetpos
   cpx toolWinScroll+1
   bcc +
   dex
+  jsr aceWinPos
   lda #$ff
   ldy toolWinPalette+2
   jsr aceWinCursor
   rts

ComposeHex = *  ;( composeChars ) : composeCode, .CS=err
   lda composeChars+0
   jsr ComposeCheckHex
   bcs +
   asl
   asl
   asl
   asl
   sta composeCode
   lda composeChars+1
   jsr ComposeCheckHex
   bcs +
   ora composeCode
   sta composeCode
   clc
+  rts

ComposeCheckHex = *  ;( .A=char ) : .A=binValue, .CS=err
   +cmpASCII "0"
   bcc ++
   cmp #$3a
   bcc +
   and #$7f
   +cmpASCII "a"
   bcc ++
   cmp #$47
   bcs ++
   sbc #6
+  and #$0f
   clc
   rts
++ sec
   rts

RestoreVersion = *  ;( .X=offset )
   ldy #0
-  lda tooltitle,x
   sta composePrompt,y
   inx
   iny
   cpy #16
   bcc -
   lda #<composePrompt
   ldy #>composePrompt
   jmp toolStatTitle

ComposeIso8859_1 = *  ;( composeChars ) : composeCode, .CS=err
   jsr ComposeCheckIso
   bcc +
   jsr ComposeSwapChars
   jsr ComposeCheckIso
   bcc +
   jsr ComposeSwapChars
   jsr ComposeAlterCases
   jsr ComposeCheckIso
   bcc +
   jsr ComposeSwapChars
   jsr ComposeCheckIso
+  rts

ComposeCheckIso = *  ;( composeChars ) : composeCode, .CS=not found
   ldx #0
-  lda composeChars+0
   cmp iso8859_1CompCodes+0,x
   bne +
   lda composeChars+1
   cmp iso8859_1CompCodes+1,x
   beq ++
+  inx
   inx
   cpx #iso8859_1ExtraCodeValues-iso8859_1CompCodes
   bcc -
   sec
   rts
++ txa
   lsr
   adc #$a0
   sta composeCode
   bcs +
   rts
+  tax
   lda iso8859_1ExtraCodeValues,x
   sta composeCode
   clc
   rts

iso8859_1CompCodes = *
   !pet "  !!C/L-XOY-||SO",34,34,"COA_<<~~--RO__"           ;ASCII $a0--$af
   !pet "0^+-2^3^''/UP!.^,,1^O_>>141234??"                  ;ASCII $b0--$bf
   !pet "`A'A^A~A",34,"A*AAEC,`E'E^E",34,"E`I'I^I",34,"I"   ;ASCII $c0--$cf
   !pet "D-~N`O'O^O~O",34,"O**O/`U'U^U",34,"U'YPPss"        ;ASCII $d0--$df
   !pet "`a'a^a~a",34,"a*aaec,`e'e^e",34,"e`i'i^i",34,"i"   ;ASCII $e0--$ef
   !pet "%o~n`o'o^o~o",34,"o//o/`u'u^u",34,"u'ypp",34,"y"   ;ASCII $f0--$ff
   !pet "C|L=X0Y S!S0C0R0"                                  ;Extra codes
iso8859_1ExtraCodeValues = *
   !byte $a2,$a3,$a4,$a5,$a7,$a7,$a9,$ae

ComposeSwapChars = *
   lda composeChars+0
   ldx composeChars+1
   sta composeChars+1
   stx composeChars+0
   rts

ComposeAlterCases = *
   ldx #1
-  lda composeChars,x
   and #$7f
   +cmpASCII "a"
   bcc +
   cmp #$5b
   bcs +
   lda composeChars,x
   eor #$80
   sta composeChars,x
+  dex
   bpl -
   rts

Buzz = *
   lda #chrBEL
   jsr putchar
   rts

;===user-configurable options===

txBackarrow: !byte $5f  ;underscore
txHome:      !byte $7f  ;del
txDel:       !byte $08  ;backspace
txStop:      !byte $03  ;CTRL+C
defEmulate:  !byte 2    ;vt100

userkeyInit = *
   jsr aceConKeyAvail
   cpy #$00
   bne +
   lda #$1b
   sta txBackarrow
+  rts

;=== escape sequence control ===

EscProcess = *  ;( .A=char ) ...finite-state machine
   sta escChar
   ;** ANSI-ish interpreter
   ldx escState
   beq +
   jmp escNext
+  ldx #$01
   stx escState
   ldx #0
   stx escParm
   stx escQuesFlag
   stx escParmData+0
   stx escParmData+1
   cmp #$1b  ;ESC
   bne +
   rts
+  cmp #$9b  ;CSI
   bne +
   ldx #$02
   stx escState
   rts
+  cmp #$90  ;DCS
   bne +
   ldx #$03
   sta escState
   ;** command terminators
+  ldx #0
-  cmp escAnsiRawChar,x
   beq +
   inx
   cpx #escAnsiRawDispatch-escAnsiRawChar
   bcc -
   jmp escFinish
+  txa
   asl
   tax
   lda escAnsiRawDispatch+0,x
   sta syswork+0
   lda escAnsiRawDispatch+1,x
   sta syswork+1
   jsr +
   jmp escFinish
+  jmp (syswork+0)

escAnsiRawChar:
   !byte $00,$05,$07,$08  ;NUL,ENQ,BEL, BS  ;(1)
   !byte $09,$0a,$0b,$0c  ; HT, LF, VT, FF  ;(2)
   !byte $0d,$0e,$0f,$11  ; CR, SO, SI,XON  ;(3)
   !byte $13,$18,$1a,$7f ;XOFF,CAN,SUB,DEL  ;(4)
   !byte $84,$85,$88,$8d  ;IND,NEL,HTS, RI  ;(5)
   !byte $8e,$8f,$90,$9c  ;SS2,SS3          ;(6)
escAnsiRawDispatch:
   !word ActNull,ActEnquire,ActBell,ActBackspace    ;(1)
   !word ActTab,ActLinefeed,ActLinefeed,ActLinefeed ;(2)
   !word ActCr,ActSetG1toGL,ActSetG0toGL,ActXon     ;(3)
   !word ActXoff,ActNull,ActRvsQuestion,ActNull     ;(4)
   !word ActIndex,ActNewline,ActTabSet,ActRvsIndex  ;(5)
   !word ActSetG2toGL,ActSetG3toGL                  ;(6)

   escNext = *
   ldx escState
   cpx #$02
   beq escCsi
   +cmpASCII "["
   bne +
   ldx #$02
   stx escState
   rts
+  +cmpASCII "("
   bne +
-  sta escQuesFlag
   rts
+  +cmpASCII ")"
   beq -
   +cmpASCII "*"
   beq -
   +cmpASCII "+"
   beq -
   ;** command terminators
+  +cmpASCII "="
   bne +
   jmp escKeypadApp
+  +cmpASCII ">"
   bne +
   jmp escKeypadNorm
+  +cmpASCII "D"
   bne +
   jmp escCursorDownScroll
+  +cmpASCII "M"
   bne +
   jmp escCursorUpScroll
+  +cmpASCII "E"
   bne +
   jmp escNewline
+  +cmpASCII "H"
   bne +
   jmp escTabSet
+  +cmpASCII "7"
   bne +
   jmp escCursorSave
+  +cmpASCII "8"
   bne +
   jmp escCursorRestore
+  +cmpASCII "Z"
   bne +
   jmp escDeviceId
+  +cmpASCII "c"
   bne +
   jmp escHardReset
+  jmp escMalformed

   escCsi = *
   +cmpASCII "?"
   bne +
-  sta escQuesFlag
   rts
+  +cmpASCII ">"
   beq -
   +cmpASCII "!"
   beq -
+  +cmpASCII "0"
   bcc +
   cmp #$3a
   bcs +
   jsr escHandleDigit
   rts
+  +cmpASCII ";"
   bne ++
   inc escParm
   ldx escParm
   cpx #23
   bcc +
   ldx #23
   stx escParm
+  lda #0
   sta escParmData,x
   rts
   ;** command terminators
++ inc escParm
   +cmpASCII "A"
   bne +
   jmp escCursorUp
+  +cmpASCII "B"
   bne +
   jmp escCursorDown
+  +cmpASCII "b"
   bne +
   jmp escBlankspace
+  +cmpASCII "C"
   bne +
   jmp escCursorRight
+  +cmpASCII "D"
   bne +
   jmp escCursorLeft
+  +cmpASCII "d"
   bne +
   jmp escCursorPos
+  +cmpASCII "H"
   bne +
   jmp escCursorPos
+  +cmpASCII "G"
   bne +
   jmp escCursorHorizPos
+  +cmpASCII "f"
   bne +
   jmp escCursorPos
+  +cmpASCII "g"
   bne +
   jmp escTabClear
+  +cmpASCII "m"
   bne +
   jmp escAttrib
+  +cmpASCII "h"
   bne +
   jmp escTermModeSet
+  +cmpASCII "l"
   bne +
   jmp escTermModeClear
+  +cmpASCII "L"
   bne +
   jmp escInsertLine
+  +cmpASCII "M"
   bne +
   jmp escDeleteLine
+  +cmpASCII "@"
   bne +
   jmp escInsertChar
+  +cmpASCII "P"
   bne +
   jmp escDeleteChar
+  +cmpASCII "X"
   bne +
   jmp escEraseChar
+  +cmpASCII "K"
   bne +
   jmp escEraseLine
+  +cmpASCII "J"
   bne +
   jmp escEraseScreen
+  +cmpASCII "r"
   bne +
   jmp escScrollRegion
+  +cmpASCII "S"
   bne +
   jmp escScrollViewUp
+  +cmpASCII "T"
   bne +
   jmp escScrollViewDown
+  +cmpASCII "i"
   bne +
   jmp escPrinterControl
+  +cmpASCII "n"
   bne +
   jmp escDeviceStatus
+  +cmpASCII "c"
   bne +
   jmp escDeviceAttr
+  +cmpASCII "p"
   bne +
   jmp escSoftReset
+  +cmpASCII "s"
   bne +
   jmp escCursorSave
+  +cmpASCII "u"
   bne +
   jmp escCursorRestore
+  jmp escMalformed

   escMalformed = *
   lda #chrBEL
   jsr putchar

   escFinish = *
   lda #$00
   sta escState
   rts

escHandleDigit = *  ;( .A=digit )
   and #$0f
   sta work+0
   ldx escParm
   lda escParmData,x
   asl
   bcs +
   asl
   bcs +
   clc
   adc escParmData,x
   bcs +
   asl
   bcs +
   clc
   adc work+0
   bcc ++
+  lda #255
++ sta escParmData,x
   rts

;=== escape sequence action routines, VT-220 annotations ===

ActNull = *  ;do nothing
   rts

ActEnquire = *  ;send answerback message
   nop  ;&&&
   rts

ActBell = *  ;ring bell
   lda #chrBEL
   jmp putchar

ActBackspace = *  ;backspace
   lda #chrBS
   jmp putchar

ActTab = *   ;perform tab
   nop ;&&& check if tabstops are 8 or custom
   lda #chrTAB
   jmp putchar

ActLinefeed = *  ;perform linefeed/newline
   nop ;&&& check if chrCR should be used
   nop ;&&& check if top line needs to be saved
   lda #chrVT
   jmp putchar

ActNewline = *  ;perform newline
   lda #chrCR
   jmp putchar

ActCr = *    ;perform carriage return only
   lda #chrBOL
   jmp putchar

ActSetG1toGL = *  ;set G1 into GL
ActSetG0toGL = *  ;set G0 into GL
ActSetG2toGL = *  ;set G2 into GL
ActSetG3toGL = *  ;set G3 into GL
ActXon = *  ;enable keyboard-input transmission
ActXoff = *  ;disable keyboard-input transmission
ActRvsQuestion = *  ;display a reverse-question error indicator
ActTabSet = *  ;set tab stop
   nop  ;&&&
   rts

ActIndex = *  ;cursor down and scroll screen if necessary
   jmp escCursorDownScroll

ActRvsIndex = *  ;cursor up and scroll screen if necessary
   jmp escCursorUpScroll

escCursorHorizPos = *   ;ESC [col G
   lda escParmData+0
   sta escParmData+1
   jsr aceConGetpos
   sta escParmData+0
escCursorPos = *  ;ESC [ row ; col H    //   ESC [ row ; col f
   ;** get coordinates
   ldx #1
-  lda escParmData,x
   bne +
   lda #1
+  sec
   sbc #1
   cmp toolWinScroll+0,x
   bcc +
   lda toolWinScroll+0,x
   sbc #1
+  sta escParmData,x
   dex
   bpl -
   ;** determine if location is inside of current scroll window
   sec
   lda toolWinScroll+2
   sbc toolWinScroll+2
   sta work+0         ;start col of scroll window in full term window
   lda escParmData+0
   cmp work+0
   bcc +
   clc
   lda work+0
   adc toolWinScroll+0
   cmp escParmData+0
   beq +
   bcs ++
   ;** if not within window, make window full-screen--approximation of vt100
+  lda toolWinScroll+2
   ldx toolWinScroll+3
   sta toolWinScroll+2
   stx toolWinScroll+3
   sta syswork+0
   stx syswork+1
   lda toolWinScroll+0
   ldx toolWinScroll+1
   sta toolWinScroll+0
   stx toolWinScroll+1
   jsr aceWinSet
   lda #0
   sta work+0
   ;** if within window, move cursor
++ sec
   lda escParmData+0
   sbc work+0
   ldx escParmData+1
   jsr aceConPos
   jmp escFinish

escCursorUpScroll = *
escCursorUp = *   ;ESC [ count A   //   ESC M
   lda #$91
   escCursorRep = *
   sta escCursorChar
   lda escParmData+0
   bne .escCursorBra
   inc escParmData+0
.escCursorBra
   lda escCursorChar
   jsr aceConPutctrl
   dec escParmData+0
   bne .escCursorBra
   jmp escFinish
escCursorChar: !byte 0

escCursorDownScroll
escCursorDown = *  ;ESC [ count B  //   ESC D
   lda #$11
   jmp escCursorRep

escBlankspace = *   ;ESC [ count b
   lda #$20
   jmp escCursorRep
   
escCursorRight = *  ;ESC [ count C
   lda #$1d
   jmp escCursorRep

escCursorLeft = *  ;ESC [ count D
   lda #$9d
   jmp escCursorRep

escCursorSave = *  ;ESC 7
   sec
   lda toolWinScroll+2
   sbc toolWinScroll+2
   sta cursorSavePos+0
   jsr aceConGetpos
   sec ;sic
   adc cursorSavePos+0
   sta cursorSavePos+0
   inx
   stx cursorSavePos+1
   lda attribMode
   sta cursorSaveAttr
   lda charColor
   sta cursorSaveColor
   jmp escFinish

escCursorRestore = *  ;ESC 8
   lda cursorSaveAttr
   sta attribMode
   lda cursorSaveColor
   sta charColor
   jsr escAssertAttrib
   lda cursorSavePos+0
   ldx cursorSavePos+1
   sta escParmData+0
   stx escParmData+1
   jmp escCursorPos

escNewline = *  ;ESC E
   lda #13
   jsr putchar
   jmp escFinish

escEraseLine = *  ;ESC [ cmd K
   lda #$f1
   ldx escParmData+0
   beq +
   lda #$f0
   dec escParmData+0
   beq +
   lda #$f8
+  ldx #1
   stx escParmData
   jmp escCursorRep

escEraseScreen = *  ;ESC [ cmd J
   lda #$e0
   ldx escParmData+0
   beq +
   lda #$fe
   dec escParmData+0
   bne ++
+  ldx #1
   stx escParmData
   jmp escCursorRep
++ lda #$c0
   ldx #" "
   ldy toolWinPalette+0
   jsr aceWinCls
   jmp escFinish

escKeypadApp = *  ;ESC =
   lda #$ff
   sta keypadMode
   jmp escFinish

escKeypadNorm = *  ;ESC >
   lda #$00
   sta keypadMode
   jmp escFinish

escScrollRegion = *  ;ESC [ top bottom r
   lda escParmData+0
   beq +
   sec
   sbc #1
   cmp toolWinScroll+0
   bcc +
   lda toolWinScroll+0
   sbc #1
+  clc
   adc toolWinScroll+2
   sta syswork+0
   ldx toolWinScroll+3
   stx syswork+1
   lda escParmData+1
   bne +
   lda toolWinScroll+0
+  cmp toolWinScroll+0
   beq +
   bcc +
   lda toolWinScroll+0
+  clc
   adc toolWinScroll+2
   sec
   sbc syswork+0
   ldx toolWinScroll+1
   jsr aceWinSet
   jsr aceWinSize
   sta toolWinScroll+0
   stx toolWinScroll+1
   lda syswork+0
   ldx syswork+1
   sta toolWinScroll+2
   stx toolWinScroll+3
   jmp escFinish

scrollFlag !byte 0
escScrollViewUp = *     ;ESC [ n S
   lda #$e8
   sta scrollFlag       ;scroll Up
   jmp +
   
escScrollViewDown = *   ;ESC [ n T
   lda #$e4
   sta scrollFlag       ;scroll Down
+  lda #$20
   sta syswork+4        ;fill with <SP>
   lda #0
   sta syswork+6        ;fill attr.
   ldy toolWinPalette+0 ;bkgd. color
   ldx escParmData+0    ;rows
   bne +
   inx
+  lda scrollFlag
   jsr aceWinScroll
   jmp escFinish

escTabSet = *  ;ESC H
   nop
   jmp escFinish

escTabClear = *  ;ESC command g
   nop
   jmp escFinish

escInsertLine = *  ;ESC [ count L
   lda #$e9
   jmp escCursorRep

escDeleteLine = *  ;ESC [ count M
   lda #$e4
   jmp escCursorRep

escInsertChar = *  ;ESC [ count @
   lda #$94
   jmp escCursorRep

escDeleteChar = *  ;ESC [ count P
   lda #$08
   jmp escCursorRep

escAttrib = *  ;ESC [ mode m
   ldx #0
-  lda escParmData,x
   bne +
   ldy toolWinPalette+0
   sty charColor
   jmp +++
+  tay
   lda #$01
   cpy #1
   beq +
   lda #$20
   cpy #4
   beq +
   lda #$10
   cpy #5
   beq +
   lda #$40
   cpy #7
   beq +
   jsr escAttribExtra
   jmp .escAttribNext
+  ora attribMode
+++sta attribMode
.escAttribNext:
   inx
   cpx escParm
   bcc -
   jsr escAssertAttrib
   jmp escFinish

   escAttribExtra = *
   lda #$ff-$01
   cpy #22
   beq +
   cpy #21
   beq +
   lda #$ff-$20
   cpy #24
   beq +
   lda #$ff-$10
   cpy #25
   beq +
   lda #$ff-$40
   cpy #27
   bne ++
+  and attribMode
   sta attribMode
-  rts
++ cpy #30
   bcc -
   cpy #38
   bcs +
   tya
   sec
   sbc #30
   tay
   lda charColor
   and #$f0
   ora escAttribColors,y
   sta charColor
   rts
+  cpy #40
   bcc -
   cpy #48
   bcs -
   tya
   sec
   sbc #40
   tay
   lda escAttribColors,y
   asl
   asl
   asl
   asl
   sta work
   lda charColor
   and #$0f
   ora work
   sta charColor
   rts
escAttribColors : !byte $0,$8,$4,$d,$2,$a,$7,$e

   escAssertAttrib = *
   ldx #3
   lda attribMode
   and #$f0
   sec
   jsr aceConOption
   lda attribMode
   and #$01
   sta work
   ldx #2
   lda charColor
   eor work
   sec
   jmp aceConOption

escTermModeSet = *  ;ESC [ type h   //   ESC [ ? type h
   lda escParmData+0
   cmp #1
   bne +
   lda escQuesFlag
   +cmpASCII "?"
   bne +
   lda #$ff
   sta cursorMode
   jmp escFinish
+  cmp #3
   bne +
   lda #chrCLS
   jsr putchar
   jmp escFinish
+  jmp escFinish

escTermModeClear = *  ;ESC [ type l   //   ESC [ ? type l
   lda escParmData+0
   cmp #1
   bne +
   lda escQuesFlag
   +cmpASCII "?"
   bne +
   lda #$00
   sta cursorMode
   jmp escFinish
+  cmp #3
   bne +
   lda #chrCLS
   jsr putchar
   jmp escFinish
+  jmp escFinish

escEraseChar = *  ;ESC [ count X
   lda #<escEraseCharMsg
   ldy #>escEraseCharMsg
   jsr puts
   jmp escFinish
escEraseCharMsg: !pet "{erase_char}",0

escPrinterControl = *  ;ESC [ command i   //   ESC [ ? command i
   nop
   jmp escFinish

escDeviceStatus = *  ;ESC type n
   lda escParmData+0
   cmp #6
   beq +
   nop
   jmp escFinish
+  lda #$00
   sta work+1
   sta work+2
   sta work+3
   sec
   lda toolWinScroll+2
   sbc toolWinScroll+2
   sta work+0
   jsr aceConGetpos
   sec ;sic
   adc work+0
   sta work+0
   inx
   stx work+5
   ldx #2
   stx escDevLen
   jsr escDevPutnum
   ldx escDevLen
   +ldaSCII ";"
   sta escDevStatReply,x
   inc escDevLen
   lda work+5
   sta work+0
   jsr escDevPutnum
   ldx escDevLen
   lda #$52
   sta escDevStatReply,x
   inx
   lda #<escDevStatReply
   ldy #>escDevStatReply
   jsr modemSend
   jmp escFinish
escDevStatReply: !pet 27,"[24;80r",0,0,0   ;note: taken as ASCII
escDevLen: !byte 0

   escDevPutnum = * ;( [work+0]=num )
   clc
   lda #<escDevStatReply
   ldy #>escDevStatReply
   adc escDevLen
   bcc +
   iny
+  sta zp+0
   sty zp+1
   lda #1
   ldx #work+0
   jsr aceMiscUtoa
   tya
   clc
   adc escDevLen
   sta escDevLen
   rts

escDeviceAttr = *  ;ESC [ command c  //  ESC [ ? command c  //  ESC [ > cmd c
   lda escParmData+0
   cmp #0
   beq escDeviceId
   nop
   jmp escFinish

escDeviceId = *  ;ESC Z
   lda #<escDeviceIdMsg
   ldy #>escDeviceIdMsg
   ldx #7
   jsr modemSend
   jmp escFinish
escDeviceIdMsg: !pet 27,"[?1;2",$63,0

escSoftReset = *  ;ESC [ ! p
   nop
   jmp escFinish

escHardReset = *  ;ESC c
   jsr HotQ
   jmp escFinish

;******** standard library ********

eputs = *
   ldx #stderr
   jmp fputs
puts = *
   ldx #stdout
fputs = *
   sta zp+0
   sty zp+1
zpputs = *
   ldy #$ff
-  iny
   lda (zp),y
   bne -
   tya
   ldy #0
   jmp write

putchar = *
   ldx #stdout
putc = *
   sta putcBuffer
   lda #<putcBuffer
   ldy #>putcBuffer
   sta zp+0
   sty zp+1
   lda #1
   ldy #0
   jmp write
putcBuffer !byte 0

getchar = *
   ldx #stdin
getc = *
   lda #<getcBuffer
   ldy #>getcBuffer
   sta zp+0
   sty zp+1
   lda #1
   ldy #0
   jsr read
   beq +
   lda getcBuffer
   rts
+  sec
   rts
getcBuffer !byte 0

cls = *
   lda #chrCLS
   jmp putchar

getarg = *
   sty zp+1
   asl
   sta zp+0
   rol zp+1
   clc
   lda aceArgv+0
   adc zp+0
   sta zp+0
   lda aceArgv+1
   adc zp+1
   sta zp+1
   ldy #0
   lda (zp),y
   tax
   iny
   lda (zp),y
   stx zp+0
   sta zp+1
   ora zp+0
   rts

;===bss===

bss        = *
readbuf    = bss+0
bssEnd     = readbuf+readbufLenMax

;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2020 Brian Holdsworth                                    │
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