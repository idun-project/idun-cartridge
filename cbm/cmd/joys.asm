!source "sys/acehead.asm"
!source "sys/acemacro.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

save = $02 ;(3)

main = *
  ; init zp
  lda #<joyMsg
  sta zp
  lda #>joyMsg
  sta zp+1
  jsr aceConStopkey
  bcc +
  jmp exit
+ jsr aceConJoystick
  cmp save+0  ; check JOY1 changed?
  bne joy1
  txa
  cmp save+1  ; check JOY2 changed?
  bne joy2
  jmp main

joy1:
  sta save+0
  +ldaSCII "1"
  sta joyMsg+1
  lda save+0
  jmp message
joy2:
  sta save+1
  +ldaSCII "2"
  sta joyMsg+1
  lda save+1
message:
  sta save+2
  ldx #6
  +ldaSCII "-"
- sta joyMsg,x
  inx
  cpx #10
  bne -
  clc
  ldx #6
- lsr save+2
  bcc +
  inx
  cpx #10
  bne -
  beq ++
+ +ldaSCII "*"
  sta joyMsg,x
  inx
  cpx #10
  bne -
++lsr save+2
  bcc +
  lda #11
  jmp ++
+ lda #16
++ldy #0
  ldx #0
  jsr aceConWrite
  ;jsr $5ac1
  jmp main
exit:
  rts

joyMsg = *
!pet chrCR
!pet "1:   "
!pet "---- "
!pet "FIRE!"
