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

* = aceToolAddress
jmp init
!byte aceID1,aceID2,aceID3
!byte 64,0

init:
    lda #FALSE
    jsr toolStatEnable              ;disable toolbar
    jsr aceWinSize
    stx columns
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
    jsr aceWinCls                   ;clear screen to $99
    lda #<irq                       ; setup IRQ vector
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
+   ldx is_copying_palette          ; is the palette still being changed ?
    beq +
    jsr copy_palette
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
; copy_palette
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
copy_palette = *
    ldx palette_copied_bytes
    ldy #7                          ; copy 8 bytes starting from the last
copy_loop:                              ; position. in total 256 bytes are copied
new_palette_addr = * + 1
    lda luminances, x               ; self modifying address
    sta luminances, x
    inx
    dey
    bpl copy_loop
    stx palette_copied_bytes
    cpx #00
    bne +
    dec is_copying_palette          ; is_copying_palette = false
+   rts

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; set_new_palette
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
set_new_palette = *
    inc is_copying_palette          ; is_copying_palette = true
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
    sta new_palette_addr ; copy_palette function
    lda palettes_table + 1, x
    sta new_palette_addr + 1
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
    lda sine_table, x
    adc sine_table, y
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
    lda sine_table, x
    adc sine_table, y
    sta x_buf + XX
    txa
    clc
    adc #3                  ; 3
    tax
    tya
    clc
    adc #7                  ; 7
    tay
}
    lda x_idx_b
    clc
    adc #02                         ; 2
    sta x_idx_b
    lda y_idx_b
    sec
    sbc #3                          ; -3
    sta y_idx_b

!set YY=0
!do until YY=25 {
    !for XX, 0, 19 {
        lda x_buf + XX
        adc y_buf + YY
        tax
        lda luminances, x
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

sine_table:
; autogenerated table: easing_table_generator.py -s128 -m255 -aTrue -r bezier:0,0.02,0.98,1
!byte   0,  0,  1,  1,  2,  2,  3,  4
!byte   4,  5,  6,  7,  8, 10, 11, 12
!byte  14, 15, 17, 18, 20, 21, 23, 25
!byte  27, 29, 31, 33, 35, 37, 39, 41
!byte  44, 46, 48, 51, 53, 55, 58, 60
!byte  63, 66, 68, 71, 73, 76, 79, 82
!byte  84, 87, 90, 93, 96, 98,101,104
!byte 107,110,113,116,119,122,125,128
!byte 130,133,136,139,142,145,148,151
!byte 154,157,159,162,165,168,171,173
!byte 176,179,182,184,187,189,192,195
!byte 197,200,202,204,207,209,211,214
!byte 216,218,220,222,224,226,228,230
!byte 232,234,235,237,238,240,241,243
!byte 244,245,247,248,249,250,251,251
!byte 252,253,253,254,254,255,255,255
; reversed
!byte 255,255,254,254,253,253,252,251
!byte 251,250,249,248,247,245,244,243
!byte 241,240,238,237,235,234,232,230
!byte 228,226,224,222,220,218,216,214
!byte 211,209,207,204,202,200,197,195
!byte 192,189,187,184,182,179,176,173
!byte 171,168,165,162,159,157,154,151
!byte 148,145,142,139,136,133,130,128
!byte 125,122,119,116,113,110,107,104
!byte 101, 98, 96, 93, 90, 87, 84, 82
!byte  79, 76, 73, 71, 68, 66, 63, 60
!byte  58, 55, 53, 51, 48, 46, 44, 41
!byte  39, 37, 35, 33, 31, 29, 27, 25
!byte  23, 21, 20, 18, 17, 15, 14, 12
!byte  11, 10,  8,  7,  6,  5,  4,  4
!byte   3,  2,  2,  1,  1,  0,  0,  0

x_buf !fill 40,0
y_buf !fill 25,0

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