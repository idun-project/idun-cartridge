;'copy' cmd: copy files from source to dest device
;
;Copyright© 2020 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Source and destination devices may be either native or
; virtual drives, but cannot be the same device.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)
;
;@see usemsg

!source "sys/acehead.asm"
!source "sys/acemacro.asm"
* = aceToolAddress

jmp copymain
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

;*** global declarations

libwork = $60
chrQuote = $22
overwriteAllFlag !byte 0
insertHeaderFlag !byte 0
abortFlag        !byte 0
;start with assuming src and dest are virtual
virtualDevsFlag  !byte 1

copyBufferPtr    = 2 ;(2)
copyBufferLength = 4 ;(2)
copyInFile       = 6 ;(1)
copyOutFile      = 7 ;(1)
scanPos          = 8 ;(1)
copyInDevice     = 9 ;(1)
copyInName       = 10 ;(2)
copyOutName      = 12 ;(2)
copyOpenName     = 14 ;(2)
copyArg          = 16 ;(2)
lastArg          = 18 ;(2)
baseArg          = 20 ;(1)
cpErrno          = 22 ;(4)

copyUsageErrorMsg = *
!pet "usage: copy [/h] <src> <dest> -or-",chrCR
!pet "       copy [/f] <src1> [src2..srcN] <dev:>",chrCR
!pet "Note: src and dest NOT same device",chrCR
!pet "[/h] to add addr header to dest PRG",chrCR
!pet "[/f] to force overwrite existing dest",chrCR,0

;===copy===
copymain = *
   lda #0
   sta overwriteAllFlag
   sta insertHeaderFlag
   sta abortFlag
   jsr getBufferParms
   ;** check for at least three arguments
   lda aceArgc+1
   bne +
   lda aceArgc
   cmp #3
   bcs +
   beq +
   jmp copyUsageError
   ;** check for first argument option
   ;   either /f or /h
+  lda #1
   sta baseArg
   lda #1
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
   +cmpASCII "h"
   bne copyUsageError
   lda #$ff
   sta insertHeaderFlag
   inc baseArg
   jmp ++
+  lda #$ff
   sta overwriteAllFlag
   inc baseArg
   ;** check if destination is a directory
++ jsr getLastArg
   jsr aceDirIsdir
   cpy #0
   beq +
   jmp copyToDir
   ;** check for exactly three parameters
+  lda aceArgc+1
   bne copyUsageError
   sec
   lda aceArgc
   sbc baseArg
   cmp #2
   bne copyUsageError
   ;** get buffer parameters
   lda baseArg
   ldy #0
   jsr getarg
   lda zp
   ldy zp+1
   sta copyInName
   sty copyInName+1
   inc baseArg
   lda baseArg
   ldy #0
   jsr getarg
   ;** if /h is used, check if outputting to PRG
   lda insertHeaderFlag
   bpl ++
   ldy #0
-  iny 
   lda (zp),y
   bne -
   dey
   lda (zp),y
   +cmpASCII "p"
   beq +
   lda #0
   sta insertHeaderFlag
   jmp ++
+  dey
   lda (zp),y
   +cmpASCII ","
   beq ++
   lda #0
   sta insertHeaderFlag
++ lda zp
   ldy zp+1
   sta copyOutName
   sty copyOutName+1
   jsr copyfile
   rts

copyUsageError = *
   lda #<copyUsageErrorMsg
   ldy #>copyUsageErrorMsg
   ldx #stderr
   jsr fputs
   rts

copyfile = *
   ;** open files
   lda copyInName
   ldy copyInName+1
   sta zp
   sty zp+1
   jsr aceMiscDeviceInfo
   lda syswork+1
   sta copyInDevice
   bcs +
   lda #0
   sta virtualDevsFlag
+  +ldaSCII "R"
   jsr open
   bcc +
   lda copyInName
   ldy copyInName+1
   jmp copyOpenError
