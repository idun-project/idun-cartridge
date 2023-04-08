!source "sys/acehead.asm"
!source "sys/toolhead.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

!source "toolx/vdc/core.asm"
!source "toolx/vdc/draw.asm"

;zp vars
stepX   = $02 ;(2)
stepY   = $04 ;(2)
current = $06 ;(2)
last    = $08 ;(2)
next    = $0a ;(2)

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
Ori !byte 0,0,0,50
    !byte 20,0,0,0
Endpts = *

main = *
    lda #FALSE
    jsr toolStatEnable
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
    ;** vdc mode 1
    lda #$01
    ldx #$00
    ldy #$00
    jsr xGrMode
    bcs +
    ;** clear bitmap screen
    lda #$00
    ldy #$00
    jsr xGrClear
    jmp mainloop
+   rts

mainloop = *
    ;erase last
    lda last+0
    ldy last+1
    ldx #2
    clc
    jsr xVdcPlot
    ;draw current
    lda current+0
    ldy current+1
    ldx #2
    sec
    jsr xVdcPlot

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
    cmp #80
    bcs ++
    cmp #0
    beq +
    rts
+   lda #4
    sta $0,x
    rts
++  lda #79
    sta (next),y
    lda #-4
    sta $0,x
    rts

checkY = *
    beq +
    cmp #200
    bcs ++
    rts
+   lda #4
    sta $0,x
    jmp changeColor
++  lda #200
    sta (next),y
    lda #-4
    sta $0,x
changeColor = *
    cpx #stepY+1
    beq +
    rts
+   ldx #26
    jsr vdcRead
    adc #16
    and #$f0
    bne +
    lda #$10
+   jmp vdcWrite

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
