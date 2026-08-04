; Idun Kernel, Copyright ©2026 Brian Holdsworth
; This is free software, released under the MIT License.
;
; IEC (serial-bus) physical disk drive support, extracted from acecall.asm.
; Only assembled when useIec=1 (see sys/ace.asm). Every routine here talks
; to the real KERNAL device I/O (kernelOpen/kernelClose/kernelChkin/
; kernelChrin/kernelChrout) and/or the disk drive's command channel.
;
; Shared-dispatch call sites in acecall.asm reach these routines with a
; plain `jmp mioXxx`. When useIec=0, sys/acemionone.asm is sourced instead
; of this file and aliases each of these entry point names to
; mioUnsupported, so those jumps still resolve to something rather than an
; undefined symbol.

;-- mioOpenDiskSa: secondary-address search/assignment for physical disk opens
;   ( openDevice=set, openFcb=set ) : .Y=sa, falls into nonDiskSa (acecall.asm)
mioOpenDiskSa = *
   lda #true
   sta checkStat
   ldy #2
   diskSaSearch = *
   ldx #fcbCount-1
-  lda lftable,x
   bmi +
   lda devtable,x
   cmp openDevice
   bne +
   tya
   cmp satable,x
   bne +
   iny
   bne diskSaSearch
+  dex
   bpl -
   jmp nonDiskSa

;-- mioOpenNameSuffix: append ",<mode>" for physical disk file opens
;   ( .X=name length in stringBuffer, openMode=set ) : jmp openGotName (acecall.asm)
mioOpenNameSuffix = *
   ;** stick the mode for disk files
   cpx #0
   bne +
   lda #aceErrOpenDirectory
   sec
   rts
+  +ldaSCII ","
   sta stringBuffer,x
   inx
   lda openMode
   sta stringBuffer,x
   inx
   lda #0
   sta stringBuffer,x
   jmp openGotName

;-- mioOpenDiskStatus: verify disk drive status after open/bload
;   ( .A=device, checkStat=flag ) : errno=.A=errcode, .CS=errflag
mioOpenDiskStatus = *
   bit checkStat
   bne +
   clc
   rts
+  sta mioDiskStatusDev ;temp. store device here!
   jsr mioCmdchOpen
   bcc +
   cmp #aceErrFileOpen
   bne ++
+  jsr mioCheckDiskStatus
   php
   pha
   ldx mioDiskStatusDev
   jsr cmdchClose
   pla
   plp
++ rts
mioDiskStatusDev !byte 0

mioCmdchOpen = *  ;( .A=device )
   tax
   lda configBuf+2,x
   tay
   lda configBuf+1,x
   tax
   lda #cmdlf
   jsr kernelSetlfs
   lda #0
   jsr kernelSetnam
   jsr kernelOpen
   bcc +
   sta errno
+  rts

mioCmdchSend = *  ;( stringBuffer )
   ldx #cmdlf
   jsr kernelChkout
   bcs mioCmdchErr
   ldx #0
-  lda stringBuffer,x
   beq +
   jsr kernelChrout
   bcs mioCmdchErr
   inx
   bne -
+  jsr kernelClrchn
   clc
   rts

   mioCmdchErr = *
   sta errno
   pha
   jsr kernelClrchn
   pla
   sec
   rts

mioCheckDiskStatusCode !byte 0

mioCheckDiskStatus = *
   ldx #cmdlf
   jsr kernelChkin
   bcs mioCmdchErr
   jsr kernelChrin
   bcs mioCmdchErr
   and #$0f
   sta mioCheckDiskStatusCode
   asl
   asl
   adc mioCheckDiskStatusCode
   asl
   sta mioCheckDiskStatusCode
   jsr kernelChrin
   bcs mioCmdchErr
   and #$0f
   clc
   adc mioCheckDiskStatusCode
   sta mioCheckDiskStatusCode
-  jsr kernelReadst
   and #$80
   beq +
   lda #aceErrDeviceNotPresent
   sec
   bcs mioCmdchErr
