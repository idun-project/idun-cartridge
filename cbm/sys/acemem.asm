; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)
;
; Kernel Dynamic Memory & Process routines.

;*** memory routines ***

!if useC128 {
   comCodeBuffer = $201
}
temp1 = $93

bkSelectRam0 = $ff01
edat         = $df00
cpuspd       = $0a37

;***startup

initMemory = *
!if useC128 {
   ldx #0
-  lda comCodeStart,x
   sta comCodeBuffer,x
   inx
   cpx #comCodeEnd-comCodeStart
   bcc -
}
   rts

internBankConfigs = *
!if useC128 {
   !byte $3f,$7f,$bf,$ff,$bf,$ff,$bf,$ff
   !byte $3f,$7f,$bf,$ff,$bf,$ff,$bf,$00
} else {
   !byte $70,$70
}

internBankGroups = *
!if useC128 {
   !byte $04,$04,$04,$04,$14,$14,$24,$24
   !byte $04,$04,$04,$04,$14,$14,$24,$04
}

;***common code

comCodeStart = *
!if useC128 {
} else {
   comCodeBuffer = comCodeStart
}

comZpLoad = *
   sty temp1
   ldy mp+2
!if useC128 {
   lda internBankGroups,y
   sta $d506
}
   lda internBankConfigs,y
   sta bkSelect
   ldy #0
-  lda (mp),y
   sta 0,x
   inx
   iny
   cpy temp1
   bcc -
   lda #bkACE
   sta bkSelect
   clc
   rts

comZpStore = *
   sty temp1
   ldy mp+2
!if useC128 {
   lda internBankGroups,y
   sta $d506
}
   lda internBankConfigs,y
   sta bkSelect
   ldy #0
-  lda 0,x
   sta (mp),y
   inx
   iny
   cpy temp1
   bcc -
   lda #bkACE
   sta bkSelect
   clc
   rts

comCopyToRam0 = *
   ldx mp+2
!if useC128 {
   lda internBankGroups,x
   sta $d506
   lda internBankConfigs,x
   tax
} else {
   lda internBankConfigs,x
   sta bkSelect
}
   dey
   beq +
!if useC128 {
-  stx bkSelect
   lda (mp),y
   sta bkSelectRam0
} else {
-  lda (mp),y
}
   sta (zp),y
   dey
   bne -
!if useC128 {
+  stx bkSelect
   lda (mp),y
   sta bkSelectRam0
} else {
+  lda (mp),y
}
   sta (zp),y
   lda #bkACE
   sta bkSelect
   clc
   rts

comCopyFromRam0 = *
   ldx mp+2
!if useC128 {
   lda internBankGroups,x
   sta $d506
   lda internBankConfigs,x
   tax
} else {
   lda internBankConfigs,x
   sta bkSelect
}
   dey
   beq +
!if useC128 {
-  sta bkSelectRam0
   lda (zp),y
   stx bkSelect
} else {
-  lda (zp),y
}
   sta (mp),y
   dey
   bne -
!if useC128 {
+  sta bkSelectRam0
   lda (zp),y
   stx bkSelect
} else {
+  lda (zp),y
}
   sta (mp),y
   lda #bkACE
   sta bkSelect
   clc
   rts
comCodeEnd = *

seBank = *
!if useFastClock {
   ldy $d030
   sty cpuspd
   ldy #0
   sty $d030
}
   sta $deff
-  bit $defe
   bvc -
!if useFastClock {
   ldy cpuspd
   sty $d030
}
   rts

sePage = *
!if useFastClock {
   ldy $d030
   sty cpuspd
   ldy #0
   sty $d030
}
   sta $defe
-  bit $defe
   bvc -
!if useFastClock {
   ldy cpuspd
   sty $d030
}
   rts

;*** aceMemZpload( [mp]=Source, .X=ZpDest, .Y=Length ) : .CS=err

kernMemZpload = *
   lda mp+3
   beq nullPtrError
   cmp #aceMemInternal
   bne +
   jmp comZpLoad-comCodeStart+comCodeBuffer

zeroPageEramload = *
+  sty temp1
   lda mp+2
   jsr seBank
   lda mp+1
   beq +
   jsr sePage
+  ldy #255
-  iny
   lda edat,y
   sta $00,x
   inx
   dec temp1
   bne -
   clc
   rts

nullPtrError = *
   lda #aceErrNullPointer
   sta errno
   sec
   rts

