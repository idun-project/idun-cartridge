; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)
;
; Configuration overlay, used during kernel startup

* = aceAppAddress

totalBanks !byte 0,0

.configBuf   = 2   ;(2)
.ram0FreeMap = 6   ;(2)
aceEndPage   = 8   ;(1)
sysType      = 9   ;(1)
charset4bitP = 10  ;(2)
keymapAddr   = 12  ;(2)
scrDrivers   = 14  ;(1)
memRead      = 16  ;(2)
memWrite     = 18  ;(2)
banks        = 20  ;(1)
bankLimit    = 21  ;(1)
save0        = 22  ;(2)
save2        = 24  ;(2)
saveN        = 26  ;(2)

configMain = *
   lda sysType
   sta aceSystemType
   lda #0
   sta aceTotalMemory+0
   sta aceTotalMemory+1
   sta totalBanks+0
   sta totalBanks+1
   jsr pidInit          ;Before accessing cart devices!
   jsr loadConfig
   bcs +
   jsr screenInit
   jsr setDate
   jsr internalMemory
   lda aceInternalBanks
   sta totalBanks+0
   jsr reserveRam0HiMem
!if useC64 {
   ;** reduce TPA if no ERAM on C64
   jsr eramDetect
   bcc +
   lda #$b0
   ldy #$c6
   sta (.configBuf),y
}
+  jsr reserveTPA
   jsr eramMemory
   lda totalBanks+0
   ldy totalBanks+1
   sta aceTotalMemory+2
   sty aceTotalMemory+3
   jsr loadCharset
   bcs +
   jmp Inits
+  rts

Inits = *
   jsr pidInit
   jsr aceIrqInit
   jsr initMemoryAlloc
   clc
   rts

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
aceIrqInit = *
   php
   sei
!if useC64 {
   ldx #5
-  lda c64IntVecs,x
   sta $fffa,x
   dex
   bpl -
}
   lda #<irqHandler
   ldy #>irqHandler
   sta $314
   sty $315
   ;use the VIC raster interrupt as the timer
   lda vic+$11
   and #$7f
   sta vic+$11
   lda #252
   sta vic+$12
   plp
   rts
c64IntVecs = *
   !word nmiIntDispatch,resetIntDispatch,irqIntDispatch
initMemoryAlloc = *
   ldx #0
   ldy #0
   stx freemapPage
   stx freemapDirty
-  lda ram0FreeMap,x
   sta freemap,x
   bne +
   iny
+  inx
   bne -
   lda #0
   ldy #aceMemInternal
   sta freemapBank+0
   sty freemapBank+1
   clc
   rts

testMemoryType = *  ;( .A=type, .X=bankLimit ) : .A=bankCount
   sta mp+3
   stx bankLimit
   lda #$00
   ldy #$80  ;** page to use for testing ram
   ldx #$00
   sta mp+0
   sty mp+1
   stx mp+2
   lda #0
   sta banks

   nextBank = *
   lda banks
   sta mp+2
   jsr saveBank
   lda #$ff-$cb
   sta memWrite
   lda mp+2
   sta memWrite+1
   ldx #memWrite
   ldy #2
   jsr aceMemZpstore
   lda #$ff-$cb
   ldx mp+2
   jsr testBank
   bcs bankFail
   lda #$cb
   sta memWrite
   ldx #memWrite
   ldy #2
   jsr aceMemZpstore
   lda #$cb
   ldx mp+2
   jsr testBank
   bcs bankFail
   lda #$cb
   ldx #0
   jsr testBank
   bcs bankFail
   lda mp+2
   cmp #2
   bcc +
   lda #$cb
   ldx #2
   jsr testBank
   bcs bankFail
+  jsr restoreBank
   inc banks
   lda banks
   cmp bankLimit
   bcc nextBank

   bankFail = *
   jsr restoreWrapBanks
   lda banks
   rts

saveBank = *  ;()
   ldx #saveN
   ldy #2
   lda mp+2
   cmp #0
   bne +
   ldx #save0
+  cmp #2
   bne +
   ldx #save2
+  jsr aceMemZpload
   rts

restoreBank = *  ;()
   lda mp+2
   cmp #0
   beq +
   cmp #2
   beq +
   ldx #saveN
   ldy #2
   jsr aceMemZpstore
