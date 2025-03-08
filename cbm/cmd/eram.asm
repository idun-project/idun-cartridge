!source "sys/acehead.asm"
* = aceToolAddress

jmp Main
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

;zero page vars
utoa  = $2    ;(4)
x0    = $6
x1    = $7
strX  = $8

diag_list !pet "rdwr","aloc","addp","mmap","fsig","fill","save","garb"
is_ok !pet ":ok",13,0
is_fail !pet ":fail",13,0
fail_accum !pet ":fail with ",0

diagstr = *
   stx strX
   jsr +
   jsr +
   jsr +
+  ldx strX
   lda diag_list,x
   jsr putchar
   inc strX
   rts
Failure = *
   jsr diagstr
   lda #<is_fail
   ldy #>is_fail
   jmp puts
FailAccum = *
   jsr diagstr
   lda #<fail_accum
   ldy #>fail_accum
   jsr puts
   jmp putnum
Ok = *
   jsr diagstr
   lda #<is_ok
   ldy #>is_ok
   jmp puts
Iter = *
   jsr diagstr
   lda #":"
   jsr putchar
   lda x0
   lsr
   lsr
   lsr
   lsr
   sta utoa+0
   lda #0
   sta utoa+1
putnum:
   lda #<strbuf
   ldy #>strbuf
   sta zp+0
   sty zp+1
   ldx #utoa
   lda #1
   jsr aceMiscUtoa
   lda #<strbuf
   ldy #>strbuf
   jsr puts
   lda #13
   jmp putchar

Main = *
   ;init zp vars
   lda #0
   sta utoa+2
   sta utoa+3
   sta x0
   sta x1
   ;this part does a stress test of page read/write
   ;select block #127
   lda #127
   jsr setBlk
-  jsr fill0
   lda x0
   beq alloc_block
   jsr fill1
   jsr accum
   ;verify accumulates to zero
   ldx #0
   lda utoa+0
   ora utoa+1
   beq +
   jsr FailAccum
   jmp -
+  jsr Iter
   jmp -
alloc_block = *
   lda #0
   sta utoa+2
   sta utoa+3
   ;alloc block #0 in BAM
   ldx #0
   lda aceStatB+75
   jsr allocBlk
   lda #$01
   sta $defe
-  bit $defe
   bvc -
   ldx #4
   lda $df00
   cmp aceStatB+75
   beq +
   jmp Failure
+  jsr Ok
   ;this part tests adding a page in the block
   lda #0
   jsr setBlk
   lda #$80
   sta $defe
-  bit $defe
   bvc -
   ldx #128
   lda #$42
-  sta $df00,x
   dex
   bpl -
   ldx #8
   lda #255
   jsr setBlk
   lda $df00
   cmp #63
   beq +
   jsr Failure
   jmp mmap_file
+  jsr Ok
   jmp mmap_file

fname !pet "z:tty",0
fsig  !byte $4c,$22,$6d,$cb,$06,$10,$40,$00
mmap_file = *
   ;file needs to be open'd first
   lda #<fname
   ldy #>fname
   sta zp+0
   sty zp+1
   lda #"R"
   jsr open
   bcc +
   ldx #12
   jmp Failure
   ;mmap to block #0
+  jsr aceMiscDeviceInfo   ;device number -> sw+1
   lda #$20                ;LISTEN #0
   jsr pidChOut
   lda #$7F                ;SECOND #31
   jsr pidChOut
   lda #$fb                ;CMD_MMAP
   jsr pidChOut
   lda syswork+1
   lsr
   lsr
   jsr pidChOut            ;device
   lda #0                  ;destination block
   jsr pidChOut
   ;wait for mmap to be completed
   lda #255
   jsr setBlk
   ;check for correct pages free
   ldx #12
   lda $df00
   cmp #45
   beq +
   sta utoa+0
   lda #0
   sta utoa+1
   jsr FailAccum
   jmp ++
+  jsr Ok
   ;also check file signature
++ lda #0
   jsr setBlk
   lda #1
   sta $defe
-  bit $defe
   bvc -
   ldx #16
   ldy #0
-  lda fsig,y
   beq ++
   cmp $df00,y
   beq +
   jsr Failure
   jmp switch_block
