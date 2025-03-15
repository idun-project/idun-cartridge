; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.

; Tagged far memory manager.

; Tagged data is stored in far memory and each entry may occupy
; 256 up to 65,280 bytes, since all storage is done using full page
; boundaries.

; Only a single byte "Pearson Hash" value is used to identify
; the block. Hash collisions are possible, but unlikely. Attempts
; to alloc a new block with an existing hash value will error.

mpsave      = syswork+8    ;(4)
tagwork     = syswork+12   ;(4)

; Each tag requires 5 bytes for tag(1), size(2), and page addr(2).
;   TAGPTR_ENTRY = TYYMM
;              T = Pearson Hash value for tag
;              YY= Size of the far memory block
;              MM= Far mem page addr. of memory block
; Allows up to 50 entries stored in tagMemTable[0..249].
; Entry #51 at tagMemTable[250..254] is temp storage used internally.
; tagMemTable[255] is the index of the next free "slot" for allocation.

;Randomized values used to calculate a one-byte unique hash for a tag.
;@see `jsr pearson`
pearsonHash !byte $ce,$4a,$67,$b5,$3f,$2f,$5c,$c8,$fa,$53,$da,$7f,$96,$a8,$ea,$13
            !byte $dd,$7e,$1e,$ec,$e3,$0f,$8b,$86,$8f,$cb,$a6,$37,$c9,$ef,$4e,$83
            !byte $32,$db,$99,$d0,$55,$9d,$6d,$33,$bf,$b6,$f9,$c5,$2a,$38,$95,$fc
            !byte $11,$bb,$6b,$57,$c4,$29,$0e,$5f,$06,$3c,$30,$1f,$ff,$78,$12,$2b
            !byte $77,$61,$d5,$42,$d2,$9c,$d9,$cf,$4c,$ad,$75,$a3,$7a,$70,$59,$af
            !byte $ca,$92,$7c,$34,$e1,$a9,$ab,$79,$84,$10,$b1,$bd,$fd,$d7,$a0,$4f
            !byte $d8,$4d,$5b,$8a,$01,$14,$bc,$87,$03,$89,$e2,$90,$9e,$2c,$25,$66
            !byte $21,$19,$43,$3a,$d3,$20,$05,$02,$d6,$b0,$9a,$6c,$8d,$f5,$e9,$6a
            !byte $18,$ed,$85,$f4,$72,$17,$08,$b3,$e5,$94,$d1,$3e,$39,$00,$44,$aa
            !byte $81,$04,$fb,$9b,$31,$e7,$f2,$5a,$88,$76,$48,$ac,$64,$2e,$49,$fe
            !byte $16,$8c,$c2,$62,$ba,$e6,$35,$82,$93,$91,$40,$f8,$1d,$1a,$e8,$27
            !byte $97,$73,$c3,$41,$cd,$80,$2d,$de,$3b,$8e,$b4,$dc,$0c,$65,$be,$1c
            !byte $09,$c6,$7b,$63,$a5,$f6,$f3,$3d,$47,$6e,$e0,$24,$54,$c0,$36,$b9
            !byte $9f,$71,$56,$51,$26,$cc,$6f,$d4,$23,$22,$0a,$f1,$69,$7d,$07,$46
            !byte $1b,$e4,$0d,$a7,$df,$45,$28,$50,$0b,$ae,$c1,$b2,$60,$f7,$74,$a4
            !byte $c7,$4b,$5d,$58,$68,$f0,$15,$b8,$5e,$a1,$a2,$52,$ee,$b7,$eb,$98


restoreMp = *
   ldx #0
-  lda mpsave,x
   sta mp,x
   inx
   cpx #4
   bne -
   rts

kernHashTag = *
pearson = *       ;( (.AY)=tag : .A=hash)
   sta tagwork+2
   sty tagwork+3
   lda #0
   sta tagwork+0
   ldy #0
-  lda (tagwork+2),y
   beq +
   eor tagwork+0
   tax
   lda pearsonHash,x
   sta tagwork+0
   iny
   jmp -
+  lda tagwork+0
   rts

locateMemTag = *   ;(.A=hash : .X=index,.CS=not found)
   sta tagwork+0  ;hash value to locate
   ldx #0
-  cpx aceTagsCur
   beq +
   lda tagMemTable,x
   cmp tagwork+0
   beq ++
   txa
   clc
   adc #5
   tax
   jmp -
+  sec            ;not found
   rts
++ clc            ;found .X=entry
   rts

