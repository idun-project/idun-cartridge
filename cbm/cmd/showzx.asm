;'showzx' cmd: Simple ZX Spectrum SCR image viewer
;
;Copyright© 2021 Brian Holdsworth
;
; This is free software, released under the MIT License.
;

!source "sys/acehead.asm"
!source "sys/toolhead.asm"
!source "sys/acemacro.asm"

SCR_FILE_SZ = 6912
* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

zp_work  = $02    ;(4)
scrnMode = $06    ;(1)
argnum   = $07    ;(1)

showUsageErrMsg = *
;    |1234567890123456789012345678901234567890|
!pet "usage: showzx <scr_file> [scr2..scrN]",chrCR
!pet "C128 VDC required",chrCR,0

main = *
   lda #0
   sta scrnMode
   sta argnum
   ;check for C128
   jsr aceMiscSysType
   cmp #$80
   beq +
   jmp showUsageError
   ;check for at least one arg
+  lda aceArgc
   cmp #2
   bcs +
   beq +
   jmp showUsageError
+  jsr graphicOn
   ;get image file from args
   loadImageFile = *
   inc argnum
   ldy #0
   lda argnum
   jsr getarg
   bne +
   jmp exit
+  lda #<(bmapBuffer+SCR_FILE_SZ)
   ldy #>(bmapBuffer+SCR_FILE_SZ)
   iny
   sta zw+0
   sty zw+1
   lda #<bmapBuffer
   ldy #>bmapBuffer
   jsr aceFileBload
   bcc +
   jmp showLoadError
+  jsr showScrBmap
   jsr aceConGetkey
   cmp #$03          ;STOP key?
   beq exit
   jmp loadImageFile
exit = *
   jsr graphicOff
   rts
showUsageError = *
   lda #<showUsageErrMsg
   ldy #>showUsageErrMsg
   jmp eputs
showLoadError = *
   jsr zpputs
   lda #<showLoadErrMsg
   ldy #>showLoadErrMsg
   jsr eputs
   jmp exit
showLoadErrMsg !pet ": Fail load SCR format",chrCR,0

graphicOn = *
   lda scrnMode
   beq +
   lda #0
   jmp vdcScnclr
+  lda #FALSE
   jsr toolStatEnable
   lda #<modecmd
   ldy #>modecmd
   sta zp
   sty zp+1
   lda #<modeptrs
   ldy #>modeptrs
   ldx #(modeend-modeptrs)
   jsr toolSyscall
   lda #3
   sta scrnMode
   lda #0
   jmp vdcScnclr
; Cmd: "mode vdc 3 32 24"
modeptrs !word (modecmd-modeptrs),(modeargs-modeptrs),(modeargs+4-modeptrs),(modeargs+6-modeptrs),(modeargs+9-modeptrs),$0000
modecmd  !pet "mode",0
modeargs !pet "vdc",0,"3",0,"32",0,"24",0
modeend = *

graphicOff = *
   lda scrnMode
   beq +
   jsr aceGrExit
   lda #0
   sta scrnMode
   jsr toolWinRestore
   lda #TRUE
   jsr toolStatEnable
+  rts

showScrBmap = *
   lda #$00
   sta _vdc_addr+0
   sta _vdc_addr+1
   ldx #$12
   jsr vdcWrite
   ldx #$13
   jsr vdcWrite        ;R18/19 update VDC mem from $0000
   lda #$1f
   sta vdcSelect
   lda #>bmapBuffer
   _copy_bmp = *
   sta zp_work+1
   lda #<bmapBuffer
   _copy_page = *
   sta zp_work
   lda zp_work+1
   sta zp_work+3
   ldx #$08
   _copy_row = *
   lda zp_work
   sta zp_work+2
   ldy #$00
-- lda (zp_work+2),y
-  bit vdcStatus
   bpl -
   sta vdcData
   iny
   cpy #$20
   bne --
   inc zp_work+3
   dex
   jsr _vdc_next_row
   bne _copy_row
   lda zp_work
   clc
   adc #$20
   bcc _copy_page
   lda zp_work+1
   clc
   adc #$08
   _stop = *
   cmp #>(bmapBuffer+$1800)       ;end of bmap
   bcc _copy_bmp
   _copy_attr = *
   ldy #$27
   lda #$d8    ;init to $2800-$28
   sty _vdc_addr+1
   sta _vdc_addr+0
   ldy #$00
   sty zp_work+2
   _copy_attr_row = *
   jsr _vdc_next_row
   ldy #0
-- lda (zp_work+2),y
   and #$7f
   tax
   lda palette_attr_lookup,x
