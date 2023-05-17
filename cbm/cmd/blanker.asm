; Simple Screensaver, Copyright© 2020 Brian Holdsworth, MIT License.

; This application provides the simplest possible screensaver tool.
; It blanks the screen without modifying the displayed contents.
; Pressing any key will exit.

!source "sys/acehead.asm"
!source "sys/toolhead.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved


main = *
  jsr ScreenSave
  ; Disable toolbox IRQ
  lda #<doNothing
  ldy #>doNothing
  jsr aceIrqHook
  ; Wait on keypress
  jsr aceConGetkey
  jsr ScreenUnsave
  jsr toolWinRestore
doNothing = *
  rts

ScreenSave = *
   lda toolWinRegion+1
   cmp #40
   beq +
   jmp vdcScreenSave
+  jmp vicScreenSave

ScreenUnsave = *
   lda toolWinRegion+1
   cmp #40
   beq +
   jmp vdcScreenUnsave
+  jmp vicScreenUnsave

;vdc register addresses

vdcSelect = $d600
vdcStatus = $d600
vdcData = $d601

vdcRegNum    !byte 0
vdcSsColor  !byte 0
vdcSsMode   !byte 0
vdcSsActive !byte $00

vdcScreenSave = *
-  bit vdcStatus
   bpl -
   lda vdcRegNum
   pha
   ldx #$19
   jsr vdcRead
   sta vdcSsMode
   ldx #$1a
   jsr vdcRead
   sta vdcSsColor
   lda #$ff
   sta vdcSsActive
   ldx #$19
   lda vdcSsMode
   and #%10111111
   jsr vdcWrite
   ldx #$1a
   lda #$00
   jsr vdcWrite
   pla
   sta vdcRegNum
   sta vdcSelect
-  bit vdcStatus
   bpl -
   rts

vdcScreenUnsave = *
-  bit vdcStatus
   bpl -
   lda vdcRegNum
   pha
   ldx #$19
   lda vdcSsMode
   jsr vdcWrite
   ldx #$1a
   lda vdcSsColor
   jsr vdcWrite
   lda #$00
   sta vdcSsActive
   pla
   sta vdcRegNum
   sta vdcSelect
-  bit vdcStatus
   bpl -
   rts

vdcRead = *  ;( .X=register ) : .A=value
   stx vdcRegNum
   stx vdcSelect
-  bit vdcStatus
   bpl -
   lda vdcData
   rts

vdcWrite = *  ;( .X=register, .A=value )
   stx vdcRegNum
   stx vdcSelect
-  bit vdcStatus
   bpl -
   sta vdcData
   rts

;where's Vic?
vic   = $d000

vicSsColor  !byte 0
vicSsRows   !byte 0
vicSsActive !byte $00

vicScreenSave = *
   lda vic+$11
   sta vicSsRows
   lda vic+$20
   sta vicSsColor
   lda #$ff
   sta vicSsActive
   lda #$00
   sta vic+$11
   lda #$00
   sta vic+$20
   rts

vicScreenUnsave = *
   lda vicSsRows
   and #%01111111
   sta vic+$11
   lda vicSsColor
   sta vic+$20
   lda #$00
   sta vicSsActive
   rts

;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2020 Brian Holdsworth                                    │
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