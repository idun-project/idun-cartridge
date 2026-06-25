;'sidplay' cmd: Simple PSIDv2 player
;
;Copyright© 2023 Brian Holdsworth
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
subTune     = $60  ;(4)
numTune     = $64  ;(4)
argnum      = $68  ;(1)
rsid        = $69  ;(1)

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
   ldx #$09
-  sta subTune,x
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
   ;load sidplay.lua module
   lda #0
   ldy #0
   jsr getarg
   ldx #0         ;load usr module "sidplay.lua"
   jsr usrcall
nextSid = *
   ;get next sid filename
   inc argnum
   ldy #0
   lda argnum
   jsr getarg
   bne +
   jmp exit
   ;load sid
+  ldx #2         ;sidplay.load(packed)
   jsr usrcall
   jsr mapstat
   bcs luaError
   lda #<procSidHdr
   ldy #>procSidHdr
   ldx zw
   jsr maprecv
   lda rsid
   beq +
   jsr playerRSID
   jmp nextSid
   ;process SID header
+  lda #0
   jsr statusUpdate
   ;get sid program
   ldx #1         ;sidplay.getsid()
   lda #0
   sta zw
   sta zw+1
   jsr usrcall
   jsr mapstat
   bcs luaError
   lda #<sidData
   ldy #>sidData
   jsr mapload
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
luaError = *
   lda errno
   clc
   adc #$30
   sta luaErrorCode
   lda #<luaCallErrorMsg
   ldy #>luaCallErrorMsg
   jsr eputs
   jmp exit
playerRSID = *
   lda #<playerFileErrorMsg
   ldy #>playerFileErrorMsg
   jsr eputs
   rts
playerFileErrorMsg !pet "Error",chrCR,0
luaCallErrorMsg !pet "Lua Error "
luaErrorCode !byte 0,0
luaStartMsg !pet "Relocating ",0
loadingMsg  !pet "Loading...",0
                   ;    |0123456789012345678901|
playingMsg1 !pet chrBOL,"Playing tune #xx",0
playingMsg2 !pet        " of yy",0
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

initTune:
   lda subTune
   musicInit = *+1
   jsr $7100   ;modified by procSidHdr to correct addr
   rts
stopPlayback:
   ;cancel interrupts
   jsr toolTmoCancel
   ;turn off SID oscillators
   lda #$00
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

procSidHdr = *    ;(: rsid=error code)
   ;copy full message to sidData
   lda #<sidData
   ldy #>sidData
   jsr aceTtyGet
   ;check first 4 bytes "PSID"
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
   sta rsid
   rts
   ;store player init and interrupt vector
+  lda sidData+$0a
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
   lda #0 ;no errors
   sta rsid
   rts

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
   bne +
   rts
+  ldy #0
   sty zw+1
-  lda (zp),y
   beq +
   iny 
   jmp -
+  sty zw
   lda zp+1
   rts
* = $7100
;this is where the SID file header/program loaded to...
sidData = *
;also temporary space for the long'ish instructions
playerUsageErrorMsg = *
;    |1234567890123456789012345678901234567890|
!pet "usage: sidplay <sidfile> <sidfile2>...",chrCR
!pet "<cursor> for next/prev tune, <space> for",chrCR
!pet "next sid, <stop> to quit",chrCR,0

;===the end===

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