memSizeError = *
   lda #aceErrMemorySize
   sta errno
   sec
   rts

;*** aceMemZpstore( .X=ZpSource, [mp]=Dest, .Y=Length ) : .CS=err

kernMemZpstore = *
zpstore = *   ;;internally called operation
   lda mp+3
   bne +
   jmp nullPtrError
+  cmp #aceMemInternal
   bne +
   jmp comZpStore-comCodeStart+comCodeBuffer

zeroPageEramstore = *
+  sty temp1
   lda mp+2
   jsr seBank
   lda mp+1
   beq +
   jsr sePage
+  ldy #255
-  iny
   lda $00,x
   sta edat,y
   inx
   dec temp1
   bne -
   clc
   rts


;*** aceMemFetch( [mp]=FarSource, (zp)=Ram0Dest, .AY=Length )

opLength     !byte 0,0
opSaveSource !byte 0
opSaveDest   !byte 0

kernMemFetch = *
fetch = *    ;;internally called operation
   sta opLength
   sty opLength+1
   ldx mp+3
   beq fetchNullPtrError
   cpy #64
   bcc +
   beq +
   jmp memSizeError
+  cpx #aceMemERAM
   bne +
   lda mp+2
   jsr seBank
   lda opLength
   ldy opLength+1
+  cpy #0
   bne fetchLong
   tay
   bne fetchPage
   clc
   rts

   fetchNullPtrError = *
   jmp nullPtrError

   fetchPage = *  ;( [mp]=from, (zp)=to, .Y=len(0=256) )
   ldx mp+3
   cpx #aceMemInternal
   beq +
   jmp fetchEram
+  ldx mp+2
   cpx #0
   beq +
   ;xx don't have to worry about the 64 having more than one bank yet
   jmp comCopyToRam0-comCodeStart+comCodeBuffer
!if useC128 {
+  stx bkSelectRam0
} else {
+  ldx #bkRam0
   stx bkSelect
}
   dey
   beq +
-  lda (mp),y
   sta (zp),y
   dey
   bne -
+  lda (mp),y
   sta (zp),y
   lda #bkACE
   sta bkSelect
   clc
   rts

   fetchLong = *
   lda mp+1
   sta opSaveSource
   lda zp+1
   sta opSaveDest
   lda opLength+1
   beq fetchLongExit
-  ldy #0
   jsr fetchPage
   inc mp+1
   inc zp+1
   dec opLength+1
   bne -

   fetchLongExit = *
   ldy opLength
   beq +
   jsr fetchPage
+  lda opSaveSource
   sta mp+1
   lda opSaveDest
   sta zp+1
   clc
   rts

   fetchEram = *  ;( [mp]=from, (zp)=to, .Y=len(0=256) )
   sty temp1
   lda mp+1
   jsr sePage
   ldx mp+0
   ldy #0
-  lda edat,x
   sta (zp),y
   inx
   iny
   dec temp1
   bne -
   rts

;*** aceMemStash( (zp)=Ram0Source, [mp]=FarDest, .AY=length )

kernMemStash = *
stash = *        ;;internally called operation
   sta opLength
   sty opLength+1
   ldx mp+3
   beq stashNullPtrError
   cpy #64
   bcc +
   beq +
   jmp memSizeError
+  cpx #aceMemERAM
   bne +
   lda mp+2
   jsr seBank
   lda opLength
   ldy opLength+1
+  cpy #0
   bne stashLong
   tay
   bne stashPage
   clc
   rts

   stashNullPtrError = *
   jmp nullPtrError

   stashPage = *
   ldx mp+3
   cpx #aceMemInternal
   beq +
   jmp stashEram
+  ldx mp+2
   cpx #0
   beq +
   ;xx don't have to worry about the 64 having more than one bank yet
   jmp comCopyFromRam0-comCodeStart+comCodeBuffer
!if useC128 {
+  stx bkSelectRam0
} else {
+  ldx #bkRam0
   stx bkSelect
}
   dey
   beq +
-  lda (zp),y
   sta (mp),y
   dey
   bne -
+  lda (zp),y
   sta (mp),y
   lda #bkACE
   sta bkSelect
   clc
   rts

   stashLong = *
   lda zp+1
   sta opSaveSource
   lda mp+1
   sta opSaveDest
   lda opLength+1
   beq stashLongExit
