; Idun Shell, Copyright© 2025 Brian Holdsworth
; This is free software, released under the MIT License.

; This application provides a custom tty that runs the Linux
; shell. It includes a set of Idun command handlers for those
; commands that Linux will forward to this app.
!source "sys/toolbox.asm"

jmp Init

; Zero-page
cmdPtr   = $60  ;(1)
argPtr   = $62  ;(2)  ;pointer to args
tempPtr  = $64  ;(2)  ;temp. pointer
count    = $66  ;(1)  ;temp. counter

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

;=== Init (one-time) ===
Init = *
   ; aceSharedBuf is used for linux sharing it's cd path
   ; as a nul-term petscii string. Make sure it starts off
   ; empty/ignored.
   lda #0
   sta aceSharedBuf
   jmp Startup

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
   bmi normalExit             ;Killed
   cmp #64
   bcc Startup
   and #$3f
   sta cmdPtr
   ; Shell exec signalled -> run command
   ; The args are already present in hi-mem
   ; w/ argPtr pointing to the args block.
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
   jsr aceProcExecSub
   jmp Tty

   normalExit = *
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

exec = *
   rts

go = *
   lda #0
   ldy #0
   jsr getarg
   lda #aceRestartApplReset
   jmp aceRestart

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