+  rts

restoreWrapBanks = *  ;()
   lda banks
   cmp #3
   bcc +
+  lda #2
   sta mp+2
   ldx #save2
   ldy #2
   jsr aceMemZpstore
   lda banks
   cmp #1
   bcc +
   lda #0
   sta mp+2
   ldx #save0
   ldy #2
   jsr aceMemZpstore
+  rts

rdVal  = 10  ;(1)
rdBank = 11  ;(1)

testBank = *  ;( .A=data, .X=bank ) : .CS=err
   sta rdVal
   lda mp+2
   sta rdBank
   stx mp+2
   lda #$ff
   sta memRead
   sta memRead+1
   ldx #memRead
   ldy #2
   jsr aceMemZpload
   lda memRead
   cmp rdVal
   bne +
   lda memRead+1
   cmp mp+2
   bne +
   lda rdBank
   sta mp+2
   clc 
   rts
+  lda rdBank
   sta mp+2
   sec
   rts


loadConfig = *
   ; IDUN: use service on I: device to fetch configuration data.
   lda .configBuf+0
   ldy .configBuf+1
   jmp pisvcGetConfig

loadCharset = *
   ; IDUN: Bload the configured character set data
   lda #26     ; Z:
   asl
   asl
   sta bloadDevice
   lda #$87
   ldy .configBuf+1
   sta bloadFilename+0
   sty bloadFilename+1
   lda #<charsetBuf
   ldy #>charsetBuf
   sta bloadAddress+0
   sty bloadAddress+1
   lda #<(4144+256)
   clc
   adc bloadAddress+0
   sta zw+0
   lda #>(4144+256)
   adc bloadAddress+1
   sta zw+1
   jmp pidBload

screenInit = *
   lda #147
   jsr $ffd2
   lda #<640
   ldy #>640
   sta aceMouseLimitX
   sty aceMouseLimitX+1
   lda #<491
   ldy #>491
   sta aceMouseLimitY
   sty aceMouseLimitY+1
   lda #8
   sta aceMouseScaleX
   sta aceMouseScaleY
   rts

setDate = *
   lda #<configDate
   ldy #>configDate
   jsr pisvcTimeGetDate
   lda #<configDate
   ldy #>configDate
   jmp aceTimeSetDate

configDate = *
   !fill 8,0

addToFree = *  ;( [$44]=bytes )
   clc
   lda $44
   adc aceFreeMemory+0
   sta aceFreeMemory+0
   lda $45
   adc aceFreeMemory+1
   sta aceFreeMemory+1
   lda $46
   adc aceFreeMemory+2
   sta aceFreeMemory+2
   bcc +
   inc aceFreeMemory+3
+  rts

resetFree = *
   lda #0
   ldx #3
-  sta $44,x
   dex
   bpl -
   rts

internalMemory = *
   lda #aceMemInternal
   ldx #255
   sei
   jsr testMemoryType
   cli
   sta aceInternalBanks
   pha
   jsr installInternVectors
   pla
   tax
   lda #0
   sta $45
   jsr resetFree

   ;** ram0
   lda #aceMemInternal
   sta mp+3
   lda #0
   sta aceInternalCur
   lda .ram0FreeMap+0
   ldy .ram0FreeMap+1
   sta aceRam0Freemap+0
   sty aceRam0Freemap+1
   ldx #0
   sta mp+0
   sty mp+1
   stx mp+2
   ldy #$a3
   bit sysType
   bmi +
   ldy #$c1
+  lda (.configBuf),y
   tay
   lda #1
   ldx #>aceAppAddress
   jsr initBanks
   jsr freeRam0AfterKernel

   ;** ram1
   bit sysType
   bpl expInternal64
   lda #$00
   sta mp+0
   ldy #$a0
   lda (.configBuf),y
   sta mp+1
   sta aceRam1Freemap
   lda #1
   sta mp+2
   ldy #$a1
   lda (.configBuf),y
   tay
   lda #2
   ldx mp+1
   inx
   jsr initBanks

   ;** ram2-7 c128
   expInternal128 = *
   lda #2
   sta mp+2
   lda #$00
   ldy #$04
   sta mp+0
   sty mp+1
   ldy #$a5
   lda (.configBuf),y
   ldx aceInternalBanks
   jsr min
   sta aceInternalBanks
   ldx #$05
   ldy #$ff
   jsr initBanks
   jsr addToFree
   rts

   ;** ram1-3 c64
   expInternal64 = *
   lda #1
   sta aceInternalBanks
   jsr addToFree
   rts