-  ldy #0
   jsr stashPage
   inc mp+1
   inc zp+1
   dec opLength+1
   bne -

   stashLongExit = *
   ldy opLength
   beq +
   ldx mp+2
   jsr stashPage
+  lda opSaveSource
   sta zp+1
   lda opSaveDest
   sta mp+1
   clc
   rts

   stashEram = *
   sty temp1
   lda mp+1
   ora #$80
   jsr sePage
   ldx mp+0
   ldy #0
-  lda (zp),y
   sta edat,x
   inx
   iny
   dec temp1
   bne -
   rts

;*** memory-allocation routines

freemapBank     !byte 0,0
freemapDirty    !byte 0
freemapPage     !byte 0
freemapBankSave !byte 0,0

getFreemap = *  ;( .AY=bank )
   cmp freemapBank+0
   bne +
   cpy freemapBank+1
   bne +
   rts

   ;** save old freemap
+  sta freemapBankSave+0
   sty freemapBankSave+1
   lda freemapDirty
   beq +
   lda freemapBank+0
   ldy freemapBank+1
   jsr locateBankFreemap
   jsr setZpFreemap
   jsr stash

   ;** load new freemap
+  lda freemapBankSave+0
   ldy freemapBankSave+1
   sta freemapBank+0
   sty freemapBank+1
   jsr locateBankFreemap
   jsr setZpFreemap
   jsr fetch
   lda #0
   sta freemapDirty
   sta freemapPage
   rts

   setZpFreemap = *  ;() : (zp)=#freemap, .AY=#256
   lda #<freemap
   ldy #>freemap
   sta zp+0
   sty zp+1
   lda #<256
   ldy #>256
   rts

locateBankFreemap = *  ;( .AY=bank ) : [mp]
   sta mp+2
   sty mp+3
   lda #<$ff00
   ldx #>$ff00
   sta mp+0
   stx mp+1
   cpy #aceMemInternal
   beq +
   rts
+  lda mp+2
   bne +
   ;** ram0
   lda aceRam0Freemap+0
   ldy aceRam0Freemap+1
-  sta mp+0
   sty mp+1
   rts
+  cmp #1
   bne +
   ;** ram1
   lda #0
   ldy aceRam1Freemap
   jmp -
   ;** exp.int.ram
+  lda #<$0400
   ldy #>$0400
   jmp -

searchSize      !byte 0
allocProcID     !byte 0

;kernel procids for pages: $00=free,$01=kernel,$ff=malloc,$fe=tpa,$fd=tag ram,
;                          $fc=devices,$fb=reservedRamdisk,$fa=console history

kernMemAlloc = *  ;( .A=pages, .X=memType ) : [mp]=farPtr
   pha
   lda aceProcessID
   sta allocProcID
   pla
kernPageAlloc = *
   sta searchSize
   cmp #0
   bne +
   jsr pageAllocFail
   clc
   rts
+  cpx #aceMemERAM
   bne +
   jmp pageAllocEram
+  cpx #aceMemInternal
   bne pageAllocFail
   jsr pageAllocInternal
   bcs pageAllocFail
   ldx mp+3
   lda mp+2
   cmp minUsedBank
   bcs +
   sta minUsedBank
+  cmp maxUsedBank
   bcc +
   sta maxUsedBank
+  clc
   rts

   pageAllocFail = *
   lda #aceErrInsufficientMemory
   sta errno
   lda #$00
   sta mp+0
   sta mp+1
   sta mp+2
   sta mp+3
   sec
   rts

pageAllocEram = *  ;( searchSize ) : [mp]=farPtr, .CC=ok
   lda searchSize
   cmp #65    ;max 64 pages for ERAM alloc
   bcc +
   jmp pageAllocFail
+  ldx #aceMemERAM
   stx mp+3
   jsr scanEramBAM
   bcc +
   jmp pageAllocFail
+  rts

scanCursor !byte 0

scanEramBAM = *
   lda aceEramCur
   sta scanCursor
   ;check if "system allocation"; if so allocate from end
   lda #$ff
   cmp allocProcID
   bne +
   sta scanCursor
+  jsr seBank
-  lda #1
   jsr sePage
   ldx scanCursor
   lda edat,x
   beq new_bank
   cmp allocProcID
   beq +
   sec
   rts
   ;check sufficient space in current bank
+  lda #0
   jsr sePage
   sec
   lda edat,x
   sbc searchSize
   bcs current_bank
   lda #$ff
   cmp allocProcID
   bne +
   dec scanCursor
   jmp -
