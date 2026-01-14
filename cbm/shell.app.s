; Idun Shell, Copyright© 2025 Brian Holdsworth
; This is free software, released under the MIT License.

; This application provides a custom tty that runs the Linux
; shell. It includes a set of Idun command handlers for those
; commands that Linux will forward to this app.
!source "sys/toolbox.asm"
!source "sys/toolhead.asm"

jmp Init

; Zero-page
cmdPtr   = $60  ;(1)
argPtr   = $62  ;(2)  ;pointer to args
tempPtr  = $64  ;(2)  ;temp. pointer
count    = $66  ;(1)  ;temp. counter
argCnt   = $66  ;(1)  ;reuse for args counter
procId   = $68  ;(4)  ;process Id for redirection
; String constants we'll need
; home !pet "c:",0
tty_path !pet "z:tty",0

; Arguments strings for launching `tty`
neo_exec !word 6,12,0
neofetch !pet "_:tty",0,"x:bash --rcfile ~/.newshell",0
neo_exec_sz = * - neo_exec
tty_exec !word 6,12,0
tty_tool !pet "_:tty",0,"x:",0
tty_exec_sz = * - tty_exec

; Error strings we hope we don't need
errResident !pet "Failed to make commands resident.",0
errChrset !pet "Failed to load ANSI chrset.",0
errNotFound !pet "Error: File not found",13,10,0
errAnykey !pet "Press <Enter> to continue.",13,10,0
errUnrecognized !pet "Error: Command unrecognized",13,10,0

; Jump table for all the command handlers
CmdTable:
   jmp exec          ;0 command
   jmp go            ;1
   jmp load          ;2
   jmp dir           ;3
   jmp catalog       ;4
   jmp drives        ;5
   jmp mount         ;6
   jmp assign        ;7

;=== Init (one-time) ===
Init = *
   ; aceSharedBuf is used for linux sharing it's cd path
   ; as a nul-term petscii string. Make sure it starts off
   ; empty/ignored.
   lda #0
   sta aceSharedBuf
   ;Try to enable soft-80 columns for C64 mode
   jsr aceMiscSysType
   bmi +
   jsr aceWinSize
   cpx #80
   beq +
   lda #0
   ldx #80
   jsr aceWinScreen
   jsr toolWinRestore
+  jmp Startup

   errorLoadCmd = *
   lda #<errResident
   ldy #>errResident

   errorExit = *
   jsr puts
   jsr aceConGetkey
   lda #0
   ldx #0
   jmp aceProcExit

shellName: !byte 0,0
;=== Startup. Makes shell resident for fast reload. ===
Startup = *
   ;get default shell app
   ldx #15
   clc
   jsr aceConOption
   lda zp+0
   sta shellName+0
   lda zp+1
   sta shellName+1
   ;check fast reload code in ERAM
   ldx #0
   jsr aceSearchPath
   jsr open
   bcs +
   jsr close
   jmp NeoTty
   ;determine size of shell.app above aceToolAddress
+  lda #<bss+1
   sec
   sbc #<aceToolAddress
   sta zw+0
   lda #>bss
   sbc #>aceToolAddress
   sta zw+1
   ;allocate and tag mem holding fast reload code
   lda #<aceToolAddress
   ldy #>aceToolAddress
   ldx #$ff       ;using system area
   jsr new
   bcc +
   rts
+  lda shellName+0
   ldy shellName+1
   jsr memtag
   ; make `tty` command memory-resident
   lda #<tty_path
   ldy #>tty_path
   sta zp
   sty zp+1
   jsr resident
   ; set the machine type and num. mem banks
   jsr aceMiscSysType
   pha
   ; assume .Y is the count for ERAM 16K banks
   cpy #255
   bne +
   ldy #64
   sty count
   jmp ++
+  sty count
   lsr count
   lsr count