addMemTag = *  ;(.A=hash, zw=size, (mp)) : .CS=error
   ldx aceTagsCur
   cpx #255
   bcc +
   rts
+  sta tagMemTable,x
   lda zw
   inx
   sta tagMemTable,x
   lda zw+1
   inx
   sta tagMemTable,x
   lda mp+1
   inx
   sta tagMemTable,x
   lda mp+2
   inx
   sta tagMemTable,x
   inx
   stx aceTagsCur
   clc
   rts

tagMemPtr = *
   jsr pearson
   jsr locateMemTag
   bcc +
   rts
+  inx
   lda tagMemTable,x
   sta tagwork+0
   inx
   lda tagMemTable,x
   sta tagwork+1
   inx
   lda tagMemTable,x
   sta mp+1
   inx
   lda tagMemTable,x
   sta mp+1
   jsr setMemType
   lda #0
   sta mp+0
   clc
   rts

setMemType = *
   ldx #aceMemERAM
   lda aceEramBanks
   bne +
   ldx #aceMemInternal
+  stx mp+3
   rts

;---------------------- File API support ------------------------
;*** (bloadDevice, bloadAddress, bloadFilename, zw=limit addr.+1)
;     : .AY=end addr.+1, .CS=error, errno
internTagBload = *
   lda bloadFilename+0
   ldy bloadFilename+1
   jsr tagMemPtr
   bcc +
   lda #aceErrFileNotFound
   sta errno
   rts
+  sta tagwork+0     ;store size
   sty tagwork+1
   ;check if found 1st entry, which is *always* the shell app
   lda tagMemTable+3
   cmp mp+1
   bne +
   lda tagMemTable+4
   cmp mp+2
   bne +
   ;reloading shell app is a special case...
   lda #<aceToolAddress
   sta bloadAddress+0
   lda #>aceToolAddress
   sta bloadAddress+1
   ;fetch binary
+  lda bloadAddress+0
   sta zp+0
   lda bloadAddress+1
   sta zp+1
   lda tagwork+0
   ldy tagwork+1
   jsr kernMemFetch
   bcc +
   lda #aceErrInsufficientMemory
   sta errno
   sec
   rts
+  clc
   lda bloadAddress+0
   adc tagwork+0
   adc #1
   sta tagwork+0
   lda bloadAddress+1
   adc tagwork+1
   sta tagwork+1
   lda tagwork+0
   ldy tagwork+1
   clc
   rts

!macro setTagFileInfo {    ; (.X=tag_entry, .Y=Fd)
   tya
   asl
   asl 
   asl 
   tay
   lda #$1f    ;always device #31
   sta fileinfoTable,y
   iny
   iny
   lda #4
   sta tagwork+3
-  iny
   inx
   lda tagMemTable,x
   sta fileinfoTable,y
   dec tagwork+3
   bne -
}
!macro clearTagFileInfo {    ; (.Y=Fd)
   pha
   tya
   asl
   asl 
   asl 
   tay
   ldx #8
   lda #0
-  dex
   beq +
   sta fileinfoTable,y
   iny
   jmp -
+  pla
}

;*** (openDevice, openFcb, openNameScan, openMode, (zp)=name)
;    : .A=Fcb , .CS=error, errno
internTagOpen = *
   ;allow device #31
   lda openDevice
   lsr
   lsr
   cmp #$1f
   beq +
   lda #aceErrIllegalDevice
   jmp tagOpenError
   ;allow RO 
+  lda openMode
   +cmpASCII "r"
   beq +
   lda #aceErrFileNotOutput
   jmp tagOpenError
   ;check if name exists in tag store
+  lda zp+0
   clc
   adc openNameScan
   sta zp+0
   lda zp+1
   adc #0
   tay
   lda zp+0
   jsr pearson
   jsr locateMemTag
   bcc +
   lda #aceErrFileNotFound
   jmp tagOpenError
   ;keep track of file ptrs in `fileinfoTable`
+  ldy openFcb
   +setTagFileInfo
   lda #0
   sta errno
   lda openFcb
   clc
   rts
   tagOpenError = *
   sta errno
   sec
   rts

;*** (closeFd) : .CS=error, errno
internTagClose = *
   ldy closeFd
   +clearTagFileInfo
   lda closeFd
   asl
   asl
   asl
   cmp fcbIndex
   bne +
   lda #0
   sta fcbIndex
+  lda #0
   sta errno
   clc
   rts

