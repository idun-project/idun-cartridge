!source "sys/toolbox.asm"

jmp Startup

; String constants we'll need
cpem_path !pet "c:/idun-base/cpm",0
zload_path !pet "z:zload",0
tty_path !pet "z:tty",0

; Arguments strings for launching `tty`
cpem_exec_c128 !word 6,12,0
cpem_c128 !pet "_:tty",0,"x:./cpem C128",0
cpem_exec_c128_sz = * - cpem_exec_c128
cpem_exec_c64 !word 6,12,0
cpem_c64 !pet "_:tty",0,"x:./cpem C64",0
cpem_exec_c64_sz = * - cpem_exec_c64

; Error strings we hope we don't need
errCpmPath !pet "CP/M files not installed.",0
errResident !pet "Failed to make commands resident.",0

;=== Startup ===
Startup = *
   ; setup text display
   jsr ToolwinInit
   lda #FALSE
   jsr toolStatEnable
   jsr aceWinMax
   jsr aceWinSize
   jsr cls
   ; cd to directory where `cpem` should be!
   lda #<cpem_path
   ldy #>cpem_path
   sta zp
   sty zp+1
   lda #$00
   jsr aceDirChange
   bcc +
   lda #<errCpmPath
   ldy #>errCpmPath
   jmp errorExit
   ; make `zload` and `tty` commands memory-resident
+  lda #<zload_path
   ldy #>zload_path
   sta zp
   sty zp+1
   jsr resident
   bcs errorLoadCmd
   lda #<tty_path
   ldy #>tty_path
   sta zp
   sty zp+1
   jsr resident
   bcs errorLoadCmd
   ; Start cpem
   jsr aceMiscSysType
   bpl +
   lda #<cpem_exec_c128
   ldy #>cpem_exec_c128
   ldx #cpem_exec_c128_sz
   jsr toolSyscall
   jmp waitTty
+  lda #<cpem_exec_c64
   ldy #>cpem_exec_c64
   ldx #cpem_exec_c64_sz
   jsr toolSyscall

   waitTty = *
   rts

   errorLoadCmd = *
   lda #<errResident
   ldy #>errResident

   errorExit = *
   jsr puts
   jsr aceConGetkey
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

;=== bss ===
macroUserCmds = * ;not used