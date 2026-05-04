!source "sys/acehead.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

; Constants
bkACE    = $36
bkExtrom = $37
bkSelect = $01
romlOn   = $de7f
romlOff  = $de7e
turboOff = $d07a
turboOn  = $d07b

; Z-page
tmp   = $02 ;(1)
count = $03 ;(1)
save  = $04 ;(2)
pct   = $06 ;(4)

main = *
   lda #100
   sta count
   lda #0
   sta pct
   sta pct+1
   sta pct+2
   sta pct+3
-  jsr poison
   dec count
   bne -
   lda #<poisonComp
   ldy #>poisonComp
   jsr printResults
   lda #50
   sta count
   lda #0
   sta pct
-  jsr nmitest
   dec count
   bne -
   lda pct
   asl
   sta pct
   lda #<nmiComp
   ldy #>nmiComp
   jsr printResults
   clc
   rts
poison = *
   ldx #4
-  lda pVal,x
   sta $8004,x
   dex
   bpl -
   jsr romon
   ldx #4
-  lda $8004,x
   cmp pVal,x
   bne +
   dex
   bpl -
   jsr romoff
   rts
+  jsr romoff
   inc pct
   rts
nmitest = *
   ; high-jack the NMI handler
   lda $318
   ldy $319
   sta save+0
   sty save+1
   lda #<handler
   ldy #>handler
   sta $318
   sty $319
   ; trigger NMI with a load syscall
   lda #$ff
   sta tmp
   ldx #MAP_SYS_LOAD_BINARY
   lda #2
   jsr syscall
   ; wait on nmi call
-  lda tmp
   bmi -
   lda tmp
   bne +
   jmp testdone
+  cmp #$31
   bne +
   inc pct
   jmp testdone
+  cmp #$38
   bne testdone
   inc pct
   ; restore the NMI handler
   testdone = *
   lda save+0
   ldy save+1
   sta $318
   sty $319
   rts

rom_sig !pet "CBM"
handler = *
   lda $dd0d   ;clear CIA2 nmi
   lda #0
   sta tmp
   jsr romon
   sta turboOff
   ;Check for ROM preamble
   ldx #2
-  lda rom_sig,x
   cmp $8004,x
   bne +
   dex
   bpl -
+  cpx #$ff
   bne hexit
   lda $8007
   sta tmp
   hexit = *
   jsr romoff
   sta turboOn
   rti

romon = *
   lda #bkExtrom
   sta bkSelect
   sta romlOn
   rts
romoff = *
   sta romlOff
   lda #bkACE
   sta bkSelect
   rts

printResults = *
   jsr puts
   ldx #pct
   jsr putnum
   lda #<resultStr
   ldy #>resultStr
   jsr puts
   rts

pVal !byte $40,$42,$84,$82,$80
poisonComp !pet "ROML read, success = ",0
nmiComp !pet "NMI+ROML sign, success = ",0
resultStr !pet "%",chrCR,0

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
die = *
   lda #1
   ldx #0
   jmp aceProcExit

;=== bss ===
.localBuf = *
