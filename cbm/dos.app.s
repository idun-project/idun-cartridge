; Idun Shell, Copyright© 2023 Brian Holdsworth
; This is free software, released under the MIT License.

; This application provides a shell that is a work-alike of the
; shell used in MS-DOS. Real Commodore disks and Idun Virtual
; drives are normally accessed using drive letters A: through Z:

; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)

; Idun Shell is the first app that gets loaded. So, it includes the
; Toolbox code. Toolbox remains resident for usage by those "tools"
; that are loaded into the TPA by Idun Shell.
!source "sys/toolbox.asm"
jmp DosStartup

chrQuote = 34
suppressPromptFlag  !byte 0

stackPtr = $60
name     = $62

parseArgc !byte 0,0
parseArgv !byte 0,0
shellExitFlag !byte 0
shellPromptFlag !byte 0
checkPromptFlag !byte 0
abortCommandFlag !byte 0
ssaverCountdown !byte 10
regsave !byte 0,0,0

shellTitle !pet "Idun Shell      "
shellName: !byte 0,0

;Hack alert- these kernel constants are needed for batch files;
;copied here from kernhead.asm.
aceTagsCur        = aceStatB+93  ;(1)
aceTagsStart      = aceStatB+94  ;(1)

;=== Dos Startup. Makes Dos resident for fast reload. ===
DosStartup = *
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
   jmp idunMacroStorage
   ;determine size of dos.app above aceToolAddress
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
   ;init user macro storage
idunMacroStorage = *
   ldx #aceMemInternal
   lda #1
   jsr aceMemAlloc
   bcs +
   lda mp+1
   sta macroCmdsStash+0
   lda mp+2
   sta macroCmdsStash+1
+  ldx #0
   lda #0
-  sta macroUserCmds,x
   inx
   bne -
   ;fall-through to dos shell init
idunDosMain = *
   ; IDUN: Remove parsing of arguments.
   jsr ToolwinInit
   lda #<shellTitle
   ldy #>shellTitle
   jsr toolStatTitle
   jsr ashrc
   ; Setup minute tmo- used for screen-saver
   ldx #13
   clc
   jsr aceConOption
   sta ssaverCountdown
   ldx #60
   lda #<minuteTimeout
   ldy #>minuteTimeout
   jsr toolTmoSecs
   ; cd HOME
   ; lda #$80
   ; jsr aceDirChange
   ; Start shell
   lda #stdin
   sta inputFd
   jsr shell
   rts

dosReinit = *
   lda toolWinRegion+0
   sec
   sbc #1 
   jsr ToolwinInit2
   lda #<shellTitle
   ldy #>shellTitle
   jsr toolStatTitle
   lda toolWinScroll+0
   sec
   sbc #1
   ldx #0
   jsr aceConPos
   ; Re-init for screen-saver
   ldx #13
   clc
   jsr aceConOption
   sta ssaverCountdown
   ldx #60
   lda #<minuteTimeout
   ldy #>minuteTimeout
   jsr toolTmoSecs
   ; Fetch user macros
   jsr macrosUpdate
   beq +
   jsr aceMemFetch
+  rts
macrosUpdateStash = *
   ; Stash user macros
   jsr macrosUpdate
   beq +
   jsr aceMemStash
+  rts
macrosUpdate = *
   lda #0
   sta mp+0
   lda macroCmdsStash+0
   sta mp+1
   ora macroCmdsStash+1
   beq +
   lda macroCmdsStash+1
   sta mp+2
   lda #aceMemInternal
   sta mp+3
   lda #<macroUserCmds
   ldy #>macroUserCmds
   sta zp+0
   sty zp+1
   lda #<256
   ldy #>256
+  rts

tempIndex = $3
minuteTimeout = *
   dec ssaverCountdown
   bne ++
   ldx #14
   clc
   jsr aceConOption
   ldy #0
   sty tempIndex
-  lda (zp),y
   beq +
   jsr aceMiscRobokey
   inc tempIndex
   ldy tempIndex
   jmp -
+  lda #chrCR
   ldx #$ff
   jsr aceMiscRobokey
   rts
++ ldx #60
   lda #<minuteTimeout
   ldy #>minuteTimeout
   jsr toolTmoSecs
   rts

ashrc = *
   lda #<ashrcName
   ldy #>ashrcName
   sta zp+0
   sty zp+1
   ;** mmap load the batch file
   lda #<memBatchTag
   ldy #>memBatchTag
   ldx #0
   jsr mmap
   bcc +
   jmp ashrcError
   ;** open mmap file
+  lda #<memBatchFile
   ldy #>memBatchFile
   sta zp+0
   sty zp+1
   +ldaSCII "r"
   jsr open
   ldx errno
   bne ashrcError
   sta inputFd
   ;** memBatchTag entry gets overwritten
   lda aceTagsStart
   sta aceTagsCur
   ;** execute shell as same process
   jsr shell
   ;** close and return
   lda inputFd
   jmp close
   ;** handle error
   ashrcError = *
   lda #<ashrcOpenError
   ldy #>ashrcOpenError
   jmp eputs

ashrcName    !pet "z:autoexec.bat",0
ssaverName   !pet "blanker",0
memBatchFile !pet "_:"
memBatchTag  !pet "membat",0
ashrcOpenError !pet ": cannot open "
             !byte chrQuote
             !pet "autoexec.bat"
             !byte chrQuote
             !pet " script for execution"
             !byte chrCR,0
scriptOpenError !pet ": cannot open shell script for execution",chrCR,0

shell = *
   lda #$ff
   sta checkPromptFlag
   sta shellRedirectStdin
   sta shellRedirectStdout
   sta shellRedirectStderr
   lda #0
   sta suppressPromptFlag

   getCommand = *
   ;reset screen saver timer
   ldx #13
   clc
   jsr aceConOption
   sta ssaverCountdown
   lda #0
   sta abortCommandFlag
   lda checkPromptFlag
   beq +
   jsr shellCheckPromptability
+  lda shellPromptFlag
   beq +
   lda suppressPromptFlag
   bne +
   lda #<argBuffer
   ldy #>argBuffer
   sta zp+0
   sty zp+1
   lda #0
   jsr aceDirName
   lda #<argBuffer
   ldy #>argBuffer
   jsr eputs
   lda #<shellReady2
   ldy #>shellReady2
   jsr eputs
+  lda #0
   sta suppressPromptFlag
   sta shellExitFlag
   lda aceMemTop+0
   ldy aceMemTop+1
   sta stackPtr+0
   sty stackPtr+1
   jsr shellGetArgs
   bcs shellFinish
   lda parseArgc+0
   ora parseArgc+1
   beq +
   lda abortCommandFlag
   bne +
   jsr setupRedirects
   jsr shellConstructFrame
   jsr shellExecCommand
   lda #$ff
   sta checkPromptFlag
   jsr unsetRedirects
+  jsr closeRedirects
   lda shellExitFlag
   cmp #0
   bne shellFinish
   jmp getCommand

   shellFinish = *
   rts
   die = *
   rts

shellReady2 !pet "> ",0

shellCheckPromptability = *
   lda inputFd
   ldx #$ff
   cmp #stdin
   beq +
   ldx #0
+  stx shellPromptFlag
   lda #0
   sta checkPromptFlag
   rts

;=== command parsing ===

argPtr = $02
argQuote = $03
argWasQuoted = $04

shellGetArgChar = *
   ldx inputFd
   jmp getc


