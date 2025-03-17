; Idun Kernel, Copyright ©2025 Brian Holdsworth
; This is free software, released under the MIT License.

; New far memory-management API for use with ERAM
;
; API works without ERAM too, by substituting internal
; RAM instead. ERAM is always used if available.
;
; Public API routines:
; new -     Combines an alloc with a stash operation. If a
; size but no data is provided, then it's just an alloc with
; the memory initialized to zeroes.
; memtag -  Previously allocated memory is paired with a hash
; for the given name. This allows the data in memory to be
; accessed using the file API with a filename of "_:<name>"
; mmap -    Combines loading a file into memory with the above
; hash tagging. Any file can be instantly loaded to RAM then
; accessed via RAM using the file API.

;Mapper command constants
SET_SOURCE      = $f6
SET_DESTINATION = $f5
SET_DEVICE      = $f4
CMD_ALLOCATE    = $f9
CMD_MMAP        = $fb
CMD_GCOLLECT    = $fa

initEram = *
    lda #0
    sta aceEramCur
    sta aceTagsCur
    jsr initTags
    ;** free all the ERAM
    ldx #CMD_GCOLLECT
    lda #$ff
    jmp kernMapperCommand

;=== new === (.AY)=data, .X=$ff? zw=bytes : (mp), .CS=error
sys_area_alloc !byte 0

kernNew = *
    stx sys_area_alloc
    sta syswork
    sty syswork+1
    ldy zw+1
    lda #$ff
    bit zw+0
    beq +
    iny
+   sty syswork+2           ;number of pages
    tya
    jsr newPageAlloc
    bcc +
    rts
+   lda syswork
    ora syswork+1
    beq newInitERAM
    lda syswork
    ldy syswork+1
    sta zp
    sty zp+1
    lda zw
    ldy zw+1
    jsr kernMemStash
    rts

    newInitERAM = *
    lda mp+3
    cmp #aceMemERAM
    bne +
    ldy mp+2
    lda mp+1
    ldx #SET_SOURCE
    jsr kernMapperSetreg
    ldx #CMD_ALLOCATE
    lda syswork+2
    jsr kernMapperCommand
+   rts
    
    newPageAlloc = *
    pha
    ;use ERAM by default
    ldx #aceMemERAM
    lda aceEramBanks
    bne +
    ldx #aceMemInternal
    ;check for system alloc
+   lda sys_area_alloc
    cmp #$ff
    beq +
    lda aceProcessID
+   sta allocProcID
    pla
    jmp kernPageAlloc

;=== memtag === (.AY)=tag, zw=size, (mp) : .CS=error
kernMemtag = *
    jsr kernHashTag
    pha
    jsr locateMemTag
    pla
    bcs +
    lda #aceErrFileExists
    jmp mmap_err
+   jmp addMemTag

;=== mmap ===
mmap_tag !byte 0
mmap_tmp !byte 0

kernMmap = *       ;(.AY=tagname, .X=$ff? (zp)=filename : .CS=error)
    stx sys_area_alloc
    jsr kernHashTag
    pha
    jsr locateMemTag
    pla
    bcs +
    lda #aceErrFileExists
    jmp mmap_err
+   sta mmap_tag
    ;get the file's size
    jsr kernFileStat 
    bcc +
    lda #aceErrFileNotFound
    jmp mmap_err
+   sta zw
    sty zw+1
    ;use ERAM by default
    lda aceEramBanks
    bne +
    jmp mmapInternalRam
+   jsr mmapEramDest
    bcc +
    rts
    ;add to tag memory
+   lda mmap_tag
    jsr addMemTag
    ;command the mapper
    lda mp+1
    ldy mp+2
    ldx #SET_DESTINATION
    jsr kernMapperSetreg
    lda openDevice
    lsr
    lsr
    ldy #0
    ldx #SET_DEVICE
    jsr kernMapperSetreg
    ;check system alloc
    lda sys_area_alloc
    cmp #$ff
    beq +
    lda aceProcessID
+   ldx #CMD_MMAP
    jmp kernMapperCommand

mmapEramDest = *
    lda zw+1
    cmp #64
    bcc +
    jmp multiBlockDest
+   jsr newPageAlloc
    bcc +
    lda #aceErrInsufficientMemory
    jmp mmap_err
+   rts

    multiBlockDest = *
    lda #64
    jsr newPageAlloc ;first of multiple blocks
    bcc +
    lda #aceErrInsufficientMemory
    jmp mmap_err
+   lda allocProcID
    cmp #255
    bne +
    lda zw+1
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr             ;zw+1 / 64
    sta mmap_tmp
    lda mp+2
    sec
    sbc mmap_tmp
    sta mp+2
+   rts


mmapInternalRam = *
    ;store (zp), since kernNew may modify it!
    lda zp
    ldy zp+1
    sta loadZpSave
    sty loadZpSave+1
    ;allocate far memory
    lda #0
    ldy #0
    jsr kernNew
    bcc +
    rts
    ;add to tag memory
+   lda mmap_tag
    jsr addMemTag
    ;restore zp and open the file
    lda loadZpSave
    ldy loadZpSave+1
    sta zp
    sty zp+1
    lda #"B"
    jsr open
    sta mmap_tmp
    lda #<stringBuffer
    ldy #>stringBuffer   ;buffer for streaming in the file...
    sta zp
    sty zp+1
    ;read file into far memory
-   jsr setBufferSz
    ldx mmap_tmp
    jsr read
    jsr kernMemStash
    inc mp+1
    dec aceDirentBytes+1
    bpl -
    lda mmap_tmp
    jmp close

    mmap_err = *
    sta errno
    sec
    rts

    setBufferSz = *
    bne +
    lda aceDirentBytes+0
    ldy #0
    rts
+   lda #0
    ldy #1
    rts

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