+  sta copyInFile
copyfileOutput = *
   lda copyOutName
   ldy copyOutName+1
   sta zp
   sty zp+1
   ; checking src/dest are diff devices
   jsr aceMiscDeviceInfo
   lda syswork+1
   cmp copyInDevice
   beq copyUsageError
   jsr aceMiscDeviceInfo
   bcs +
   lda #0
   sta virtualDevsFlag
-  +ldaSCII "W"
   jmp ++
+  lda virtualDevsFlag
   beq -
   +ldaSCII "C"   ;open Command channel
++ jsr open
   bcc copyWriteOk
   lda errno
   cmp #aceErrFileExists
   beq +
-  lda copyInFile
   jsr close
   lda copyOutName
   ldy copyOutName+1
   jmp copyOpenError
+  jsr copyAskOverwrite
   beq +
   lda copyInFile
   jsr close
   sec
   rts
+  jsr copyRemoveOutfile
   jmp copyfileOutput

   copyWriteOk = *
   sta copyOutFile
   lda virtualDevsFlag
   beq +
   lda copyInFile
   ldx copyOutFile
   jsr aceFileCopyHost
   jmp copyFileFinish
+  jsr copyFileContents
   copyFileFinish = *
   lda copyOutFile
   jsr close
   lda copyInFile
   jsr close
   rts

copyAskOverwrite = *  ;() : .CS=quit, .EQ=yes, .NE=no
   lda overwriteAllFlag
   beq +
   lda #0
   rts
   copyAskCont = *
+  lda #<copyAskOverwriteMsg
   ldy #>copyAskOverwriteMsg
   jsr puts
   lda copyOutName
   ldy copyOutName+1
   jsr puts
   lda #<copyAskOverwriteMsg2
   ldy #>copyAskOverwriteMsg2
   jsr puts
   jsr getchar
   cmp #chrCR
   beq copyAskCont
   pha
-  jsr getchar
   cmp #chrCR
   bne -
   pla
   +cmpASCII "q"
   bne +
-  lda #$ff
   sta abortFlag
   sec
   rts
+  +cmpASCII "Q"
   beq -
   +cmpASCII "a"
   bne +
-  lda #$ff
   sta overwriteAllFlag
   +ldaSCII "y"
+  +cmpASCII "A"
   beq -
   +cmpASCII "y"
   beq +
   +cmpASCII "Y"
+  clc
   rts
   copyAskOverwriteMsg = *
   !pet "Overwrite ",chrQuote,0
   copyAskOverwriteMsg2 = *
   !pet chrQuote," (y/n/a/q)? ",0

copyRemoveOutfile = *
   lda copyOutName
   ldy copyOutName+1
   sta zp
   sty zp+1
   jsr aceFileRemove
   rts

copyFileContents = *
   ;** check whether adding addr header
   lda insertHeaderFlag
   bpl copyFileContinue
   lda #<aceToolAddress
   sta zp
   lda #>aceToolAddress
   sta zp+1
   ldy #0
   lda #2
   ldx copyOutFile
   jsr write
   bcc copyFileContinue
   jmp copyFileError
   ;** copy file contents
   copyFileContinue = *
   lda copyBufferPtr
   ldy copyBufferPtr+1
   sta zp
   sty zp+1
   jsr checkstop
   lda copyBufferLength
   ldy copyBufferLength+1
   ldx copyInFile
   jsr read
   bcs ++
   sta zw
   sty zw+1
   ora zw+1
   beq +
   jsr checkstop
   lda zw
   ldy zw+1
   ldx copyOutFile
   jsr write
   bcs ++
   jmp copyFileContinue
+  rts
++ jmp copyFileError
   
   copyOpenError = *
   ldx errno
   stx cpErrno+0
   sta copyOpenName
   sty copyOpenName+1
   lda #<copyOpenErrorMsg1
   ldy #>copyOpenErrorMsg1
   ldx #stderr
   jsr fputs
   lda copyOpenName
   ldy copyOpenName+1
   ldx #stderr
   jsr fputs
   lda #<copyOpenErrorMsg2
   ldy #>copyOpenErrorMsg2
   ldx #stderr
   jsr fputs
   lda #0
   sta cpErrno+1
   sta cpErrno+2
   sta cpErrno+3
   lda #<cpNumbuf
   ldy #>cpNumbuf
   sta zp+0
   sty zp+1
   ldx #cpErrno
   lda #1
   jsr aceMiscUtoa
   lda #<cpNumbuf
   ldy #>cpNumbuf
   ldx #stderr
   jsr fputs
   lda #<copyOpenErrorMsg3
   ldy #>copyOpenErrorMsg3
   ldx #stderr
   jsr fputs
   rts

