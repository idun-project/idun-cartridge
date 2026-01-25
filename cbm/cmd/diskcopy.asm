;'diskcopy' cmd: copy disk images <-> floppy drives
;
;Copyright© 2025 Brian Holdsworth
; This is free software, released under the MIT License.
;
; This tool works for 1541/71 floppy deives and D64/71
; disk image files. One commandline argument must be given,
; and is either the source floppy drive or the source disk
; image file. The tool prompts for entry of the destination
; disk image filename or floppy drive, respectively.
;
; If the destination is an unformatted floppy, then it will
; be formatted before the copy.
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

cmdlf            = 15
datalf           = 76
diraccChan       = 2
chrQuote         = $22
formatDestFlag   !byte 0

curSectorPtr     = 2 ;(2)
driveTracks      = 4 ;(1)
srcDrive         = 5 ;(1)
ptrImage         = 6 ;(2)
temp             = 8 ;(2)
driveLetter      = 10;(1)
driveIec         = 11;(1)
destMaxTracks    = 12;(1)
srcTracks        = 13;(1)
currentTrack     = 14;(4)
blocksInTrack    = 18;(1)
sectorCount      = 19;(4)
abortFlag        = 24;(1)

blocksPerTrack !byte 21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,19,19,19,19,19,19,19,18,18,18,18,18,18,17,17,17,17,17
!byte 21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,19,19,19,19,19,19,19,18,18,18,18,18,18,17,17,17,17,17

diraccName !pet "#0"
itag !pet "dimage"

copyUsageErrorMsg = *
;    |1234567890123456789012345678901234567890|
!pet "Usage: diskcopy <source>",chrCR
!pet "Tool prompts for destination.",chrCR
!pet "Ex. make floppy from disk image",chrCR
!pet "    diskcopy myimage.d71",chrCR
!pet "Ex. make disk image from floppy",chrCR
!pet "    diskcopy a:",chrCR,0

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
   sta driveIec
   sta abortFlag
   sta srcDrive
   lda #70
   sta destMaxTracks
   sta srcTracks
   ; check for one argument
   lda aceArgc
   cmp #2
   beq +
   jmp copyUsageError
   ; check source type
+  lda #1
   ldy #0
   jsr getarg
   jsr aceDirIsdir
   cpx #TRUE
   bne +
   ; source is a floppy drive
   sta driveLetter
   sta srcDrive
   jsr aceMiscDeviceInfo
   sta driveIec
   jmp copyFromFloppy
   ; source is a disk image; try to load
+  lda #<itag
   ldy #>itag
   ldx #0
   jsr mmap
   bcc +
   jmp srcOpenErrorMsg
+  jmp copyToFloppy

   copyFromFloppy = *
   jsr initIec
   bne +
   jmp initDestError
+  bcs +
   ; copy from a 1541
   lda #35
   sta srcTracks
   jmp allocImage
+  ldx driveIec
   jsr checkFormatIec   ;1571- But is it a double-sided floppy?
   bne +
   jmp srcOpenErrorMsg  ;Whoops! It's not even formatted!
+  bcs allocImage
   lda #35
   sta srcTracks        ;Single-sidded floppy
   allocImage = *
   lda srcTracks
   cmp #70
   beq +
   lda #<683            ;D64 image size in blocks
   ldy #>683
   jmp ++
+  lda #<1366           ;D71 image size in blocks
   ldy #>1366
++ sta zw
   sty zw+1
   lda #0
   ldy #0
   jsr new
   jsr askDestImage
   jmp diskCopy

   copyToFloppy = *
   jsr checkFormatVirt
   beq openSrcError
   bcs +
   lda #35
   sta srcTracks
   ; scan for acceptable floppy drive destination
+  +ldaSCII "a"
   sta driveLetter
-  jsr checkDrive
   bcc +
   inc driveLetter
   lda driveLetter
   +cmpASCII "["
   beq initDestError
   jmp -
+  lda driveTracks
   cmp srcTracks
   bcc -
   ; found a drive that supports the right num. of tracks
   jsr blockOpenIec
   bcs destOpenErrorMsg
   jsr checkFormatIec
   bne +
   ; disk needs formatting
-  lda #$ff
   sta formatDestFlag
   jmp diskCopy
+  bcc +
   jmp diskCopy         ;disk formatted both sides
+  lda srcTracks
   cmp #70
   beq -
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
destOpenErrorMsg !pet "Error: Destination not writable",chrCR,0
srcOpenErrorMsg !pet "Error: Source not readable",chrCR,0

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
   lda formatDestFlag
   bpl +
   ;do format
   jsr formatIec
   bcc +
   jmp exit
   ;print #tracks to copy
+  lda srcTracks
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
   lda #1
   sta currentTrack
   jsr aceConGetpos
   sec
   sbc #3
   sta _node+1
   sta _node4+1
   lda srcDrive
   bne +
   ;diskcopy virtual->native
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
+  jsr showProgress
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
   lda #chrCR
   jsr putchar
   lda #<cmdBuffer
   ldy #>cmdBuffer
   jsr puts
   lda srcDrive
   beq +
   ; TODO: save disk image to file
   nop
+  rts
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

