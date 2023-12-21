!zone xVdc {

;vdc register addresses
vdcSelect = $d600
vdcStatus = $d600
vdcData   = $d601
.vdcRegNum !byte 0

VDC_GRMODE_MAX = 7

;current graphics mode vars
.grmode !byte 0
.gr_x !byte 80
.gr_y !byte 25
.columns !byte 0
.rows !byte 0
.bmadr0 !word 0
.bmadr1 !word 0
.atadr0 !word 0
.atadr1 !word 0

; This represents the _canonical_ VDC graphics modes, as defined
; by the specific register values for each standard mode. Many
; variations _can be_ acheived with other VDC register settings.

; Mode 0: standard 80 column text mode with attributes (rows variable)
; Mode 1: medres (640x200), monochrome bitmap (no attr, 264 line NTSC)
; Mode 2: hires (640x480), monochrome bitmap (64k, no attr, interlace, 525 line NTSC)
; Mode 3: lores (up to 320x256), low-color bitmap (8x8 attr, 312 line PAL)
; Mode 4: hires (up to 640x480), low-color bitmap (64k, 8x8 attr, interlace, 525 line NTSC)
; Mode 5: lores (320x200), high-color bitmap (8x2 attr, 312 line PAL)
; Mode 6: hires (640x480), high-color bitmap (64k, 8x2 attr, interlace, 525 line NTSC)
; Mode 7: super-res (800x600), monochrome bitmap (64k, no attr, interlace, 625 line PAL)

.vdc_mode_preset:
   !word .vdcreg_mode_1 ;non-interlace, optinal 2nd buffer
   !byte 80,25          ;columns, rows
   !word $0000,$4000    ;main bitmap addr/2nd bitmap offset
   !word $ffff,$ffff    ;main attr addr/2nd attr offset ($ffff=no attr)
   !word .vdcreg_mode_2 ;interlace
   !byte 80,60          ;columns, rows
   !word $0000,$4b00    ;even bitmap addr/odd bitmap offset
   !word $ffff,$ffff    ;even attr addr/odd attr offset
   !word .vdcreg_mode_3 ;non-interlace, optional 2nd buffer
   !byte 40,32
   !word $0000,$2d00
   !word $2800,$2d00
   !word .vdcreg_mode_4 ;interlace
   !byte 80,60
   !word $0000,$4b00
   !word $a000,$12c0
   !word .vdcreg_mode_5 ;non-interlace, optional 2nd buffer
   !byte 40,25
   !word $0000,$3800
   !word $2800,$3800
   !word .vdcreg_mode_6 ;interlace
   !byte 80,60
   !word $0500,$5280
   !word $a730,$2940
   !word .vdcreg_mode_7 ;interlace
   !byte 100,75
   !word $0000,$76C0
   !word $ffff,$ffff
.vdcreg_mode_1:
   !byte   $06,$19         ;R6 display height=25 rows
   !byte   $18,$00         ;R24
   !byte   $0c,$00         ;R12
   !byte   $0d,$00         ;R13 display start=$0000
   !byte   $14,$40         ;R20 attr start (not used)
   !byte   $19,$87         ;R25(7-5)=%100 bitmap mode w/o attributes
   !byte   $1a,$e0         ;R26 foreground/background color
   !byte   255
.vdcreg_mode_2:
   !byte   $00,$7e         ;R0 total width=126
   !byte   $01,$50         ;R1 display width=80 cols (640 pix)
   !byte   $02,$66         ;R2 vert sync @ $66(102) cols
   !byte   $04,$40         ;R4 vert total rows (64)
   !byte   $05,$05         ;R5 vert total adjust
   !byte   $06,$3c         ;R6 display height=60 rows
   !byte   $07,$3e         ;R7 vertical sync pos
   !byte   $08,$03         ;R8 interlace sync+video
   !byte   $18,$00         ;R24
   !byte   $19,$87         ;R25(7-5)=%100 bitmap mode w/o attributes
   !byte   $1b,$00         ;R27 row increment
   !byte   $1c,$10         ;R28 64kb VRAM
   !byte   $14,$a0         ;R20 
   !byte   $15,$00         ;R21 attr start
   !byte   $0c,$00         ;R12 (even frame)
   !byte   $0d,$00         ;R13 display start=$0000
   !byte   $1a,$e0         ;R26 foreground/background color
   !byte   $24,$03         ;R36 vram refresh per scanline
   !byte   255             ;end
.vdcreg_mode_3:
   !byte   $00,$3f         ;R0 total width=63
   !byte   $01,$28         ;R1 display width=40 cols (320 pix)
   !byte   $02,$37         ;R2 vert sync @ $37 (left edge)
   !byte   $04,$26         ;R4 vert total rows
   !byte   $06,$20         ;R6 display height=32 rows (256 pix)
   !byte   $07,$24         ;R7
   !byte   $08,$00         ;R8 non-interlace
   !byte   $16,$89         ;R22 8pix per character
   !byte   $19,$d7         ;R25(7-4)=%1101 bitmap mode w/ attributes
                           ;  and double-pixel width
   !byte   $0c,$00         ;R12
   !byte   $0d,$00         ;R13 display start=$0000
   !byte   $14,$28         ;R20 
   !byte   $15,$00         ;R21 attr start=$2800
   !byte   $22,$3e         ;R34 
   !byte   $23,$32         ;R35 horiz blank col (50) 
   !byte   255             ;end
.vdcreg_mode_4:
   !byte   $00,$7e         ;R0 total width=126
   !byte   $01,$50         ;R1 display width=80 cols (640 pix)
   !byte   $02,$66         ;R2 vert sync @ $66(102) cols
   !byte   $04,$40         ;R4 vert total rows (64)
   !byte   $05,$05         ;R5 vert total adjust
   !byte   $06,$3c         ;R6 display height=60 rows
   !byte   $07,$3e         ;R7 vertical sync pos
   !byte   $08,$03         ;R8 interlace sync+video
   !byte   $18,$00         ;R24
   !byte   $19,$c7         ;R25(7-5)=%110 bitmap mode w/ attributes
   !byte   $1b,$00         ;R27 row increment
   !byte   $1c,$10         ;R28 64kb VRAM
   !byte   $14,$a0         ;R20 
   !byte   $15,$00         ;R21 attr start
   !byte   $0c,$00         ;R12 (even frame)
   !byte   $0d,$00         ;R13 display start=$0000
   !byte   $1a,$00         ;R26 foreground/background color
   !byte   $24,$03         ;R36 vram refresh per scanline
   !byte   255             ;end
.vdcreg_mode_5:
; VDC Internal Registers:
; 00: 7f 50 66 49  9b e0 64 8c  fc e1 a0 e7  00 00 xx xx  
; 10: xx xx xx xx  3e 80 78 e8  20 c7 f0 00  3f xx xx xx  
; 20: xx xx 7d 64  f0 3f
   !byte   $00,$3f         ;R0 total width=63
   !byte   $01,$28         ;R1 display width=40 cols (320 pix)
   !byte   $02,$37         ;R2 vert sync @ $37 (left edge)
   !byte   $03,$49
   !byte   $04,$9b         ;R4 vert total rows
   !byte   $05,$e0
   !byte   $06,$64         ;R6 display height=100 rows (200 pix)
   !byte   $07,$7b         ;R7
   !byte   $08,$fc
   !byte   $09,$e1         ;R9 2 lines per row
   !byte   $0b,$e7
   !byte   $1a,$a0
   !byte   $16,$89         ;R22 8pix per character
   !byte   $17,$e8
   !byte   $18,$20
   !byte   $19,$d7         ;R25(7-4)=%1101 bitmap mode w/ attributes
                           ;  and double-pixel width
   !byte   $1a,$f0
   !byte   $1b,$00
   !byte   $1c,$3f
   !byte   $0c,$00         ;R12
   !byte   $0d,$00         ;R13 display start=$0000
   !byte   $14,$28         ;R20 
   !byte   $15,$00         ;R21 attr start=$2800
   !byte   $24,$f0
   !byte   255             ;end
.vdcreg_mode_6:
   !byte   $00,$7e         ;R0 total width=126
   !byte   $01,$50         ;R1 display width=80 cols (640 pix)
   !byte   $02,$66         ;R2 vert sync @ $66(102) cols
   !byte   $03,$89         ;R3 vert/horiz sync pulse widths
   !byte   $04,$84         ;R4 vert total rows (128)
   !byte   $05,$e3         ;R5 vert total adjust
   !byte   $06,$84         ;R6 display height=128 rows
   !byte   $07,$83         ;R7 vertical sync pos
   !byte   $08,$ff         ;R8 interlace sync+video
   !byte   $09,$e3         ;R9 scan lines per char -1
   !byte   $0a,$a0         ;no cursor
   !byte   $0c,$00         ;R12 (even frame)
   !byte   $0d,$00         ;R13 display start=$0000
   !byte   $14,$a5         ;R20 
   !byte   $15,$00         ;R21 attr start
   !byte   $16,$78         ;R22 char horiz. size
   !byte   $17,$e8         ;R23 char vertical size
   !byte   $18,$20         ;R24
   !byte   $19,$c7         ;R25(7-5)=%110 bitmap mode w/ attributes
   !byte   $1a,$f0         ;R26 fgd/bkgd color
   !byte   $1b,$00         ;R27 row increment
   !byte   $1c,$f0         ;R28 64kb VRAM
   !byte   $24,$f2         ;R36 vram refresh per scanline
   !byte   255             ;end
.vdcreg_mode_7:
   !byte   $00,$7e         ;R0 total width=126
   !byte   $01,$64         ;R1 display width=100 cols (800 pix)
   !byte   $02,$6e         ;R2 vert sync @$6e (110) cols
   !byte   $03,$89         ;R3
   !byte   $04,$4d         ;R4 vert total rows
   !byte   $05,$01         ;R5 vert total adjust
   !byte   $06,$4c         ;R6 display height
   !byte   $07,$4d         ;R7 vertical sync pos
   !byte   $08,$03         ;R8 interlace sync+video
   !byte   $19,$87         ;R25(7-5)=%100 bitmap mode w/o attributes
   !byte   $0c,$00         ;R12 (even frame)
   !byte   $0d,$00         ;R13 display start=$0000
   !byte   $14,$ff         ;R20 (no attribute)
   !byte   $18,$00         ;R24
   !byte   $1a,$e0         ;R26 foreground/background color
   !byte   $1b,$00         ;R27 row increment
   !byte   $1c,$10         ;R28
   !byte   $23,$6a         ;R35 horiz blank col (106)
   !byte   $24,$03         ;R36 vram refresh per scanline
   !byte   255             ;end

; _Important_: Only switches any mode TO or FROM MODE 0.
xVdcGrMode = *  ;(.A=mode, .X=cols, .Y=rows): .X=cols, .Y=rows, .CS=error
   sta .grmode
   stx .gr_x
   sty .gr_y
   cmp #0
   bne ++

   ;mode 0- return to default VDC text mode settings
   jsr aceGrExit
   lda .gr_y
   ldx #80
   jsr aceWinScreen
   lda #$00
   sta .vdcInterlaced
   clc
+  rts

   ;mode 1-7
++ cmp #VDC_GRMODE_MAX+1
   bcc +
   rts               ;illegal mode
+  jsr .vramCheck
   bcc +
   rts               ;requires more vram
   ;need pointer to mode settings (.A-1 * 12)
+  sec
   sbc #1
   asl
   asl
   sta zw+0 ;4x temp. storage
   asl      ;8x
   clc
   adc zw+0 ;8x+4x=12x
   tax
   ;register pairs -> (zp)
   lda .vdc_mode_preset,x
   sta zp
   inx
   lda .vdc_mode_preset,x
   sta zp+1
   ;default X,Y dims -> zw
   inx
   lda .vdc_mode_preset,x
   sta zw
   sta .columns
   inx
   lda .vdc_mode_preset,x
   sta zw+1
   sta .rows
   ;bitmap and attr address
   inx
   lda .vdc_mode_preset,x
   sta .bmadr0+0
   inx
   lda .vdc_mode_preset,x
   sta .bmadr0+1
   inx
   lda .vdc_mode_preset,x
   sta .bmadr1+0
   inx
   lda .vdc_mode_preset,x
   sta .bmadr1+1
   inx
   lda .vdc_mode_preset,x
   sta .atadr0+0
   inx
   lda .vdc_mode_preset,x
   sta .atadr0+1
   inx
   lda .vdc_mode_preset,x
   sta .atadr1+0
   inx
   lda .vdc_mode_preset,x
   sta .atadr1+1

   ldy #0
-  lda (zp),y
   cmp #255    ;check for last entry
   bne +
   jmp .set_dim_cont
+  cmp #25     ;check for version-dependency (R25)
   bne +
   jsr .vdcVersionCheck
   iny
   jmp -
+  tax
   iny
   lda (zp),y
   jsr vdcWrite
   iny
   jmp -
   .set_dim_cont = *
   ;update default dimensions if provided
   lda .gr_x
   ora .gr_y
   beq .set_mouse_cont
   lda .gr_x
   cmp #0
   beq +
   cmp zw
   bcs +
   sta zw
+  lda .gr_y
   cmp #0
   beq +
   cmp zw+1
   bcs +
   sta zw+1
   sec
+  jsr xVdcGrExtents
   .set_mouse_cont = *
   ;** set mouse limits
   lda #0
   sta aceMouseLimitX+1
   sta aceMouseLimitY+1
   lda zw
   sta aceMouseLimitX+0
   asl aceMouseLimitX+0
   rol aceMouseLimitX+1
   asl aceMouseLimitX+0
   rol aceMouseLimitX+1
   asl aceMouseLimitX+0
   rol aceMouseLimitX+1
   lda zw+1
   sta aceMouseLimitY+0
   asl aceMouseLimitY+0
   rol aceMouseLimitY+1
   asl aceMouseLimitY+0
   rol aceMouseLimitY+1
   asl aceMouseLimitY+0
   rol aceMouseLimitY+1
   ;** set interlace flag
   ldx #$00
   lda .grmode
   cmp #7
   bne +
   ldx #$ff
+  and #1
   bne +
   ldx #$ff
+  stx .vdcInterlaced
   ;** return actual extents
   ldx zw
   stx .gr_x
   ldy zw+1
   sty .gr_y
   clc
   rts

;Change the pixel extents of current bitmap.
; - VDC registers adjusted to center on screen.
; - Call ONLY after setting mode with xVdcGrMode.
;** ( zw=X/8, zw+1=Y/8 for X,Y pixels
;    .CS=set, .CC=get)
;.CC RETURNS: .X,.Y = x/8, y/8 pixel extents
;             syswork+0 = VDC bitmap start addr (even field, if interlace)
;             syswork+2 = VDC attr start addr (even field, if interlace)
;             syswork+4 = VDC bitmap start addr (odd field, if interlace)
;             syswork+6 = VDC attr start addr (odd field, if interlace)
xVdcGrExtents = *
   bcs +
   lda .bmadr0+0
   ldy .bmadr0+1
   sta syswork+0
   sty syswork+1
   lda .atadr0+0
   ldy .atadr0+1
   sta syswork+2
   sty syswork+3
   lda .bmadr1+0
   ldy .bmadr1+1
   sta syswork+4
   sty syswork+5
   lda .atadr1+0
   ldy .atadr1+1
   sta syswork+6
   sty syswork+7
   ldx .gr_x
   ldy .gr_y
   rts
+  ldx zw
   ldy zw+1
   sta .gr_x
   sty .gr_y
   ;R2 = R2 - (R1 - X)/2
   ldx #1
   jsr vdcRead
   sec
   sbc zw
   lsr
   sta syswork+0
   ldx #2
   jsr vdcRead
   sec
   sbc syswork+0
   jsr vdcWrite
   ;R7 = R7 - (R6 - Y)/2
   ldx #6
   jsr vdcRead
   sec
   sbc zw+1
   lsr
   sta syswork+0
   ldx #7
   jsr vdcRead
   sec
   sbc syswork+0
   jsr vdcWrite
   rts
   .vramCheck = *
   pha
   cmp #1
   bne +
   jmp ++
+  cmp #3
   bne +
   jmp ++
+  cmp #5
   bne +
   jmp ++
+  jsr aceMiscSysType
   lda syswork+0
   cmp #64
   beq ++
   sec
   pla
   rts
++ clc
   pla
   rts
   .vdcVersionCheck = *  ;special handling for R25
   lda vdcSelect
   and #$07
   bne +
   iny
   lda (zp),y
   and #$f8
   ldx #25
   jmp vdcWrite
+  iny
   lda (zp),y
   ldx #25
   jmp vdcWrite

vdcRamWrite = *  ;( .A=value )
   ldx #$1f

vdcWrite = *  ;( .X=register, .A=value )
   stx .vdcRegNum
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sta vdcData
   rts

vdcAddrWrite16 = *  ;( .AY=value )
   ldx #$12
vdcWrite16 = *  ;( .X=hiRegister, .AY=value )
   stx .vdcRegNum
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sty vdcData
   inx
   stx .vdcRegNum
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sta vdcData
   rts

vdcRamRead = *  ;( ) : .A=value
   ldx #$1f

vdcRead = *  ;( .X=register ) : .A=value
   stx .vdcRegNum
   stx vdcSelect
-  bit vdcStatus
   bpl -
   lda vdcData
   rts

vdcDumpRegs = *   ;((zp)=filename) : .CS=error
   lda #"W"
   jsr open
   bcc +
   rts
+  sta .dumpFd
   ldx #0
-  cpx #37
   beq +
   jsr vdcRead
   sta .reg_dump_buffer,x
   inx
   jmp -
+  lda #<.reg_dump_buffer
   ldy #>.reg_dump_buffer
   sta zp
   sty zp+1
   ldy #0
   lda #37
   ldx .dumpFd
   jsr write
   lda .dumpFd
   jmp close
.reg_dump_buffer !fill 37,0
.dumpFd !byte 0

vdcMult = *
   pha
   lda .columns
   cmp #100
   bne +
   pla
   jmp .mult100
+  cmp #80
   bne +
   pla
   jmp .mult80
+  pla
   jmp .mult40
.msb !byte 0
.mult100 = *  ;( .AY=row, .X=col ) : (sw+0)=row*100+col, .X:unch
   sta syswork+0
   sty .msb
   ldy #1
-  asl
   rol syswork+1
   asl
   rol syswork+1
   adc syswork+0
   sta syswork+0
   lda syswork+1
   adc .msb
   sta syswork+1
   asl syswork+0
   rol syswork+1
   lda syswork+1
   sta .msb
   lda syswork+0
   dey
   bpl -
   lda syswork+0
   stx syswork+0
   clc
   adc syswork+0
   bcc +
   inc syswork+1
+  sta syswork+0
   rts
.mult80 = *  ;( .A=row:0-255, .X=col ) : (sw+0)=row*80+col, .X:unch
   sta syswork+0
   ldy #0
   sty syswork+1
   asl
   rol syswork+1
   asl
   rol syswork+1
   adc syswork+0
   bcc +
   inc syswork+1
+  asl
   rol syswork+1
   asl
   rol syswork+1
   asl
   rol syswork+1
   asl
   rol syswork+1
   stx syswork+0
   clc
   adc syswork+0
   bcc +
   inc syswork+1
+  sta syswork+0
   rts
.mult40 = *  ;( .A=row:0-255, .X=col ) : (sw+0)=row*40+col, .X:unch
   sta syswork+0
   ldy #0
   sty syswork+1
   asl
   rol syswork+1
   asl
   rol syswork+1
   adc syswork+0
   bcc +
   inc syswork+1
+  asl
   rol syswork+1
   asl
   rol syswork+1
   asl
   rol syswork+1
   stx syswork+0
   clc
   adc syswork+0
   bcc +
   inc syswork+1
+  sta syswork+0
   rts

.vdcBmFrame !byte 0
.vdcBmRows  !byte 0
.vdcBmCols  !byte 0
.vdcBmBuffer = $400
.vdcGrOpFlags = syswork+15
.vdcGrOpFlagsIn !byte 0
.vdcInterlaced !byte 0   ;$ff=interlaced video
.mem_base !word 0
.frame_base !word 0

xVdcGrAttr = * ;uses same args as xVdcGrOp
   pha
   txa
   pha
   lda .atadr0+1
   sta .mem_base+1
   lda .atadr0+0
   sta .mem_base+0
   lda .atadr1+0
   sta .frame_base+0
   lda .atadr1+1
   sta .frame_base+1
   pla
   tax
   pla
   jmp vdcGrOpBegin
xVdcGrOp = *  ;( .A=opflags, .X=X, (sw+0)=Y, .Y=cols, (sw+2)=rows, sw+4=interlv,
   ;**           sw+5=fillval, (sw+6)=sPtr, (sw+8)=dPtr, (sw+10)=mPtr )
   ;**           <all syswork arguments can change>
   ;** opflags: $80=get, $40=put, $20=copy, $10=fill,$8=mask/attr,$4=and,$2=xor,$1=or
   pha
   txa
   pha
   lda .bmadr0+1
   sta .mem_base+1
   lda .bmadr0+0
   sta .mem_base+0
   lda .bmadr1+0
   sta .frame_base+0
   lda .bmadr1+1
   sta .frame_base+1
   pla
   tax
   pla
   vdcGrOpBegin = *
   sta .vdcGrOpFlags
   sta .vdcGrOpFlagsIn
   sty .vdcBmCols
   and #$0f
   beq +
   bit .vdcGrOpFlags
   bmi +
   lda #<.vdcBmBuffer
   ldy #>.vdcBmBuffer
   sta syswork+8
   sty syswork+9
   lda .vdcGrOpFlags
   ora #$80
   sta .vdcGrOpFlags
+  clc
   lda .vdcBmCols
   adc syswork+4
   sta syswork+4
   bit .vdcInterlaced
   bmi +
   lda syswork+0
   ldy syswork+1
   jsr vdcMult
   jmp vdcGrOpLoop
+  lsr syswork+1
   lda syswork+0
   sta .vdcBmFrame
   ror
   ldy syswork+1
   jsr vdcMult
   lda .vdcBmFrame
   and #$01
   beq vdcGrOpLoop
   clc
   lda syswork+0
   adc .frame_base+0
   sta syswork+0
   lda syswork+1
   adc .frame_base+1
   sta syswork+1
vdcGrOpLoop = *
   ldy #0
   cpy .vdcBmCols
   bne vdcGrOpGet
   jmp vdcGrOpContinue
vdcGrOpGet = *
   bit .vdcGrOpFlags
   bpl vdcGrOpPut
   jsr .vdcSetaddr
   lda #$1f
   sta .vdcRegNum
   sta vdcSelect
   ldy #0
-  bit vdcStatus
   bpl -
   lda vdcData
   sta (syswork+8),y
   iny
   cpy .vdcBmCols
   bcc -
vdcGrOpPut = *
   bit .vdcGrOpFlags
   bvc vdcGrOpCopy
   jsr .vdcSetaddr
   lda #$1f
   sta .vdcRegNum
   sta vdcSelect
   ldy #0
vdcGrOpPutLoop:
-  lda .vdcGrOpFlags
   and #$0f
   bne +
-  lda (syswork+6),y
   jmp vdcGrPut
+  and #$08
   bne +
   lda (syswork+8),y
   jmp ++
+  lda (syswork+10),y
   eor #$ff
   and (syswork+8),y
++ ldx .vdcGrOpFlags
   stx syswork+14
   lsr syswork+14
   bcc +
   ora (syswork+6),y
   jmp vdcGrPut
+  lsr syswork+14
   bcc +
   eor (syswork+6),y
   jmp vdcGrPut
+  lsr syswork+14
   bcc -
   sta syswork+14
   lda (syswork+6),y
   eor #$ff
   and syswork+14

   vdcGrPut = *
-  bit vdcStatus
   bpl -
   sta vdcData
   iny
   cpy .vdcBmCols
   bcc vdcGrOpPutLoop
vdcGrOpCopy = *
   lda .vdcGrOpFlags
   and #$20
   beq vdcGrOpFill
   ldx #$20
   jsr .vdcSetaddr
   lda #$00  ;xx get real address
   ldy #$00
   jsr vdcAddrWrite16
   ldx #$1e
   lda .vdcBmCols
   jsr vdcWrite
vdcGrOpFill = *
   lda .vdcGrOpFlags
   and #$10
   beq vdcGrOpContinue
   jsr .vdcSetaddr
   lda syswork+5
   jsr vdcRamWrite
   ldx .vdcBmCols
   dex
   beq vdcGrOpContinue
   txa
   ldx #$1e
   jsr vdcWrite
vdcGrOpContinue = *
   lda syswork+2+0
   bne +
   dec syswork+2+1
+  dec syswork+2+0
   lda syswork+2+0
   ora syswork+2+1
   bne +
   clc
   rts
+  bit .vdcGrOpFlagsIn
   bmi +
   clc
   lda syswork+8+0
   adc syswork+4
   sta syswork+8+0
   bcc +
   inc syswork+8+1
+  bit .vdcGrOpFlags
   bvc +
   clc
   lda syswork+6+0
   adc syswork+4
   sta syswork+6+0
   bcc +
   inc syswork+6+1
+  lda .vdcGrOpFlags
   and #$08
   beq +
   clc
   lda syswork+10+0
   adc syswork+4
   sta syswork+10+0
   bcc +
   inc syswork+10+1
+  bit .vdcInterlaced
   bmi +
   lda .columns
   ldy #0
   jmp ++
+  lda .vdcBmFrame
   inc .vdcBmFrame
   and #$01
   bne +
   lda .frame_base+0
   ldy .frame_base+1
   jmp ++
+  sec
   lda syswork+0
   sbc .frame_base+0
   sta syswork+0
   lda syswork+1
   sbc .frame_base+1
   sta syswork+1
   lda .columns
   ldy #0
++ clc
   adc syswork+0
   sta syswork+0
   tya
   adc syswork+1
   sta syswork+1
   jmp vdcGrOpLoop
.vdcSetaddr = *
   lda syswork+0
   clc
   adc .mem_base+0
   pha
   lda syswork+1
   adc .mem_base+1
   tay
   pla
   jmp vdcAddrWrite16

xVdcMemClear = *  ;(.A=fill bits, .Y=fill attrs)
   sta .mempattern
   sty .mempattern+1
   jsr .vdcClearBitmap
   jmp .vdcClearAttr
.vdcClearBitmap = *
   lda #$00
   ldy #$00
   jsr vdcAddrWrite16
   jsr aceMiscSysType
   lda syswork+0
   ldy #$ff
   cmp #64
   beq +
   ldy #$3f
+  nop
-  dey
   bne +
   rts
+  lda .mempattern
   jsr vdcRamWrite
   ldx #30
   lda #$ff
   jsr vdcWrite
   jmp -
.vdcClearAttr = *
   ldx #20
   jsr vdcRead
   tay
   lda #$00
   jsr vdcAddrWrite16
   ldy .rows
-  dey
   bne +
   rts
+  lda .mempattern+1
   jsr vdcRamWrite
   ldx #30
   lda .columns
   jsr vdcWrite
   jmp -
.mempattern !byte 0,0

xVdcRowAddr = *   ;(.AY=row): sw+0=addr
   sta syswork+0
   sty syswork+1
   jsr chkAddrCache
   bcs +
   ;row addr from cache
   jmp frameBaseAdjust
   ;compute row addr & cache
+  lda syswork+0
   ldy syswork+1
   sta cache_row_val+0
   sty cache_row_val+1
   bit .vdcInterlaced
   bpl +
   lsr syswork+1
   ror
   ldy syswork+1
+  ldx #0
   jsr vdcMult
   lda syswork+0
   sta cache_row_addr+0
   lda syswork+1
   sta cache_row_addr+1
   frameBaseAdjust = *
   bit .vdcInterlaced
   bpl +
   ;check if odd field
   lda cache_row_val+0
   and #$01
   beq +
   lda syswork+0
   clc
   adc .bmadr1+0
   sta syswork+0
   lda syswork+1
   adc .bmadr1+1
   sta syswork+1
   rts
+  lda syswork+0
   clc
   adc .bmadr0+0
   sta syswork+0
   lda syswork+1
   adc .bmadr0+1
   sta syswork+1
   rts
chkAddrCache = *
   cpy cache_row_val+1
   beq +
   sec
   rts
+  sbc cache_row_val+0
   cmp #$ff
   bne ++
   ;up one row
   dec cache_row_val+0
   bit .vdcInterlaced
   bpl +
   lda cache_row_val+0
   and #$01
   beq +
   jmp .notFromCache
+  lda cache_row_addr+0
   sec
   sbc .columns
   sta cache_row_addr+0
   sta syswork+0
   lda cache_row_addr+1
   sbc #0
   sta cache_row_addr+1
   sta syswork+1
   clc
   rts
++ cmp #$01
   bne ++
   ;down one row
   inc cache_row_val+0
   bit .vdcInterlaced
   bpl +
   lda cache_row_val+0
   and #$01
   beq +
   jmp .notFromCache
+  lda cache_row_addr+0
   clc
   adc .columns
   sta cache_row_addr+0
   sta syswork+0
   lda cache_row_addr+1
   adc #0
   sta cache_row_addr+1
   sta syswork+1
   clc
   rts
++ cmp #0
   bne +
   ;same row; just use cached addr
   lda cache_row_addr+0
   ldy cache_row_addr+1
   sta syswork+0
   sty syswork+1
   clc
   rts
   .notFromCache = *
+  sec
   rts
cache_row_val !byte 0,$ff
cache_row_addr !byte 0,0

xVdcDblBuffer = *
   bit .vdcInterlaced
   bpl +
   rts   ;double-buffer not supported w/ interlace
+  jsr aceMiscSysType
   lda syswork+0
   cmp #64  ;require 64kB vram
   beq +
   rts
   ;R28 = 64kb VRAM
+  ldx #$1c
   lda #$10
   jsr vdcWrite
   ;clear row addr cache
   lda #$ff
   sta cache_row_val+1
   rts

xVdcBufswap = *
   ; bmadr0 <- R12/13
   ldx #12
   jsr vdcRead
   sta .bmadr0+1
   ldx #13
   jsr vdcRead
   sta .bmadr0+0
   ; R12/13 <- bmadr1
   ldx #12
   lda .bmadr1+1
   jsr vdcWrite
   ldx #13
   lda .bmadr1+0
   jsr vdcWrite
   ; bmadr1 <- bmadr0
   lda .bmadr0+0
   ldy .bmadr0+1
   sta .bmadr1+0
   sty .bmadr1+1
   rts
}

!ifndef xGrMode {
   xGrMode = xVdcGrMode
   xGrExtents = xVdcGrExtents
   xGrOp = xVdcGrOp
   xGrAttr = xVdcGrAttr
   xGrClear = xVdcMemClear
   xGrDblBuffer = xVdcDblBuffer
   xGrBufswap = xVdcBufswap
}
