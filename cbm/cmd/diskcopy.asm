;'diskcopy' cmd: copy native disks <-> disk images
;
;Copyright© 2021 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Source and destination devices can include a native
; IEC disk device (1541/1571) and/or a virtual device
; with a compatible disk image mounted (usually d:).
;
;@see copyUsageErrorMsg

!source "sys/acehead.asm"
!source "sys/acemacro.asm"
!source "sys/toolhead.asm"
* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

;*** global declarations

kernelReadst   = $ffb7
kernelSetlfs   = $ffba
kernelSetnam   = $ffbd
kernelOpen     = $ffc0
kernelClose    = $ffc3
kernelChkin    = $ffc6
kernelChkout   = $ffc9
kernelClrchn   = $ffcc
kernelChrin    = $ffcf
kernelChrout   = $ffd2
;kernelCloseAll = $ff4a
kernelClAll    = $ffe7

cmdlf            = 66
datalf           = 76
diraccChan       = 2
chrQuote         = $22
formatDestFlag   !byte 0

curSectorPtr     = 2 ;(2)
copyArg          = 4 ;(2)
lastArg          = 6 ;(2)
baseArg          = 8 ;(1)
writeDevice      = 9 ;(1)
writeIecAddr     = 10;(1)
readDevice       = 11;(1)
readIecAddr      = 12;(1)
destMaxTracks    = 13;(1)
srcTracks        = 14;(1)
currentTrack     = 15;(4)
blocksInTrack    = 19;(1)
sectorCount      = 20;(4)
abortFlag        = 24;(1)

blocksPerTrack !byte 21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,19,19,19,19,19,19,19,18,18,18,18,18,18,17,17,17,17,17
!byte 21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,19,19,19,19,19,19,19,18,18,18,18,18,18,17,17,17,17,17

diraccName !pet "#0"

copyUsageErrorMsg = *
;    |1234567890123456789012345678901234567890|
!pet "usage: diskcopy [/f] <src:> <dest:>",chrCR
!pet "Ex. make floppy from disk image",chrCR
!pet "    mount /d: myimage.d71",chrCR
!pet "    diskcopy d: a:",chrCR
!pet "Ex. make disk image from floppy",chrCR
!pet "    mount /w /d: newimage.d64",chrCR
!pet "    diskcopy a: d:",chrCR
!pet "Option /f formats destination device",chrCR,0

;===diskcopy===
main = *
   lda #0
   sta formatDestFlag
   sta currentTrack+0
   sta currentTrack+1
   sta currentTrack+2
   sta currentTrack+3
   sta sectorCount+0
   sta sectorCount+1
   sta sectorCount+2
   sta sectorCount+3
   sta readIecAddr
   sta writeIecAddr
   sta abortFlag
   lda #70
   sta destMaxTracks
   sta srcTracks
   ;** check for at least two arguments
   lda aceArgc+1
   bne +
   lda aceArgc
   cmp #2
   bcs +
   beq +
   jmp copyUsageError
   ;** check for first argument option
+  lda #1
   sta baseArg
   ldy #0
   jsr getarg
   ldy #0
   lda (zp),y
   cmp #"/"
   bne ++
   iny
   lda (zp),y
   +cmpASCII "f"
   beq +
   jmp copyUsageError
+  lda #$ff
   sta formatDestFlag
   inc baseArg
   ;** check destination device
++ jsr getLastArg
   jsr aceDirIsdir
   cpx #0
   bne +
   jmp copyUsageError   ;dest is not a disk
+  jsr aceMiscDeviceInfo
   cpx #1
   bne ++
   sta writeIecAddr
   tax
   jsr initIec
   bne +
   jmp initDestError
+  bcs +
   lda #35
   sta destMaxTracks
+  ldx writeIecAddr
   jsr checkFormatIec
   bne +++
   lda #$ff
   sta formatDestFlag
   jmp +++
++ cpx #7
   bne copyUsageError   ;dest not native or virtual drive
   lda syswork+1
   lsr
   lsr
   ora #$40
   sta writeDevice
   tax
   jsr checkFormatVirt
   beq openDestError
   bcs +++
   lda #35
   sta destMaxTracks
   ;** check source device