freeRam0AfterKernel = *
   ;** free end.kernel->st.app
   ldy aceEndPage
   cpy #>aceAppAddress
   bcs +
   lda #$00
-  sta (.ram0FreeMap),y
   iny
   cpy #>aceAppAddress
   bcc -
+  sec
   lda #>aceAppAddress
   sbc aceEndPage
   sta $40
   bit sysType
   bvc +
   clc
   adc #3
   sta $40
   lda #$00
   ldy #$11
   sta (.ram0FreeMap),y
   ldy #$12
   sta (.ram0FreeMap),y
+  clc
   lda $45
   adc $40
   sta $45
   bcc +
   inc $46
   bne +
   inc $47
+  rts

installInternVectors = *
   bit sysType
   bpl installVectors64
   lda aceInternalBanks
   cmp #2
   bcs +
   rts
+  sei
   lda #2
   ldy #aceMemInternal
   sta mp+2
   sty mp+3
-  lda #$05
   ldy #$ff
   sta mp+0
   sty mp+1
   sta zp+0
   sty zp+1
   lda #<251
   ldy #>251
   jsr aceMemStash
   inc mp+2
   lda mp+2
   cmp aceInternalBanks
   bcc -
   cli
   rts

installVectors64 = *
   ;xx copy to exp banks
   rts

ram0HiMemPtr !byte 0

reserveRam0HiMem = *
   lda #$ff
   sta ram0HiMemPtr
   jsr reserveVic80
   lda ram0HiMemPtr
   cmp #$ff
   beq +
   jsr reserveCharSet
   jsr reserveVic40
   jsr reserveBack80
   jmp ++
+  jsr reserveDymem
   jsr reserveVic40
   jsr reserveCharSet
++ nop
   rts

reserveVic80 = *
   lda #$00
   sta aceSoft80Allocated
   bit sysType
   bvs +
-  rts
+  ldy #$c0
   lda (.configBuf),y
   bpl -
   lda scrDrivers
   and #$20
   beq -
   lda #$fc
   ldy #$d8
-  sta (.ram0FreeMap),y
   iny
   cpy #$ff
   bcc -
   sec
   lda aceFreeMemory+1
   sbc #$ff-$d8
   sta aceFreeMemory+1
   lda aceFreeMemory+2
   sbc #0
   sta aceFreeMemory+2
   lda aceFreeMemory+3
   sbc #0
   sta aceFreeMemory+3
   lda #$d8
   sta ram0HiMemPtr
   lda #$ff
   sta aceSoft80Allocated
   rts

reserveCharSet = *
   sec
   lda ram0HiMemPtr
   sbc #>2048
   tax
   tay
   sta aceCharSetPage
   lda #$fc
-  sta (.ram0FreeMap),y
   iny
   cpy ram0HiMemPtr
   bcc -
   stx ram0HiMemPtr
   sec
   lda aceFreeMemory+1
   sbc #>2048
   sta aceFreeMemory+1
   lda aceFreeMemory+2
   sbc #0
   sta aceFreeMemory+2
   lda aceFreeMemory+3
   sbc #0
   sta aceFreeMemory+3
   rts

reserveVic40 = *
   sec
   lda ram0HiMemPtr
   sbc #>1024
   tax
   tay
   sta aceVic40Page
   lda #$fc
-  sta (.ram0FreeMap),y
   iny
   cpy ram0HiMemPtr
   bcc -
   stx ram0HiMemPtr
   sec
   lda aceFreeMemory+1
   sbc #>1024
   sta aceFreeMemory+1
   lda aceFreeMemory+2
   sbc #0
   sta aceFreeMemory+2
   lda aceFreeMemory+3
   sbc #0
   sta aceFreeMemory+3
   rts

reserveBack80 = *
   bit aceSoft80Allocated
   bmi +
   rts
+  sec
   lda ram0HiMemPtr
   sbc #>2048
   tax
   tay
   lda #$fc
