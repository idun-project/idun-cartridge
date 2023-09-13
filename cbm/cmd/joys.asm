!source "sys/acehead.asm"
!source "sys/acemacro.asm"
!source "sys/toolhead.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

joys        = $02  ;4
last        = $06  ;4
cctr        = $0a  ;1
cptr        = $0b  ;1
cdata_ptr   = $0c  ;2
hptr        = $0e  ;1

main = *
    ; zp init
    lda #$ff
    sta last+0
    sta last+1
    sta last+2
    sta last+3
    ; screen setup
    jsr clearScr
    jsr draw
    ; read gamepads
    lda #0
    sta cctr
    sta cptr
    lda #<highlight
    ldy #>highlight
    sta hptr+0
    sty hptr+1
    lda #<joys
    ldy #>joys
    clc
    jsr aceConGamepad
    ; check only 1 gamepad is connected
    lda joys+0
    bne error
    lda joys+1
    bne error
    lda #$ff
    cmp joys+2
    bne error
    cmp joys+3
    beq continue
error:
    lda #<errorMsg
    ldy #>errorMsg
    jsr eputs
    jmp exit
continue:
    ; put J: into configuration mode
    lda #<config
    ldy #>config
    sta cdata_ptr
    sty cdata_ptr+1
    sec
    jsr aceConGamepad
    ; start config process
    lda #14
    ldx #6
    jsr aceConPos
    lda #<press
    ldy #>press
    sta zp
    sty zp+1
    ldx #stdout
    lda #5
    ldy #0
    jsr write
getbtns:
    lda cctr
    cmp #8
    beq getdirs
    jsr nextbtn
    jmp getbtns
getdirs:
    jsr nextbtn
    jsr nextbtn
    ; update the new configuration
    lda #<config
    ldy #>config
    sec
    jsr aceConGamepad
    jmp exit
exit:
    rts
errorMsg:
!pet "Error: Check you have only one gamepad connected to USB, then press RESET.",13,0
config:
!text "configmode"
press:
!pet "Press"
labels:
!pet "Btn A Btn B Btn X Btn Y L TrigR TrigSelectStart "
!pet "Right Down  "
highlight:
!byte 6,21,8,19,4,19,6,17,1,4,1,19,7,10,7,14,6,6,8,4
nextbtn = *
    ; instructions
    lda #14
    ldx #12
    jsr aceConPos
    lda #<labels
    ldy #>labels
    sta zp
    sty zp+1
    clc
    adc cptr
    sta zp
    lda zp+1
    adc #0
    sta zp+1
    ldx #stdout
    lda #6
    ldy #0
    jsr write
    ; button highlight
    ldy #1
    lda (hptr),y
    tax
    dey
    lda (hptr),y
    jsr aceWinPos
    lda #1
    sta syswork+5
    lda #$40
    ldx #0
    ldy toolWinPalette+4
    jsr aceWinPut
    ; get button id
    lda cctr
    cmp #8
    bcc waitbtn
-   lda #<joys
    ldy #>joys
    clc
    jsr aceConGamepad
    dec joys+0
    lda joys+0
    cmp last+0
    beq -
    ; store into config
    ldy cctr
    sta (cdata_ptr),y
    sta last+0
    jmp setnext
waitbtn:
    lda #<joys
    ldy #>joys
    clc
    jsr aceConGamepad
    dec joys+1
    lda joys+1
    cmp last+1
    beq waitbtn
    ; store into config
    ldy cctr
    sta (cdata_ptr),y
    sta last+1
setnext:
    ; button un-highlight
    lda #$40
    ldx #0
    ldy toolWinPalette+0
    jsr aceWinPut
    ; set to next
    inc cctr
    lda hptr
    clc
    adc #2
    sta hptr
    lda hptr+1
    adc #0
    sta hptr+1
    lda cptr
    clc
    adc #6
    sta cptr
    lda cptr+1
    adc #0
    sta cptr+1
    rts

; reset the screen
clearScr = *
    lda #$c0
    ldx #$20
    jsr aceWinCls
    lda #0
    ldx #0
    jmp aceConPos

draw = *
    lda #<icon
    ldy #>icon
    sta cdata_ptr+0
    sty cdata_ptr+1
--  ldy #0
    sty cctr
-   ldy cctr
    cpy #24
    beq +
    lda (cdata_ptr),y
    beq ++
    jsr aceConPutlit
    inc cctr
    jmp -
+   lda #$0d    ;CR
    jsr aceConPutchar
    lda cdata_ptr+0
    clc
    adc #24
    sta cdata_ptr+0
    lda cdata_ptr+1
    adc #0
    sta cdata_ptr+1
    jmp --
++  rts

;******** gamepad icon chars ********
icon = *
; character codes (24x13 bytes)
!byte  32, 32, 32,132,129,133, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,132,129,133, 32, 32, 32
!byte  32, 32, 32,130,204,130, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,130,210,130, 32, 32, 32
!byte 132,129,129,139,129,139,129,129,129,129,129,129,129,129,129,129,129,129,139,129,139,129,129,133
!byte 130, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,130
!byte 130, 32, 32, 32,156, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,216, 32, 32, 32,130
!byte 130, 32, 32, 32,130, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,130
!byte 130, 32,158,129,131,129,159, 32, 32, 83, 69, 76, 32, 83, 84, 65, 32,217, 32, 32, 32,193, 32,130
!byte 130, 32, 32, 32,130, 32, 32, 32, 32,144,144,144, 32,144,144,144, 32, 32, 32, 32, 32, 32, 32,130
!byte 130, 32, 32, 32,157, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,194, 32, 32, 32,130
!byte 130, 32, 32, 32, 32, 32, 32,132,129,129,129,129,129,129,129,129,133, 32, 32, 32, 32, 32, 32,130
!byte 130, 32, 32, 32, 32, 32, 32,130, 32, 32, 32, 32, 32, 32, 32, 32,130, 32, 32, 32, 32, 32, 32,130
!byte 130, 32, 32, 32, 32, 32, 32,130, 32, 32, 32, 32, 32, 32, 32, 32,130, 32, 32, 32, 32, 32, 32,130
!byte 134,129,129,129,129,129,129,135, 32, 32, 32, 32, 32, 32, 32, 32,134,129,129,129,129,129,129,135
!byte $00   ;termination

;******** standard library ********
eputs = *
   ldx #stderr
   jmp fputs
puts = *
   ldx #stdout
fputs = *
   sta zp
   sty zp+1
   ldy #$ff
-  iny
   lda (zp),y
   bne -
   tya
   ldy #0
   jmp write
