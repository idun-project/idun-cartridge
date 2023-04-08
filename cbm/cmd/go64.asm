; Idun Go64, Copyright© 2021 Brian Holdsworth, MIT License.

; This tool is used to launch C64 native binaries. The binary
; can be a PRG on any native or virtual drive. If running on
; a C128, then the mode will be switched to C64. Go64 will also 
; use first file in a disk image or tape archive, such that this 
; command is a rough equivalent to LOAD"*":RUN

!source "sys/acehead.asm"
!source "sys/acemacro.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

; Constants
FALSE     = 0x00
ldUsage64 = *
              !pet "Usage: go64 <image>",chrCR
              !pet "Supports T64 and D64 image.",chrCR,0
mtDevice      !pet "^:",0
mtErrorMsg1   !pet "Error: illegal target device",chrCR,0
mtErrorMsg2   !pet "Error: cannot open image file",chrCR,0
mtErrorMsg3   !pet "Error: cannot mount image file",chrCR,0
mtDoneMsg     !pet "Mounted ",0
mtFoundMsg    !pet "Found ",0
argsus = *
!pet "/?"  ;show help
!word doUsageMsg
!byte 0

; Zp Vars
loadDevType = 2
dirFcb      = 3
loadFd      = 4
argnum      = 5
IdunDrive   = $9c

main = *
   lda #0
   sta argnum
   jsr getNextArg       ;checks for '/?'
   lda #1
   ldy #0
   jsr getarg
   bne +
   jmp go64
+  jsr mountImageFile
   bcc go64Disk
go64 = *
   lda #3
-  sta IdunDrive
   ldx #1      ;CMD_SYS_REBOOT
   lda #64     ;reboot C64 mode
   jmp aceMapperCommand
go64Disk = *
   lda #30
   jmp -

doUsageMsg = *
   lda #<ldUsage64
   ldy #>ldUsage64
   jsr eputs
   jmp die

mountImageFile = *
   ;mount image file read-only on "^:"
   lda zp+1
   pha
   lda zp
   pha
   lda #<mtDevice
   ldy #>mtDevice
   sta zp
   sty zp+1
   jsr aceMiscDeviceInfo
   cpx #7
   bne mtDeviceError
   ; open the image file
   ldy #0
   lda #1
   jsr getarg
   lda mtDevice+0
   and #$1f
   asl
   asl
   tax
   pla
   sta zp
   pla
   sta zp+1
   lda #FALSE
   jsr aceMountImage
   lda errno
   cmp #aceErrFileTypeMismatch
   beq mtMountError
   mtOpenError = *
   lda #<mtErrorMsg2
   ldy #>mtErrorMsg2
   jmp mtError
   mtDeviceError = *
   lda #<mtErrorMsg1
   ldy #>mtErrorMsg1
   jmp mtError
   mtMountError = *
   lda #<mtErrorMsg3
   ldy #>mtErrorMsg3
   mtError = *
   sec
   rts

   mtDone = *
   ;print Mounted...
   lda #<mtDoneMsg
   ldy #>mtDoneMsg
   jsr puts
   ldy #0
   lda #1
   jsr getarg
   ldx #stdout
   jsr zpputs
   lda #chrCR
   jsr putchar
   clc
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
putnum = *
   ldy #<numbuf
   sty zp+0
   ldy #>numbuf
   sty zp+1
   lda #1
   jsr aceMiscUtoa
   lda #<numbuf
   ldy #>numbuf
   jsr puts
   rts
numbuf !fill 11,0
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
getNextArg = *
   ldy #0
   inc argnum
   lda argnum
   jsr getarg
   ldx #0
   ldy #0
-  lda argsus,x
   bne +
   rts
+  lda (zp),y
   cmp argsus,x
   beq +
   txa
   clc
   adc #4
   tax
   jmp -
+  inx
   iny
   lda (zp),y
   cmp argsus,x
   beq +
   inx
   inx
   inx
   jmp -
+  inx
   lda argsus,x
   sta zp+0
   inx
   lda argsus,x
   sta zp+1
   jmp (zp)
die = *
   lda #1
   ldx #0
   jmp aceProcExit

;=== bss ===
.localBuf = *

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