+  iny
   jmp -
++ jsr Ok
switch_block = *
   ;this part tests switching to alloc'd block and writing to it
   lda #$00
   jsr setBlk
   ;fill first two pages
   ldx #20
   lda #1
   jsr fill_page
   jsr cmp_page
   bcc +
   jsr Failure
   jmp save_block
+  lda #2
   jsr fill_page
   jsr cmp_page
   bcc +
   jsr Failure
   jmp save_block
+  jsr Ok
save_block = *
   ;save block
   lda #$ff
   jsr setBlk
   ;reload block
   lda #$00
   jsr setBlk
   ;check contents after saving and reloading
   ldx #24
   lda #1
   jsr cmp_page
   bcc +
   jsr Failure
+  ldx #24
   lda #2
   jsr cmp_page
   bcc +
   jsr Failure
   jmp gcollect
+  jsr Ok
gcollect = *
   ;do garbage collection
   lda #$20                ;LISTEN #0
   jsr pidChOut
   lda #$7F                ;SECOND #31
   jsr pidChOut
   lda #$fa                ;CMD_GCOLLECT
   jsr pidChOut
   lda aceStatB+75
   jsr pidChOut            ;process id
   ;check freemap
   lda #$ff
   jsr setBlk
   ldx #28
   lda $df00
   cmp #64
   beq +
   jsr Failure
   jmp ++
+  jsr Ok
   ;check block deallocated
++ lda #1
   sta $defe
-  bit $defe
   bvc -
   ldx #28
   lda $df00
   beq +
   jsr Failure             ;end tests
   rts
+  jsr Ok
   rts

setBlk = *
   sta $deff
   nop
-  bit $defe
   bvc -
   rts

allocBlk = *    ;.X=blk, .A=procId
   pha
   ;ensure block #255 is loaded
   lda #$ff
   jsr setBlk
   ;select BAM block for write
   ldy #$81
   sty $defe
-  bit $defe
   bvc -
   pla
   sta $df00,x
   rts

fill_page = *  ;.A=page num.
   pha
   ora #$80
   sta $defe
-  bit $defe
   bvc -
   ldy #0
-  sta $df00,y
   iny
   bne -
   pla
   rts
cmp_page = *  ;.A=page num.
   sta $defe
-  bit $defe
   bvc -
   ora #$80
   sta cmp_val
   ldy #0
-  lda $df00,y
   cmp cmp_val
   bne +
   iny
   bpl -
   clc
   rts
+  sec
   rts
cmp_val !byte 0

aa2 = *
   lda #$82
   sta $defe
-  bit $defe
   bvc -
   lda #$aa
   ldx #0
-  sta $df00,x
   inx
   bne -
   rts
aa1 = *
   lda #$81
   sta $defe
-  bit $defe
   bvc -
   lda #$aa
   ldx #0
-  sta $df00,x
   inx
   bne -
   rts
fill0 = *
   lda #$80
   sta $defe
-  bit $defe
   bvc -
   lda x0
   clc
   adc #16
   sta x0
   ldx #0
-  sta $df00,x
   inx
   bne -
   rts
fill1 = *
   lda #$81
   sta $defe
-  bit $defe
   bvc -
   lda x1
   sec
   sbc #16
   sta x1
   ldx #0
-  sta $df00,x
   inx
   bne -
   rts
accum = *
   lda #0
   sta utoa+0
   sta utoa+1
   sta $defe
-  bit $defe
   bvc -
   jsr +
   lda #1
   sta $defe
-  bit $defe
   bvc -
+  ldx #0
-  lda $df00,x
   clc
   adc utoa+0
   sta utoa+0
   lda utoa+1
   adc #0
   sta utoa+1
   inx
   bne -
   rts

pidChOut = *
   sta $de00
   clc
   rts

peekPage = *
   sta $defe
-  bit $defe
   bvc -
   lda #$00
   ldy #$df
   jsr puts
   lda #13
   jsr putchar
   ;fall-through
die = *
   lda #1
   ldx #0
   jmp aceProcExit

strbuf !fill 11,0
;******** standard library ********
puts = *
   ldx #stdout
fputs = *
   sta zp
   sty zp+1
zpputs = *
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