+++lda baseArg
   ldy #0
   jsr getarg
   jsr aceDirIsdir
   cpx #0
   beq copyUsageError   ;src is not a disk
   jsr aceMiscDeviceInfo
   cpx #1
   bne +
   sta readIecAddr
   tax
   jsr blockOpenIec
   bcs openSrcError
   ldx readIecAddr
   jsr checkFormatIec
   beq openSrcError
   bcs ++
   lda #35
   sta srcTracks
   jmp ++
+  cpx #7
   bne copyUsageError  ;src not native or virtual drive
   lda syswork+1
   lsr
   lsr
   ora #$40
   sta readDevice
   tax
   jsr checkFormatVirt
   beq openSrcError
   bcs ++
   lda #35
   sta srcTracks
++ lda destMaxTracks
   cmp srcTracks
   bmi initDestError   ;cannot copy double-sided format to single-sided destination
   jmp diskCopy
   copyUsageError = *
   lda #<copyUsageErrorMsg
   ldy #>copyUsageErrorMsg
-  ldx #stderr
   jsr fputs
   jmp blockCloseIec
   initDestError = *
   lda #<destCompatErrorMsg
   ldy #>destCompatErrorMsg
   jmp -
   openDestError = *
   lda #<destOpenErrorMsg
   ldy #>destOpenErrorMsg
   jmp -
   openSrcError = *
   lda #<srcOpenErrorMsg
   ldy #>srcOpenErrorMsg
   jmp -
destCompatErrorMsg !pet "Error: Incompatible destination device",chrCR,0
destOpenErrorMsg !pet "Error: Destination device not writable",chrCR,0
srcOpenErrorMsg !pet "Error: Source device not readable",chrCR,0

   diskCopy = *
   ;progress display cols for 40-col mode
   lda toolWinRegion+1
   jsr progressSetColumns
   ;clear cmd buffer
   lda #0
   ldx #32
-  dex
   sta cmdBuffer,x
   bne -
   ;format the destination?
   lda writeIecAddr
   beq ++
   jsr askFormatDest
   bne ++
   bcc +
   jmp blockCloseIec
+  ;do format
   ldx writeIecAddr
   jsr formatIec
   bcc ++
   jmp exit
   ;print #tracks to copy
++ lda srcTracks
   sta currentTrack
   ldx #currentTrack
   jsr Utoa
   ldy #0
   lda (zp),y
   sta srcdstMsg1+0
   iny
   lda (zp),y
   sta srcdstMsg1+1
   lda #<srcdstMsg
   ldy #>srcdstMsg
   jsr puts
   diskCopyStart = *
   lda readIecAddr
   beq +
   jmp ++
   ;diskcopy virtual->native
+  ldx writeIecAddr
   jsr blockOpenIec
   bcs exit
   lda #1
   sta currentTrack
   jsr aceConGetpos
   sec
   sbc #3
   sta _node+1
   sta _node4+1
   jsr showProgress
-  lda srcTracks
   cmp currentTrack
   bmi diskCopyEnd
   jsr trackReadVirtual
   bcs exit
   lda abortFlag
   bmi diskCopyEnd
   jsr trackWriteIec
   bcs exit
   lda abortFlag
   bmi diskCopyEnd
   inc currentTrack
   jmp -
   ;diskcopy native->virtual
++ lda #1
   sta currentTrack
   jsr aceConGetpos
   sec
   sbc #3
   sta _node+1
   sta _node4+1
   jsr showProgress
-  lda srcTracks
   cmp currentTrack
   bmi diskCopyEnd
   jsr trackReadIec
   bcs exit
   lda abortFlag
   bmi diskCopyEnd
   jsr trackWriteVirtual
   bcs exit
   lda abortFlag
   bmi diskCopyEnd
   inc currentTrack
   jmp -
   diskCopyEnd = *
   jsr toolUserLayoutEnd
   jsr checkDiskStatus
   jsr blockCloseIec
   lda #<cmdBuffer
   ldy #>cmdBuffer
   jmp puts