+  inc scanCursor
   inc aceEramCur
   jmp -

   ;space sufficient; alloc in current bank
   current_bank = *
   lda #64
   sbc edat,x
   sta mp+1
   ;IF alloc size is greater than remaining, then
   ;we advance to the next bank for next alloc
   adc searchSize
   cmp #64
   bcc finish_scan
   inc aceEramCur
   jmp finish_scan
   
   new_bank = *
   lda #0
   sta mp+1
   jsr allocBAM
   
   finish_scan = *
   stx mp+2
   lda #0
   sta mp+0
   clc
   rts

allocBAM = *   ;(.X=block)
   lda #$81
   jsr sePage
   lda allocProcID
   sta edat,x
   sec
   lda aceFreeMemory+1
   sbc #$40
   sta aceFreeMemory+1
   bcs +
   dec aceFreeMemory+2
+  rts

pageAllocInternal = *
   lda #aceMemInternal
   sta mp+3
   lda aceInternalCur
   ldx #$00
   ldy aceInternalBanks
   jsr searchType
   sta aceInternalCur
   rts


searchCurrent !byte 0
searchStart   !byte 0
searchStop    !byte 0

searchType = *  ;( mp+3=type, .A=current, .X=start, .Y=stop ):[mp],.CC,.A=cur,.X
   sta searchCurrent
   sta mp+2
   stx searchStart
   sty searchStop
   cpx searchStop
   bcc searchTypeBra
   rts
searchTypeBra:
   lda mp+2
   ldy mp+3
   jsr getFreemap
   ldy searchSize
   jsr searchFreemap
   bcs +
   lda #0
   sta mp+0
   stx mp+1
   lda mp+2
   clc
   rts
+  inc mp+2
   lda mp+2
   cmp searchStop
   bcc +
   lda searchStart
   sta mp+2
+  lda mp+2
   cmp searchCurrent
   bne searchTypeBra
   sec
   rts

searchPages !byte 0
newmax      !byte 0

searchFreemap = *  ;( .Y=pages ) : .CC=found, .X=firstPg
   ;** first free
   ldx freemapPage
   lda freemap,x
   beq +
-  inx
   beq freemapFull
   lda freemap,x
   bne -
   stx freemapPage
   jmp +
   freemapFull = *
   sec
   rts

   ;** search
+  sty searchPages
   cpx #0
   beq +
   dex
-- ldy searchPages
-  inx
   beq freemapFull
+  lda freemap,x
   bne --
   dey
   bne -

   ;** allocate
   stx newmax
   ldy searchPages
   lda allocProcID
-  sta freemap,x
   dex
   dey
   bne -
   inx
   cpx freemapPage
   bne +
   ldy newmax
   iny
   sty freemapPage
+  lda #$ff
   sta freemapDirty
   sec
   lda aceFreeMemory+1
   sbc searchPages
   sta aceFreeMemory+1
   lda aceFreeMemory+2
   sbc #0
   sta aceFreeMemory+2
   bcs +
   dec aceFreeMemory+3
+  clc
   rts

freePage !byte 0
freeLen  !byte 0

kernMemFree = *  ;( [mp]=FarPtr, .A=pages )
   ldx aceProcessID
   stx allocProcID
kernPageFree = *
   sta freeLen
   cmp #0
   bne +
   jmp pageFreeExit
+  lda mp+3
   cmp #aceMemNull
   bne +
   lda #aceErrNullPointer
   jmp pageFreeFail
   ;free for eram done by garbage collection
+  cmp #aceMemERAM
   bne +
   jmp pageFreeExit
+  lda #aceErrInvalidFreeParms
   ldx mp+0
   bne pageFreeFail
   lda mp+1
   sta freePage
   clc
   adc freeLen
   bcc +
   lda #aceErrInvalidFreeParms
   jmp pageFreeFail
+  lda mp+2
   ldy mp+3
   jsr getFreemap
   lda allocProcID
   ldx freePage
   ldy freeLen
-  cmp freemap,x
   beq +
   lda #aceErrFreeNotOwned
   jmp pageFreeFail
+  inx
   dey
   bne -
   ldx freePage
   ldy freeLen
   lda #$00
-  sta freemap,x
   inx
   dey
   bne -
   lda #$ff
   sta freemapDirty
   lda freePage
   cmp freemapPage
   bcs +
   sta freemapPage