++ txa
   clc
   adc count
   tay
   pla
   ldx #$f2
   jsr aceMapperSetreg
   ;fall-through
   ;=== Initial bash tty runs fetch. ===
   NeoTty = *
   jsr ToolwinInit
   lda #<neofetch
   ldy #>neofetch
   sta zp
   sty zp+1
   lda #<neo_exec
   ldy #>neo_exec
   ldx #neo_exec_sz
   jsr toolSyscall
   jmp waitTty

   ; re-start tty normal (no neofetch hdr)
   Tty = *
   lda #<tty_tool
   ldy #>tty_tool
   sta zp
   sty zp+1
   lda #<tty_exec
   ldy #>tty_exec
   ldx #tty_exec_sz
   jsr toolSyscall

   waitTty = *
   lda aceSignalProc
   bpl +
   rts             ;Killed
+  cmp #64
   bcc Tty
   and #$3f
   sta cmdPtr
   ; Shell exec signalled -> run command
   ; The args are already present in hi-mem
   ; w/ argPtr pointing to the args block and
   ; process Id set if redirect is enabled.
   ; First, check if we need to update to a
   ; new working directory.
   lda aceSharedBuf
   beq +
   lda #<aceSharedBuf
   ldy #>aceSharedBuf
   sta zp
   sty zp+1
   lda #$00
   jsr aceDirChange
   ; Clear the working directory so we don't
   ; try to reuse it.
   lda #0
   sta aceSharedBuf
   ; Setup redirect?
+  lda #$ff
   sta shellRedirectStdout
   lda procId+0
   ora procId+1
   ora procId+2
   beq +
   jsr setupRedirect
   ; We have to calculate the jump table
   ; entry that corresponds to the cmdPtr.
+  lda #<CmdTable
   ldy #>CmdTable
   sta zp
   sty zp+1
   ldx cmdPtr
-  beq +
   lda zp
   clc
   adc #3
   sta zp
   lda zp+1
   adc #0
   sta zp+1
   dex
   jmp -
+  lda argPtr
   ldy argPtr+1
   sta zw
   sty zw+1
   ; if cmdPtr==0, load external process
   ; otherwise, call local sub-routine.
   lda cmdPtr
   bne +
   ; First arg is cmd name
   lda #0
   ldy #0
   jsr getarg
   ; Release joystick capture for extern cmds
   lda joykeyCapture
   and #$7f
   sta joykeyCapture
   lda argCnt
   ldy #0
   jsr aceProcExec
   jsr closeRedirect
   jmp Tty
+  lda argCnt
   ldy #0
   jsr aceProcExecSub
   jsr closeRedirect
   jmp Tty

setupRedirect = *
   lda #<UtoaNumber
   ldy #>UtoaNumber
   sta zp+0
   sty zp+1
   lda #1
   ldx #procId
   jsr aceMiscUtoa
   lda #<redirFile
   ldy #>redirFile
   sta zp+0
   sty zp+1
   +ldaSCII "W"
   jsr open
   bcs +
   sta shellRedirectStdout
   tay
   ldx #1
   jsr aceFileFdswap
+  rts

closeRedirect = *
   lda shellRedirectStdout
   bpl +
   rts
+  pha
   tay
   ldx #1
   jsr aceFileFdswap
   pla
   jsr close
   rts

reTagName = $02
resident = *
   lda zp+0
   clc
   adc #2
   sta reTagName
   lda zp+1
   adc #0
   tay
   lda reTagName
   ldx #$ff          ;using system area
   jsr mmap
   bcc +
   cmp #aceErrFileExists
   bne +
   clc
+  rts

;******** error handling ********
fileError = *
   lda errno
   cmp #4
   bne +
   lda #<errNotFound
   ldy #>errNotFound
   jmp ++
+  lda #<errUnrecognized
   ldy #>errUnrecognized
++ jsr puts
   jmp waitKey

waitKey = *
   lda #<errAnykey
   ldy #>errAnykey
   jsr puts
   jsr aceConGetkey
   rts

;******** command handlers ********

;===go===
go = *
   lda #0
   ldy #0
   jsr getarg
   lda #aceRestartApplReset
   jmp aceRestart

;===load===
loadFd      = $02
loadDevType = $03
load = *
   ;open the file
   lda #0
   ldy #0
   jsr getarg
   lda #"r"
   jsr open
   bcc +
   jmp fileError
