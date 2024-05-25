!to "plasma",plain
!source "../cbm/sys/acehead.asm"
!source "../cbm/sys/toolhead.asm"

;'plasma': Simple VIC-II plasma effect
;Based on 'plasma' from Ricardo Quesada (https://github.com/ricardoquesada/c64-misc)
;
;Copyright© 2024 Brian Holdsworth
;This is free software, released under the MIT License.
;

;Use 1 to enable raster lines
DEBUG = 0

;zero page vars
columns = $02   ;(1) - store #columns displayed when program started
lum     = $04   ;(2)
myarg   = $06   ;(2)

* = aceToolAddress
jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0

main:
    ;parse arguments
    jsr set_sine    ;default to sine curve
    lda #1
    ldy #0
    jsr getarg
    lda zp
    ora zp+1
    bne +
    jmp init
+   jsr nextarg
    jmp init
nextarg:
    ldx #0
    ldy #0
-   lda argsus,x
    bne +
    rts
+   lda (zp),y
    cmp argsus,x
    beq +
    txa
    clc
    adc #4
    tax
    jmp -
+   inx
    iny
    lda (zp),y
    cmp argsus,x
    beq +
    inx
    inx
    inx
    jmp -
+   inx
    lda argsus,x
    sta zp+0
    inx
    lda argsus,x
    sta zp+1
    jmp (zp)
init:
    ;setup lua command
    ldx #0
    ldy #0
-   lda (myarg),y
    beq +
    sta luaarg,x
    inx
    iny
    jmp -
    ;start lua script
+   lda #<luacmd
    ldy #>luacmd
    sta zp+0
    sty zp+1
    lda #"W"
    jsr open
    bcc +
    lda #<errorScript
    ldy #>errorScript
    jmp eputs
    ;read curve values (256) bytes
+   lda #<curve
    ldy #>curve
    ldx #0
    jsr aceTtyGet                   ;get 256 byte response from lua
    ;init palette, screen, and IRQ
    lda #<luminances
    ldy #>luminances
    sta lum+0
    sty lum+1                       ;init to white palette
    lda #FALSE
    jsr toolStatEnable              ;disable toolbar
    jsr aceWinSize
    stx columns                     ;remember initial screen mode
    lda #0
    ldx #40
    jsr aceWinScreen                ;40-col screen
    lda #0
    sta $d020                       ; border color
    lda #0
    sta $d021                       ; background color
    lda #$c0
    ldx #$99
    ldy #$00
    jsr aceWinCls                   ;clear screen to chr $99
    lda #<irq                       ;setup IRQ vector
    ldy #>irq
    jsr aceIrqHook
    ;fall-through
main_loop:
    lda sync
    beq main_loop
    dec sync

!if DEBUG=1 {
    inc $d020
}
    jsr do_plasma
!if DEBUG=1 {
    dec $d020
}

    ldx palette_life                ; time to change palette ?
    dex
    stx palette_life
    bne +
    jsr set_new_palette
+   jsr aceConKeyAvail
    bcc quit
    jmp main_loop
quit:
    jsr aceConGetkey
    lda #$c0
    ldx #$20
    ldy #$00
    jsr aceWinCls                   ;clear screen to $20
    ldx columns
    cpx #40
    beq +
    lda #0
    jsr aceWinScreen                ;restore 80-col screen
+   jsr toolWinRestore
    lda #TRUE
    jsr toolStatEnable
    rts


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; set_new_palette
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
set_new_palette = *
    ldx palette_idx                 ; next palette
    inx
    cpx #TOTAL_PALETTES
    bne +
    ldx #0
+   stx palette_idx
    txa                             ; multiply by 2, since each .addr takes 2 bytes
    asl
    tax
    lda palettes_table, x           ; update "copy src addr" to be used in the
    sta lum+0
    lda palettes_table + 1, x
    sta lum+1
    rts


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; irq handler
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
irq = *
    inc sync
    rts


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_plasma
; animates the plasma
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
do_plasma = *
    ldx x_idx_a
    ldy y_idx_a
!for YY, 0, 24 {
    lda curve, x
    adc curve, y
    sta y_buf + YY
    txa
    clc
    adc #4                  ; 4
    tax
    tya
    clc
    adc #9                  ; 9
    tay
}
    lda x_idx_a
    clc
    adc #03                         ; 3
    sta x_idx_a
    lda y_idx_a
    sec
    sbc #05                         ; -5
    sta y_idx_a

    ;----------

    ldx x_idx_b
    ldy y_idx_b
!for XX, 0, 19 {
    lda curve, x
    adc curve, y
    sta x_buf + XX
    txa
    clc
    adc #3
    tax
    tya
    clc
    adc #7
    tay
}
    lda x_idx_b
    clc
    adc #02
    sta x_idx_b
    lda y_idx_b
    sec
    sbc #3
    sta y_idx_b

!set YY=0
!do until YY=25 {
    !for XX, 0, 19 {
        lda x_buf + XX
        adc y_buf + YY
        tay
        lda (lum), y
        sta $d800 + YY * 40 + XX
        sta $d800 + YY * 40 + (39-XX)
    }
    !set YY=YY+1
}
    rts

x_idx_a !byte 0
y_idx_a !byte 128
x_idx_b !byte 0
y_idx_b !byte 128




;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; global variables
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
sync:                   !byte 0         ; used by raster IRQ to sync main loop
palette_life:           !byte 30        ; palette life. when 0, palette is changed
palette_idx:            !byte 255       ; which palette to use. start with -1, so the first one will be 0
is_copying_palette:     !byte 0         ; boolean. true when the palette is still being copied
palette_copied_bytes:   !byte 0         ; how many bytes have been copied so far

palettes_table !le16 luminances_grey,luminances_7_light,luminances_16,luminances_7_dark
TOTAL_PALETTES = (* - palettes_table) / 2

; starts with an empty (white) palette
luminances:
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01

luminances_grey:
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
!byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
!byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
!byte $0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c
!byte $0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c
!byte $0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c
!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

luminances_16:
!byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
!byte $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d
!byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
!byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
!byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
!byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
!byte $0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a
!byte $0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e
!byte $0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c
!byte $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08
!byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
!byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
!byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09
!byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

luminances_7_dark:
!byte $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d
!byte $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d
!byte $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d
!byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
!byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
!byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
!byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
!byte $0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c
!byte $0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c
!byte $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08
!byte $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08
!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
!byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09
!byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09
!byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09

luminances_7_light:
!byte $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d
!byte $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d
!byte $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d
!byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
!byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
!byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
!byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
!byte $0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c
!byte $0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c
!byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
!byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
!byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
!byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
!byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06

x_buf !fill 40,0
y_buf !fill 25,0


;******** cli argument handling ********
doUsageMsg:
    lda #<usemsg
    ldy #>usemsg
    jsr eputs
    ;fall-through
die:
    lda #1
    ldx #0
    jmp aceProcExit

quadnm !pet "inquad",0
set_quad:
    lda #<quadnm
    ldy #>quadnm
    sta myarg+0
    sty myarg+1
    rts
cubicnm !pet "incubic",0
set_cubic:
    lda #<cubicnm
    ldy #>cubicnm
    sta myarg+0
    sty myarg+1
    rts
exponm !pet "inexpo",0
set_expon:
    lda #<exponm
    ldy #>exponm
    sta myarg+0
    sty myarg+1
    rts
sinm !pet "insine",0
set_sine:
    lda #<sinm
    ldy #>sinm
    sta myarg+0
    sty myarg+1
    rts
circnm !pet "incirc",0
set_circle:
    lda #<circnm
    ldy #>circnm
    sta myarg+0
    sty myarg+1
    rts
backnm !pet "inback",0
set_back:
    lda #<backnm
    ldy #>backnm
    sta myarg+0
    sty myarg+1
    rts
luacmd !pet "l:plasma.lua "
luaarg !fill 8,0
argsus = *
   !pet "/?"  ;show help
   !word doUsageMsg
   !pet "qu"  ;do quad curve
   !word set_quad
   !pet "cu"  ;do cubic curve
   !word set_cubic
   !pet "ex"  ;do expon curve
   !word set_expon
   !pet "si"  ;do sine curve
   !word set_sine
   !pet "ci"  ;so circle curve
   !word set_circle
   !byte 0


;******** messages ********
usemsg = *
   !pet "plasma [curve]",chrCR
   !pet "where the default curve is 'sine'",chrCR
   !pet "curves: 'quad','cubic,'expon','sine','circle'",chrCR,0
errorScript !pet "Error launching Lua script",0


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


;256 bytes at the end of the program used for curve data
curve = *

;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2024 Brian Holdsworth                                    │
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