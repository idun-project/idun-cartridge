;*** rm program

!source "sys/acehead.asm"
* = aceToolAddress

jmp removeMain
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

;*** global declarations

libwork = $60
rmErrno = libwork  ;(4) zero-extended errno for aceMiscUtoa

chrQuote = $22

;===remove===
rmArg = 2
rmName = 4

removeMain = *
   ;** check argument count
   lda aceArgc+1
   bne rmEnoughArgs
   lda aceArgc
   cmp #2
   bcs rmEnoughArgs

rmUsage = *
   lda #<rmUsageMsg
   ldy #>rmUsageMsg
   jmp puts

rmUsageMsg = *
   !pet "usage: del <file1> [file2 .. fileN]",chrCR,0

rmEnoughArgs = *
   lda #1
   ldy #0
   sta rmArg
   sty rmArg+1
-  lda rmArg
   ldy rmArg+1
   jsr getarg
   lda zp
   ldy zp+1
   sta rmName
   sty rmName+1
   ora zp+1
   beq rmExit
   jsr aceConStopkey
   bcs stopped
   jsr rmEcho
   lda rmName
   ldy rmName+1
   sta zp
   sty zp+1
   jsr aceFileRemove
   bcc +
   jsr rmError
+  inc rmArg
   bne +
   inc rmArg+1
+  jmp -

rmExit = *
   rts

stopped = *
   lda #<stoppedMsg
   ldy #>stoppedMsg
   jmp eputs
   stoppedMsg = *
   !pet "<stopped>",chrCR,0

rmError = *
   lda #<rmErrorMsg1
   ldy #>rmErrorMsg1
   jsr eputs
   lda rmName
   ldy rmName+1
   jsr eputs
   lda #<rmErrorMsg2
   ldy #>rmErrorMsg2
   jsr eputs
   ;** print errno (decimal) followed by CR
   lda errno
   sta rmErrno+0
   lda #0
   sta rmErrno+1
   sta rmErrno+2
   sta rmErrno+3
   lda #<rmNumbuf
   ldy #>rmNumbuf
   sta zp
   sty zp+1
   ldx #rmErrno
   lda #1
   jsr aceMiscUtoa
   lda #<rmNumbuf
   ldy #>rmNumbuf
   jsr eputs
   lda #<rmErrorMsg3
   ldy #>rmErrorMsg3
   jmp eputs

rmNumbuf !fill 12,0

rmErrorMsg1 = *
   !pet "Error attempting to remove ",chrQuote,0

rmErrorMsg2 = *
   !pet chrQuote,", code ",0

rmErrorMsg3 = *
   !pet chrCR,0

rmEcho = *
   lda #<rmEchoMsg1
   ldy #>rmEchoMsg1
   jsr eputs
   lda rmName
   ldy rmName+1
   jsr eputs
   lda #<rmEchoMsg2
   ldy #>rmEchoMsg2
   jmp eputs

rmEchoMsg1 = *
   !pet "Removing file ",chrQuote,0

rmEchoMsg2 = *
   !pet chrQuote,"...",chrCR,0


;******** standard library ********
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
eputs = *
   ldx #stderr
   jmp fputs

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
getcBuffer: !byte 0

;===remove library===
getarg = *
   sty zp+1
   asl
   sta zp
   rol zp+1
   clc
   lda aceArgv
   adc zp
   sta zp
   lda aceArgv+1
   adc zp+1
   sta zp+1
   ldy #0
   lda (zp),y
   tax
   iny
   lda (zp),y
   stx zp
   sta zp+1
   rts