+  sta loadFd
   ;load from cart or from Iec device?
   jsr aceMiscDeviceInfo
   sta $102
   stx loadDevType
   cpx #1
   beq closeIec
   lda syswork+1
   lsr
   lsr
   ldx #255            ;CMD_STREAM_CHANNEL
   jsr aceMapperCommand
   jmp loadCont
   ;close Iec device only. Pid stays open.
   closeIec = *
   lda loadFd
   jsr close
   ;start the prg
   loadCont = *
   ldx loadDevType
   lda #aceRestartLoadPrg
   jmp aceRestart

;===dir/catalog===
;directory zp vars
dirArg     = 2
dirName    = 4
dirString  = 8
dirFcb     = 16
dirColumns = 17
dirCurCol  = 18
dirLong    = 19
dirSpaces  = 20
dirlineLen = 21
dirChCols  = 22
dirPaged   = 23
dirShown   = 24
dirCls     = 25
dirFiles   = 26
dirBytes   = 30
dirFree    = 34
dirFileSum = 38
dirCheckFi = 39
dirWork    = 40
;directory constants
chrQuote = 34

dir = *
   lda #FALSE
   sta dirFileSum
   sta dirLong
   sta dirCls
   jmp dirMainEntry
catalog = *
   lda #TRUE
   sta dirFileSum
   sta dirLong
   ldx aceArgc
   cpx #1
   beq +
   lda #0
   ldy #0
   jsr getarg
   ldy #0
   lda (zp),y
   +cmpASCII "/"
   bne +
   iny
   lda (zp),y
   +cmpASCII "p"
   bne +
   lda #TRUE
   sta dirCls
   jmp dirMainEntry
+  lda #FALSE
   sta dirCls
   ;fall-through
dirMainEntry = *
   ldy toolWinScroll+0
   dey
   sty dirPaged
   lda #FALSE
   sta dirShown
   lda #TRUE
   sta dirCheckFi
   ;get dirName argument
   lda aceArgc
   sec
   sbc #1
   ldy #0
   jsr getarg
   lda zp+0
   ldy zp+1
   sta dirName+0
   sty dirName+1
   jmp dirShow

dirStopped = *
   lda #<dirStoppedMsg
   ldy #>dirStoppedMsg
   jsr eputs
   lda #1
   ldx #0
   jmp aceProcExit
   dirStoppedMsg = *
   !pet "<Stopped>"
   !byte chrCR,0

dirError = *
   lda #<dirErrorMsg1
   ldy #>dirErrorMsg1
   jsr eputs
   lda dirName+0
   ldy dirName+1
   jsr eputs
   lda #<dirErrorMsg2
   ldy #>dirErrorMsg2
   jmp eputs

   dirErrorMsg1 = *
   !pet "Error reading file/directory "
   !byte chrQuote,0
   dirErrorMsg2 = *
   !byte chrQuote,chrCR,0

dirShow = *
   bit dirCheckFi
   bpl +
   lda #<dirName
   ldy #>dirName
   jsr aceDirIsdir
   cpy #0
   bne +
   jmp dirFile
+  lda dirCls
   beq +
   lda #chrCLS
   jsr putchar
+  lda dirLong
   bne dirLsLong

dirLsShort = *
   ldx toolWinScroll+1
   stx dirChCols
   dex
   txa
   ldx #0
-  inx
   sbc #20
   bcs -
   txa
   bne ++
   lda #1
++ sta dirColumns
   jmp dirCommon

dirLsLong = *
   ldx toolWinScroll+1
   stx dirChCols
   lda #1
   sta dirColumns

dirCommon = *
   lda #0
   sta dirCurCol
   ldx #3
-  sta dirBytes,x
   sta dirFiles,x
   sta dirFree,x
   dex
   bpl -

   dirGotName = *
   lda dirName+0
   ldy dirName+1
   sta zp+0
   sty zp+1
   jsr aceDirOpen
   bcc +
   jmp dirError
+  sta dirFcb
   ldx dirFcb
   jsr aceDirRead
   bcs dirExit
   ;Name of disk/directory can be zero-length
   ;beq dirExit
   jsr aceConStopkey
   bcc +
   jmp dirStopped
+  lda dirLong
   bpl dirNext
   jsr dirDisplayHeading

   dirNext = *
   ldx dirFcb 
   jsr aceDirRead
   bcs dirExit
   beq dirTrailerExit
   jsr aceConStopkey
   bcc +
   jsr dirExit
   jmp dirStopped