+  clc
   lda aceFreeMemory+1
   adc freeLen
   sta aceFreeMemory+1
   bcc pageFreeExit
   inc aceFreeMemory+2
   bne pageFreeExit
   inc aceFreeMemory+3

   pageFreeExit = *
   clc
   rts

   pageFreeFail = *
   sta errno
   sec
   rts

kernMemStat = *
   ldy #0
-  lda aceFreeMemory,y
   sta 0,x
   lda aceTotalMemory,y
   sta 4,x
   inx
   iny
   cpy #4
   bcc -
   lda aceProcessID
   clc
   rts

reclaimProcMemory = *
   lda minUsedBank
   cmp maxUsedBank
   beq +
   bcs ++
+  ldx minUsedBank
   ldy maxUsedBank
   lda #aceMemInternal
   jsr reclaimProcType
++ rts

reclaimProcEram = *     ;(.X=alloc start block)
   lda aceEramBanks
   beq ++
-  cpx aceEramCur
   beq +
   jsr reclaimEramBlock
   inx
   jmp -
   ;run garbage collector
+  ldx #CMD_GCOLLECT
   lda aceProcessID
   jsr kernMapperCommand
++ rts
   reclaimEramBlock = *
   clc
   lda aceFreeMemory+1
   adc #$40
   sta aceFreeMemory+1
   bcc +
   inc aceFreeMemory+2
+  rts

rpBank  !byte 0,0
rpEnd   !byte 0

reclaimProcType = *  ;( .A=type, .X=startBank, .Y=endBank )
   stx rpBank+0
   sta rpBank+1
   sty rpEnd
-  lda rpBank+0
   ldy rpBank+1
   cmp rpEnd
   beq +
   bcs ++
+  jsr getFreemap
   jsr reclaimProcFreemap
   inc rpBank+0
   bne -
++ rts

reclaimProcFreemap = *  ;( ) : .Y=pagesRemoved
   ldy #0
   ldx #0
   lda aceProcessID
   jmp +
-  inx
   beq ++
+  cmp freemap,x
   bne -
   lda #0
   sta freemap,x
   iny
   lda aceProcessID
   jmp -
++ cpy #0
   beq +
   lda #0
   sta freemapPage
   lda #$ff
   sta freemapDirty
   tya
   clc
   adc aceFreeMemory+1
   sta aceFreeMemory+1
   bcc +
   inc aceFreeMemory+2
   bne +
   inc aceFreeMemory+3
+  clc
   rts

minUsedBank !fill 4,0
maxUsedBank !fill 4,0  ;plus 1

clearMemoryInfo = *
   ldx #3
   lda #$ff
   ldy #$00
-  sta minUsedBank
   sty maxUsedBank
   dex
   bpl -
   rts

;*** process primitives

reclaimSave !byte 0

reclaimOpenFiles = *
   jsr kernelClrchn
   ldx #0
-  lda lftable,x
   cmp #lfnull
   beq +
   lda pidtable,x
   cmp aceProcessID
   bne +
   stx reclaimSave
   txa
   jsr close
   ldx reclaimSave
+  inx
   cpx #fcbCount
   bcc -
   rts

execArgc      !byte 0,0
execFrame     !fill 44+4,0
execStackNeed !byte 0
execAddr      !byte 0,0
execErrExit   !byte 0
reloadFlag    !byte 0

internProcExec = *
   sta execArgc+0
   sty execArgc+1
   ;IDUN: loadPathPos=3 prevents this internal loader from
   ;using the first device in path. That's good since the 1st
   ;path device should be the resident tool loader device `_:`
   lda #3
   sta loadPathPos
   ;** load app to AppAddr
   lda #<aceAppAddress
   ldy #>aceAppAddress
   jmp ProcExecCont
kernProcExec = *
   sta execArgc+0
   sty execArgc+1
   lda #0
   sta loadPathPos
   ;** load tool to ToolAddr
   lda #<aceToolAddress
   ldy #>aceToolAddress
ProcExecCont:
   sta execAddr+0
   sty execAddr+1
   jsr execLoadExternal
   bcc ++
   lda errno
   cmp #aceErrFileNotFound
   beq +
   pha
   jsr execReloadProg
   pla
   sta errno
+  sec
   rts
++ ldy #$ff
-  iny
   lda (zp),y
   sta stringBuffer,y
   bne -
   lda #$80
   sta reloadFlag
   jmp execCommon