exit = *
   jsr toolUserLayoutEnd
   sta errorMsg1+7
   jsr blockCloseIec
   lda #<errorMsg1
   ldy #>errorMsg1
   jsr eputs
   lda #<cmdBuffer
   ldy #>cmdBuffer
   jsr eputs
   lda #chrCR
   jmp putchar
errorMsg1 !pet "Error: ",0,chrCR,0
srcdstMsg      !pet "Copying "
srcdstMsg1     !pet "xx tracks."
srcdstMsgLns   !byte chrCR,chrCR,chrCR,chrCR,chrCR,0

progressSetColumns = *
   cmp #80
   beq +
   lda #<showProgress40
   ldy #>showProgress40
   sta showProgress+1
   sty showProgress+2
   lda #<updateReading40
   ldy #>updateReading40
   sta showProgress+4
   sty showProgress+5
   lda #<updateWriting40
   ldy #>updateWriting40
   sta showProgress+7
   sty showProgress+8
   lda #<updateStopped40
   ldy #>updateStopped40
   sta showProgress+10
   sty showProgress+11
   lda #<updateProgress40
   ldy #>updateProgress40
   sta showProgress+13
   sty showProgress+14
+  rts
showProgress = *
   jmp showProgress80
   jmp updateReading80
   jmp updateWriting80
   jmp updateStopped80
   jmp updateProgress80
updateReading = showProgress+3
updateWriting = showProgress+6
updateStopped = showProgress+9
updateProgress = showProgress+12

showProgress80 = *
   +toolUserIntfCol ~iprogress, 70
   lda #$80
   sta toolUserStyles   ;border on
   jsr toolUserNode
_node !byte 0,0
   lda #2      ; text color
   sta toolUserColor
   jsr toolUserLabel
rw_status   !pet "Reading Track #xx Sector #yy                                          ",0
   jsr toolUserLabel
progress    !fill 70,$20
            !byte 0
   jsr toolUserEnd
   inc iprogress
   rts
showProgress40 = *
   +toolUserIntfCol ~iprogress4, 35
   lda #$80
   sta toolUserStyles   ;border on
   jsr toolUserNode
_node4 !byte 0,0
   lda #2      ; text color
   sta toolUserColor
   jsr toolUserLabel
rw_status4   !pet "Reading Track #xx Sector #yy       ",0
   jsr toolUserLabel
progress4    !fill 35,$20
            !byte 0
   jsr toolUserEnd
   inc iprogress4
   rts
updateReading80 = *
   ldx #0
-  lda readingTxt,x
   sta rw_status,x
   inx
   cpx #7
   bne -
   dec iprogress
   rts
updateReading40 = *
   ldx #0
-  lda readingTxt,x
   sta rw_status4,x
   inx
   cpx #7
   bne -
   dec iprogress4
   rts
readingTxt !pet "Reading"
updateWriting80 = *
   ldx #0
-  lda writingTxt,x
   sta rw_status,x
   inx
   cpx #7
   bne -
   dec iprogress
   rts
updateWriting40 = *
   ldx #0
-  lda writingTxt,x
   sta rw_status4,x
   inx
   cpx #7
   bne -
   dec iprogress4
   rts
writingTxt !pet "Writing"
updateStopped80 = *
   ldx #0
-  lda stoppedTxt,x
   sta rw_status,x
   inx
   cpx #7
   bne -
   dec iprogress
   rts
updateStopped40 = *
   ldx #0
-  lda stoppedTxt,x
   sta rw_status4,x
   inx
   cpx #7
   bne -
   dec iprogress4
   rts
stoppedTxt !pet "Stopped"
lastUpdateTrk !byte 0
updateProgress80 = *
   lda currentTrack
   cmp lastUpdateTrk
   beq ++
   ;update track # display
   sta lastUpdateTrk
   ldx #currentTrack
   lda #2
   jsr Utoa
   ldy #0
   ldx #15
   lda (zp),y
   sta rw_status,x
   iny
   inx
   lda (zp),y
   sta rw_status,x
   ;update progress bar
   lda currentTrack
   ldx destMaxTracks
   cpx #70
   beq +
   asl