+  lda aceDirentName+0
   beq dirTrailerExit
   lda aceDirentUsage
   and #%00010000
   bne dirNext
   jsr dirDisplay
   jmp dirNext

   dirTrailerExit = *
   lda dirLong
   bpl dirExit
   jsr dirDisplayTrailer
   jmp dirExit

   dirExit = *
   lda dirCurCol
   beq +
   lda #chrCR
   jsr putchar
+  lda dirFcb
   jmp aceDirClose

dirDisplay = *
   ;check cls/paging flag
   bit dirCls
   bpl +
   jsr dirPaging
+  bit aceDirentFlags
   bmi ++
   inc dirFiles+0
   bne +
   inc dirFiles+1
   bne +
   inc dirFiles+2
   bne +
   inc dirFiles+3
+  ldx #0
   ldy #4
   clc
-  lda dirBytes,x
   adc aceDirentBytes,x
   sta dirBytes,x
   inx
   dey
   bne -
++ bit dirLong
   bmi +
   jmp dirDisplayShort
+  jsr dirSetupDirline
   lda #<dirline
   ldy #>dirline
   sta zp+0
   sty zp+1
   lda dirlineLen
   ldy #0
   ldx #stdout
   jmp write

dirPaging = *
   dec dirPaged
   bne +
   lda #<dirPauseMsg
   ldy #>dirPauseMsg
   jsr puts
   jsr aceConGetkey
   ldy toolWinScroll+0
   dey
   sty dirPaged
+  rts
dirPauseMsg !pet "<Pause>",chrBOL,0

;*            000000000011111111112222222222333333333344444444445555555555
;*       pos: 012345678901234567890123456789012345678901234567890123456789
dirline !pet "drwx*e-t  00-Xxx-00  12:00a 12345678 *SEQ  1234567890123456\n"
        !byte 0
dirFlagNames !pet "drwx*e-t"
dirDateStr   !pet "  00-Xxx-00  12:00a "
dirDateEnd = *

dirSetupDirline = *
   ;** flags
   ldx #0
   lda aceDirentFlags
-  asl
   pha
   +ldaSCII "-"
   bcc +
   lda dirFlagNames,x
+  sta dirline+0,x
   pla
   inx
   cpx #8
   bcc -

   ;** date
   jsr dirPutInDate
   ldx #dirDateEnd-dirDateStr-1
-  lda dirDateStr,x
   sta dirline+8,x
   dex
   bpl -

   ;** bytes
   ldx #3
-  lda aceDirentBytes,x
   sta dirFree,x
   dex
   bpl -
   lda #<UtoaNumber
   ldy #>UtoaNumber
   sta zp+0
   sty zp+1
   lda #8
   ldx #dirFree
   jsr aceMiscUtoa
   ldy #28
   lda dirChCols
   cmp #60
   bcs +
   ldy #8
+  ldx #0
-  lda UtoaNumber,x
   sta dirline,y
   iny
   inx
   cpx #8
   bcc -
   +ldaSCII " "
   sta dirline,y
   iny

   ;** unclosed flag
   lda dirline+4
   +cmpASCII "-"
   bne +
   +ldaSCII " "
+  sta dirline,y
   iny

   ;** filetype
   ldx #0
-  lda aceDirentType,x
   ora #$80
   sta dirline,y
   iny
   inx
   cpx #3
   bcc -
   +ldaSCII " "
   sta dirline,y
   iny
   sta dirline,y
   iny

   ;** filename
   ldx #0
-  lda aceDirentName,x
   beq +
   sta dirline,y
   iny
   inx
   bne -
+  lda #chrCR
   sta dirline,y
   iny
   lda #0
   sta dirline,y
   sty dirlineLen
   rts

dirDisplayShort = *
   lda #<aceDirentName
   ldy #>aceDirentName
   jsr puts
   inc dirCurCol
   lda dirCurCol
   cmp dirColumns
   bcc +
   lda #0
   sta dirCurCol
   lda #chrCR
   jmp putchar
