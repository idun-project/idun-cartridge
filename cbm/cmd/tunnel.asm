!source "sys/acehead.asm"
!source "sys/toolhead.asm"
!source "toolx/gfx.asm"

jmp main

; Constants
CENTER_X  = 20         ; Screen center X (for 40c bitmap)
CENTER_Y  = 100        ; Screen center Y
NUM_RECT  = 8          ; Number of rectangles
NEAR_Z    = 8          ; Smallest Z before reset
FAR_Z     = 24         ; Largest Z (starting depth)
SPEED     = 2          ; Z decrement per frame
PI        = 3.14159265358979323846

; Zero Page variables
zp_angle  = $02       ; Angle for wobble sine
size_x    = $03       ; rectangle size (width/2)
size_y    = $04       ; height/2
zrect     = $05       ; current rect
wobble_x  = $06       ; X/Y wobble value
wobble_y  = $07
ul        = $08       ; upper-left of current *Rects
pl        = $0a       ; upper-left of previous *Rects
zp_z      = $0c       ; Z-depths array start (NUM_RECT bytes)

Rects !fill NUM_RECT*8,0

; --------------------------------------
; Main loop entry
main = *
    ;** gfx mode 3
    lda #FALSE
    jsr toolStatEnable
    lda #$03
    ldx #$00
    ldy #$00
    jsr xGrMode
    ;** clear bitmap and set colors
    lda #$00
    ldy #$02
    jsr xGrClear
    lda #$10
    jsr xGrSetColor
    jsr init_rectangles

loop:
    dec zrect
    bpl +
    lda #NUM_RECT-1
    sta zrect
+   jsr update_and_draw_rect
    jsr checkStop
    inc zp_angle
    jmp loop

; --------------------------------------
; Initialize rectangle Z depths
init_rectangles:
    ldx #0
    stx zp_angle
    ldx #NUM_RECT
    stx zrect
init_loop:
    lda #FAR_Z
    sta zp_z, x
    dex
    bpl init_loop
    rts

; --------------------------------------
; Update Z depth, calculate sizes, apply wobble, draw rectangles
update_and_draw_rect:
    jsr erase
    ; Update Z depth
    ldx zrect
    lda zp_z, x
    clc
    sbc #SPEED
    cmp #NEAR_Z
    bcs no_overflow
    lda #FAR_Z
no_overflow:
    sta zp_z, x          ; Save updated Z

    ; Lookup size (size = approx 128/Z)
    ldy zp_z, x
    lda sizex_lookup, y
    sta size_x
    lda sizey_lookup, y
    sta size_y

    ; Compute wobble offset
    lda zp_angle
    clc
    adc zp_z, x          ; Per-depth phase shift
    and #$FF
    tax
    lda zp_sintab, x     ; Wobble X offset
    sta wobble_y         ; Temporarily store
    lsr
    lsr
    lsr
    sta wobble_x

    ; Compute Left X = CENTER_X - size + wobble_x
    lda #CENTER_X
    sec
    sbc size_x           ; CENTER_X - size
    clc
    adc wobble_x
    ldy #0
    sta (ul),y

    ; Compute Top Y = CENTER_Y - size + wobble_y
    lda #CENTER_Y
    sec
    sbc size_y           ; CENTER_Y - size
    clc
    adc wobble_y
    ldy #3
    sta (ul),y

    ; Compute Right X = CENTER_X + size + wobble_x
    lda #CENTER_X
    clc
    adc size_x           ; CENTER_X + size
    clc
    adc wobble_x         ; Apply same wobble X
    ldy #4
    sta (ul),y

    ; Compute Bottom Y = CENTER_Y + size + wobble_y
    lda #CENTER_Y
    clc
    adc size_y           ; CENTER_Y + size
    clc
    adc wobble_y         ; Apply same wobble Y
    ldy #7
    sta (ul),y

    ; Call rectangle drawing routine
    lda ul
    ldy ul+1
    sec
    jmp xRectangle

; --------------------------------------
; Erase previous rect, accounting for rollover
; Also update the ul pointer for next rect.
erase:
    lda zrect
    bne +
    lda #<Rects
    sta ul
    lda #>Rects
    sta ul+1
    lda #<(Rects+((NUM_RECT-1) * 8))
    sta pl
    lda #>(Rects+((NUM_RECT-1) * 8))
    sta pl+1
    jmp ++
+   asl
    asl
    asl
    clc
    adc #<Rects
    sta ul
    lda #>Rects
    adc #0
    sta ul+1
    lda ul
    sec
    sbc #8
    sta pl
    lda ul+1
    sbc #0
    sta pl+1
++  lda pl
    ldy pl+1
    clc
    jmp xRectangle

; --------------------------------------
; Size lookup table (approximate scale = 128/Z)
sizex_lookup:
!byte 16,14,12,11,9,8,7,6,6,5,5,4,4,3,3,3
!byte 2,2,2,2,2,1,1,1,1,1,1,1,1,1,1,1
sizey_lookup:
!byte 64,56,48,42,36,32,28,24,22,20,18,16,14,12,10,10
!byte 8,8,6,6,6,4,4,4,4,2,2,2,2,2,2,2

; --------------------------------------
; Sine lookup table for wobble (256 entries, range -16 to +16)
zp_sintab = *
!for i, 0, 255 {
  !byte int(16.0 * sin(i * PI / 128)) & $00FF
}

checkStop = *
   jsr aceConStopkey
   bcs ++
   jsr aceConKeyAvail
   bcc +
   rts
+  jsr aceConGetkey
   cmp #"Q"
   beq ++
   rts
++ jsr aceGrExit
   lda #TRUE
   jsr toolStatEnable
   lda #1
   ldx #0
   jmp aceProcExit

!eof
┌────────────────────────────────────────────────────────────────────────┐
│                        TERMS OF USE: MIT License                       │
├────────────────────────────────────────────────────────────────────────┤
│ Copyright (c) 2025 Brian Holdsworth                                    │
│                                                                        │
│ Permission is hereby granted, free of charge, to any person obtaining  │
│ a copy of this software and associated documentation files (the        │
│ "Software"), to deal in the Software without restriction, including    │
│ without limitation the rights to use, copy, modify, merge, publish,    │
│ distribute, sublicense, and/or sell copies of the Software, and to     │
│ permit persons to whom the Software is furnished to do so, subject to  │
│ the following conditions:                                              │
│                                                                        │
│ The above copyright notice and this permission notice shall be         │
│ included in all copies or substantial portions of the Software.        │
│                                                                        │
│ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND         │
│ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     │
│ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. │
│ IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   │
│ CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   │
│ TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      │
│ SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 │
└────────────────────────────────────────────────────────────────────────┘