cpNumbuf !fill 12,0
   copyOpenErrorMsg1 = *
   !pet "Error opening file ",chrQuote,0
   copyOpenErrorMsg2 = *
   !pet chrQuote,", code ",0
   copyOpenErrorMsg3 = *
   !pet chrCR,0

   copyFileError = *
   lda #<copyFileErrorMsg
   ldy #>copyFileErrorMsg
   ldx #stderr
   jmp fputs
   copyFileErrorMsg = *
   !pet "File data error!",chrCR,0

copyVirtualContents = *
   rts

copyToDir = *
   lda baseArg
   ldy #0
   sta copyArg+0
   sty copyArg+1
-  lda aceArgc+0
   ldy aceArgc+1
   sec
   sbc #1
   bcs +
   dey
+  cmp copyArg+0
   bne +
   cpy copyArg+1
   beq copyToDirExit
+  jsr checkstop
   lda copyArg+0
   ldy copyArg+1
   jsr getarg
   lda zp+0
   ldy zp+1
   sta copyInName+0
   sty copyInName+1
   jsr copyFileToDir
   lda abortFlag
   bne copyToDirStopped
   inc copyArg+0
   bne +
   inc copyArg+1
+  jmp -

copyToDirExit = *
   rts

checkstop = *
   jsr aceConStopkey
   bcs +
   rts
copyToDirStopped = *
+  lda #<stoppedMsg
   ldy #>stoppedMsg
   jsr eputs
   lda #1
   ldx #0
   jmp aceProcExit

   stoppedMsg = *
   !pet "<Stopped>",chrCR,0

copyFileToDir = *
   ;** generate output file name
   jsr getLastArg
   ldy #0
-  lda (zp),y
   beq +
   sta copyNameBuf,y
   iny
   bne -
+  tya
   tax
   ;** extract basename
   ldy #0
   sty scanPos
-  lda (copyInName),y
   beq +
   +cmpASCII ":"
   bne basenameNext
   iny
   sty scanPos
   dey
   basenameNext = *
   iny
   bne -

+  ldy scanPos
-  lda (copyInName),y
   sta copyNameBuf,x
   beq +
   inx
   iny
   bne -
   ;** copy file
+  lda #<copyNameBuf
   ldy #>copyNameBuf
   sta copyOutName+0
   sty copyOutName+1
   jsr copyToDirStatus
   jsr copyfile
   rts

nameSpace !byte 0

copyToDirStatus = *
   lda copyInName+0
   ldy copyInName+1
   jsr puts

   ldy #255
-  iny
   lda (copyInName),y
   bne -
   tya
-  sec
   sbc #10
   bcs -
   adc #10
   sta nameSpace
   sta nameSpace
   sec
   lda #10
   sbc nameSpace
   sta nameSpace

-  lda #" "
   jsr putchar
   dec nameSpace
   bne -

   lda copyOutName+0
   ldy copyOutName+1
   jsr puts
   lda #chrCR
   jsr putchar
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

;===copy library===
getBufferParms = *
   lda #<cpEnd
   ldy #>cpEnd
   sta copyBufferPtr+0
   sty copyBufferPtr+1
   sec
   lda aceMemTop+0
   sbc copyBufferPtr+0
   sta copyBufferLength+0
   lda aceMemTop+1
   sbc copyBufferPtr+1
   sta copyBufferLength+1
   bcc +
   rts
+  lda #"!"
   jmp putchar
;   lda #$00
;   ldy #$01
;   sta copyBufferLength+0
;   sty copyBufferLength+1
   rts

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
cpBss = *
copyNameBuf = cpBss+0
cpEnd = cpBss+256

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