+  ldy #$ff
-  iny
   lda aceDirentName,y
   bne -
   sty dirSpaces
   lda #20
   sbc dirSpaces
   sta dirSpaces
-  +ldaSCII " "
   jsr putchar
   dec dirSpaces
   bne -
   rts

dirDisplayHeading = *
   lda #<dirHeadingMsg
   ldy #>dirHeadingMsg
   jsr puts
   lda #<aceDirentName
   ldy #>aceDirentName
   jsr puts
   lda #chrCR
   jsr putchar
   rts

   dirHeadingMsg = *
   !pet "Dir: "
   !byte 0

dirDisplayTrailer = *
   ldx #3
-  lda aceDirentBytes,x
   sta dirFree,x
   dex
   bpl -
   ldx dirFileSum
   beq dirDisplayShortTrailer
   ldx #0
   ldy #0
-- lda dirTrailingMsg,x
   beq +
   cmp #4
   bcc dirStoreNum
   sta dirTrailBuf,y
   inx
   iny
   bne --
+  lda #<dirTrailBuf
   ldx #>dirTrailBuf
   sta zp+0
   stx zp+1
   tya
   ldy #0
   ldx #stdout
   jmp write

   dirDisplayShortTrailer = *
   lda #<UtoaNumber
   ldy #>UtoaNumber
   sta zp+0
   sty zp+1
   ldx #dirFree
   lda #0
   jsr aceMiscUtoa
   lda #<UtoaNumber
   ldy #>UtoaNumber
   jsr puts
   lda #<dirTrailShMsg
   ldy #>dirTrailShMsg
   jmp puts

   dirTrailShMsg = *
   !pet " bytes free"
   !byte chrCR,0

   dirStoreNum = *
   stx dirWork+0
   sty dirWork+1
   sec
   sbc #1
   asl
   asl
   adc #dirFiles
   tax
   lda #<UtoaNumber
   ldy #>UtoaNumber
   sta zp+0
   sty zp+1
   lda #1
   jsr aceMiscUtoa
   ldx #0
   ldy dirWork+1
-  lda UtoaNumber,x
   beq +
   sta dirTrailBuf,y
   inx
   iny
   bne -
+  ldx dirWork+0
   inx
   jmp --

   dirTrailingMsg = *
   !pet "files="
   !byte 1
   !pet "  bytes="
   !byte 2
   !pet "  free="
   !byte 3,chrCR,0

dirTrailBuf !fill 64,0

dirPutInDate = *
   ;** year
   lda aceDirentDate+1
   ldx #9
   jsr dirPutDigits
   ;** month
   lda aceDirentDate+2
   cmp #$10
   bcc +
   sec
   sbc #$10-10
+  tax
   lda dirMonthStr+0,x
   sta dirDateStr+5
   lda dirMonthStr+13,x
   sta dirDateStr+6
   lda dirMonthStr+26,x
   sta dirDateStr+7
   ;** day
   lda aceDirentDate+3
   ldx #2
   jsr dirPutDigits
   ;** hour
   +ldaSCII "a"
   tax
   lda aceDirentDate+4
   cmp #$00
   bne +
   lda #$12
   jmp dirPutHour
+  cmp #$12
   bcc dirPutHour
   pha
   +ldaSCII "p"
   tax
   pla
   cmp #$12
   beq dirPutHour
   sed
   sec
   sbc #$12
   cld
   dirPutHour = *
   stx dirDateStr+18
   ldx #13
   jsr dirPutDigits
   ;** minute
   lda aceDirentDate+5
   ldx #16
   jsr dirPutDigits
   rts

   dirPutDigits = *  ;( .A=num, .X=offset )
   pha
   lsr
   lsr
   lsr
   lsr
   ora #$30
   sta dirDateStr,x
   pla
   and #$0f
   ora #$30
   sta dirDateStr+1,x
   rts
 
   dirMonthStr = *
   !pet "XJFMAMJJASOND"
   !pet "xaeapauuuecoe"
   !pet "xnbrrynlgptvc"


dirFile = *
   ldx toolWinScroll+1
   cpx #60
   bcc +
   lda #<dirFileLongMsg
   ldy #>dirFileLongMsg
   jmp ++
+  lda #<dirFileShortMsg
   ldy #>dirFileShortMsg