shellGetArgs = *
   lda #0
   sta parseArgc+0
   sta parseArgc+1

   newarg = *
   jsr shellGetArgChar
   bcc +
   jmp argEof
+  +cmpASCII " "
   beq newarg
   cmp #chrTAB
   beq newarg
   cmp #chrCR
   bne +
   jmp argEndOfLine
   ;Ignore virtual drive commands
+  cmp #"$"    ;Cbm format directory listing
   bne +
   jmp newarg
+  cmp #"%"    ;Mount command
   bne +
   jmp newarg
+  cmp #"!"    ;Delete command
   bne +
   jmp newarg
+  cmp #"="    ;Rename command
   bne +
   jmp newarg
+  cmp #"+"    ;Copy command
   bne +
   jmp newarg
+  +cmpASCII ";"
   bne +
   lda #$ff
   sta suppressPromptFlag
   jmp argEndOfLine
+  +cmpASCII "#"
   bne ++
-  jsr shellGetArgChar
   bcc +
   jmp argEof
+  cmp #chrCR
   bne -
   jmp argEndOfLine

++ ldx #0
   stx argPtr
   stx argWasQuoted
+  cmp #92  ; cmp #"\"
   bne ++
   jsr shellGetArgChar
   bcc +
   jmp argEof
+  cmp #chrCR
   beq newarg
   jmp +++

++ nop

   argNewQuote = *
   ldx #0
   stx argQuote
   cmp #$22
   beq argStartQuote
   +cmpASCII "'"
   bne +++
   argStartQuote = *
   sta argQuote
   sta argWasQuoted
   jmp argNextChar

+++ldx argPtr
   sta argBuffer,x
   inc argPtr

   argNextChar = *
   jsr shellGetArgChar
   bcs argEof
   ldx argQuote
   bne argQuoteMode
   +cmpASCII " "
   beq argProcess
   cmp #chrTAB
   beq argProcess
-  +cmpASCII ";"
   bne +
   ldx argWasQuoted
   bne +
   lda #$ff
   sta suppressPromptFlag
   lda #chrCR
+  cmp #chrCR
   beq argProcess
   ldx argPtr
   sta argBuffer,x
   inc argPtr
   jmp argNextChar

   argQuoteMode = *
   cmp #0
   beq -
   cmp argQuote
   bne -
   jsr shellGetArgChar
   bcs argEof
   +cmpASCII " "
   beq argProcess
   cmp #chrTAB
   beq argProcess
   cmp #chrCR
   beq argProcess
   jmp argNewQuote

   argProcess = *
   pha
   ldx argPtr
   lda #0
   sta argBuffer,x
   jsr shellHandleArg
   pla
   cmp #chrCR
   beq argEndOfLine
   jmp newarg
   argEndOfLine = *
   clc
   argEof = *
   rts

shellHandleArg = *
   lda abortCommandFlag
   beq +
   rts
+  lda argWasQuoted
   bne ++
   ldx #stdin
   +ldaSCII "r"
   tay
   lda argBuffer
   +cmpASCII "<"
   beq shellHandleRedirect
   ldx #stdout
   pha
   +ldaSCII "W"
   tay
   pla
   +cmpASCII ">"
   beq shellHandleRedirect
   lda parseArgc+0
   bne +
   jsr checkMacros
   bcs +
   jmp shellStoreMacro
+  jsr checkWildcards
   bcc ++
   rts
++ jsr shellStoreArg
   rts

shellStoreArg = *
   lda stackPtr+0
   ldy stackPtr+1
   clc
   sbc argPtr
   bcs +
   dey
+  sta stackPtr+0
   sty stackPtr+1
   sta zp+0
   sty zp+1
   ldy #0
-  lda argBuffer,y
   sta (zp),y
   beq +
   iny
   bne -
+  lda parseArgc+1
   sta zp+1
   lda parseArgc+0
   asl
   rol zp+1
   clc
   adc #<argArgvBuffer
   sta zp+0
   lda zp+1
   adc #>argArgvBuffer
   sta zp+1
   ldy #0
   lda stackPtr+0
   sta (zp),y
   iny
   lda stackPtr+1
   sta (zp),y
   inc parseArgc+0
   bne +
   inc parseArgc+1
+  rts

shellHandleRedirect = *   ;( .X=fd, .Y=mode )
   lda #<argBuffer+1
   sta zp+0
   lda #>argBuffer+1
   sta zp+1
   lda argBuffer+1
   +cmpASCII ">"
   bne +
   jsr shellRedirInc
   +ldaSCII "A"
   tay
   lda argBuffer+2
+  +cmpASCII "!"
   bne +
-  ldx #stderr
   jsr shellRedirInc
   lda #0
+  +cmpASCII "&"
   beq -
   lda shellRedirectStdin,x
   cmp #255
   bne redirectMultiError
   tya
   stx cmdBuffer
   sta regsave
   jsr open
   bcs redirectError
   ldx cmdBuffer
   sta shellRedirectStdin,x
   rts

redirectError = *
   lda #<redirectErrorMsg
   ldy #>redirectErrorMsg
redirectErrorWmsg = *
   pha
   tya
   pha
   lda #$ff
   sta abortCommandFlag
   lda zp+0
   ldy zp+1
   jsr eputs
   pla
   tay
   pla
   jsr eputs
   rts

   redirectErrorMsg = *
   !pet ": Error opening redirection file.",chrCR,0

redirectMultiError = *
   lda #<redirectMultiErrorMsg
   ldy #>redirectMultiErrorMsg
   jmp redirectErrorWmsg

   redirectMultiErrorMsg = *
   !pet ": Error - Multiple redirections of same stream.",chrCR,0

shellRedirInc = *
   inc zp+0
   bne +
   inc zp+1
+  rts

shellSetupRed = 2

setupRedirects = *
unsetRedirects = *
   ldx #0
   stx shellSetupRed
-  lda shellRedirectStdin,x
   cmp #255
   beq +
   tay
   jsr aceFileFdswap
+  inc shellSetupRed
   ldx shellSetupRed
   cpx #3
   bcc -
   rts

shellCloseRed = 2

closeRedirects = *
   ldx #0
   stx shellCloseRed
-  lda shellRedirectStdin,x
   cmp #$ff
   beq +
   jsr close
   ldx shellCloseRed
   lda #$ff
   sta shellRedirectStdin,x
+  inc shellCloseRed
   ldx shellCloseRed
   cpx #3
   bcc -
   rts

wildPrefix = 10
wildSuffix = 11

checkWildcards = *
   lda #255
   sta wildPrefix
   sta wildSuffix
   ldx argPtr
-  dex
   cpx #255
   beq +
   lda argBuffer,x
   +cmpASCII ":"
   beq +
   +cmpASCII "*"
   bne -
   ldy wildSuffix
   cpy #255
   bne -
   stx wildSuffix
   inc wildSuffix
   jmp -
+  inx
   stx wildPrefix
   lda wildSuffix
   cmp #255
   bne +
   clc
   rts
+  jsr handleWildcards
   sec
   rts

wildLength = 12
wildSuffixLength = 13
wildFcb = 14
wildMatch = 15

handleWildcards = *
   lda #0
   sta wildMatch
   ldx argPtr
   inx
-  dex
   lda argBuffer,x
   sta cmdBuffer+1,x
   cpx wildPrefix
   bne -
   lda #0
   sta cmdBuffer,x
   sta argBuffer,x
   ldx wildSuffix
   sta cmdBuffer,x
   inc wildPrefix
   inc wildSuffix
   ldx #0
