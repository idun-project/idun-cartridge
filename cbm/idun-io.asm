; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Idun I/O Driver
; NOTE: This driver code *must* be ROM-able.
; It is used by both idunk and ROM bootstrap.

; Some parameters and addresses for Idun I/O interface.
!addr idDataport = $de00
!addr idRxBufLen = $de01
!addr STASH      = $02af

!if useC128 {
  recvByte = $c8
  lengthBuf= $c9
  recvAvail= $ca
  bkExtrom = %00001010
  bkSelect = $ff00
  kernelNmiHandler = $fa40
} else {
  recvByte = $a8
  lengthBuf= $a9
  recvAvail= $aa
  bkExtrom = $37
  bkSelect = $01
  kernelNmiHandler = $fe47
}

; Initialization
pidInit = *
  ; init fileinfoTable
  ldx #0
  lda #0
- sta fileinfoTable,x
  inx
  bne -
!if romsize=0 {
pidInitNmi = *
  sei
  lda #<nmiMmap
  sta nmiRedirect+0
  lda #>nmiMmap
  sta nmiRedirect+1
  cli
} else {
  pidInitNmi = *
}
  jmp pidFlushbuf

!if romsize=0 {
rom_sig !pet "CBM"
nmiMmap = *             ;33 cycles (in kernal)
  ; Exrom access needs 1MHz
  bit winDriver         ;4
  bpl +                 ;2
  lda #$00              ;2
  sta $d030             ;4
+ lda #bkExtrom         ;2
  sta bkSelect          ;4
  ;Check for ROM preamble
  ldx #2                ;2
- lda rom_sig,x         ;4
  cmp $8004,x           ;4
  bne +                 ;2
  dex                   ;2
  bpl -                 ;24
+ cpx #255              ;2
  bne nmiOther          ;2
  ;If preamble, check next character for "8" or "1",
  ;and then make appropriate JMP or JSR.
  lda #"8"              ;2
  cmp $8007             ;4
  bne +                 ;3
  jmp ($8002)
+ jsr $8009             ;6+
  ;FIXME return value in .A to MemMapper process
  ;
  ;soft-switch disable ROM
  lda #0                ;2
  sta $de7e             ;4
  lda $81ff             ;4
  lda $8000             ;4
  ; Restore 2MHz
  bit winDriver         ;4
  bpl +                 ;2
  lda #$01              ;2
  sta $d030             ;4
+ jmp nmiExit
  nmiOther = *
  ; Restore 2MHz
  bit winDriver         ;4
  bpl +                 ;2
  jsr winClockFast      ;28
+ jmp nmiContinue       ;48
}

; .A=char
; return .CS=error
pidChOut = *
  sta idDataport
  clc
  rts

; (writePtr[.X]), .X=length, max. of 0/256
; return .CS=error
kernModemPut = *
  sta writePtr+0
  sty writePtr+1
pidPutbuf = *
  stx lengthBuf
  ldy #0
- lda (writePtr),y
  sta idDataport
  iny
  cpy lengthBuf
  bne -
  clc
  rts

pidChIn = *
  ; preserve X, Y
  lda idRxBufLen
  bne +
  sec
  rts
  ; Add 2 cycle delay before accessing IO1 again.
+ nop
  lda idDataport
  sta recvByte
  clc
  rts

;*** pidCharAvail : .A=avail
kernModemAvail = *
  lda idRxBufLen
  rts

;*** (.AY=buffer, .X=length, where 0=256
;                 : .CS=error
kernModemGet = *
  sta readPtr+0
  sty readPtr+1
pidGetbuf = *
  stx lengthBuf
  ldy #0
  ; wait for data available
--lda idRxBufLen
  sta recvAvail
  beq --
  ; copy all available, up to lengthBuf
- lda idDataport
  sta (readPtr),y
  iny
  cpy lengthBuf
  beq +
  dec recvAvail
  beq --
  jmp -
+ clc
  rts
pidReadseq = *
  stx lengthBuf
  ldy #0
  ; wait for data available
--lda idRxBufLen
  sta recvAvail
  beq --
  ; copy all available, up to lengthBuf
- lda idDataport
  cmp #$fa    ;EOF?
  bne +
  sec
  rts
+ sta (readPtr),y
  iny
  cpy lengthBuf
  beq +
  dec recvAvail
  beq --
  jmp -
+ clc
  rts
pidBankload = *
  stx lengthBuf
  ldx #readPtr
  stx $2b9
  ldy #0
  ; wait for data available
--lda idRxBufLen
  sta recvAvail
  beq --
  ; copy all available, up to lengthBuf
- lda idDataport
  ldx bloadBank
  jsr STASH
  iny
  cpy lengthBuf
  beq +
  dec recvAvail
  beq --
  jmp -
+ clc
  rts

pidFlushbuf = *
- lda idRxBufLen
  nop
  beq +
  lda idDataport
  jmp -
+ rts


;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2023 Brian Holdsworth                                    │
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