+  tay
   dey
   lda #$9a
   sta progress,y
   dey
   bmi ++
   sta progress,y
++ ldx #sectorCount
   lda #2
   jsr Utoa
   ldy #0
   ldx #26
   lda (zp),y
   sta rw_status,x
   iny
   inx
   lda (zp),y
   sta rw_status,x
   dec iprogress
   rts
updateProgress40 = *
   lda currentTrack
   cmp lastUpdateTrk
   beq ++
   ;update track # display
   sta lastUpdateTrk
   ldx #currentTrack
   lda #2
   jsr Utoa
   ldy #0
   ldx #15
   lda (zp),y
   sta rw_status4,x
   iny
   inx
   lda (zp),y
   sta rw_status4,x
   ;update progress bar
   lda currentTrack
   ldx destMaxTracks
   cpx #35
   beq +
   lsr
+  tay
   dey
   lda #$9a
   sta progress4,y
   dey
   bmi ++
   sta progress4,y
++ ldx #sectorCount
   lda #2
   jsr Utoa
   ldy #0
   ldx #26
   lda (zp),y
   sta rw_status4,x
   iny
   inx
   lda (zp),y
   sta rw_status4,x
   dec iprogress4
   rts

initIec = *  ;(.X=IEC device) : .ZS=error .CS=70trk, .CC=35 trk
   txa
   pha
   jsr kernelClAll
   ;send U9 to reset drive
   pla
   tax
   jsr cmdchOpen
   bcs ++
   +ldaSCII "u"
   sta cmdBuffer
   +ldaSCII "9"
   sta cmdBuffer+1
   ldx #2
   jsr cmdchSend
   bcs ++
   jsr checkDiskStatus
   jsr cmdchClose
   ;scan for drive model
   ldy #0
-  lda cmdBuffer,y
   cmp #chrCR
   beq +
   iny
   jmp -
+  tya
   sec 
   sbc #8
   tay
   lda cmdBuffer,y
   +cmpASCII "7"  ;1570/71
   bne +
   sec
   lda #1
   rts
+  +cmpASCII "4"  ;1540/41
   bne ++         ;other drives (1581?) unsupported
   clc
   lda #1
   rts
++ lda #0
   rts

checkFormatIec = *    ;(.X=IEC device) : .ZS=no format, .CS=70trk, .CC=35trk
   lda #18
   sta currentTrack
   lda #0
   sta sectorCount
   jsr formatCurrTrkSec
   jsr setCmdBRead
   jsr cmdchSend
   bcs ++
   ldx #datalf
   jsr kernelChkin
   bcs ++
   ldy #0
-  jsr kernelChrin
   bcs ++
   cpy #2
   bne +
   cmp #$41
   bne ++
+  cpy #3
   bne +
   ora #1
   asl
   rts
+  iny
   jmp -
++ lda #0
   rts

checkFormatVirt = *    ;(.X=IEC device) : .ZS=no format, .CS=70trk, .CC=35trk
   +ldaSCII "r"
   jsr blockOpenVirt
   bcc +
   lda #0
   rts
+  tax
   stx readVirtFcb
   lda #<trackBuffer
   ldy #>trackBuffer
   sta zp+0
   sty zp+1
   lda #1
   jsr aceDirectRead
   lda readVirtFcb
   jsr close
   ldy #2
   lda (zp),y
   cmp #$41
   bne ++
   iny
   lda (zp),y
   ora #1
   asl
   rts
++ lda #0
   rts

formatDevice !byte 0
formatIec = *    ;(.X=IEC device)
   stx formatDevice
   jsr cmdchOpen
   bcc +
   rts
+  ldx #0
-  lda cmdBFormat,x
   sta cmdBuffer,x
   inx
   cmp #chrCR
   bne -
   jsr cmdchSend
   bcc +
   rts
+ jmp cmdchClose
cmdBFormat   !pet "n0:blank,2d",chrCR