-  lda argBuffer,x
   beq +
   sta cmdBuffer,x
   inx
   bne -
+  sec
   lda argPtr
   sbc wildSuffix
   sta wildSuffixLength
   inc wildSuffixLength
   sec
   lda argPtr
   sbc wildPrefix
   sta wildLength

   ;lda #<cmdBuffer
   ;ldy #>cmdBuffer
   lda #<currentDir
   ldy #>currentDir
   sta zp+0
   sty zp+1
   jsr aceDirOpen
   bcs noMatch
   sta wildFcb
   ldx wildFcb
   jsr aceDirRead
   bcs +
   beq +
   jsr scanWildcard
+  lda wildFcb
   jsr aceDirClose
   lda wildMatch
   bne +
   noMatch = *
   lda #$ff
   sta abortCommandFlag
   lda #<noMatchMsg
   ldy #>noMatchMsg
   jsr eputs
+  rts
currentDir !pet ".:",0

noMatchMsg = *
   !pet "No match for wildcard"
   !byte chrCR,0

scanWildcard = *
   ldx wildFcb
   jsr aceDirRead
   bcs +
   bne ++
+  rts
++ lda aceDirentName
   bne +
   rts
+  lda aceDirentUsage
   and #%00010000
   bne scanWildcard
   lda aceDirentNameLen
   cmp wildLength
   bcc scanWildcard
   ldx wildPrefix
   ldy #0
   jsr substrCmp
   bcs scanWildcard
   ldx wildSuffix
   sec
   lda aceDirentNameLen
   sbc wildSuffixLength
   tay
   jsr substrCmp
   bcs scanWildcard

   ldx #0
-  lda cmdBuffer,x
   beq +
   sta argBuffer,x
   inx
   bne -
+  ldy #0
-  lda aceDirentName,y
   sta argBuffer,x
   beq +
   inx
   iny
   bne -
+  lda aceDirentType
   +cmpASCII "p"
   bne +
   sta argBuffer+1,x
   +ldaSCII ","
   sta argBuffer,x
   inx
   inx
   lda #0
   sta argBuffer,x
+  stx argPtr
   jsr shellStoreArg
   lda #$ff
   sta wildMatch
   jmp scanWildcard

substrCmp = *  ;( .X=cmdbufOff, .Y=direntNameOff ) : .CC=match
-  lda cmdBuffer,x
   bne +
   clc
   rts
+  cmp aceDirentName,y
   bne +
   iny
   inx
   bne -
+  sec
   rts

checkMacros = *
   ;** check if arg is a macro alias
+  lda #<argBuffer
   ldy #>argBuffer
   sta zp+0
   sty zp+1
   jsr DosMacroHandler
   rts

shellStoreMacro = *
   ldx #0
   stx argPtr
-- lda macroUserCmds,y
   sta argBuffer,x
   beq +          ;reached end of macro
   cmp #$20       ;reached end of argument
   beq insertArg
   iny
   inx
   inc argPtr
   jmp --
+  jmp shellStoreArg
insertArg:
   sty regsave+2  ;save .Y
   lda #0
   sta argBuffer,x
   jsr shellStoreArg
   ldy regsave+2
-  iny
   lda macroUserCmds,y
   cmp #$20
   beq -          ;skip any additional spaces
   ldx #0
   jmp --


;=== stack management ===

frameArgvSource = $02
frameArgvDest = $04
frameArgvBytes = $06

shellConstructFrame = *
   ;** push the ZERO trailer argv
   sec
   lda stackPtr+0
   sbc #2
   sta stackPtr+0
   bcs +
   dec stackPtr+1
+  ldy #0
   lda #0
   sta (stackPtr),y
   iny
   sta (stackPtr),y

   ;** push argv[] array here
   lda parseArgc+0
   ldy parseArgc+1
   sty frameArgvBytes+1
   asl
   sta frameArgvBytes+0
   rol frameArgvBytes+1
   sec
   lda stackPtr+0
   sbc frameArgvBytes+0
   sta stackPtr+0
   sta frameArgvDest+0
   lda stackPtr+1
   sbc frameArgvBytes+1
   sta stackPtr+1
   sta frameArgvDest+1
   lda #<argArgvBuffer
   ldy #>argArgvBuffer
   sta frameArgvSource+0
   sty frameArgvSource+1
-  lda frameArgvBytes+0
   ora frameArgvBytes+1
   beq frameSetArgvPtr
   ldy #0
   lda (frameArgvSource),y
   sta (frameArgvDest),y
   inc frameArgvSource+0
   bne +
   inc frameArgvSource+1
+  inc frameArgvDest+0
   bne +
   inc frameArgvDest+1
+  lda frameArgvBytes+0
   bne +
   dec frameArgvBytes+1
+  dec frameArgvBytes+0
   jmp -

   ;** set argv pointer
   frameSetArgvPtr = *
   lda stackPtr+0
   ldy stackPtr+1
   sta parseArgv+0
   sty parseArgv+1
   rts


;=== dispatch ===

dispArgv = $02
dispArgPtr = $04
dispVector = $02

shellExecCommand = *
   ;** fetch the command name
   lda parseArgv+0
   ldy parseArgv+1
   sta dispArgv+0
   sty dispArgv+1
   ldy #1
-  lda (dispArgv),y
   sta dispArgPtr,y
   sta name,y
   dey
   bpl -
   ldy #0
-  lda (dispArgPtr),y
   sta argBuffer,y
   beq +
   iny
   bne -

   ;** check for and handle "@" commands
+  lda argBuffer
   cmp #"@"
   bne +
   lda #13
   sta argBuffer,y
   iny
   lda #0
   sta argBuffer,y
   lda #<(argBuffer+1)
   ldy #>(argBuffer+1)
   sta zp
   sty zp+1
   jmp aceIecCommand

   ;** check for and handle drive-switch
+  ldy #2
   lda (name),y
   bne +
   dey
   lda (name),y
   cmp #":"
   bne +
   lda name+0
   ldy name+1
   sta zp+0
   sty zp+1
   jmp cdSetDevice

   ;** search internal dispatch table for name
+  ldy #0
   dispCmpCommand = *
   lda dispTable,y
   beq shellLoadExternal
   ldx #0
-  lda argBuffer,x
   cmp dispTable,y
   bne +
   cmp #0
   beq dispMatch
   inx
   iny
   bne -
   brk
+  dey
-  iny
   lda dispTable,y
   bne -
   iny
   iny
   iny
   jmp dispCmpCommand

   dispMatch = *
   lda dispTable+1,y
   cmp #<exec_batch
   bne +
   lda dispTable+2,y
   cmp #>exec_batch
   bne +
   jmp exec_batch
+  lda suppressPromptFlag
   pha
   lda dispTable+1,y
   pha
   lda dispTable+2,y
   tay
   pla
   jsr dispSetup
   jsr aceProcExecSub
   pla
   sta suppressPromptFlag
   rts

   dispSetup = *  ;( (.AY)=zp contents ) : zp, zw, .AY=argc
   sta zp+0
   sty zp+1
   lda parseArgv+0
   ldy parseArgv+1
   sta zw+0
   sty zw+1
   lda parseArgc+0
   ldy parseArgc+1
   rts

;** load external file into transient program area
; IDUN: If the command name ends with ".app", then
; check the signature and load new app overtop Dos.

