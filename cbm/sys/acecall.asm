; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)
;
; Main file/dir/other system calls

kernelSetbnk = $ff68

;====== file calls ======

;*** open( zp=filenameZ, .A=mode["r","w","a","W","A"] ) : .A=fcb

aceOpenOverwrite = *
   +ldaSCII "w"
   jsr open
   bcs +
   rts
+  ldy errno
   cpy #aceErrFileExists
   beq +
   sec
   rts
+  jsr internRemove
   bcs +
   +ldaSCII "w"
   jsr open
+  rts

aceOpenForceAppend = *
   +ldaSCII "a"
   jsr open
   bcs +
   rts
+  ldy errno
   cpy #aceErrFileNotFound
   beq +
   sec
   rts
+  +ldaSCII "w"
   jsr open
   rts

;NAME   :  open
;PURPOSE:  open a file
;ARGS   :  (zp) = pathname
;          .A   = file mode ("r", "w", "a", "W", "A", or "C")
;RETURNS:  .A   = file descriptor number
;          .CS  = error occurred flag
;ALTERS :  .X, .Y, errno

openFcb      = syswork+0
openNameScan = syswork+1
openMode     = syswork+2
openNameLength = syswork+3
openDevice   = syswork+4
checkStat !byte 0

kernFileOpen = *
internOpen = *
   sta openMode
   +cmpASCII "W"
   bne +
   jmp aceOpenOverwrite
+  +cmpASCII "A"
   bne +
   jmp aceOpenForceAppend
+  +cmpASCII "C"
   bne ++
   jsr getFcb
   bcc +
   rts
+  +ldaSCII "R"
   sta openMode
   lda #cmdlf
   jmp fileOpenCont
++ jsr getLfAndFcb
   bcc fileOpenCont
   rts
   fileOpenCont = *
   sta lftable,x
   lda #$00
   sta eoftable,x
   stx openFcb
   jsr getDevice
   sty openNameScan
   ldx openFcb
   sta devtable,x
   sta openDevice
   tax
   lda #true
   sta checkStat
   ;get sa here
   lda configBuf+0,x
   cmp #0
   bne +
   ldy configBuf+2,x
   jmp nonDiskSa
+  ldy #0
   ;** check native disk device
   cmp #1
   beq openDiskSa
   ;** check console
   cmp #2
   bne +
-  lda openFcb
   clc
   rts
   ;** check null device