kernProcExecSub = *
   sta execArgc+0
   sty execArgc+1
   lda #0  ;null reload name means execsub
   sta stringBuffer+0
   lda #10
   sta execStackNeed
   lda zp+0
   ldy zp+1
   sta execAddr+0
   sty execAddr+1
   lda #$00
   sta reloadFlag

   execCommon = *
   ;** put in filename
   ldx #$ff
-  inx
   lda stringBuffer,x
   bne -
   inx
   stx syswork+0
   sec
   lda zw+0
   sbc syswork+0
   sta syswork+0
   lda zw+1
   sbc #0
   sta syswork+1
   ldy #0
-  lda stringBuffer,y
   sta (syswork),y
   beq +
   iny
   bne -

   ;** set up new frame info
+  ldx #1
-  lda aceFramePtr,x
   sta execFrame+0,x
   lda aceArgc,x
   sta execFrame+2,x
   lda aceArgv,x
   sta execFrame+4,x
   dex
   bpl -
   ldx #3
-  lda mp,x
   sta execFrame+14,x
   lda #0
   sta execFrame+18,x
   lda #aceMemNull
   sta execFrame+24,x
   dex
   bpl -
   tsx
   stx execFrame+22
   lda reloadFlag
   sta execFrame+23
   ldx #3
-  lda minUsedBank,x
   sta execFrame+28,x
   lda maxUsedBank,x
   sta execFrame+36,x
   dex
   bpl -
   lda aceEramCur
   sta execFrame+28+4

   ;** store new frame info
   sec
   lda syswork+0
   sbc #44
   sta syswork+0
   bcs +
   dec syswork+1
+  ldy #43
-  lda execFrame,y
   sta (syswork),y
   dey
   bpl -

   ;** set up globals for new process
   ldx #1
-  lda syswork+0,x
   sta aceFramePtr,x
   sta aceMemTop,x
   lda execArgc,x
   sta aceArgc,x
   lda zw,x
   sta aceArgv,x
   dex
   bpl -
   jsr clearMemoryInfo

   ;** call the new program
   inc aceProcessID
   lda execAddr+0
   ldy execAddr+1
   sta zp+0
   sty zp+1
   lda #0
   tax
   tay
   pha
   plp
   jsr aceEnter
   ;TODO: why override process' return value?
   lda #0
   ldx #0
   jmp internExit

   aceEnter = *
   jmp (zp)

exitCodeSave !byte 0,0
exitArgc     !byte 0,0
exitArgv     !byte 0,0

kernProcExit = *
internExit = *
   sta exitCodeSave+0
   stx exitCodeSave+1
   lda aceFramePtr+0
   ldy aceFramePtr+1
   sta syswork+0
   sty syswork+1
   ldy #43
-  lda (syswork),y
   sta execFrame,y
   dey
   bpl -
   ldx execFrame+22
   txs
   ldx #1
-  lda aceArgc,x
   sta exitArgc,x
   lda aceArgv,x
   sta exitArgv,x
   lda execFrame+2,x
   sta aceArgc,x
   lda execFrame+4,x
   sta aceArgv,x
   lda execFrame+0,x
   sta aceMemTop,x
   sta aceFramePtr,x
   dex
   bpl -
   lda execFrame+23
   sta reloadFlag

   jsr reclaimOpenFiles
   ldx execFrame+28+4
   jsr reclaimProcEram
   jsr reclaimProcMemory
   dec aceProcessID
   ldx #3
-  lda execFrame+28,x
   sta minUsedBank,x
   lda execFrame+36,x
   sta maxUsedBank,x
   dex
   bpl -
   lda execFrame+28+4
   sta aceEramCur
   lda aceTagsStart
   sta aceTagsCur
   
   ;** reload previous program if necessary
   ;xx note: currently, a process that was "execsub"ed cannot "exec" another
   ;xx process or else the "execsub"ed process will not be reloaded, since I
   ;xx only check the reactivated frame and I don't go all the way back up
   ;xx looking for a program to reload
   bit reloadFlag
   bpl +
   jsr execReloadProg
+  nop

   ;** prepare exit parameters
   ldx #3
-  lda execFrame+14,x
   sta mp,x
   dex
   bpl -
   ldx #1
-  lda exitArgc,x
   sta zp,x
   lda exitArgv,x
   sta zw,x
   dex
   bpl -
   lda exitCodeSave+0
   ldx exitCodeSave+1
   ldy #0
   clc
   rts