shellLoadExternal = *
   jsr toolTmoCancel
   lda suppressPromptFlag
   pha
   lda name+0
   ldy name+1
   jsr dispSetup
   jsr aceProcExec
   bcs +
   pla
   sta suppressPromptFlag
   jsr dosReinit
   rts
+  pla
   sta suppressPromptFlag
   jsr dosReinit
   lda errno
   pha
   lda name+0
   ldy name+1
   jsr eputs
   pla
   cmp #aceErrFileNotFound
   beq dispCmdNotFound
   cmp #aceErrBadProgFormat
   beq dispBadProg
   lda #<dispLoadErrorMsg1
   ldy #>dispLoadErrorMsg1
   jmp eputs

   dispBadProg = *
   lda #<dispBadProgMsg
   ldy #>dispBadProgMsg
   jmp eputs

   dispCmdNotFound = *
   lda #<dispLoadErrorMsg2
   ldy #>dispLoadErrorMsg2
   jmp eputs
   dispLoadErrorMsg1 = *
   !pet ": External-program load error"
   !byte chrCR,0
   dispLoadErrorMsg2 = *
   !pet ": Command not found"
   !byte chrCR,0
   dispBadProgMsg = *
   !pet ": Bad external-program format"
   !byte chrCR,0


;===internal command name and dispatch table===

dispTable = *
!pet "funkey"
!byte 0
!word funkey
!pet "doskey"
!byte 0
!word doskey
!pet "echo"
!byte 0
!word echo
!pet "cd"
!byte 0
!word cd
!pet "type"
!byte 0
!word cat
!pet "cls"
!byte 0
!word cls
!pet "exit"
!byte 0
!word reset
!pet "reboot"
!byte 0
!word reboot
!pet "load"
!byte 0
!word loader
!pet "mem"
!byte 0
!word getmem
!pet "info"
!byte 0
!word getinfo
!pet "exec"
!byte 0
!word exec_batch
!pet "path"
!byte 0
!word path
!pet "dir"
!byte 0
!word dirCmdDir
!pet "resident"
!byte 0
!word resident
!pet "mount"
!byte 0
!word mount
!pet "assign"
!byte 0
!word assign
!pet "nix"
!byte 0
!word xex
!pet "linux"
!byte 0
!word xex
!pet "lua"
!byte 0
!word lua
!pet "basic"
!byte 0
!word basic
!pet "help"
!byte 0
!word launch_help
!byte 0  ;end built-in commands


;===reset===
reset = *
   jmp shellExit


;===reboot===
reboot = *
   jsr aceViceEmuCheck
   beq reset   ;just do a warm reset for emulator
   ldx #1      ;CMD_SYS_REBOOT
   lda #0      ;reboot C128 mode
   jmp aceMapperCommand


;===load===
loadFd      = 2
loadDevType = 3

loader = *
   lda #1
   jsr getarg
   beq ldUsageError
   ;check file exists
   loaderCont = *
   +ldaSCII "r"
   jsr open
   bcc +
   lda #<ldOpenError
   ldy #>ldOpenError
   jmp eputs
   ;prep for loading
+  sta loadFd
   jsr aceMiscDeviceInfo
   stx loadDevType
   bcs +
   jmp closeIec
+  sta $9b        ;Pass $ba and $9b/$9c values to BASIC
   sta $ba
   lda syswork+1
   lsr
   lsr
   sta $9c
   ldx #255            ;CMD_STREAM_CHANNEL
   jsr aceMapperCommand
   ldx loadDevType
   jmp loaderRestart
   ;close Iec device only. Pid device stays open
   ;for use by the MemMapper.
   closeIec = *
   lda loadFd
   sta $ba        ;substitute SETLFS
   jsr close
   ldx #1
   loaderRestart = *
   lda #aceRestartLoadPrg
   jmp aceRestart
   ldUsageError = *
   lda #<ldUsageStr
   ldy #>ldUsageStr
   jmp eputs

ldOpenError !pet "Error: cannot open file",chrCR,0
ldUsageStr  !pet "usage: load <filename>",chrCR,0

;===lua===
; Execute Lua command on host using `tty` for I/O
xePrefix  = 2  ;(2)

lua = *
   lda #<luaPrefix
   ldy #>luaPrefix
   sta xePrefix+0
   sty xePrefix+1
   jmp roboCmdCont
luaPrefix !pet "tty ",chrQuote,"l:",0

;===help===
; Execute Lua command on host using `tty` for I/O
launch_help = *
   lda #<helpPrefix
   ldy #>helpPrefix
   sta xePrefix+0
   sty xePrefix+1
   jmp roboCmdCont
helpPrefix !pet "tty ",chrQuote,"l:help.lua ",0

;===xex===
; Execute cli command on host using `tty` for I/O
xex = *
   lda #<nixPrefix
   ldy #>nixPrefix
   sta xePrefix+0
   sty xePrefix+1
roboCmdCont = *
   ldy #0
-  lda (xePrefix),y
   beq +
   jsr aceMiscRobokey
   iny
   jmp -
+  lda #1
   sta regsave
   ldy #0
   jsr getarg
   beq ++
-- ldy #0
-  lda (zp),y
   beq +
   jsr aceMiscRobokey
   iny
   jmp -
+  ldy #0
   inc regsave
   lda regsave
   jsr getarg
   beq ++
   lda #$20
   jsr aceMiscRobokey
   jmp --
++ lda #chrQuote
   jsr aceMiscRobokey
   lda #chrCR
   ldx #$ff
   jsr aceMiscRobokey
   rts
nixPrefix !pet "tty ",chrQuote,"x:",0

;===basic===
; Exit shell into a Basic 7.80 environment (C128 only)
basic = *
   jsr aceMiscSysType
   cmp #128
   bne +       ;C64 just exit to regular BASIC
   lda #<basicExtPrg
   ldy #>basicExtPrg
   sta zp+0
   sty zp+1
   jmp loaderCont
+  jmp shellExit
basicExtPrg !pet "z:basic780",0

;===unmount===
; unmtUsageMsg = *
;    !pet chrCR,"unmount [/w] [/f] [/d:]",chrCR
;    !pet "Unmount floppy image file",chrCR
;    !pet "- optional [/w] to write-back changes",chrCR
;    !pet "- optional [/f] to force ignore changes",chrCR
;    !pet "- optional device, default ",chrQuote,"d:",chrQuote
;    !pet chrCR,0

; unmount = *
;    lda #<unmtUsageMsg
;    ldy #>unmtUsageMsg
;    jmp eputs


;===mount===
mtWritable  = 2   ;(1)
mtArg       = 4   ;(1)
mtPathArg   = 5   ;(1)
mtDrive !pet "d:",0     ;default mount to d:

mtUsageMsg = *
   !pet "mount [/d:] [imagefile]",chrCR,chrCR
   !pet "Mounts image file as virtual floppy",chrCR
   !pet "- optionally specify drive letter (d: default)",chrCR
   !pet "- no args will list mounted drives",chrCR,0
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
   lda #0
   sta mtPathArg
   lda #$44
   sta mtDrive
   ; check for no args
   lda aceArgc+0
   sta mtArg
   dec mtArg
   cmp #2
   lda aceArgc+1
   sbc #0
   bcs mountNextArg
   jmp mountShowAll
   
   ; get arguments
   mountNextArg = *
   lda mtArg
   beq mountCont
   ldy #0
   jsr getarg
   ldy #0
   lda (zp),y
   +cmpASCII "/"
   bne mtRequiredArg
   iny
   lda (zp),y
   +cmpASCII "?"
   bne mtDriveArg
   jmp mtShowUsage
   
   mtDriveArg = *
   cmp #$40
   bcc mtShowUsage
   cmp #$5b
   bcs mtShowUsage
   sta mtDrive
   dec mtArg
   jmp mountNextArg

   ; handle required argument
   mtRequiredArg = *
   lda mtArg
   sta mtPathArg
   dec mtArg
   jmp mountNextArg

   mountCont = *
   lda #<mtDrive
   ldy #>mtDrive
   sta zp
   sty zp+1
   lda mtPathArg
   beq mountShowDrv
   ; get device type of mount drive
   jsr aceMiscDeviceInfo
   cpx #7
   bne mtDeviceError
   ; open the path
   ldy #0
   lda mtPathArg
   jsr getarg
   lda mtDrive
   +as_device
   tax
   ; default is read-write
   lda #"W"
   jsr aceMountImage
   bcc mtDone
   lda errno
   cmp #aceErrFileTypeMismatch
   beq mtMountError
   jmp mtOpenError

   mtShowUsage = *
   lda #<mtUsageMsg
   ldy #>mtUsageMsg
   jmp eputs
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
   ldy #0
   lda mtPathArg
   jsr getarg
   ldx #stdout
   jsr zpputs
   lda #<mtDoneMsg2
   ldy #>mtDoneMsg2
   jsr puts
   lda #<mtDrive
   ldy #>mtDrive
   jsr puts
   lda #chrCR
   jmp putchar

   mountShowDrv = *
   lda #$80
   jsr aceDirStat
   bcc +
   rts
+  ldx #stdout
   jsr zpputs
   lda #"="
   jsr putchar
   lda #<aceSharedBuf
   ldy #>aceSharedBuf
   jsr puts
   lda #chrCR
   jmp putchar

   mountShowAll = *
   lda #$40
   sta mtDrive
-  inc mtDrive
   lda #<mtDrive
   ldy #>mtDrive
   sta zp
   sty zp+1
   jsr aceMiscDeviceInfo
   cpx #7
   bne +
   jsr mountShowDrv
+  lda mtDrive
   cmp #$5a
   bne -
   rts


;===assign===
asUsageMsg = *
   !pet "assign [/d:] [directory]",chrCR,chrCR
   !pet "Assign directory as virtual drive",chrCR
   !pet "- /d = drive letter for assign",chrCR
   !pet "- no args lists assigned drives",chrCR,0
asDoneMsg1   = *
   !pet "Assigned ",0
asDoneMsg2   = *
   !pet " to ",0

assign = *
   lda #0
   sta mtPathArg
   sta mtDrive
   ; check for no args
   lda aceArgc+0
   sta mtArg
   dec mtArg
   cmp #2
   lda aceArgc+1
   sbc #0
   bcs assignNextArg
   jmp assignShowAll
   
   ; get arguments
   assignNextArg = *
   lda mtArg
   beq assignCont
   cmp #2
   beq asRequiredArg
   ldy #0
   jsr getarg
   ldy #0
   lda (zp),y
   +cmpASCII "/"
   bne asRequiredArg
   iny
   lda (zp),y
   +cmpASCII "?"
   bne asDriveArg
   jmp asShowUsage
   
   asDriveArg = *
   cmp #$40
   bcc asShowUsage
   cmp #$5b
   bcs asShowUsage
   sta mtDrive
   dec mtArg
   jmp assignNextArg

   ; handle required argument
   asRequiredArg = *
   lda mtArg
   sta mtPathArg
   dec mtArg
   jmp assignNextArg

   assignCont = *
   lda mtDrive
   beq asShowUsage
   lda #<mtDrive
   ldy #>mtDrive
   sta zp
   sty zp+1
   lda mtPathArg
   beq assignShowDrv
   ; get device type of mount drive
   jsr aceMiscDeviceInfo
   cpx #4
   beq +
   jmp mtDeviceError
   ; open the path
+  ldy #0
   lda mtPathArg
   jsr getarg
   lda mtDrive
   +as_device
   tax
   jsr aceDirAssign
   bcc asDone
   lda errno
   cmp #aceErrFileTypeMismatch
   bne +
   jmp mtMountError
+  jmp mtOpenError

   asShowUsage = *
   lda #<asUsageMsg
   ldy #>asUsageMsg
   jmp eputs
   asDone = *
   lda #<asDoneMsg1
   ldy #>asDoneMsg1
   jsr puts
   ldy #0
   lda mtPathArg
   jsr getarg
   ldx #stdout
   jsr zpputs
   lda #<asDoneMsg2
   ldy #>asDoneMsg2
   jsr puts
   lda #<mtDrive
   ldy #>mtDrive
   jsr puts
   lda #chrCR
   jmp putchar

   assignShowDrv = *
   lda #$80
   jsr aceDirStat
   bcc +
   rts
+  ldx #stdout
   jsr zpputs
   lda #"="
   jsr putchar
   lda #<aceSharedBuf
   ldy #>aceSharedBuf
   jsr puts
   lda #chrCR
   jmp putchar

   assignShowAll = *
   lda #$40
   sta mtDrive
-  inc mtDrive
   lda #<mtDrive
   ldy #>mtDrive
   sta zp
   sty zp+1
   jsr aceMiscDeviceInfo
   cpx #4
   bne +
   jsr assignShowDrv
+  lda mtDrive
   cmp #$5a
   bne -
   rts


;===mem===
gmTpa       = 2  ;(4)
gmDynFree   = 6  ;(4)
gmTotal     = 10 ;(4)
gmOption    = 14 ;(1)
gmTemp      = 15 ;(4)

;             |---------1---------2---------3---------4|
gmTpaMsg !pet "xxxxx application bytes available.",chrCR,0
gmUsageMsg = *
   !pet  "mem [/s]"
   !byte chrCR,chrCR
   !pet  "    /s : short-form system memory only"
   !byte chrCR,0

getmem = *
   ; clear variables
   lda #0
   ldx #$11
-  sta gmTpa,x
   dex
   bpl -
   ; default to long version
   lda #$ff
   sta gmOption 
   ; check for allowed options
   lda #1
   ldy #0
   jsr getarg
   lda zp+0
   ora zp+1
   beq ++       ; no optional arg
   ldy #0
   lda (zp),y
   +cmpASCII "/"
   beq +              ; invalid option prefix
   gmShowUsage = *
   lda #<gmUsageMsg   ; show help text and punt
   ldy #>gmUsageMsg
   jmp eputs
+  iny
   lda (zp),y
   sta gmOption ; option stored
   ; check for /h, /?, or unrecognized option
   +cmpASCII "s"
   beq ++
   jmp gmShowUsage
   ; get dynamic memory free/total
++ ldx #gmDynFree
   jsr aceMemStat
   lda #<gmMemMsg
   sta zp+0
   lda #>gmMemMsg
   sta zp+1
   ldx #gmTotal
   jsr getKb
   +ldaSCII "k"
   ldx #5
   sta gmMemMsg,x
   lda #<UtoaNumber
   sta zp+0
   lda #>UtoaNumber
   sta zp+1
   ldx #gmDynFree
   jsr getKb
   ldx #0
-  lda UtoaNumber, x
   sta gmMemMsg+25,x
   inx
   cpx #5
   bne -
   ; output system RAM/free as bordered text
   lda #0
   ldx #39
   jsr toolUserLayout
   lda #$80    ; border on
   sta toolUserStyles
   lda #2      ; text color
   sta toolUserColor
   jsr toolUserNode
   jsr toolUserLabel