formatDevName !byte 0,0
askFormatDest = *  ;(.A=IEC addr) : .CS=quit, .EQ=yes, .NE=no
   clc
   adc #$30
   sta formatDevName+0
   lda formatDestFlag
   bmi +
   lda #0
   rts
   formatAskCont = *
+  lda #<formatAskMsg
   ldy #>formatAskMsg
   jsr puts
   lda #<formatDevName
   ldy #>formatDevName
   jsr puts
   lda #<formatAskMsg2
   ldy #>formatAskMsg2
   jsr puts
   jsr getchar
   cmp #chrCR
   beq formatAskCont
   pha
-  jsr getchar
   cmp #chrCR
   bne -
   pla
   +cmpASCII "q"
   bne +
-  sec
   rts
+  +cmpASCII "Q"
   beq -
   +cmpASCII "y"
   beq +
   +cmpASCII "Y"
+  clc
   rts
   formatAskMsg = *
   !pet "Format disk in drive #",0
   formatAskMsg2 = *
   !pet " (y/n/q)? ",0

checkstop = *
   lda abortFlag
   bpl +
   rts
+  jsr aceConStopkey
   bcs +
   rts
+  jsr updateStopped
   lda #$ff
   sta abortFlag
   rts

copyToDestStatus = *
   rts