+  jsr kernelChrin
   bcs mioCmdchErr
   cmp #chrCR
   bne -
   jsr kernelClrchn
   lda mioCheckDiskStatusCode
   cmp #62
   bne +
   lda #aceErrFileNotFound
   sta errno
   sec
   rts
+  cmp #20
   bcc +
   sta errno
   ;carry already set: bcc above didn't branch, so C=1 from the cmp #20
+  rts

;-- mioClosePath: physical KERNAL close, for fds not owned by pid/tag/console
;   ( closeFd=set ) : jmp closeFdEntry (acecall.asm)
mioClosePath = *
   ldx closeFd
   lda lftable,x
   clc
   jsr kernelClose
   jmp closeFdEntry

;-- mioReadPath: physical KERNAL byte-at-a-time read, for fds not owned by
;   pid/tag/console. readDeviceDisk is set here from the device type: $ff
;   for disk fds (watch KERNAL status for EOF), else 0 (read until the
;   caller's requested length is satisfied, no EOF tracking)
;   ( .A=device type, readFcb=set ) : jmp readExit (acecall.asm)
mioReadPath = *
   ldy #0
   cmp #1
   bne +
   ldy #$ff
+  ldx readFcb
   sty readDeviceDisk
   lda lftable,x
   tax
   jsr kernelChkin
   bcc mioReadByte
   sta errno
   rts

   mioReadByte = *
   lda readLength+0
   cmp readMaxLen+0
   lda readLength+1
   sbc readMaxLen+1
   bcc +
   jmp readExit
+  jsr kernelChrin
   ldy #0
   sta (readPtr),y
   inc readPtr+0
   bne +
   inc readPtr+1
+  inc readLength+0
   bne +
   inc readLength+1
+  bit readDeviceDisk
   bpl mioReadByte
   lda st
   and #$40
   beq mioReadByte
   ldx readFcb
   sta eoftable,x
   jmp readExit

;-- mioWritePath: physical KERNAL byte-at-a-time write, for fds not owned by
;   pid/console/null
;   ( regsave+1=fcb, writeLength/writePtr=set ) : .CS=error
mioWritePath = *
   ldx regsave+1
   lda lftable,x
   tax
   jsr kernelChkout
   bcc mioWriteByte
   rts

   mioWriteByte = *
   lda writeLength+0
   ora writeLength+1
   beq mioWriteFinish
   ldy #0
   lda (writePtr),y
   jsr kernelChrout
   bcc +
   sta errno
   jsr kernelClrchn
   sec
   rts
+  inc writePtr+0
   bne +
   inc writePtr+1
+  lda writeLength+0
   bne +
   dec writeLength+1
+  dec writeLength+0
   jmp mioWriteByte

   mioWriteFinish = *
   jsr kernelClrchn
   clc
   rts

;-- mioBloadPath: physical KERNAL binary load, disk devices (type #1) only
;   ( bloadDevice/bloadFilename/bloadAddress/bloadBank/checkStat=set )
;   : .AY=End+1, .CS=error,errno
mioBloadPath = *
   lda #true
   sta checkStat
   lda configBuf+1,x
   tax
   lda #0
   ldy #0
   jsr kernelSetlfs
   ldy #0
-  lda (bloadFilename),y
   beq +
   iny
   bne -
+  tya
   ldx bloadFilename+0
   ldy bloadFilename+1
   jsr kernelSetnam
!if useC128 {
   lda bloadBank
   beq +
   ldx #0
   jsr kernelSetbnk
}
+  lda #0
   ldx bloadAddress+0
   ldy bloadAddress+1
   jsr kernelLoad
   bcc mioBloadOk
   pha
   cmp #aceErrDeviceNotPresent
   beq +
   ldx bloadDevice
   lda configBuf+0,x
   cmp #1
   bne +
   txa
   jsr mioOpenDiskStatus
+  pla
-  sta errno
   lda #0
   ldx #0
   ldy #0
   sec
   rts

   mioBloadOk = *
   ldx bloadDevice
   lda configBuf+0,x
   cmp #1
   bne +
   txa
   jsr mioOpenDiskStatus
   bcs -
+  lda bloadAddress+0
   ldy bloadAddress+1
   rts

;-- mioRemovePath: send "s0:name" over the command channel, check status
;   ( removeDevice=set, openNameScan=set, (zp)=path ) : .CS=error,errno
mioRemovePath = *
   +ldaSCII "s"
   sta stringBuffer
   +ldaSCII ":"
   sta stringBuffer+1
   ldx #1
   ldy openNameScan
   lda (zp),y
   +cmpASCII "/"
   beq mioRemoveSlash
   ldx #2
mioRemoveSlash:
   lda (zp),y
   sta stringBuffer,x
   beq +
   iny
   inx
   bne mioRemoveSlash
+  lda #0
   sta stringBuffer,x
   lda removeDevice
   jsr mioCmdchOpen
   bcs ++
   jsr mioCmdchSend
   bcs +
   jsr mioCheckDiskStatus
+  php
   ldx removeDevice   ;cmdchClose needs .X=device, not leftover X
   jsr cmdchClose
   plp
++ rts

;-- mioRenamePath: send "r:new=old" over the command channel, check status
;   ( renameDevice=set, openNameScan=set, (zp)=old, (zw)=new ) : .CS=error,errno
mioRenamePath = *
   +ldaSCII "r"
   sta stringBuffer+0
   +ldaSCII ":"
   sta stringBuffer+1
   ;** copy new name
   ldy #0
   ldx #2
-  lda (zw),y
   sta stringBuffer,x
   beq +
   iny
   inx
   bne -
+  +ldaSCII "="
   sta stringBuffer,x
   inx
   ;** copy old name
   ldy openNameScan
-  lda (zp),y
   sta stringBuffer,x
   beq +
   inx
   iny
   bne -
+  lda renameDevice
   jsr mioCmdchOpen
   bcs ++
   jsr mioCmdchSend
   bcs +
   jsr mioCheckDiskStatus
+  php
   ldx renameDevice  ;cmdchClose needs .X=device, not leftover X
   jsr cmdchClose
   plp
++ rts

;-- mioFileStat: IEC path for aceFileStat
;   opens filtered dir "$:BASENAME", reads one entry into aceDirentBuffer
;   ( syswork+1=device, (zp)=path ) : .AY=file size,.CS=error,errno
mioFileStat = *
   +ldaSCII "$"
   sta stringBuffer+0
   +ldaSCII ":"
   sta stringBuffer+1
   ldy #0
-  lda (zp),y
   beq mioFileStatNotFound
   iny
   cmp #<":"
   bne -
   ldx #2
-  lda (zp),y
   sta stringBuffer,x
   beq +
   iny
   inx
   bne -
+  lda syswork+1
   sta openDevice
   jsr mioDirOpen      ; .A = fcb
   bcs mioFileStatRts
   sta fstatFcb        ; kernDirRead clobbers openFcb=syswork+0 via dirBlocks
   tax
   jsr kernDirRead    ; skip disk name header entry
   ldx fstatFcb
   jsr kernDirRead    ; read actual file entry
   php
   lda fstatFcb
   jsr kernDirClose
   plp
   bcs mioFileStatRts
   bne +
mioFileStatNotFound = *
   lda #aceErrFileNotFound
   sta errno
mioFileStatRts = *
   sec
   rts
+  clc
   rts

;-- mioDirOpenRoot: open a physical drive's full directory listing
;   ( openDevice=set ) : .A=fd, .CC -- falls into mioDirOpen below
mioDirOpenRoot = *
   +ldaSCII "$"          ; CBM DOS convention: filename "$" = directory listing
   sta stringBuffer+0
   ldx #1                ; name length = 1 (just "$")
   ;** falls through into mioDirOpen -- no jmp needed, .X is already set up

;-- mioDirOpen: open IEC filtered dir with pre-built name in stringBuffer
;   ( openDevice=set, .X=name length ) : .A=fd, .CC
mioDirOpen = *
   stx openNameLength
   jsr fcbSetup
   bcc +
   rts
+  lda #true
   sta checkStat
   lda openDevice
   jsr mioOpenDiskStatus
   ldx openNameLength
   jsr openGotName
   bcc +
   rts
+  ldx openFcb
   lda lftable,x
   tax
   jsr kernelChkin
   jsr kernelChrin
   jsr kernelChrin
   jsr kernelClrchn
   lda openFcb
   clc
   rts

;-- mioChdirPath: send "cd:name" over the command channel, check status
;   ( chdirDevice=set, chdirNameScan=set(.Y), (zp)=dirname ) : .CS=error
mioChdirPath = *
   +ldaSCII "c"
   sta stringBuffer+0
   +ldaSCII "d"
   sta stringBuffer+1
   ldx #2
-  lda (zp),y
   sta stringBuffer,x
   beq +
   +cmpASCII ":"
   beq +
   iny
   inx
   bne -
+  lda #0
   sta stringBuffer,x
   cpx #2
   bne +
   jmp chdirSetName
+  lda chdirDevice
   jsr mioCmdchOpen
   bcc +
   rts
+  jsr mioCmdchSend
   bcs mioChdirAbort
   jsr mioCheckDiskStatus
   bcs mioChdirAbort
   ldx chdirDevice  ;cmdchClose needs .X=device, not leftover X
   jsr cmdchClose
   lda #0
   sta stringBuffer+2
   jmp chdirSetName

   mioChdirAbort = *
   ldx chdirDevice  ;cmdchClose needs .X=device, not leftover X
   jsr cmdchClose
   sec
   rts

;-- mioIecCommand: aceIecCommand( (zp)=Command ), send raw DOS command
;   string to the current device's command channel
mioIecCommand = *
   ldx #0
   ldy #0
-  lda (zp),y
   sta stringBuffer,x
   beq +
   iny
   inx
   bne -
+  ldx aceCurrentDevice
   lda configBuf+0,x
   cmp #1
   beq +
   sec
   rts
+  lda aceCurrentDevice
   jsr mioCmdchOpen
   bcs ++
   jsr mioCmdchSend
   bcs +
   ;read device response
   ldx #cmdlf
   jsr kernelChkin
-  jsr kernelChrin
   pha
   jsr kernConPutchar
   pla
   cmp #13
   bne -
   clc
+  php
   ldx aceCurrentDevice  ;cmdchClose needs .X=device, not leftover X
   jsr cmdchClose
   plp
++ rts

;-- mioDirRead: read one BASIC-style directory listing entry from the
;   command channel into aceDirentBuffer/aceDirentBytes
;   ( .X=fcb, aceDirentBytes already zeroed by kernDirRead ) : .Z=eof
dirBlocks = syswork+0
mioDirRead = *
   lda lftable,x
   tax
   jsr kernelChkin
   bcc +
   lda #0
   rts
   ;** read the link
+  jsr kernelChrin
   sta syswork+4
   jsr kernelReadst
   and #$40
   bne mioDirreadEofExit
   jsr kernelChrin
   ora syswork+4
   bne +

   mioDirreadEofExit = *
   jsr kernelClrchn
   ldx #0
   rts
   mioDirreadErrExit = *
   sta errno
   jsr kernelClrchn
   ldx #0
   sec
   rts

   ;** read the block count
+  jsr kernelChrin
   sta dirBlocks
   sta aceDirentBytes+1
   jsr kernelChrin
   sta dirBlocks+1
   sta aceDirentBytes+2
   asl dirBlocks
   rol dirBlocks+1
   lda #0
   rol
   sta dirBlocks+2
   sec
   lda #0
   sbc dirBlocks
   sta aceDirentBytes+0
   lda aceDirentBytes+1
   sbc dirBlocks+1
   sta aceDirentBytes+1
   lda aceDirentBytes+2
   sbc dirBlocks+2
   sta aceDirentBytes+2
   ;** read the filename
   lda #0
   sta aceDirentName
   sta aceDirentNameLen
-  jsr kernelChrin
   bcs mioDirreadErrExit
   bit st
   bvs mioDirreadErrExit
   +cmpASCII " "
   beq -
   cmp #18
   beq -
   cmp #$22
   bne mioDirreadExit
   ldx #0
-  jsr kernelChrin
   bcs mioDirreadErrExit
   bit st
   bvs mioDirreadErrExit
   cmp #$22
   beq +
   sta aceDirentName,x
   inx
   bne -
+  lda #0
   sta aceDirentName,x
   stx aceDirentNameLen
-  jsr kernelChrin
   +cmpASCII " "
   beq -
   ;** read type and flags
   ldx #%01100000
   stx aceDirentFlags
   ldx #%10000000
   stx aceDirentUsage
   +cmpASCII "*"
   bne +
   lda aceDirentFlags
   ora #%00001000
   sta aceDirentFlags
   jsr kernelChrin
+  ldx #3
   ldy #0
   jmp mioDirTypeFirst
-  jsr kernelChrin
   mioDirTypeFirst = *
   sta aceDirentType,y
   iny
   dex
   bne -
   lda #0
   sta aceDirentType+3
   lda aceDirentType
   +cmpASCII "d"
   bne +
   lda aceDirentFlags
   ora #%10010000
   sta aceDirentFlags
   jmp mioDirreadExit
+  +cmpASCII "p"
   bne mioDirreadExit
   lda aceDirentFlags
   ora #%00010000
   sta aceDirentFlags
   jmp mioDirreadExit

   mioDirreadExit = *
   jsr kernelChrin
   cmp #0
   bne +
   jmp mioDirreadRealExit
+  +cmpASCII "<"
   bne +
   lda aceDirentFlags
   and #%11011111
   sta aceDirentFlags
+  ldx #7
   lda #0
-  sta aceDirentDate,x
   dex
   bpl -
-  jsr kernelChrin
   cmp #0
   beq mioDirreadRealExit
   +cmpASCII "0"
   bcc -
   cmp #$3a
   bcs -

   mioDirreadDate = *
   jsr mioDirGetNumGot
   bcs mioDirreadRealExit
   sta aceDirentDate+2
   jsr mioDirGetNum
   bcs mioDirreadRealExit
   sta aceDirentDate+3
   jsr mioDirGetNum
   bcs mioDirreadRealExit
   sta aceDirentDate+1
   ldx #$19
   cmp #$70
   bcs +
   ldx #$20
+  stx aceDirentDate+0  ;century
   jsr mioDirGetNum
   bcs mioDirreadRealExit
   sta aceDirentDate+4
   jsr mioDirGetNum
   bcs mioDirreadRealExit
   sta aceDirentDate+5
   jsr kernelChrin
   and #$ff
   beq mioDirreadRealExit
   jsr kernelChrin
   and #$ff
   beq mioDirreadRealExit
   +cmpASCII "a"
   bne mioDirreadPM

   mioDirreadAM = *
   lda aceDirentDate+4
   cmp #$12
   bne +
   lda #$00
   sta aceDirentDate+4
   jmp +

   mioDirreadPM = *
   lda aceDirentDate+4
   cmp #$12
   beq mioDirReadInternBr
   clc
   sed
   adc #$12
   cld
   sta aceDirentDate+4
mioDirReadInternBr:
   jsr kernelChrin
   cmp #0
   bne mioDirReadInternBr

   mioDirreadRealExit = *
   jsr kernelClrchn
   ldx #$ff
   clc
   rts

   mioDirGetNum = *
-  jsr kernelChrin
   mioDirGetNumGot = *
   cmp #0
   beq +
   +cmpASCII "0"
   bcc -
   cmp #$3a
   bcs -
   asl
   asl
   asl
   asl
   sta syswork+6
   jsr kernelChrin
   cmp #0
   beq +
   and #$0f
   ora syswork+6
   clc
+  rts