;             |---------1---------2---------3---------4|
gmMemMsg !pet "xxxxxk RAM System        xxxxxk free.",0
   jsr toolUserEnd
   ; check if short option ('/s') was used
   lda gmOption
   +cmpASCII "s"
   bne +
   rts
   ; calculate and show application memory
+  sec
   lda aceMemTop+0
   sbc #<aceAppAddress
   sta gmTpa+0
   lda aceMemTop+1
   sbc #>aceAppAddress
   sta gmTpa+1
   lda #<gmTpaMsg
   sta zp+0
   lda #>gmTpaMsg
   sta zp+1
   ldx #gmTpa
   lda #5
   jsr aceMiscUtoa
   +ldaSCII " "
   ldx #5
   sta gmTpaMsg,x
   lda #<gmTpaMsg
   ldy #>gmTpaMsg
   jmp puts

getKb = *
   ; need to divide $0,X 32-bit value by 1024
   lda $0,x
   sta divn+4
   inx
   lda $0,x
   sta divn+5
   inx
   lda $0,x
   sta divn+2
   inx
   lda $0,x
   sta divn+3
   lda #$00
   sta divn
   lda #$04
   sta divn+1
   jsr div32
   lda #0
   sta gmTemp+2
   sta gmTemp+3
   lda divn+4
   sta gmTemp+0
   lda divn+5
   sta gmTemp+1
   ldx #gmTemp
   lda #5
   jmp aceMiscUtoa


;===info===
giOption       = 2  ;(1)
giDevice       = 3  ;(1)
giDeviceAsLong = 4  ;(4)
giVirtPath     = 8  ;(2)
giVirtFlags    = 10 ;(1)

giDeviceStr !pet  "x: ",0
giVirPath1  !pet  "home"
giVirPath2  !pet  "sys "
giVirPath3  !pet  "user"
giTtyDevs   !pet  "Interactive Terminals = ",0
giCtlDevs   !pet  "Controller Ports      = ",0
giOthDevs   !pet  "Other Active Devices  = ",0

giUsageMsg = *
   !pet  "info [/d]"
   !byte chrCR,chrCR
   !pet  "    /d : short-form disk devices only"
   !byte chrCR,0

getinfo = *
   ; clear variables
   ldx #3
   lda #0
-  sta giDeviceAsLong,x
   dex
   bpl -
   ; default to long version
   lda #$ff
   sta giOption 
   ; check for allowed options
   lda #1
   ldy #0
   jsr getarg
   lda zp+0
   ora zp+1
   beq ++       ; no optional arg
   ldy #0
   lda (zp),y
   +cmpASCII "/"
   beq +              ; invalid option prefix
   giShowUsage = *
   lda #<giUsageMsg   ; show help text and punt
   ldy #>giUsageMsg
   jmp eputs
+  iny
   lda (zp),y
   sta giOption ; option stored
   ; check for /h, /?, or unrecognized option
   +cmpASCII "d"
   beq ++
   jmp giShowUsage
   ; initialize toolText
++ lda #0
   ldx #39
   jsr toolUserLayout ;unretained, 39 wide
   lda #$80    ; border on
   sta toolUserStyles
   lda #2      ; text color
   sta toolUserColor
   jsr toolUserNode
   jsr toolUserLabel
;                 |---------1---------2---------3---------4|
giHeader    !pet  "             Disk Devices",0
   jsr toolUserSeparator
   
   ; iterate all devices outputting only disks
   +ldaSCII "a"
   sta giDevice
   giIterateDevices = *
   sta giDeviceStr
   lda #<giDeviceStr
   ldy #>giDeviceStr
   sta zp+0
   sty zp+1
   jsr aceMiscDeviceInfo
   sta giDeviceAsLong
   lda syswork+0
   sta giVirtFlags
   cpx #1
   bne +    ;handle native disk device
   lda giDevice
   sta giNatDrv+1
   lda #<UtoaNumber
   ldy #>UtoaNumber
   sta zp+0
   sty zp+1
   ldx #giDeviceAsLong
   lda #2
   jsr aceMiscUtoa
   lda UtoaNumber
   sta giNatDrv+23
   lda UtoaNumber+1
   sta giNatDrv+24
   jsr toolUserLabel
;                 |---------1---------2---------3---------4|
giNatDrv    !pet  " x: Native IEC Device #xx",0
   jmp getNextDevice
+  cpx #4
   bne +++    ;handle virtual drive
   lda giDevice
   sta giVirDrv+1
   lda #$04
   bit giVirtFlags
   beq +
   ; /user path
   ldy #0
   ldx #24
-  lda giVirPath3,y
   sta giVirDrv,x
   inx
   iny
   cpy #4
   bne -
   jmp ++
+  lda #$02
   bit giVirtFlags
   beq +
   ; /sys path
   ldy #0
   ldx #24
-  lda giVirPath2,y
   sta giVirDrv,x
   inx
   iny
   cpy #4
   bne -
   jmp ++
   ; /home path
+  ldy #0
   ldx #24
-  lda giVirPath1,y
   sta giVirDrv,x
   inx
   iny
   cpy #4
   bne -
++ jsr toolUserLabel
;                 |---------1---------2---------3---------4|
giVirDrv    !pet  " x: Virtual Fileystem [/xxxx]",0
   jmp getNextDevice
+++cpx #7
   bne getNextDevice    ;handle disk image
   lda giDevice
   sta giMount+1
   jsr toolUserLabel
;                 |---------1---------2---------3---------4|
giMount     !pet  " x: Disk Image [use 'mount']",0

   getNextDevice = *
   inc giDevice
   lda giDevice
   +cmpASCII "["
   bpl +
   jmp giIterateDevices
+  jsr toolUserEnd
   
   ; check for /d arg and exit early
   lda giOption
   +cmpASCII "d"
   bne +
   rts
   ; continue by listing all the console devices (type=6)
+  lda #<giTtyDevs
   ldy #>giTtyDevs
   jsr puts
   +ldaSCII "a"
   sta giDevice
-  sta giDeviceStr
   lda #<giDeviceStr
   ldy #>giDeviceStr
   sta zp+0
   sty zp+1
   jsr aceMiscDeviceInfo
   cpx #6
   bne +
   lda #<giDeviceStr
   ldy #>giDeviceStr
   jsr puts
+  inc giDevice
   lda giDevice
   +cmpASCII "["
   bpl +
   jmp -

   ; continue by listing all the ctrl. devices (type=3)
+  lda #chrCR
   jsr putchar
   lda #<giCtlDevs
   ldy #>giCtlDevs
   jsr puts
   +ldaSCII "a"
   sta giDevice
-  sta giDeviceStr
   lda #<giDeviceStr
   ldy #>giDeviceStr
   sta zp+0
   sty zp+1
   jsr aceMiscDeviceInfo
   cpx #3
   bne +
   lda #<giDeviceStr
   ldy #>giDeviceStr
   jsr puts
+  inc giDevice
   lda giDevice
   +cmpASCII "["
   bpl +
   jmp -

   ; continue by listing all the other devices (type=2)
   ; FIXME: what about types 0, 5 and 8?
+  lda #chrCR
   jsr putchar
   lda #<giOthDevs
   ldy #>giOthDevs
   jsr puts
   +ldaSCII "a"
   sta giDevice
