; Graphical Screensaver, Copyright© 2020 Brian Holdsworth, MIT License.
;
; Draws animated lines display in varying colors. Most interestingly,
; the use of toolx/gfx allows the code to work not just on C64 and on
; C128, but also for either VIC-II or VDC display.
;
!source "sys/acehead.asm"
!source "sys/toolhead.asm"
!source "toolx/gfx.asm"

jmp main

;zp vars
stepX   = $02 ;(2)
stepY   = $04 ;(2)
current = $06 ;(2)
last    = $08 ;(2)
next    = $0a ;(2)
color   = $0c ;(1)
limX    = $0d ;(1)
limY    = $0e ;(1)

Pts !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
    !byte 0,0,0,0
Ori !byte 0,0,0,20
    !byte 10,0,0,0
Endpts = *

main = *
    lda #FALSE
    jsr toolStatEnable
    lda #$10
    sta color
    ;** step num pixels
    lda #4
    sta stepX
    sta stepX+1
    sta stepY
    sta stepY+1
    lda #<Ori
    ldy #>Ori
    sta current+0
    sty current+1
    lda #<Pts
    ldy #>Pts
    sta last+0
    sty last+1
    ;** mode 1 - monochrome bitmaps
    lda #$01
    ldx #$00
    ldy #$00
    jsr xGrMode
    bcs ++
    stx limX    ;X cols
    tya
    asl
    asl
    asl
    sta limY    ;Y lines
    ;** adjust starting line length
    lda #40
    cmp limX
    beq +
    ldx #3
    lda Ori,x
    asl
    sta Ori,x
    inx
    lda Ori,x
    asl
    sta Ori,x    
    ;** clear bitmap screen
+   lda #$00
    ldy #$00
    jsr xGrClear
    ;** set fg/bg colors
    lda color
    jsr xGrSetColor
    jmp mainloop
++  rts

mainloop = *
    ;erase last
    lda last+0
    ldy last+1
    ldx #2
    clc
    jsr xPlot
    ;draw current
    lda current+0
    ldy current+1
    ldx #2
    sec
    jsr xPlot

    jsr step1
    ldx #stepX
    jsr moveX
    ldx #stepY
    jsr moveY

    jsr step2
    ldx #stepX+1
    jsr moveX
    ldx #stepY+1
    jsr moveY

    jsr advance
    jsr checkStop
    jmp mainloop

step1 = *
    lda current+0
    ldy current+1
    clc
    adc #8
    sta next+0
    tya
    adc #0
    sta next+1
    cmp #>Endpts
    bne +
    lda next+0
    cmp #<Endpts
    bne +
    lda #<Pts
    ldy #>Pts
    sta next+0
    sty next+1
+   rts

step2 = *
    lda current+0
    clc
    adc #4
    sta current+0
    lda current+1
    adc #0
    sta current+1
    lda next+0
    clc
    adc #4
    sta next+0
    lda next+1
    adc #0
    sta next+1
    rts

advance = *
    ;current = next-4
    lda next+0
    sec
    sbc #4
    sta next+0
    lda next+1
    sbc #0
    sta next+1
    tay
    lda next+0
    sta current+0
    sty current+1
    ;last = last+8
    lda last+0
    clc
    adc #8
    sta last+0
    lda last+1
    adc #0
    sta last+1
    cmp #>Endpts
    bne +
    lda last+0
    cmp #<Endpts
    bne +
    lda #<Pts
    ldy #>Pts
    sta last+0
    sty last+1
+   rts

moveX = *
    ldy #1
    lda (current),y   ;Xlo
    clc
    adc $0,x
    cmp #7
    bmi +
    bcc ++
+   and #7
    sta (next),y
    dey
    lda $0,x
    php
    lda (current),y
    plp
    bmi +
    adc #0
    jmp ++
+   adc #-1
++  sta (next),y
    jmp checkX

moveY = *
    ldy #3
    lda (current),y   ;Ylo
    clc
    adc $0,x
    sta (next),y
    jmp checkY

checkX = *
    ldy #0
    lda (next),y
    cmp limX
    bcs ++
    cmp #0
    beq +
    rts
+   lda #4
    sta $0,x
    rts
++  dec limX
    lda limX
    sta (next),y
    lda #-4
    sta $0,x
    inc limX
    rts

checkY = *
    beq +
    cmp limY
    bcs ++
    rts
+   lda #4
    sta $0,x
    jmp changeColor
++  lda limY
    sta (next),y
    lda #-4
    sta $0,x
changeColor = *
    cpx #stepY+1
    beq +
    rts
+   lda color
    clc
    adc #16
    sta color
    and #$f0
    bne +
    lda #$10
+   jmp xGrSetColor

checkStop = *
    jsr aceConKeyAvail
    bcc +
    rts
+   jsr aceConGetkey
exit = *
    jsr aceGrExit
    lda #TRUE
    jsr toolStatEnable
    lda #1
    ldx #0
    jmp aceProcExit

!eof
┌────────────────────────────────────────────────────────────────────────┐
│                        TERMS OF USE: MIT License                       │
├────────────────────────────────────────────────────────────────────────┤
│ Copyright (c) 2020 Brian Holdsworth                                    │
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