-  sta (.ram0FreeMap),y
   iny
   cpy ram0HiMemPtr
   bcc -
   stx ram0HiMemPtr
   sec
   lda aceFreeMemory+1
   sbc #>2048
   sta aceFreeMemory+1
   lda aceFreeMemory+2
   sbc #0
   sta aceFreeMemory+2
   lda aceFreeMemory+3
   sbc #0
   sta aceFreeMemory+3
   rts

reserveDymem = *
   sec
   lda ram0HiMemPtr
   sbc #>768
   sta ram0HiMemPtr
   rts

reserveTPA = *
   ldy #$a8
   ldx #$c0
   bit sysType
   bmi +
   ldy #$c6
   ldx #$d0
+  lda (.configBuf),y
   cmp ram0HiMemPtr
   bcc +
   lda ram0HiMemPtr
+  stx $40
   cmp $40
   bcc +
   lda $40
+  sta $40
   sta aceTpaLimit
   ldy #>aceAppAddress
   lda #$fe
   cpy $40
   bcs +
-  sta (.ram0FreeMap),y
   iny
   cpy $40
   bcc -
+  sec
   lda $40
   sbc #>aceAppAddress
   sta $40
   sec
   lda aceFreeMemory+1
   sbc $40
   sta aceFreeMemory+1
   lda aceFreeMemory+2
   sbc #0
   sta aceFreeMemory+2
   lda aceFreeMemory+3
   sbc #0
   sta aceFreeMemory+3
   rts

eramDetect = *
   ;detect ERAM presence
!if useFastClock {
   ldy $d030
   sty $44
   ldy #0
   sty $d030
}
   ldy #1
   sty $defe
-  iny
   beq eramDetectFail
   bit $defe
   bvc -
!if useFastClock {
   ldy $44
   sty $d030
}
   lda $defe
   cmp #65
   bne eramDetectFail
   lda $df00
   bmi eramDetectFail
   lda $dfff
   cmp #255
   bne eramDetectFail
   clc
   rts
eramDetectFail:
!if useFastClock {
   ldy $44
   sty $d030
}
   sec
   rts
availEram = *
   jsr resetFree
   lda aceEramBanks
   bne +
   rts
+  ldx aceEramStart
-  lda $df00,x
   clc
   adc $45
   sta $45
   bcc +
   inc $46
+  inx
   bne -
   rts
eramMemory = *
   lda #0
   sta aceEramBanks
!if useC128 {
   ldy #$a6
} else {
   ldy #$c2
}
   lda (.configBuf),y
   sta aceEramCur
   sta aceEramStart
   ;** detect ERAM accessible ("Bertha" 2024+)
   jsr eramDetect
   bcc +
   rts            ;ERAM not present
+  lda #255
   jsr seBank   ;select the freemap
   lda #255
   sec
   sbc aceEramStart
   sta aceEramBanks
   lda #$40       ;256 16k blocks = 64 banks = 4,096K
   clc
   adc totalBanks+0
   sta totalBanks+0
   bcc +
   inc totalBanks+1
+  jsr availEram
   jsr addToFree
   rts

endBank   = 10  ;(1)
startFree = 11  ;(1)
endFree   = 12  ;(1)

initBanks = *  ;( [mp]=firstFreemap, .A=endBank+1, .X=startFree, .Y=endFree+1 )
   sta endBank
   stx startFree
   sty endFree
   lda #<freemap
   ldy #>freemap
   sta zp+0
   sty zp+1
   ldx #0
   lda #$ff
-  sta freemap,x
   inx
   bne -
   ldx startFree
   cpx endFree
   bcs freeNextBank
   lda #$00
-  sta freemap,x
   inx
   cpx endFree
   bcc -

   freeNextBank = *
   lda mp+2
   cmp endBank
   bcs +
   lda #<256
   ldy #>256
   jsr aceMemStash
   inc mp+2
   sec
   lda endFree
   sbc startFree
   clc
   adc $45
   sta $45
   bcc freeNextBank
   inc $46
   bne freeNextBank
   inc $47
   jmp freeNextBank
+  rts

min = *  ;( .A=num1, .X=num2 ) : .A=min
   stx $40
   cmp $40
   bcc +
   lda $40
+  rts

;=== bss ===
.freemap = *
.charsetBegin = .freemap+256
charsetBuf = *


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