-  bit vdcStatus
   bpl -
   sta vdcData
   iny
   cpy #$20
   bne --
   lda zp_work+2
   clc
   adc #$20
   sta zp_work+2
   bne +
   inc zp_work+3
+  lda zp_work+3
   cmp #>(bmapBuffer+$1b00)     ;end of attr
   bcc _copy_attr_row
   rts

   _vdc_next_row = *
   inc _vdc_row_count
   txa
   pha
   lda _vdc_addr+0
   clc
   adc #40
   sta _vdc_addr+0
   lda _vdc_addr+1
   adc #0
   sta _vdc_addr+1
   ldx #$12
   jsr vdcWrite
   lda _vdc_addr+0
   ldx #$13
   jsr vdcWrite
   lda #$1f
   sta vdcSelect
   pla
   tax
   rts
_vdc_addr !word 0
_vdc_row_count !byte 0

;vdc register addresses
vdcSelect = $d600
vdcStatus = $d600
vdcData   = $d601

vdcWrite = *  ;( .X=register, .A=value )
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sta vdcData
   rts

vdcScnclr = *  ;(.A=fill value)
   sta @scnclr_fill
   ldx #$2c
   stx @scnclr_page
-  lda @scnclr_page
   ldx #$12
   jsr vdcWrite
   lda @scnclr_fill
   ldx #$1f
   jsr vdcWrite
   lda #$ff
   ldx #$1e
   jsr vdcWrite
   dec @scnclr_page
   bne -
   rts
@scnclr_page !byte 0
@scnclr_fill !byte 0

;******** standard library ********
eputs = *
   ldx #stderr
   jmp fputs
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

palette_attr_lookup:
   !byte   $00
   !byte   $02
   !byte   $08
   !byte   $0a
   !byte   $04
   !byte   $06
   !byte   $0c
   !byte   $0e
   !byte   $20
   !byte   $22
   !byte   $28
   !byte   $2a
   !byte   $24
   !byte   $26
   !byte   $2c
   !byte   $2e
   !byte   $80
   !byte   $82
   !byte   $88
   !byte   $8a
   !byte   $84
   !byte   $86
   !byte   $8c
   !byte   $8e
   !byte   $a0
   !byte   $a2
   !byte   $a8
   !byte   $aa
   !byte   $a4
   !byte   $a6
   !byte   $ac
   !byte   $ae
   !byte   $40
   !byte   $42
   !byte   $48
   !byte   $4a
   !byte   $44
   !byte   $46
   !byte   $4c
   !byte   $4e
   !byte   $60
   !byte   $62
   !byte   $68
   !byte   $6a
   !byte   $64
   !byte   $66
   !byte   $6c
   !byte   $6e
   !byte   $c0
   !byte   $c2
   !byte   $c8
   !byte   $ca
   !byte   $c4
   !byte   $c6
   !byte   $cc
   !byte   $ce
   !byte   $e0
   !byte   $e2
   !byte   $e8
   !byte   $ea
   !byte   $e4
   !byte   $e6
   !byte   $ec
   !byte   $ee
   !byte   $00
   !byte   $03
   !byte   $09
   !byte   $0b
   !byte   $05
   !byte   $07
   !byte   $0d
   !byte   $0f
   !byte   $30
   !byte   $33
   !byte   $39
   !byte   $3b
   !byte   $35
   !byte   $37
   !byte   $3d
   !byte   $3f
   !byte   $90
   !byte   $93
   !byte   $99
   !byte   $9b
   !byte   $95
   !byte   $97
   !byte   $9d
   !byte   $9f
   !byte   $b0
   !byte   $b3
   !byte   $b9
   !byte   $bb
   !byte   $b5
   !byte   $b7
   !byte   $bd
   !byte   $bf
   !byte   $50
   !byte   $53
   !byte   $59
   !byte   $5b
   !byte   $55
   !byte   $57
   !byte   $5d
   !byte   $5f
   !byte   $70
   !byte   $73
   !byte   $79
   !byte   $7b
   !byte   $75
   !byte   $77
   !byte   $7d
   !byte   $7f
   !byte   $d0
   !byte   $d3
   !byte   $d9
   !byte   $db
   !byte   $d5
   !byte   $d7
   !byte   $dd
   !byte   $df
   !byte   $f0
   !byte   $f3
   !byte   $f9
   !byte   $fb
   !byte   $f5
   !byte   $f7
   !byte   $fd
   !byte   $ff
;Buffer for bitmap needs to start on a page boundary
* = $7000
bmapBuffer = *

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