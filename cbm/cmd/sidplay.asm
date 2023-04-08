;'sidplay' cmd: Simple PSIDv2 player
;
;Copyright© 2021 Brian Holdsworth
;
; This is free software, released under the MIT License.
;
; Simple PSIDv2 player that can coexist with the Idun kernel and shell. This relies
; on using an external Lua script and C prog to first relocate the SID file driver/data
; to page $71, and to use zero-page entries <$60. The relocation prevents any interference
; with Idun or this program.
;
; TODO: Support RSID files by exiting to a replayer program using `go64`.

!source "sys/acehead.asm"
!source "sys/toolhead.asm"
!source "sys/acemacro.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

;BE CAREFUL using zp variables with this tool. The loaded SID player
;routine can use zp $02-$5f, and Idun uses $70-$ff (leaving only $60-$6f).
luaFcb      = $60  ;(1)
sidSize     = $61  ;(2)
subTune     = $63  ;(4)
numTune     = $67  ;(4)
argnum      = $6b  ;(1)

musicIntr !byte 0,0
sidInfoBuf !fill 35,0
sidInfoBrk !pet chrCR,"by ",0
setSidInfo = *
   ;print tune name
   ldx #$16
   jsr setSidString
   lda #<sidInfoBrk
   ldy #>sidInfoBrk
   jsr puts
   ;print author and release info
   ldx #$36
   jsr setSidString
   lda #","
   jsr putchar
   ldx #$56
   jsr setSidString
   lda #chrCR
   jsr putchar
   rts
setSidString = *
   lda #<sidInfoBuf
   ldy #>sidInfoBuf
   sta zp
   sty zp+1
   ldy #0
-  lda sidData,x
   beq +++
   cmp #"@"
   bcc ++
   cmp #"Z"
   bcs +
   adc #$80
   jmp ++
+  sbc #$20
++ sta (zp),y
   inx
   iny
   cpy #32
   bne -
+++lda #0
   sta (zp),y
   ldx #stdout
   jmp zpputs

main = *
   lda #0
   ldx #$0b
-  sta luaFcb,x
   dex
   bpl -
   ;check for at least one arg
   lda aceArgc
   cmp #2
   bcs +
   beq +
   jmp playerUsageError
   ;init hotkeys
+  jsr initHotkeys
nextSid = *
   ;get next sid filename
   inc argnum
   ldy #0
   lda argnum
   jsr getarg
   bne +
   jmp exit
   ; prepare Lua command to relocate/load SID
+  ldx #255
-  inx
   lda luaLaunchPrefix,x
   sta sidData,x
   bne -
   ldy #255
-  iny
   lda (zp),y
   sta sidData,x
   beq +
   inx
   jmp -
   ; launch Lua
+  lda #<sidData
   ldy #>sidData
   sta zp+0
   sty zp+1
   +ldaSCII "w"
   jsr open
   bcc +
   jmp playerLuaError
   ; wait for Lua
+  sta luaFcb
   jsr waitForReady
   bne +
   jmp playerLuaError
   ; request SID header
+  lda #"H"
   jsr sendRequest
   bcc +
   jmp playerLuaError
   ;process SID header
+  lda #0
   jsr statusUpdate
   jsr procSidHdr
   bne +
   jsr playerRSID
   lda luaFcb
   jsr close
   jmp nextSid
   ;load SID program
+  jsr waitForReady
   lda #"P"
   jsr sendRequest
   bcc +
   jmp playerLuaError
+  lda #1
   jsr statusUpdate
   jsr procSidProg
   bne +
   jsr playerRSID
   lda luaFcb
   jsr close
   jmp nextSid
   ; sid loaded
+  jsr waitForReady
   lda #"Q"    ;send Quit
   jsr sendRequest
   jsr waitForReady
   lda luaFcb
   jsr close
   ;initialize SID player
   lda #2
   jsr statusUpdate
   jsr initTune
-  lda musicIntr+0
   ldy musicIntr+1
   ldx #1
   jsr toolTmoJifs
   jsr aceConKeyAvail
   bcs -
   jsr aceConGetkey
   cmp #$20
   bne +
   jsr stopPlayback    ;<space> = load next sid
   jmp nextSid
+  jsr toolKeysHandler
   jmp -
luaLaunchPrefix !pet "l:sidplay.lua ",0
luaStartMsg !pet "Relocating ",0
loadingMsg  !pet "Loading...",0
                   ;    |0123456789012345678901|
playingMsg1 !pet chrBOL,"Playing tune #xx",0
playingMsg2 !pet        " of yy",0
luaResultOk !byte 0,0
statusUpdate = *
   bne +
   lda #<luaStartMsg
   ldy #>luaStartMsg
   jsr puts
   jmp +++
+  cmp #1
   bne ++
   lda #<loadingMsg
   ldy #>loadingMsg
   jmp puts
++ lda #<(playingMsg1+15)
   ldy #>(playingMsg1+15)
   sta zp+0
   sty zp+1
   inc subTune
   ldx #subTune
   lda #2
   jsr aceMiscUtoa
   dec subTune
   lda #<(playingMsg2+4)
   ldy #>(playingMsg2+4)
   sta zp+0
   sty zp+1
   ldx #numTune
   lda #2
   jsr aceMiscUtoa
   lda #<playingMsg1
   ldy #>playingMsg1
   jsr puts
   lda #<playingMsg2
   ldy #>playingMsg2
   jmp puts
+++lda argnum
   ldy #0
   jsr getarg
   ldx #stdout
   jsr zpputs
   lda #chrCR
   jmp putchar

playerRSID = *
   lda #<playerFileErrorMsg
   ldy #>playerFileErrorMsg
   jsr eputs
   rts
