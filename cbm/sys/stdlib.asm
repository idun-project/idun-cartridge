;******** standard library ********
;C-like character and null-terminated string output
putchar = *    ;.A=char -> stdout
   ldx #stdout
putc = *       ;.A=char -> .X=lfn
   sta putcBuffer
   lda #<putcBuffer
   ldy #>putcBuffer
   sta zp+0
   sty zp+1
   lda #1
   ldy #0
   jmp write
putcBuffer !byte 0
eputs = *      ;.AY=null-terminated str -> stderr
   ldx #stderr
   jmp fputs
puts = *       ;.AY=null-terminated str -> stdout
   ldx #stdout
fputs = *      ;.AY=null-terminated str -> .X=lfn
   sta zp+0
   sty zp+1
zpputs = *     ;zp=null-terminated str -> .X=lfn
   ldy #$ff
-  iny
   lda (zp),y
   bne -
   tya
   ldy #0
   jmp write
;Output number to stdout
;.X is the zero-page address of the LSB of a 32-bit
;unsigned value in little-endian order.
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
;Get the nth command-line argument
getarg = *      ;.AY=specify nth arg
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
;exit to parent
exit = *    ;.A=exit code
   ldx #0
   jmp aceProcExit