-  sta giDeviceStr
   lda #<giDeviceStr
   ldy #>giDeviceStr
   sta zp+0
   sty zp+1
   jsr aceMiscDeviceInfo
   cpx #2
   bne +
   lda #<giDeviceStr
   ldy #>giDeviceStr
   jsr puts
+  inc giDevice
   lda giDevice
   +cmpASCII "["
   bpl +
   jmp -
+  lda #chrCR
   jsr putchar
   rts


;===exec===
exec_batch = *
   ; 2nd argument is the batch file name
   lda parseArgc
   cmp #2
   bne handleScriptError
   lda parseArgv+0
   ldy parseArgv+1
   clc
   adc #2
   sta zw+0
   tya
   adc #0
   sta zw+1
   ldy #0
   lda (zw),y
   sta zp+0
   iny
   lda (zw),y
   sta zp+1
   ldy #0
   ldx #0
-  lda (zp),y
   sta cmdBuffer,x
   beq +
   iny
   inx
   bne -
+  cpy #0
   beq handleScriptError
   ;** mmap load the batch file
   lda #<memBatchTag
   ldy #>memBatchTag
   ldx #0
   jsr mmap
   bcc +
   jmp handleScriptError
+  ldy #0
   sty errno
   ;** open mmap file
   lda #<memBatchFile
   ldy #>memBatchFile
   sta zp+0
   sty zp+1
   +ldaSCII "r"
   jsr open
   ldy errno
   cpy #0
   bne handleScriptError
   sta inputFd
   ;** memBatchTag entry gets overwritten
   lda aceTagsStart
   sta aceTagsCur
   ;** execute shell as same process
   jsr shell
   ;** close and return
   lda inputFd
   jsr close
   lda #stdin
   sta inputFd
   rts
   ;** handle error
   handleScriptError = *
   lda #<scriptOpenError
   ldy #>scriptOpenError
   jmp eputs


;===resident===

reTagName = $02

resident = *
   ; tagname=filename[2..] for mem-mapped file
   lda #1
   ldy #0
   jsr getarg
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
   lda #<residentErrMsg
   ldy #>residentErrMsg
   jmp eputs 
+  rts
residentErrMsg = *
   !pet "Fail load file to memory buffer"
   !byte chrCR,0

;===funkey===

hkArgv = $02
hkHex  = $04
hkCode = $06

funkey = *
   ;get keycode arg
   lda #1
   ldy #0
   jsr getarg
   ldy #0
   lda (zp),y
   +cmpASCII "0"
   beq +
-  lda #<funkeyErrMsg
   ldy #>funkeyErrMsg
   jmp eputs   
+  iny
   lda (zp),y
   +cmpASCII "x"
   bne -
   iny
   lda (zp),y
   sta hkHex+0
   iny
   lda (zp),y
   sta hkHex+1
   ;convert hexadecimal
   sec
   sbc #$30
   cmp #10
   bmi +
   sbc #7
+  sta hkCode
   lda hkHex+0
   sec
   sbc #$30
   cmp #10
   bmi +
   sbc #7
+  clc
   asl
   asl
   asl
   asl
   ora hkCode
   sta hkCode
   ;get command string
   lda #2
   ldy #0
   jsr getarg
+  lda hkCode
   ;add to programmed keys
   jsr toolKeysMacro
   bcc +
   lda #<macroUnrecognizeMsg
   ldy #>macroUnrecognizeMsg
   jmp eputs
+  jsr macrosUpdateStash
   rts
funkeyErrMsg = *
   !pet "usage: funkey <0xHH> ",chrQuote,"command",chrQuote
   !byte chrCR,0
macroUnrecognizeMsg = *
   !pet "error: illegal key code, not programmed."
   !byte chrCR,0
   

;===doskey===

dkTag = $02

doskey = *
   ;get alias string
   lda #1
   ldy #0
   jsr getarg
   bne +
-  lda #<doskeyErrMsg
   ldy #>doskeyErrMsg
   jmp eputs
   ;get hash for alias
+  lda zp+0
   ldy zp+1
   jsr aceHashTag
   ;don't collide with function key macros!
   sta dkTag
   and #$f0
   cmp #$80
   bne +
   lda #$f0
   eor dkTag
   sta dkTag
   ;get command string
+  lda #2
   ldy #0
   jsr getarg
   beq -
   ;add to programmed macros
   ldx dkTag
   jsr MacroCommand
   bcc +
   lda #<macroSizeMsg
   ldy #>macroSizeMsg
   jmp eputs
+  jsr macrosUpdateStash
   rts
doskeyErrMsg = *
   !pet "usage: doskey alias ",chrQuote,"command",chrQuote
   !byte chrCR,0
macroSizeMsg = *
   !pet "error: doskey macro memory space limit."
   !byte chrCR,0


;===echo===

echoArgv = $02
echoSpace = $04
echoTemp = $06

echo = *
   lda #0
   sta echoSpace
   lda aceArgv+0
   ldy aceArgv+1

   echoNewArg = *
   clc
   adc #2
   bcc +
   iny
+  sta echoArgv+0
   sty echoArgv+1
   ldy #0
   lda (echoArgv),y
   sta echoTemp+0
   iny
   lda (echoArgv),y
   sta echoTemp+1
   ora echoTemp+0
   beq echoExit
   +ldaSCII " "
   cmp echoSpace
   bne +
   jsr putchar
+  +ldaSCII " "
   sta echoSpace
   lda echoTemp+0
   ldy echoTemp+1
   jsr puts
   lda echoArgv+0
   ldy echoArgv+1
   jmp echoNewArg
   
   echoExit = *
   lda #chrCR
   jsr putchar
   rts

;===copy parameters===

copyBufferPtr = $02
copyBufferLength = $04

getBufferParms = *
   lda #<copyBuffer
   ldy #>copyBuffer
   sta copyBufferPtr+0
   sty copyBufferPtr+1
   sec
   lda aceMemTop+0
   sbc copyBufferPtr+0
   sta copyBufferLength+0
   lda aceMemTop+1
   sbc copyBufferPtr+1
   sta copyBufferLength+1
   rts

;===cd===

cdScanSave !byte 0

cd = *
   lda aceArgc+0
   cmp #2
   lda aceArgc+1
   sbc #0
   bcs +
   lda #<currentDir
   ldy #>currentDir
   sta zp
   sty zp+1
   lda #$00
   jsr aceDirStat
   lda #<aceSharedBuf
   ldy #>aceSharedBuf
   jsr puts
   lda #chrCR
   jmp putchar
+  lda #1
   ldy #0
   jsr getarg
   ldy #0
   lda #"."
   cmp (zp),y
   bne cdSetDevice
   iny
   cmp (zp),y
   bne cdSetDevice
   lda #$40
   jsr aceDirChange
   rts

   cdSetDevice = *
   ldx #2
   ldy #0
   lda (zp),y
   sta argBuffer+0
   iny
   lda (zp),y
   sta argBuffer+1
   iny
   +cmpASCII ":"
   bne +
   lda argBuffer+0
   cmp #$40
   bcc +
   cmp #$60
   bcc cdCheckPath
+  ldx #0
   ldy #0

   cdCheckPath = *
   sty cdScanSave
-  lda (zp),y
   sta argBuffer,x
   beq cdOkay
   inx
   iny
   bne -

   cdOkay = *
   lda #<argBuffer
   ldy #>argBuffer
   sta zp+0
   sty zp+1
   lda #$00
   jsr aceDirChange
   bcs +
   rts
