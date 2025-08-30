; Graphical Screensaver, Copyright© 2023 Brian Holdsworth, MIT License.
;
; Draws animated boxes in varying colors. Most interestingly,
; the use of toolx/gfx allows the code to work not just on C64
; and on C128, but also for either VIC-II or VDC display.
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
limX    = $0d ;(2)
limY    = $0f ;(1)
zptmp   = $10 ;(2)

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
Ori !byte 0,0,0,0
    !byte 80,0,40,0
Endpts = *

doNothing = *
    rts
    
main = *
    ; Disable toolbox IRQ
    lda #<doNothing
    ldy #>doNothing
    jsr aceIrqHook
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
    sty limX+1
    jsr xGrMode
    bcs ++
    txa
    sta limX+0
    asl
    rol limX+1
    asl
    rol limX+1
    asl
    rol limX+1
    sta limX+0
    tya
    asl
    asl
    asl
    sta limY    ;Y lines
    ;** adjust starting rect diagonal
    lda #$40
    cmp limX
    beq +
    ldx #4
    lda Ori,x
    asl
    sta Ori,x
    ldx #6
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
    ;TESTING
;     lda #<300
;     ldy #>300
;     sta X1
;     sty X1+1
;     lda #<50
;     ldy #>50
;     sta Y1
;     sty Y1+1
;     lda #<50
;     ldy #>50
;     sta X2
;     sty X2+1
;     lda #<150
;     ldy #>150
;     sta Y2
;     sty Y2+1
;     sec
;     jsr xRectangle
; -   jsr aceConStopkey
;     bcc -
;     jmp exit

    ;erase last
    lda last+0
    ldy last+1
    jsr box
    clc
    jsr xRectangle
    
    ;draw current
    lda current+0
    ldy current+1
    jsr box
    sec
    jsr xRectangle

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

box = *
    sta zptmp
    sty zptmp+1
    ldy #7
-   lda (zptmp),y
    sta X1,y
    dey
    bpl -
    rts

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
    lda $0,x
    sta soffset
    bmi +
    lda #$00
    sta soffset+1
    beq ++
+   lda #$ff
    sta soffset+1
++  ldy #0
    lda (current),y  ;Xlo
    clc
    adc soffset
    sta (next),y
    iny
    lda (current),y  ;Xhi
    adc soffset+1
    sta (next),y
    jmp checkX
soffset !word 0

moveY = *
    ldy #2
    lda (current),y   ;Ylo
    clc
    adc $0,x
    sta (next),y
    jmp checkY

checkX = *
    ldy #0
    lda (next),y
    sta chkval
    iny
    lda (next),y
    sta chkval+1
    +CMP16 chkval,limX
    bcs ++
    +CMP16 chkval, zero
    beq +
    rts
+   lda #4
    sta $0,x
    rts
++  dec limX
    lda limX
    ldy #0
    sta (next),y
    lda limX+1
    iny
    sta (next),y
    lda #-4
    sta $0,x
    inc limX
    rts
chkval !byte 0,0
zero !word 0

checkY = *
    beq +
    cmp limY
    bcs ++
    rts
+   lda #4
    sta $0,x
    jmp changeColor
++  dec limY
    lda limY
    sta (next),y
    lda #-4
    sta $0,x
    inc limY
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
    jsr toolWinRestore
    lda #1
    ldx #0
    jmp aceProcExit

!eof
┌────────────────────────────────────────────────────────────────────────┐
│                        TERMS OF USE: MIT License                       │
├────────────────────────────────────────────────────────────────────────┤
│ Copyright (c) 2023 Brian Holdsworth                                    │
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