++ jsr puts
   lda dirName+0
   ldy dirName+1
   jsr puts
   lda #chrCR
   jsr putchar
   rts

   dirFileLongMsg = *
   !pet "*argument is a file--option not supported: "
   !byte 0
   dirFileShortMsg = *
   !pet "*argument is a file-n: "
   !byte 0

;===drives===
devDrive !pet "a:",0
drives = *
   lda #$40
   sta devDrive
-  inc devDrive
   lda #<devDrive
   ldy #>devDrive
   sta zp
   sty zp+1
   jsr aceMiscDeviceInfo
   cpx #4
   bne +
   jsr DrivesShowDrv
   jmp ++
+  cpx #7
   bne ++
   jsr DrivesShowDrv
++ lda devDrive
   cmp #$5a
   bne -
   rts

   DrivesShowDrv = *
   lda #$80
   jsr aceDirStat
   bcc +
   rts
+  ldy #$ff
   ldx #$ff
-  iny
   inx
   lda (zp),y
   sta driveBuffer,x
   bne -
   lda #"="
   sta driveBuffer,x
   ldy #$ff
-  iny
   inx
   lda aceSharedBuf,y
   sta driveBuffer,x
   bne -
   ; append CR
   lda #chrCR
   sta driveBuffer,x
   inx
   txa
   ldx #<driveBuffer
   ldy #>driveBuffer
   stx zp
   sty zp+1
   ldy #0
   ldx #stdout
   jmp write
driveBuffer !fill 82,0

;===mount/assign===
devType = $02
mtErrorMsg1 = *
   !pet "Error: illegal target device",chrCR,0
mtErrorMsg2 = *
   !pet "Error: cannot open path",chrCR,0
mtErrorMsg3 = *
   !pet "Error: cannot mount path",chrCR,0
mtDoneMsg1   = *
   !pet "Mounted ",0
mtDoneMsg2   = *
   !pet " on ",0
mount = *
   lda #7
   sta devType
   jmp mountCont
assign = *
   lda #4
   sta devType
   ;fall-through
   mountCont = *
   ; get device argument (e.g. "d:")
   lda #0
   ldy #0
   jsr getarg
   ldy #0
   lda (zp),y
   sta devDrive
   ; get device type of mount drive
   lda #<devDrive
   ldy #>devDrive
   sta zp
   sty zp+1
   jsr aceMiscDeviceInfo
   cpx devType
   bne mtDeviceError
   ; get path argument
   lda #1
   ldy #0
   jsr getarg
   ; open the path
   lda devDrive
   +as_device
   tax
   lda devType
   cmp #7
   beq +
   jsr aceDirAssign     ;assign device
   jmp ++
   ; default is read-write
+  lda #"W"
   jsr aceMountImage    ;mount image
++ bcc mtDone
   lda errno
   cmp #aceErrFileTypeMismatch
   beq mtMountError
   jmp mtOpenError

   mtDeviceError = *
   lda #<mtErrorMsg1
   ldy #>mtErrorMsg1
   jmp eputs
   mtOpenError = *
   lda #<mtErrorMsg2
   ldy #>mtErrorMsg2
   jmp eputs
   mtMountError = *
   lda #<mtErrorMsg3
   ldy #>mtErrorMsg3
   jmp eputs
   mtDone = *
   lda #<mtDoneMsg1
   ldy #>mtDoneMsg1
   jsr puts
   ldx #stdout
   jsr zpputs
   lda #<mtDoneMsg2
   ldy #>mtDoneMsg2
   jsr puts
   lda #<devDrive
   ldy #>devDrive
   jsr puts
   lda #chrCR
   jmp putchar

;This is a plaeholder, since using exec causes an
;external command tool to be executed.
exec = *
   rts

;******** standard library ********

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
cls = *
   lda #chrCLS
   jmp putchar
getarg = *
   sty zp+1
   asl
   rol zp+1
   clc
   adc argPtr+0
   sta zp+0
   lda argPtr+1
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
redirFile      !pet "[:"
UtoaNumber     !fill 11,0

;=== bss ===
bss = *
macroUserCmds = * ;not used

!eof
;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2025 Brian Holdsworth                                    │
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