playerFileErrorMsg !pet "Error",chrCR,0
playerLuaError = *
   lda #<playerLuaErrorMsg
   ldy #>playerLuaErrorMsg
   jsr eputs
   jmp exit
playerLuaErrorMsg !pet "Error: Lua script",chrCR,0
initTune:
   lda subTune
   musicInit = *+1
   jsr $7100   ;modified by procSidHdr to correct addr
   rts
stopPlayback:
   ;cancel interrupts
   jsr toolTmoCancel
   ;close file
   lda luaFcb
   beq +
   jsr close
   ;turn off SID oscillators
+  lda #$00
   sta $d400
   sta $d401
   sta $d407
   sta $d408
   sta $d40e
   sta $d40f
   ;terminate last status text
   lda #chrCR
   jmp putchar
exit:
   jsr stopPlayback
   ;cancel hotkeys
   jsr termHotkeys
   ;terminate the process
   ldx #0
   lda #0
   jmp aceProcExit
playerUsageError = *
   lda #<playerUsageErrorMsg
   ldy #>playerUsageErrorMsg
   jmp eputs

initHotkeys = *
   ldx #<exit
   ldy #>exit
   lda #HotkeyStop
   jsr toolKeysSet
   ldx #<playNext
   ldy #>playNext
   lda #HotkeyRight
   jsr toolKeysSet
   ldx #<playPrev
   ldy #>playPrev
   lda #HotkeyLeft
   jsr toolKeysSet
   rts

termHotkeys = *
   lda #HotkeyStop
   jsr toolKeysRemove
   lda #HotkeyRight
   jsr toolKeysRemove
   lda #HotkeyLeft
   jsr toolKeysRemove
   rts

playNext = *
   inc subTune
   lda subTune
   cmp numTune
   bne +
   lda #0
   sta subTune
+  jsr initTune
   lda #2
   jmp statusUpdate

playPrev = *
   dec subTune
   bpl +
   inc subTune
+  jsr initTune
   lda #2
   jmp statusUpdate

waitForReady = *  ;(: .Z=error)
   ;wait for `READY` or `ERR ec` response
   lda #<luaMsgBuf
   ldy #>luaMsgBuf
   ldx #5
   jsr aceTtyGet
   lda luaMsgBuf+0
   cmp #"E"
   rts

sendRequest = *
   sta luaMsgBuf+0
   lda #$0a
   sta luaMsgBuf+1
   ldx #2
   lda #<luaMsgBuf
   ldy #>luaMsgBuf
   jmp aceTtyPut

procSidHdr = *    ;(: .Z=error)
   ;check first 4 bytes "PSID"
   lda #<sidData
   ldy #>sidData
   ldx #5
   jsr aceTtyGet
   lda sidData+0
   cmp #"P"
   bne errSidHdr
   lda sidData+1
   cmp #"S"
   bne errSidHdr
   lda sidData+2
   cmp #"I"
   bne errSidHdr
   lda sidData+3
   cmp #"D"
   beq +
   errSidHdr = *
   lda #0
   rts
   ;retrieve rest of SID header
+  lda #<(sidData+5)
   ldy #>(sidData+5)
   ldx #$79
   jsr aceTtyGet
   ;store player init and interrupt vector
   lda sidData+$0a
   ldy sidData+$0b
   sta musicInit+1
   sty musicInit+0
   lda sidData+$0c
   ldy sidData+$0d
   sta musicIntr+1
   sty musicIntr+0
   ;store number of sub-tune
   lda sidData+$0f
   sta numTune
   lda #0
   sta subTune
   ;store SID file text
   jsr setSidInfo
   lda #1 ;no errors
   rts

procSidProg = *   ;(: .Z=error)
   ;check first 3-bytes not "ERR"
   lda #<(sidData-2)
   ldy #>(sidData-2)
   ldx #5
   jsr aceTtyGet
   lda sidData-2
   cmp #"E"
   bne +
   lda sidData-1
   cmp #"R"
   bne +
   lda sidData+0
   cmp #"R"
   bne +
   rts
   ;first two bytes is the size
+  lda sidData-2
   sec
   sbc #3
   sta sidSize+0
   lda sidData-1
   sbc #0
   sta sidSize+1
   ;check size not too large
   clc
   adc #$71
   cmp #$bf
   bcc +
   lda #0   ;too big
   rts
+  lda #<(sidData+3)
   ldy #>(sidData+3)
   sta loadDest+0
   sty loadDest+1
   contLoad = *
   lda loadDest+0
   ldy loadDest+1
   ldx #0
   cpx sidSize+1
   beq finishLoad
   jsr aceTtyGet
   inc loadDest+1
   dec sidSize+1
   jmp contLoad
   finishLoad = *
   ldx sidSize+0
   beq +
   jsr aceTtyGet
+  lda #1   ;no errors
   rts
loadDest !byte 0,0

;******** standard library ********
eputs = *
   ldx #stderr
   jmp fputs
puts = *
   ldx #stdout
fputs = *
   sta zp
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
   sta zp
   sty zp+1
   lda #1
   ldy #0
   jmp write
putcBuffer !byte 0

getarg = *
   sty zp+1
   asl
   rol zp+1
   clc
   adc aceArgv+0
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
   rts
;this is a 5-byte buffer used for messaging with the Lua script
* = $70fb
luaMsgBuf = *
* = $7100
;this is where the SID file header/program loaded to...
sidData = *
;also temporary space for the long'ish instructions
playerUsageErrorMsg = *
;    |1234567890123456789012345678901234567890|
!pet "usage: sidplay <sidfile> [sid2..sidN]",chrCR
!pet "<cursor> for next/prev tune, <space> for",chrCR
!pet "next sid, <stop> to quit",chrCR,0

;===the end===

;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2021 Brian Holdsworth                                    │
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