;*** (readFcb, readPtr[readMaxLen]) : readPtr[zw], .AY=zw,
;                                    .CS=err, errno, .ZS=eof

fcbIndex !byte 0   ;track changes to Fcb from read-to-read
zpsave   !byte 0,0
seekop   !byte 0   ;flag to allow some code shared with `seek`

internTagRead = *
   lda #0
   sta seekop
   ;need to save/restore (zp) to prevent side-effects
   lda zp+0
   sta zpsave+0
   lda zp+1
   sta zpsave+1
   ;init size of read to 0
   lda #0
   sta zw+0
   sta zw+1
   ;check Fcb device is #31
   tagReadPrepare = *
   lda readFcb
   asl
   asl
   asl
   tax
   lda fileinfoTable,x
   cmp #$1f
   beq +
   lda #aceErrIllegalDevice
   jmp tagReadError
   ;check if Fcb changed from last read
+  cpx fcbIndex
   beq +
   stx fcbIndex
   bit seekop
   bmi +
   jsr preFetchPage
   ;current pos->tagwork+0
+  ldx fcbIndex
   inx
   lda fileinfoTable,x
   sta tagwork+0
   inx
   lda fileinfoTable,x
   sta tagwork+1
   ;EOF pos->tagwork+2
   inx
   lda fileinfoTable,x
   sta tagwork+2
   inx
   lda fileinfoTable,x
   sta tagwork+3
   bit seekop
   bpl +
   jmp tagSeekContinue

   ;read until end of current page, or readMaxLen, or EOF
+  ldy #0
   tagReadContinue = *
   jsr tagCheckEOF
   bcc +
   jmp tagReadComplete
+  ldx tagwork+0
   lda aceSharedBuf,x
   sta (readPtr),y
   inc tagwork+0
   bne +
   jsr tagBufComplete
+  iny
   inc zw+0
   bne +
   inc zw+1
   ;check zw still less than readMaxLen
+  lda zw+1
   cmp readMaxLen+1
   bne +
   lda zw+0
   cmp readMaxLen+0
   beq tagReadComplete
+  jmp tagReadContinue
   
   tagReadComplete = *
   ;update pos
   ldx fcbIndex
   inx
   lda tagwork+0
   sta fileinfoTable,x
   inx
   lda tagwork+1
   sta fileinfoTable,x

   tagReadDone = *
   lda zpsave+0
   sta zp+0
   lda zpsave+1
   sta zp+1
   ldy zw+1
   lda zw+0
   clc
   rts

   tagReadError = *
   sta errno
   sec
   rts

   tagCheckEOF = *
   lda tagwork+3
   cmp tagwork+1
   beq +
   bcs tagNotEOF
   sec
   rts
+  lda tagwork+2
   cmp tagwork+0
   bne +
   sec
   rts 
+  bcs tagNotEOF
   sec
   rts
   tagNotEOF = *
   clc
   rts

;done reading buffer
;update pos and fetch next page
tagBufComplete = *
   lda #0
   ldx fcbIndex
   inx
   sta fileinfoTable,x
   inx
   lda fileinfoTable,x
   clc
   adc #1
   sta fileinfoTable,x
preFetchPage = *
   tya
   pha
   ;get current position->tagwork
   ldx fcbIndex
   inx
   lda fileinfoTable,x
   sta tagwork+0
   inx
   lda fileinfoTable,x
   sta tagwork+1
   ;get base far ptr
   inx
   inx
   inx
   lda fileinfoTable,x
   sta mp+1
   inx
   lda fileinfoTable,x
   sta mp+2
   jsr setMemType
   ;add current pos to base ptr
   lda mp+1
   clc
   adc tagwork+1
   sta mp+1
   lda mp+2
   adc #0
   sta mp+2
   lda tagwork+0
   sta mp+0
   ;fetch next 256 bytes into aceSharedBuf
   lda #<aceSharedBuf
   sta zp+0
   lda #>aceSharedBuf
   sta zp+1
   lda #0
   ldy #1
   jsr kernMemFetch
   pla
   tay
   rts


;*** (.X=seekFcb, seekPtr) : .CS=err, errno

internTagSeek = *
   lda #$ff
   sta seekop
   stx readFcb
   jmp tagReadPrepare
   tagSeekContinue = *
   ;make sure not seeking past EOF
   lda seekPtr+0
   sta tagwork+0
   lda seekPtr+1
   sta tagwork+1
   jsr tagCheckEOF
   bcc +
   lda #aceErrInvalidFilePos
   jmp tagReadError
+  rts


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