openIecDevice !byte 0
blockOpenIec = * ;( .X=IEC device) : .CS=error
   stx openIecDevice
   clc
   ;open data channel
   lda #2
   ldx #<diraccName
   ldy #>diraccName
   jsr kernelSetnam
   ldy #diraccChan
   lda #datalf
   ldx openIecDevice
   jsr kernelSetlfs
   jsr kernelOpen
   bcc +
   sta errno
   rts
   ;open command channel (#15)
+  ldx openIecDevice
   jsr cmdchOpen
   bcc +
   sta errno
+  rts

blockOpenVirt = *  ;(.X=dev, .A=mode) : .CS=error .A=Fcb
   stx cmdVPrefix
   ldx #<cmdVPrefix
   ldy #>cmdVPrefix
   stx zp+0
   sty zp+1
   jmp open
cmdVPrefix !pet "d:#"
cmdVCurrTrkSec  !byte $31,$38,$20,$30,$20,$00

trackReadIec = *  ;(currentTrack, trackBuffer) : .CS=error
   jsr updateReading
   lda currentTrack
   tax
   dex
   lda blocksPerTrack,x
   sta blocksInTrack
   lda #<trackBuffer
   ldy #>trackBuffer
   sta curSectorPtr+0
   sty curSectorPtr+1
   lda #0
   sta sectorCount
-- cmp blocksInTrack
   clc
   beq ++
   jsr updateProgress
   jsr checkstop
   jsr formatCurrTrkSec
   jsr setCmdBRead
   jsr cmdchSend
   bcs +
   ldx #datalf
   jsr kernelChkin
   bcs +
   ldy #0
-  jsr kernelChrin
   sta (curSectorPtr),y
   iny
   bne -
   inc curSectorPtr+1
   inc sectorCount
   lda sectorCount
   jmp --
++ rts
   setCmdBRead = *
   ldx #0
-  lda cmdBReadPrefix,x
   sta cmdBuffer,x
   inx
   cpx #7
   bne -
   ldy #0
-  lda cmdBCurrTrkSec,y
   sta cmdBuffer,x
   inx
   iny
   cmp #chrCR
   bne -
   rts
cmdBReadPrefix   !pet "u1:",diraccChan+$30,$20,$30,$20

readVirtFcb !byte 0
trackReadVirtual = *  ;(currentTrack, trackBuffer) : .CS=error
   jsr updateReading
   lda #2
   ldx #currentTrack
   jsr Utoa
   ldy #0
   lda (zp),y
   sta cmdVCurrTrkSec+0
   iny
   lda (zp),y
   sta cmdVCurrTrkSec+1
   +ldaSCII "r"
   ldx readDevice
   jsr blockOpenVirt
   bcc +
   rts
+  sta readVirtFcb
   ldx currentTrack
   dex
   lda blocksPerTrack,x
   sta blocksInTrack
   lda #<trackBuffer
   ldy #>trackBuffer
   sta curSectorPtr+0
   sty curSectorPtr+1
   lda #0
   sta sectorCount
-  jsr updateProgress
   jsr checkstop
   lda curSectorPtr+0
   ldy curSectorPtr+1
   sta zp+0
   sty zp+1
   ldx readVirtFcb
   lda #1
   jsr aceDirectRead
   inc curSectorPtr+1
   inc sectorCount
   dec blocksInTrack
   bne -
   lda readVirtFcb
   jmp close

trackWriteIec = *  ;(currentTrack, trackBuffer) : .CS=error
   jsr updateWriting
   lda currentTrack
   tax
   dex
   lda blocksPerTrack,x
   sta blocksInTrack
   lda #<trackBuffer
   ldy #>trackBuffer
   sta curSectorPtr+0
   sty curSectorPtr+1
   lda #0
   sta sectorCount
   jsr setCmdBReset
   jsr cmdchSend
   bcs +
-- jsr updateProgress
   jsr checkstop
   ldx #datalf
   jsr kernelChkout
   ldy #0
-  lda (curSectorPtr),y
   jsr kernelChrout
   bcs +
   iny
   bne -
   jsr doCmdWriteBuffer
   bne +
   inc curSectorPtr+1
   inc sectorCount
   dec blocksInTrack
   bne --
   clc
   rts
+  sta errno
   rts
   formatCurrTrkSec = *
   ldx #currentTrack
   jsr Utoa
   ldy #0
   lda (zp),y
   sta cmdBCurrTrkSec+0
   iny
   lda (zp),y
   sta cmdBCurrTrkSec+1
   ldx #sectorCount
   jsr Utoa
   ldy #0
   lda (zp),y
   sta cmdBCurrTrkSec+3
   iny
   lda (zp),y
   sta cmdBCurrTrkSec+4
   rts
   setCmdBReset = *
   ldx #0
-  lda cmdBReset,x
   sta cmdBuffer,x
   inx
   cmp #chrCR
   bne -
   rts
   doCmdWriteBuffer = *
   ;seek to current T/S
   lda currentTrack
   sta cmdBSeekTS+0
   lda sectorCount
   sta cmdBSeekTS+1
   ldx #0
-  lda cmdBSeekPrefix,x
   sta cmdBuffer,x
   inx
   cmp #chrCR
   bne -
   jsr cmdchSend
   lda #$b0
   sta cmdBJob
   jsr cmdchJobSend
   jsr waitDiskCmd
   beq +
   jmp cmdchErr
   ;write buffer job
+  lda #$90
   sta cmdBJob
   jsr cmdchJobSend
   waitDiskCmd = *
   ;wait for job complete
-  jsr checkJobStatus
   bit job_status_val
   bmi -
   lda job_status_val
   cmp #1
   rts
cmdBCurrTrkSec    !byte $20,$20,$20,$20,$20,chrCR
cmdBReset         !pet "b-p:",diraccChan+$30,$20,$30,chrCR
cmdBSeekPrefix    !pet "m-w",6,0,2
cmdBSeekTS        !byte 0,0,chrCR
cmdBJobPrefix     !pet "m-w",0,0,1
cmdBJob           !byte 1,chrCR
cmdBPollJob       !pet "m-r",0,0,chrCR

writeVirtFcb !byte 0
trackWriteVirtual = *  ;(currentTrack, trackBuffer) : .CS=error
   jsr updateWriting
   lda #2
   ldx #currentTrack
   jsr Utoa
   ldy #0
   lda (zp),y
   sta cmdVCurrTrkSec+0
   iny
   lda (zp),y
   sta cmdVCurrTrkSec+1
   +ldaSCII "w"
   ldx writeDevice
   jsr blockOpenVirt
   bcc +
   rts
+  sta writeVirtFcb
   ldx currentTrack
   dex
   lda blocksPerTrack,x
   sta blocksInTrack
   lda #<trackBuffer
   ldy #>trackBuffer
   sta curSectorPtr+0
   sty curSectorPtr+1
   lda #0
   sta sectorCount
-  jsr updateProgress
   jsr checkstop
   lda curSectorPtr+0
   ldy curSectorPtr+1
   sta zp+0
   sty zp+1
   ldx writeVirtFcb
   lda #1
   jsr aceDirectWrite
   inc curSectorPtr+1
   inc sectorCount
   dec blocksInTrack
   bne -
   lda writeVirtFcb
   jmp close

cmdchJobSend = *
   ldx #0
-  lda cmdBJobPrefix,x
   sta cmdBuffer,x
   inx
   cmp #chrCR
   bne -
   jmp cmdchSend

blockCloseIec = *
   jsr cmdchClose
   bcc +
   sta errno
   rts
+  lda #datalf
   jsr kernelClose
   bcc +
   sta errno
+  rts

;*** IEC device command channel access
cmdchOpen = *  ;( .X=IEC device )
   clc
   lda #0
   jsr kernelSetnam
   ldy #15
   lda #cmdlf
   jsr kernelSetlfs
   jsr kernelOpen
   bcc +
   sta errno
+  rts

cmdchClose = *
   lda #cmdlf
   jsr kernelClose
   bcc +
   sta errno
+  rts

cmdchErr = *
   sta errno
   pha
   jsr kernelClrchn
   pla
   sec
   rts

sendCounter !byte 0
cmdchSend = *  ;(.X=cmd.len. cmdBuffer )
   stx sendCounter
   ldx #cmdlf
   jsr kernelChkout
   bcs cmdchErr
   ldx #0
-  lda cmdBuffer,x
   jsr kernelChrout
   bcs cmdchErr
   inx
   cpx sendCounter
   bmi -
   jsr kernelClrchn
   clc
   rts
cmdBuffer !fill 32,0

checkDiskStatus = *     ;() : .CS/errno=error, .A=code, cmdBuffer=message
   ldx #cmdlf
   jsr kernelChkin
   bcs cmdchErr
   jsr kernelChrin
   bcs cmdchErr
   and #$0f
   sta checkDiskStatusCode
   asl
   asl
   adc checkDiskStatusCode
   asl
   sta checkDiskStatusCode
   jsr kernelChrin
   bcs cmdchErr
   and #$0f
   clc
   adc checkDiskStatusCode
   sta checkDiskStatusCode
   ldy #0
-  jsr kernelReadst
   and #$40
   bne ++
   jsr kernelChrin
   bcs cmdchErr
   sta cmdBuffer,y
   iny
   cmp #chrCR
   bne -
++ lda #0
   sta cmdBuffer,y
   jsr kernelClrchn
   lda checkDiskStatusCode
   cmp #62
   bne +
   lda #aceErrFileNotFound
   sta errno
   sec
   rts
+  cmp #20
   bcc +
   sta errno
+  rts
checkDiskStatusCode !byte 0

checkJobStatus = *
   ldx #0
-  lda cmdBPollJob,x
   sta cmdBuffer,x
   inx
   cmp #chrCR
   bne -
   jsr cmdchSend
   ldx #cmdlf
   jsr kernelChkin
   jsr kernelChrin
   sta job_status_val
   rts
job_status_val !byte 0

;******** standard library ********
Utoa = *
   lda #<UtoaNumConv
   ldy #>UtoaNumConv
   sta zp+0
   sty zp+1
   lda #2
   jmp aceMiscUtoa
UtoaNumConv !fill 11,0

eputs = *
   ldx #stderr
   jmp fputs
puts = *
   ldx #stdout
fputs = *
   sta zp
   sty zp+1
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

getchar = *
   ldx #stdin
getc = *
   lda #<getcBuffer
   ldy #>getcBuffer
   sta zp
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

getLastArg = *
   lda aceArgc+0
   ldy aceArgc+1
   sec
   sbc #1
   bcs +
   dey
+  jmp getarg

;===the end===
;maximum of 21 sectors * 256 bytes/sector = 5.25 KiB
trackBuffer = *

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