+  cmp #3
   beq -
   ; IDUN: Check idun virtual devices (type #4-7)
   ;** check virtual disk
   cmp #4
   bne +++
-  ldx openFcb
   lda lftable,x
   cmp #cmdlf
   bne ++
   stx regsave+1
   ldx openDevice
   lda configBuf+2,x
   sta openFcb
   jsr pidOpen
   bcc +
   rts
+  lda regsave+1
   rts
++ jmp pidOpen
+++cmp #7
   bcc +
   jmp -
   ;** check mem-mapper files
+ cmp #5
   bne +
   jmp internTagOpen
   ;** check virtual console
+  cmp #6
   bne +
   jmp pidOpen
   ;** illegal device
+  lda #aceErrIllegalDevice
   sta errno
   sec
   rts

   openDiskSa = *
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

   nonDiskSa = *
   ldx openFcb
   tya
   sta satable,x

   ;set the name
   ldx #0
   ldy openNameScan
-  lda (zp),y
   sta stringBuffer,x
   beq +
   iny
   inx
   bne -
+  ldy openDevice
   lda configBuf+0,y
   cmp #1
   bne nonDiskOpen
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

   ;** get rid of the filename for non-disks
   nonDiskOpen = *
   ldx #0

   openGotName = *
   ;** dispatch here for non-kernel devices
   txa
   ldx #<stringBuffer
   ldy #>stringBuffer
   jsr kernelSetnam

   ;set lfs
   ldx openFcb
   lda lftable,x
   pha
   lda satable,x
   tay
   lda devtable,x
   tax
   lda configBuf+1,x
   tax
   pla
   jsr kernelSetlfs

   ;do the open
   jsr kernelOpen
   bcs openError
+  ldx openDevice
   lda configBuf+0,x
   cmp #1
   bne +
   lda checkStat
   beq +
   txa
   jsr openDiskStatus
   bcc +

   openError = *
   sta errno
   ldx openFcb
   lda lftable,x
   clc
   jsr kernelClose
   ldx openFcb
   lda #lfnull
   sta lftable,x
   sec
   lda #fcbNull
   rts
+  lda openFcb
   clc
   rts

openDiskStatus = *  ;( .A=device ) : errno=.A=errcode, .CS=errflag
   jsr cmdchOpen
   bcc +
   cmp #aceErrFileOpen
   bne ++
+  jsr checkDiskStatus
   php
   pha
   jsr cmdchClose
   pla
   plp
++ rts

cmdchOpen = *  ;( .A=device )
   pha
   jsr cmdchClose
   pla
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

cmdchClose = *
   lda devtable,x
   tax
   lda configBuf+0,x
   cmp #1
   beq +
   lda configBuf+2,x
   sta closeFd
   jmp pidClose
+  sec
   lda #cmdlf
   jsr kernelClose
   bcc +
   sta errno
+  rts

cmdchSend = *  ;( stringBuffer )
   ldx #cmdlf
   jsr kernelChkout
   bcs cmdchErr
   ldx #0
-  lda stringBuffer,x
   beq +
   jsr kernelChrout
   bcs cmdchErr
   inx
   bne -
+  jsr kernelClrchn
   clc
   rts

   cmdchErr = *
   sta errno
   pha
   jsr kernelClrchn
   pla
   sec
   rts

checkDiskStatusCode !byte 0

checkDiskStatus = *
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
-  jsr kernelReadst
   and #$80
   beq +
   lda #aceErrDeviceNotPresent
   sec
   bcs cmdchErr
+  jsr kernelChrin
   bcs cmdchErr
   cmp #chrCR
   bne -
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


;NAME   :  close
;PURPOSE:  close an open file
;ARGS   :  .A   = File descriptor number
;RETURNS:  .CS  = error occurred flag
;ALTERS :  .A, .X, .Y, errno

closeFd !byte 0

kernFileClose = *
aceClose = *
internClose = *
   tax
   lda lftable,x
   cmp #cmdlf
   bne +
   jmp cmdchClose
+  lda pidtable,x
   cmp aceProcessID
   beq +
   clc
   rts
+  ldy devtable,x
   stx closeFd
   internCloseCont = *
   lda configBuf+0,y
   cmp #2
   bne +
   jmp closeFdEntry
+  cmp #3
   bne +
   jmp closeFdEntry
   ; IDUN: Check idun virtual devices (type #4-7)
   ;** check virtual disk
+  cmp #4
   bne +
   jsr pidClose
   jmp closeFdEntry
+  cmp #7
   bcc +
   jsr pidClose
   jmp closeFdEntry
   ;** check mem-mapper files
+  cmp #5
   bne +
   jsr internTagClose
   jmp closeFdEntry
   ;** check virtual console
+  cmp #6
   bne +
   jsr pidClose
   jmp closeFdEntry
+  ldx closeFd
   lda lftable,x
   clc
   jsr kernelClose

   closeFdEntry = *
   ldx closeFd
   lda #lfnull
   sta lftable,x
   clc
   rts

;NAME   :  read
;PURPOSE:  read data from an open file
;ARGS   :  .X   = File descriptor number
;          (zp) = pointer to buffer to store data into
;          .AY  = maximum number of bytes to read
;RETURNS:  .AY  = (zw) = number of bytes actually read in
;          .CS  = error occurred flag
;          .ZS  = EOF reached flag
;ALTERS :  .X, errno

readMaxLen     = syswork+0
readPtr        = syswork+2
readLength     = syswork+6
readFcb        = syswork+8
readDeviceDisk = syswork+9

;*** read( .X=fcb, (zp)=data, .AY=maxLength ) : .AY=(zw)=length, .Z=eof
kernFileRead = *
   sta readMaxLen+0
   sty readMaxLen+1
   stx readFcb
   lda zp+0
   ldy zp+1
   sta readPtr+0
   sty readPtr+1
   lda #0
   sta readLength+0
   sta readLength+1
   lda eoftable,x
   beq +
   jmp readEofExit
+  ldy #0
   lda devtable,x
   tax
   lda configBuf+0,x
   ; IDUN: Check idun virtual devices (type #4-7)
   ;** check virtual disk
   cmp #4
   bne +
   jmp pidRead
+  cmp #7
   bcc +
   jmp pidRead
   ;** check mem-mapper files
+  cmp #5
   bne +
   jmp internTagRead
+  cmp #2
   bne +
   lda readMaxLen+0
   ldy readMaxLen+1
   ldx readFcb
   jmp conRead
+  cmp #3
   bne +
   lda #0
   ldy #0
   sta zw+0
   sty zw+1
   clc
   rts
+  cmp #1
   bne +
   ldy #$ff
+  ldx readFcb
   sty readDeviceDisk
   lda lftable,x
   tax
   jsr kernelChkin
   bcc readByte
   sta errno
   rts
   
   readByte = *
   lda readLength+0
   cmp readMaxLen+0
   lda readLength+1
   sbc readMaxLen+1
   bcs readExit
   jsr kernelChrin
   ldy #0
   sta (readPtr),y
   inc readPtr+0
   bne +
   inc readPtr+1
+  inc readLength+0
   bne +
   inc readLength+1
+  bit readDeviceDisk
   bpl readByte
   lda st
   and #$40
   beq readByte
   ldx readFcb
   sta eoftable,x

   readExit = *
   jsr kernelClrchn
   readExitNoclr = *
   lda readLength+0
   ldy readLength+1
   sta zw+0
   sty zw+1
   ldx #$ff
   clc
   rts

   readEofExit = *
   lda #0
   ldy #0
+  sta zw+0
   sty zw+1
   clc
   rts


;NAME   :  write
;PURPOSE:  write data to an open file
;ARGS   :  .X   = file descriptor number
;          (zp) = pointer to data to be written
;          .AY  = length of data to be written in bytes
;RETURNS:  .CS  = error occurred
;ALTERS :  .A, .X, .Y, errno

writeLength = syswork+0
writePtr    = syswork+2

;*** write( .X=fcb, (zp)=data, .AY=length )
kernFileWrite = *
internWrite = *
   sta writeLength+0
   sty writeLength+1
   lda zp+0
   ldy zp+1
   sta writePtr+0
   sty writePtr+1
   stx regsave+1
   lda devtable,x
   tax
   lda configBuf+0,x
   ; IDUN: Virtual disks (type #4, 7). Replace with acepid.
   cmp #4
   bne +
   ldx regsave+1
   jmp pidWrite
+  cmp #7
   bcc +
   ldx regsave+1
   jmp pidWrite
+  cmp #2
   bne +
   lda writeLength+0
   ldy writeLength+1
   ldx regsave+1
   jmp conWrite
   ;** check null device
+  cmp #3
   bne +
   clc
   rts
+  ldx regsave+1
   lda lftable,x
   tax
   jsr kernelChkout
   bcc writeByte
   rts

   writeByte = *
   lda writeLength+0
   ora writeLength+1
   beq writeFinish
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
   jmp writeByte
   
   writeFinish = *
   jsr kernelClrchn
   clc
   rts

;NAME   :  seek
;PURPOSE:  seek to file location
;ARGS   :  .X   = file descriptor number
;          .AY  = desired seek offset from start-of-file
;RETURNS:  .CS  = error occurred
;ALTERS :  .A, .X, .Y, errno

seekPtr       = syswork+0

;*** seek( .X=fcb, .AY=offset )

kernFileLseek = *
   sta seekPtr+0
   sty seekPtr+1
   ldy #0
   lda devtable,x
   tax
   lda configBuf+0,x
   ;seek only suppoorted by mem-mapped files (#5)
   cmp #5
   bne +
   jmp internTagSeek
   lda #aceErrIllegalDevice
   sta errno
   sec
   rts


;NAME   :  aceFileRemove
;PURPOSE:  delete a file
;ARGS   :  (zp) = pathname
;RETURNS:  .CS  = error occurred flag
;ALTERS :  .A, .X, .Y, errno

removeDevice = syswork+0

;*** aceFileRemove( (zp)=Name )
kernFileRemove = *
internRemove = *
   jsr getDiskDevice
   bcc +
   rts
+  sta removeDevice
   sty openNameScan
   ; IDUN: Type #4/7. Replace with acepid.
   cpx #4
   bne +
   ldx removeDevice
   jmp pidRemove
+  cpx #7
   bne +
   ldx removeDevice
   jmp pidRemove
+  +ldaSCII "s"
   sta stringBuffer
   +ldaSCII ":"
   sta stringBuffer+1
   ldx #1
   lda (zp),y
   +cmpASCII "/"
   beq bSlash
   ldx #2
bSlash:
   lda (zp),y
   sta stringBuffer,x
   beq +
   iny
   inx
   bne bSlash
+  lda #0
   sta stringBuffer,x
   lda removeDevice
   jsr cmdchOpen
   bcs ++
   jsr cmdchSend
   bcs +
   jsr checkDiskStatus
+  php
   jsr cmdchClose
   plp
++ rts


;NAME   :  aceFileRename
;PURPOSE:  rename a file or directory
;ARGS   :  (zp) = old filename
;          (zw) = new filename
;RETURNS:  .CS  = error occurred flag
;ALTERS :  .A, .X, .Y, errno

renameDevice = syswork+0
renameScan   = syswork+1

;*** aceFileRename( (zp)=OldName, (zw)=NewName )
;*** don't even think about renaming files outside the current directory
kernFileRename = *
   jsr getDiskDevice
   bcc +
   rts
+  sta renameDevice
   sty openNameScan
   ; IDUN: Type #4/7. Replace with acepid.
   cpx #4
   bne +
   ldx renameDevice
   jmp pidRename
+  cpx #7
   bne +
   ldx renameDevice
   jmp pidRename
+  sty renameScan
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
   ldy renameScan
-  lda (zp),y
   sta stringBuffer,x
   beq +
   inx
   iny
   bne -
+  lda renameDevice
   jsr cmdchOpen
   bcs ++
   jsr cmdchSend
   bcs +
   jsr checkDiskStatus
+  php
   jsr cmdchClose
   plp
++ rts


;NAME   :  aceFileBload/aceFileBkload
;PURPOSE:  binary load
;ARGS   :  .X   = RAM bank (0-3 *aceFileBkload only*)
;          (zp) = pathname
;          .AY  = address to load file
;          (zw) = highest address that file may occupy, plus one
;RETURNS:  .AY  = end address of load, plus one
;          .CS  = error occurred flag
;ALTERS :  .X, errno
bloadAddress = syswork
bloadFilename= syswork+2
bloadDevice  = syswork+8
bloadBank    = syswork+9

;*** aceFileBkload( .X=Bank (zp)=Name, .AY=Address, (zw)=Limit+1 ) : .AY=End+1
kernFileBkload = *
internBkload = *
   stx bloadBank
   ldx #0
   jmp +
;*** aceFileBload( (zp)=Name, .AY=Address, (zw)=Limit+1 ) : .AY=End+1
kernFileBload = *
internBload = *
   ldx #0
   stx bloadBank
+  stx BloadAppflag
   sta bloadAddress+0
   sty bloadAddress+1
   jsr getDevice
   sta bloadDevice
   tax
   clc
   tya
   adc zp+0
   sta bloadFilename+0
   lda zp+1
   adc #0
   sta bloadFilename+1
   ;IDUN: Check prog name not NUL
   ldy #0
   lda (bloadFilename),y
   bne +
   lda #aceErrFileNotFound
   sta errno
   sec
   rts
+  lda configBuf+0,x
   ; IDUN: Load from RAM disk replaced with acepid.
   cmp #4
   bne +
   jmp pidBload
+  cmp #7
   bne +
   jmp pidBload
   ; IDUN: Load from Tag RAM replaces RAM disk.
+  cmp #5
   bne +
   jmp internTagBload
+  cmp #1
   beq +
   lda #aceErrIllegalDevice
   sta errno
   sec
   rts
+  lda configBuf+1,x
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
   stx bloadAddress+0
   sty bloadAddress+1
   bcc bloadOk
   pha
   cmp #aceErrDeviceNotPresent
   beq +
   ldx bloadDevice
   lda configBuf+0,x
   cmp #1
   bne +
   txa
   jsr openDiskStatus
+  pla
-  sta errno
   lda #0
   ldx #0
   ldy #0
   sec
   rts

   bloadOk = *
   ldx bloadDevice
   lda configBuf+0,x
   cmp #1
   bne +
   txa
   jsr openDiskStatus
   bcs -
+  lda bloadAddress+0
   ldy bloadAddress+1
   rts

;*** aceDirStat ( .A=stat, (zp)=path ) : CS=error,errno
;                                .CC=filled aceSharedBuf

kernDirStat = *
   ldx #"/"
   cmp #$80
   bne +
   ldx #"%"
+  stx cmdPrefix
   jsr kernMiscDeviceInfo
   bcs +
   lda #aceErrIllegalDevice
   sta errno
   sec
   rts
+  lda syswork+1
   sta openDevice
   lda #"r"
   sta openMode
   lda #2
   sta openNameScan
   jsr pidCommandSend
   lda #<dstatRespHandler
   ldy #>dstatRespHandler
   jmp pidCommandResponse
dstatRespHandler = *
   ldx #$00
-  jsr pidChIn
   bcs -
   beq +
   tax
   lda #<aceSharedBuf
   ldy #>aceSharedBuf
   jsr kernModemGet
   lda #$00
+  sta aceSharedBuf,x
   rts

;*** aceFileStat ( (zp)=path ) : .AY=file size,.CS=error,errno
;                                .CC=filled aceDirentBuffer

kernFileStat = *
   jsr kernMiscDeviceInfo
   bcs +
   lda #aceErrIllegalDevice
   sta errno
   sec
   rts
+  lda syswork+1
   sta openDevice
   lda #"r"
   sta openMode
   lda #"#"
   sta cmdPrefix
   lda #2
   sta openNameScan
   jsr pidCommandSend
   lda #<fstatRespHandler
   ldy #>fstatRespHandler
   jmp pidCommandResponse
fstatRespHandler = *
   lda #<aceDirentBuffer
   ldy #>aceDirentBuffer
   ldx #aceDirentLength
   jsr kernModemGet
   lda aceDirentNameLen
   bne +
   sec
   rts
+  lda aceDirentBytes+0
   ldy aceDirentBytes+1
   rts


;*** aceFileIoctl ( .X=virt. device, (zp)=io cmd ) : .CS=error,errno

kernFileIoctl = *
   stx openDevice
   +ldaSCII "w"
   sta openMode
   lda #"="
   sta cmdPrefix
   lda #0
   sta openNameScan
   jsr pidCommandSend
   jmp pidCommandFinish

;*** aceFileFdswap( .X=Fcb1, .Y=Fcb2 )

kernFileFdswap = *
   lda lftable,x
   pha
   lda lftable,y
   sta lftable,x
   pla
   sta lftable,y
   lda devtable,x
   pha
   lda devtable,y
   sta devtable,x
   pla
   sta devtable,y
   lda satable,x
   pha
   lda satable,y
   sta satable,x
   pla
   sta satable,y
   lda eoftable,x
   pha
   lda eoftable,y
   sta eoftable,x
   pla
   sta eoftable,y
   lda pidtable,x
   pha
   lda pidtable,y
   sta pidtable,x
   pla
   sta pidtable,y
   ; IDUN: also fix up fileinfoTable
   jmp pidFdswap

;====== directory calls ======

;*** aceDirOpen( (zp)=deviceName ) : .A=fcb

kernDirOpen = *
   lda #true
   sta checkStat
   jsr getDiskDevice
   bcc +
   rts
+  sta openDevice
   sty openNameScan
   jsr getLfAndFcb
   bcc +
   rts
+  sta lftable,x
   lda openDevice
   sta devtable,x
   lda #0
   sta eoftable,x
   lda #0
   sta satable,x
   stx openFcb
   ldx openDevice
   lda configBuf+0,x
   ; IDUN: Replace with acepid for type #4/7
   cmp #4
   bne +
   jmp pidDirOpen
+  cmp #7
   bne +
   jmp pidDirOpen
+  +ldaSCII "$"
   sta stringBuffer+0
   +ldaSCII "0"
   sta stringBuffer+1
   lda #0
   sta stringBuffer+2
   ldx #2
   jsr dirOpenSetName
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

   dirOpenSetName = *
   ldy openDevice
   lda configBuf+3,y
   bmi dirNameDate
   ldy openNameScan
   lda (zp),y
   bne +
   rts
+  ldx #1

   dirNameNormal = *
-  lda (zp),y
   sta stringBuffer,x
   beq +
   iny
   inx
   bne -
+  dex
   +ldaSCII ":"
   cmp stringBuffer,x
   beq +
   inx
   sta stringBuffer,x
+  inx
   +ldaSCII "*"
   sta stringBuffer,x
   inx
   lda #0
   sta stringBuffer,x
   rts

   dirNameDate = *
   +ldaSCII "="
   sta stringBuffer+1
   +ldaSCII "t"
   sta stringBuffer+2
   ldx #3
   ldy openNameScan
   jsr dirNameNormal
   +ldaSCII "="
   sta stringBuffer,x
   inx
   +ldaSCII "l"
   sta stringBuffer,x
   inx
   lda #0
   sta stringBuffer,x
   rts

;*** aceDirClose( ... ) : ...

kernDirClose = *
   tax
   lda pidtable,x
   cmp aceProcessID
   beq +
   clc
   rts
+  stx closeFd
   ldy devtable,x
   jmp internCloseCont

;*** aceDirRead( .X=fcb ) : .Z=eof, aceDirentBuffer=data

dirBlocks = syswork+0

kernDirRead = *
   ; ensure aceDirentBytes is zero
   lda #0
   ldy #3
-  sta aceDirentBytes,y
   dey
   bpl -
   ldy devtable,x
   lda configBuf+0,y
   ; IDUN: Replace with acepid for type #4/7
   cmp #4
   bne +
   jmp pidDirRead
+  cmp #7
   bne +
   jmp pidDirRead
+  lda lftable,x
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
   bne dirreadEofExit
   jsr kernelChrin
   ora syswork+4
   bne +

   dirreadEofExit = *
   jsr kernelClrchn
   ldx #0
   rts
   dirreadErrExit = *
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
   bcs dirreadErrExit
   bit st
   bvs dirreadErrExit
   +cmpASCII " "
   beq -
   cmp #18
   beq -
   cmp #$22
   bne dirreadExit
   ldx #0
-  jsr kernelChrin
   bcs dirreadErrExit
   bit st
   bvs dirreadErrExit
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
   jmp dirTypeFirst
-  jsr kernelChrin
   dirTypeFirst = *
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
   jmp dirreadExit
+  +cmpASCII "p"
   bne dirreadExit
   lda aceDirentFlags
   ora #%00010000
   sta aceDirentFlags
   jmp dirreadExit

   dirreadExit = *
   jsr kernelChrin
   cmp #0
   bne +
   jmp dirreadRealExit
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
   beq dirreadRealExit
   +cmpASCII "0"
   bcc -
   cmp #$3a
   bcs -

   dirreadDate = *
   jsr dirGetNumGot
   bcs dirreadRealExit
   sta aceDirentDate+2
   jsr dirGetNum
   bcs dirreadRealExit
   sta aceDirentDate+3
   jsr dirGetNum
   bcs dirreadRealExit
   sta aceDirentDate+1
   ldx #$19
   cmp #$70
   bcs +
   ldx #$20
+  stx aceDirentDate+0  ;century
   jsr dirGetNum
   bcs dirreadRealExit
   sta aceDirentDate+4
   jsr dirGetNum
   bcs dirreadRealExit
   sta aceDirentDate+5
   jsr kernelChrin
   and #$ff
   beq dirreadRealExit
   jsr kernelChrin
   and #$ff
   beq dirreadRealExit
   +cmpASCII "a"
   bne dirreadPM

   dirreadAM = *
   lda aceDirentDate+4
   cmp #$12
   bne +
   lda #$00
   sta aceDirentDate+4
   jmp +

   dirreadPM = *
   lda aceDirentDate+4
   cmp #$12
   beq dirReadInternBr
   clc
   sed
   adc #$12
   cld
   sta aceDirentDate+4
dirReadInternBr:
   jsr kernelChrin
   cmp #0
   bne dirReadInternBr

   dirreadRealExit = *
   jsr kernelClrchn
   ldx #$ff
   clc
   rts

   dirGetNum = *
-  jsr kernelChrin
   dirGetNumGot = *
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

;*** aceDirIsdir( (zp)=FilenameZ ) : .A=Dev, .X=isDisk, .Y=isDir

kernDirIsdir = *
   jsr getDevice
   pha
   tax
   lda configBuf+0,x
   cmp #4
   bne +
   ldx #false
   jmp ++
+  cmp #1
   beq +
   cmp #7
   beq +
   ldx #false
   ldy #false
   jmp isDirExit
+  ldx #true
++ ldy #255
-  iny
   lda (zp),y
   bne -
   dey
   lda (zp),y
   ldy #true
   +cmpASCII ":"
   beq isDirExit
   ldy #false

   isDirExit = *
   pla
   rts

;*** aceDirChange( (zp)=DirName, .A=flags($80=home,$40=parent) )

chdirDevice = syswork+0
chdirNameScan = syswork+1
chdirParent !byte $5f,0

kernDirChange = *
internDirChange = *
   cmp #$40
   bne +
   lda #<chdirParent
   ldy #>chdirParent
   sta zp+0
   sty zp+1
   jmp ++
+  cmp #$80
   bne ++
   lda #<configBuf+$80
   ldy #>configBuf+$80
   sta zp+0
   sty zp+1
++ jsr getDiskDevice
   bcc +
   rts
+  sty chdirNameScan
   sta chdirDevice
   ; IDUN: Replace with acepid for virtual drives/floppies.
   cpx #4
   bne +
   ldx chdirDevice
   jmp pidChDir
+  cpx #7
   bne +
   ldx chdirDevice
   jmp pidChDir
+  +ldaSCII "c"
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
   beq chdirSetName
   lda chdirDevice
   jsr cmdchOpen
   bcc +
   rts
+  jsr cmdchSend
   bcs chdirAbort
   jsr checkDiskStatus
   bcs chdirAbort
   jsr cmdchClose
   lda #0
   sta stringBuffer+2

   chdirSetName = *
   lda chdirDevice
   sta aceCurrentDevice
   lsr
   lsr
   ora #$40
   sta aceCurDirName+0
   +ldaSCII ":"
   sta aceCurDirName+1
   lda #0
   sta aceCurDirName+2
   clc
   rts

   chdirAbort = *
   jsr cmdchClose
   sec
   rts

;*** aceIecCommand( (zp)=Command )

kernIecCommand = *
   sta syswork
   sty syswork+1
   ldx #0
   ldy #0
-  lda (zp),y
   sta stringBuffer,x
   beq +
   iny
   inx
   bne -
+  lda aceCurrentDevice
   jsr cmdchOpen
   bcs ++
   jsr cmdchSend
   bcs +
   jsr checkDiskStatus
+  php
   jsr cmdchClose
   plp
++ rts

;*** aceDirName( .A=sysdir, (zp)=buf, .Y=assignLen ) : buf, .Y=len
;***   .A : 0=curDir, 1=homedir, 2=execSearchPath, 3=configSearchPath, 4=tempDir
;***   .A : $80+above: assign directory

dirnamePath   !byte 0
dirnameSet    !byte 0
dirnameSetLen !byte 0

kernDirName = *
   ldx #$00
   cmp #$80
   bcc +
   sty dirnameSetLen
   ldx #$ff
+  stx dirnameSet
   and #$07
   ldx #$ff
   cmp #2
   bne +
   ldx #$e0
   stx dirnamePath
   ldy #>configBuf
   jmp ++
+  cmp #4
   bne +
   ldx #$ec
   stx dirnamePath
   ldy #>configBuf
   jmp ++
+  ldx #$00
   stx dirnamePath
   ldx #<aceCurDirName
   ldy #>aceCurDirName
++ stx syswork+0
   sty syswork+1
   bit dirnameSet
   bmi dirnameSetCopy
   ldy #0
-  lda (syswork+0),y
   sta (zp),y
   beq +
   iny
   bne -
+  bit dirnamePath
   bpl +
   iny 
   lda (syswork+0),y
   bne -
   sta (zp),y
+  rts

   dirnameSetCopy = *
   ldy #0
-  lda (zp),y
   sta (syswork+0),y
   iny
   cpy dirnameSetLen
   bcc -
   rts

;====== time calls ======

;*** aceTimeGetDate( (.AY)=dateString )  fmt:YY:YY:MM:DD:HH:MM:SS:TW
;                                             0  1  2  3  4  5  6  7

prevHour !byte 0

kernTimeGetDate = *
internGetDate = *
   php
   sei
   sta syswork+$e
   sty syswork+$f
   ldy #3
-  lda aceDate,y
   sta (syswork+$e),y
   dey
   bpl -
   ldy #4
   lda cia1+$b
   bpl +
   and #$1f
   sed
   clc
   adc #$12
   cld
+  cmp #$12
   bne +
   lda #$00
+  cmp #$24
   bne +
   lda #$12
+  sta (syswork+$e),y
   iny
   lda cia1+$a
   sta (syswork+$e),y
   iny
   lda cia1+$9
   sta (syswork+$e),y
   iny
   lda cia1+$8
   asl
   asl
   asl
   asl
   ora aceDOW
   sta (syswork+$e),y
   ;** check for increment date
   ldy #4
   lda (syswork+$e),y
   cmp prevHour
   sta prevHour
   bcs +
   ldy #3
   lda aceDate,y
   sed
   clc
   adc #$01
   cld
   sta aceDate,y
   sta (syswork+$e),y
   ;** exit
+  plp
   clc
   rts

;*** aceTimeSetDate( (.AY)=dateString )

kernTimeSetDate = *
   sta syswork+0
   sty syswork+1
   ldy #3
-  lda (syswork),y
   sta aceDate,y
   dey
   bpl -
   ldy #4
   lda (syswork),y
   sta prevHour
   cmp #$13
   bcc +
   sed
   sec
   sbc #$12
   cld
   ora #$80
+  sta cia1+$b
   iny
   lda (syswork),y
   sta cia1+$a
   iny
   lda (syswork),y
   sta cia1+$9
   iny
   lda (syswork),y
   lsr
   lsr
   lsr
   lsr
   sta cia1+$8
   lda (syswork),y
   and #$07
   sta aceDOW
   rts


;====== miscellaneous calls ======

;*** aceMiscUtoa( $0+X=value32, (zp)=buf, .A=minLen ) : buf, .Y=len

utoaBin = syswork+2     ;(4)
utoaBcd = syswork+6     ;(5)
utoaFlag = syswork+11   ;(1)
utoaLen = syswork+12    ;(1)
utoaPos = syswork+13    ;(1)
utoaInitOff !byte 0      ;(1)

kernMiscUtoa = *
   ldy #0
   sty utoaInitOff
   cmp #0
   bne +
   lda #1
+  cmp #11
   bcc +
   sec
   sbc #10
   sta utoaInitOff
   ;.y == 0
   +ldaSCII " "
-  sta (zp),y
   iny
   cpy utoaInitOff
   bcc -
   lda #10
+  sta utoaLen
   sec
   lda #10
   sbc utoaLen
   sta utoaLen
   ldy #0
-  lda 0,x
   sta utoaBin,y
   inx
   iny
   cpy #4
   bcc - 
   ldx #4
   lda #0
-  sta utoaBcd,x
   dex
   bpl -
   sta utoaFlag
   ldy #32
   sed

   utoaNextBit = *
   asl utoaBin+0
   rol utoaBin+1
   rol utoaBin+2
   rol utoaBin+3
   ldx #4
-  lda utoaBcd,x
   adc utoaBcd,x
   sta utoaBcd,x
   dex
   bpl -
   dey
   bne utoaNextBit
   cld
   
   lda #10
   sta utoaPos
   ldx #0
   ldy utoaInitOff
-  lda utoaBcd,x
   jsr utoaPutHex
   inx
   cpx #5
   bcc -
   lda #0
   sta (zp),y
   rts

   utoaPutHex = *
   pha
   lsr
   lsr
   lsr
   lsr
   jsr utoaPutDigit
   pla
   and #$0f

   utoaPutDigit = *
   dec utoaPos
   beq utoaForceDigit
   cmp utoaFlag
   bne utoaForceDigit
   dec utoaLen
   bmi +
   rts
+  lda #$20
   bne utoaPoke
   utoaForceDigit = *
   ora #$30
   sta utoaFlag
   
   utoaPoke = *
   sta (zp),y
   iny
   rts

;*** aceMiscIoPeek( (zw)=ioaddr, .Y=offset ) : .A=data

kernMiscIoPeek = *
   lda #bkKernel
   sta bkSelect
   lda (zw),y
   pha
   lda #bkApp
   sta bkSelect
   pla
   rts

;*** aceMiscIoPoke( (zw)=ioaddr, .Y=offset, .A=data )

kernMiscIoPoke = *
   pha
   lda #bkKernel
   sta bkSelect
   pla
   sta (zw),y
   pha
   lda #bkApp
   sta bkSelect
   pla
   rts

;*** aceMiscSysType () : .A=model, .X=int. banks, .Y=ERAM banks
;                        .sw+0=vdc mem.
kernMiscSysType = *
   ldx aceInternalBanks
   ldy aceEramBanks
   lda configBuf+$aa
   sta syswork+0
   lda aceSystemType
   rts

;*** aceMiscDeviceInfo( (zp)=path: .A=iec addr,.X=type,.Y=scan pos
;                                  sw=flags,sw+1=device,.CS=virt.drv )
kernMiscDeviceInfo = *
   jsr getDevice
   sty syswork+2
   sta syswork+1
   tay
   lda configBuf+3,y
   sta syswork+0
   lda configBuf+0,y
   tax
   lda configBuf+1,y
   ldy syswork+2
   cpx #7
   bne +
   sec
   rts
+  cpx #4
   bne +
   sec
   rts
+  clc
   rts


;*** aceMountImage ( (zp)=image file .X=device, .A=R/W flag)
;                    : .CS=error,errno
kernMountImage = *
   sta regsave+0
   stx regsave+1
   bmi +
   +ldaSCII "r"
   sta regsave+0
   jmp ++
+  +ldaSCII "w"
   sta regsave+0
++ jsr open
   bcc +
   rts
+  pha            ;store image file fd
   ldx regsave+1
   lda regsave+0
   jsr pidMount
   pla
   php
   jsr close      ;close image file
   plp
   bcs +
   lda #0
-  sta errno
   rts
+  lda #aceErrFileTypeMismatch
   jmp -

;*** aceFileCopyHost ( .A=src Fcb, .X=dest Fcb) : .CS=error,errno
; Prerequisites:
; 1. Both source file and destination must be virtual disk files (type #4/7)
; 2. Source file must be valid open'd Fcb
; 3. Destination must be valid, open'd Command Channel (Lfn #31) Fcb
kernCopyHost = *
   jmp pidCopyLocal   

;====== support functions ======

;*** getDevice( zp=filenameZ ) : .A=device, .Y=scanPos

getDevice = *
   ldy #0
   lda (zp),y
   beq useDefault
   ldy #1
   lda (zp),y
   +cmpASCII ":"
   bne useDefault
   ldy #0
   lda (zp),y
   ldy #2
   +cmpASCII "."
   bne +
   lda aceCurrentDevice
   jmp gotDev
+  and #$1f
   asl
   asl
   jmp gotDev
   
   useDefault = *
   lda aceCurrentDevice
   ldy #0

   gotDev = *
   rts

getFcb = *
   ldx #0
-  lda lftable,x
   bmi +
   inx
   cpx #fcbCount
   bcc -
   lda #aceErrTooManyFiles
   sta errno
   sec
   rts
+  lda aceProcessID
   sta pidtable,x
   rts
   
getLfAndFcb = * ;() : .X=fcb, .A=lf
   jsr getFcb
   bcc +
   rts
   openLfSearch = *
+  inc newlf
   lda newlf
   and #$1f
   sec
   sbc #1
   ldy #fcbCount-1
-  cmp lftable,y
   beq openLfSearch
   dey
   bpl -
   clc
   rts

getDiskDevice = *  ;( (zp)=devname ) : .A=device, .Y=scan, .X=dev_t, .CC=isDisk
   jsr getDevice
   pha
   tax
   lda configBuf+0,x
   cmp #1
   bne +
-  tax
   pla
   clc
   rts
+  cmp #4
   beq -
   cmp #7
   beq -
   pla
   lda #aceErrDiskOnlyOperation
   sta errno
   sec
   rts


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