askDestImage = *        ;() : destImageFile, .X=filename length
-  lda #<destAskMsg
   ldy #>destAskMsg
   jsr puts
   lda #0
   sta temp
-  jsr getchar
   cmp #chrCR
   beq +
   ldx temp
   sta destImageFile,x
   inc temp
   jsr putchar
   jmp -
+  ldx temp
   lda #0
   sta destImageFile,x
   rts
destAskMsg !pet "Name new disk image: ",0
destImageFile !fill 64,0

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
   pla
   tax
   jsr cmdchOpen
   bcs ++
   ;send I(nitialize) to make device ready
   ; +ldaSCII "i"
   ; sta cmdBuffer
   ; ldx #1
   ; jsr cmdchSend
   ; bcs ++
   ;send U9 to reset drive
   +ldaSCII "u"
   sta cmdBuffer
   +ldaSCII "9"
   sta cmdBuffer+1
   lda #chrCR
   sta cmdBuffer+2
   ldx #3
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

checkDrive = * ;(.A=drive letter) : driveIec, driveTracks, .CC=1541/71
   ;check if the device is the right type
   sta drivePrefix
   lda #<drivePrefix
   ldy #>drivePrefix
   sta zp
   sty zp+1
   jsr aceMiscDeviceInfo
   cpx #1
   beq +
   sec
   rts
   ;check type of drive and set num. tracks
+  sta driveIec
   tax
   jsr initIec
   bne +
   sec
   rts
+  lda #35
   bcc +
   lda #70
+  sta driveTracks
   clc
   rts
drivePrefix !pet "a:",0

checkFormatIec = *    ;(driveIec) : .ZS=no format, .CS=70trk, .CC=35trk
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

checkFormatVirt = *    ;(.mp=eram dimage) : .ZS=no format, .CS=70trk, .CC=35trk
   ; we need the address of track 18, sector 0
   lda #<357
   ldy #>357
   ldx #ptrImage
   jsr Block2Eram
   ; now we can access the BAM
   lda ptrImage+1
   sta $deff
-  bit $defe
   bvc -
   lda ptrImage
   sta $defe
-  bit $defe
   bvc -
   ; Check byte 2 for DOS version
   lda $df02
   cmp #$41
   bne +
   ; Check byte 3 for double-sided
   lda $df03
   ora #1
   asl
   rts
+  lda #0
   rts

Block2Eram = *         ;( .A=blkLo, .Y=blkHi, .X=#ptr : [ptr] to TS in ERAM )
   pha
   lda mp+1
   sta $00,x
   lda mp+2
   sta $01,x
-  dey
   bmi +
   clc
   adc #4
   sta $01,x
   jmp -
+  pla
   tay
-  cpy #0
   beq +
   dey
   inc $00,x
   lda $00,x
   cmp #64
   bne -
   inc $01,x
   lda #0
   sta $00,x
   jmp -
+  rts

formatIec = *    ;(driveIec)
   lda driveIec
   clc
   adc #$30
   sta formatMsgX
   lda #<formatMsg
   ldy #>formatMsg
   jsr puts
   ldx #0
-  lda cmdBFormat,x
   sta cmdBuffer,x
   inx
   cmp #chrCR
   bne -
   jsr cmdchSend
   bcc +
   rts
+  jmp checkDiskStatus
formatMsg  !pet "Formatting Floppy Device #"
formatMsgX !pet $38,chrCR,0
cmdBFormat !pet "n0:blank,2d",chrCR

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

blockOpenIec = * ;( driveIec ) : .CS=error
   clc
   ;open data channel
   lda #2
   ldx #<diraccName
   ldy #>diraccName
   jsr kernelSetnam
   ldy #diraccChan
   lda #datalf
   ldx driveIec
   jsr kernelSetlfs
   jsr kernelOpen
   bcc +
   sta errno
   rts
   ;open command channel (#15)
+  ldx driveIec
   jsr cmdchOpen
   bcc +
   sta errno
+  rts

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

mpNext = *       ;(mp) : mp
   ; advance to next sector in Eram
   inc mp+1
   lda mp+1
   cmp #64
   bne +
   inc mp+2
   lda #0
   sta mp+1
+  rts

mpGet = *         ;([mp], [curSectorPtr])
   lda curSectorPtr+0
   ldy curSectorPtr+1
   sta zp+0
   sty zp+1
   lda #0
   ldy #1
   jmp aceMemFetch

mpPut = *         ;([mp], [curSectorPtr])
   lda curSectorPtr+0
   ldy curSectorPtr+1
   sta zp+0
   sty zp+1
   lda #0
   ldy #1
   jmp aceMemStash

trackReadVirtual = *  ;(currentTrack, trackBuffer) : .CS=error
   jsr updateReading
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
   jsr mpNext
   jsr mpGet
   inc curSectorPtr+1
   inc sectorCount
   dec blocksInTrack
   bne -
   rts

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

trackWriteVirtual = *  ;(currentTrack, trackBuffer) : .CS=error
   jsr updateWriting
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
   jsr mpNext
   jsr mpPut
   inc curSectorPtr+1
   inc sectorCount
   dec blocksInTrack
   bne -
   rts

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
   sec
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
   clc
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