execReloadProg = *
   lda aceFramePtr+0
   ldy aceFramePtr+1
   clc
   adc #44
   bcc +
   iny
+  sta zp+0
   sty zp+1
   lda zp+1
   cmp aceStackTop+1
   bcs +
   ldy #0
   lda (zp),y
   beq +
   lda aceFramePtr+0
   ldy aceFramePtr+1
   sta zw+0
   sty zw+1
   lda #0
   sta loadPathPos
   jsr execLoadExternal
   bcc +
   lda #<execReloadErrMsg
   ldy #>execReloadErrMsg
   sta zp+0
   sty zp+1
   lda #<execReloadErrMsgEnd-execReloadErrMsg
   ldy #>execReloadErrMsgEnd-execReloadErrMsg
   ldx #stderr
   jsr write
   lda #255
   ldx #0
   jmp internExit
+  clc
   rts

execReloadErrMsg = *
   !pet "acekernel: Error attempting to reload program"
   !byte chrCR
execReloadErrMsgEnd = *

;** load external file into transient program area
loadPathPos !byte 0
loadGiveUp  !byte 0
loadZpSave  !byte 0,0

execLoadExternal = * ;( (zp)=given program name, (zw)=high load address ) : (zp)
   ;IDUN: Use address in execAddr for Load target
   lda #0
   sta loadGiveUp
   lda zp+0
   ldy zp+1
   sta loadZpSave+0
   sty loadZpSave+1

   execTryLoadAgain = *
   ldy loadPathPos
   lda configBuf+$e0,y
   beq execCmdNotFound
   lda loadGiveUp
   bne execCmdNotFound
   jsr getloadRestoreZp
   jsr getLoadPathname
   lda execAddr+0
   sta st
   ldy execAddr+1
   sty st+1
   jsr internBload
   jsr getloadRestoreZp
   bcs execLoadError
   ;IDUN: Special case for reload shell
   jsr isDosReload
   bcc +
   ;Normally, shell is loaded at aceAppAddress ($6000)
   lda #$00
   sta st
   lda #$60
   sta st+1
+  ldy #3
   lda (st),y
   cmp #aceID1
   bne execBadProg
   ldy #4
   lda (st),y
   cmp #aceID2
   bne execBadProg
   ldy #5
   lda (st),y
   cmp #aceID3
   bne execBadProg
   clc
   rts
   isDosReload = *
   ldx #2
-  lda stringBuffer,x
   bne +
   sec
   rts
+  cmp configBuf+$d0-2,x
   bne +
   inx
   jmp -
+  clc
   rts
   execLoadError = *
   lda errno
   cmp #aceErrFileNotFound
   beq execTryLoadAgain
   cmp #aceErrDeviceNotPresent
   beq execTryLoadAgain
   cmp #aceErrIllegalDevice
   beq execTryLoadAgain
   cmp #aceErrDiskOnlyOperation
   beq execTryLoadAgain
   sec
   rts

   execBadProg = *
   lda #aceErrBadProgFormat
   sta errno
   sec
   rts

   execCmdNotFound = *
   lda #aceErrFileNotFound
   sta errno
   sec
   rts

getloadRestoreZp = *
   lda loadZpSave+0
   ldy loadZpSave+1
   sta zp+0
   sty zp+1
   rts

kernSearchPath = *   ;( (zp)=filename, .X=PathPos ) : (zp)=lname, .X=nextPathPos, .CS=end of path
   lda configBuf+$e0,x
   beq +
   stx loadPathPos
   jsr getLoadPathname
   ldx loadPathPos
   clc
   rts
+  sec
   rts
getLoadPathname = *  ;( (zp)=filename, configBuf+$e0, loadPathPos ) : (zp)=lname
   ldy loadPathPos
   ldx #0
-  lda configBuf+$e0,y
   beq +
   sta stringBuffer,x
   iny
   inx
   bne -
+  iny
   sty loadPathPos
   ldy #1
   lda (zp),y
   +cmpASCII ":"
   beq +
   dey
   lda (zp),y
   +cmpASCII "/"
   bne getPathReally
+  sta loadGiveUp
   ldx #0

   getPathReally = *
   ldy #0
-  lda (zp),y
   sta stringBuffer,x
   beq +
   inx
   iny
   bne -
+  lda #<stringBuffer
   ldy #>stringBuffer
   sta zp+0
   sty zp+1
   rts

;blank line at end

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