+  lda #<cdErrMsg
   ldy #>cdErrMsg
   jmp eputs

cdErrMsg = *
   !pet "Error changing directory"
   !byte chrCR,0

;===cat===

catBufferPtr = $02
catBufferLength = $04
catArg = $06
catFcb = $08
catAbort = 10

cat = *
   lda #0
   sta catAbort
   jsr getBufferParms
   lda catBufferLength+1
   beq +
   lda #<254
   ldy #>254
   sta catBufferLength+0
   sty catBufferLength+1
   lda #1
   ldy #0
   sta catArg+0
   sty catArg+1
   lda aceArgc+0
   cmp #2
   lda aceArgc+1
   sbc #0
   bcs catFiles
   lda #0
   sta catFcb
   ;jmp catFile
   rts
   
   catFiles = *
   lda catArg+0
   ldy catArg+1
   jsr getarg
   +ldaSCII "r"
   jsr open
   bcc +
   lda zp+0
   ldy zp+1
   jsr eputs
   lda #<catErrMsg
   ldy #>catErrMsg
   jsr eputs
   jmp ++
+  sta catFcb
   jsr catFile
   lda catFcb
   jsr close
++ inc catArg
   bne +
   inc catArg+1
+  lda catAbort
   bne +
   lda catArg
   cmp aceArgc
   lda catArg+1
   sbc aceArgc+1
   bcc catFiles
+  rts

catErrMsg = *
   !pet ": cannot open"
   !byte chrCR,0

catFile = *
   lda catBufferPtr
   ldy catBufferPtr+1
   sta zp
   sty zp+1
-  lda catBufferLength
   ldy catBufferLength+1
   ldx catFcb
   jsr read
   beq +
   bcs +
   ldx #1
   jsr write
   bcs +
   jsr aceConStopkey
   bcs printStoppedMsg
   jmp -
+  rts

printStoppedMsg = *
   lda #$ff
   sta catAbort
   lda #<stoppedMsg
   ldy #>stoppedMsg
   jmp eputs
   stoppedMsg = *
   !pet "<Stopped>"
   !byte chrCR,0

;===exit===

shellExit = *
   lda #$ff
   sta shellExitFlag
   lda #<argBuffer
   ldy #>argBuffer
   sta zp
   sty zp+1
   lda #0
   jsr aceDirName
   jsr aceMiscDeviceInfo
   bcs +
   rts
+  sta $9b        ;Pass $ba and $9b/$9c values to BASIC
   sta $ba
   lda syswork+1
   lsr
   lsr
   sta $9c
   rts

;===path===

pathPos = 4
pathArg = 6
pathSourcePos = 7

path = *
   lda #0
   sta pathPos
   lda aceArgc+1
   beq +
   rts
+  lda aceArgc
   cmp #2
   bcs pathSet
   lda #<pathMsg
   ldy #>pathMsg
   jsr puts
   lda #$00
   sta argBuffer+0
   sta argBuffer+1
   lda #<argBuffer
   ldy #>argBuffer
   sta zp+0
   sty zp+1
   lda #2
   jsr aceDirName
   
   displayPath = *
   ldy pathPos
   lda argBuffer,y
   bne +
   lda #chrCR
   jsr putchar
   rts
+  lda #chrQuote
   sta cmdBuffer
   ldx #1
-  lda argBuffer,y
   sta cmdBuffer,x
   beq +
   iny
   inx
   bne -
+  iny
   sty pathPos
   lda #chrQuote
   sta cmdBuffer,x
   inx
   +ldaSCII " "
   sta cmdBuffer,x
   inx
   lda #<cmdBuffer
   ldy #>cmdBuffer
   sta zp
   sty zp+1
   txa
   ldy #0
   ldx #1
   jsr write
   jmp displayPath

   pathMsg = *
   !pet "path "
   !byte 0

pathSet = *
   ldy #0
   sty pathPos
   lda #1
   sta pathArg

   pathNextArg = *
   lda pathArg
   ldy #0
   jsr getarg
   lda zp
   ora zp+1
   bne +
   lda #0
   ldy pathPos
   sta argBuffer,y
   iny
   lda #<argBuffer
   ldx #>argBuffer
   sta zp+0
   stx zp+1
   lda #$82
   jsr aceDirName
   rts
+  ldy #0
   ldx pathPos
-  lda (zp),y
   sta argBuffer,x
   beq +
   inx
   iny
   bne -
+  inx
   stx pathPos
   inc pathArg
   jmp pathNextArg

;===dir===

;*** global declarations

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
dirFiles   = 32
dirBytes   = 36
dirFree    = 40
dirFileSum = 44
dirCheckFi = 45
dirWork    = 64

dirCmdDir = *
   lda #TRUE
   sta dirFileSum
   sta dirLong
   lda #FALSE
   sta dirCls
   ldy toolWinScroll+0
   dey
   sty dirPaged

dirMainEntry = *
   lda #FALSE
   sta dirShown
   lda #TRUE
   sta dirCheckFi

   lda #0
   ldy #0
   sta dirArg+0
   sty dirArg+1

   dirNextArg = *
   jsr aceConStopkey
   bcc +
   jmp dirStopped
+  inc dirArg+0
   bne +
   inc dirArg+1
+  lda dirArg+0
   ldy dirArg+1
   jsr getarg
   lda zp+0
   ora zp+1
   beq dirMainExit
   ldy #0
   lda (zp),y
   +cmpASCII "/"
   bne dirNameArg
   jsr dirHandleOption
   jmp dirNextArg

   dirNameArg = *
   lda zp+0
   ldy zp+1
   sta dirName+0
   sty dirName+1
   jsr dir
   lda #TRUE
   sta dirShown
   jmp dirNextArg

dirMainExit = *
   lda dirShown
   bne +
   lda #FALSE
   sta dirCheckFi
   lda #<dirDefaultDir
   ldy #>dirDefaultDir
   sta dirName+0
   sty dirName+1
   jsr dir
+  rts

   dirDefaultDir = *
   !pet ".",":",0

dirHandleOption = *
   ldy #0
   sty dirWork+2
   lda zp+0
   ldy zp+1
   sta dirWork+0
   sty dirWork+1

   dirNextOption = *
   inc dirWork+2
   ldy dirWork+2
   lda (dirWork),y
   bne +
   rts
+  +cmpASCII "w"
   bne +
   lda #FALSE
   sta dirLong
   sta dirCls
   jmp dirNextOption
+  +cmpASCII "p"
   bne +
   lda #TRUE
   sta dirCls
   sta dirLong
   jmp dirNextOption
+  lda #<dirUsageMsg
   ldy #>dirUsageMsg
   jsr eputs
   lda #0
   ldx #0
   jmp aceProcExit

dirUsageMsg = *
   !pet  "dir [/w] [/p] [device:]"
   !byte chrCR,chrTAB
   !pet  "/w : short-form directory listing"
   !byte chrCR,chrTAB
   !pet  "/p : clear screen and page listing"
   !byte chrCR,0

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

dir = *
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

UtoaNumber     !fill 11,0

;===bss===
;===allow 1 kB for working buffers===
bss           = *
cmdBuffer     = bss+0
copyBuffer    = bss+0
argBuffer     = cmdBuffer+256
argArgvBuffer = argBuffer+256
macroUserCmds = argArgvBuffer+256
bssAppEnd     = macroUserCmds+256


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