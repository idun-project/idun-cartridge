; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.

; Uses `fileinfoTable` defined as 256-byte table in idunk. 
; 8 bytes per Fcb #0-31 as `CXXYYMMO`
;
; C  = pid device channel (#31 is reserved for memory-mapped files)
; XX = bytes remaining for read w/ virtual disk files
;      -or- current seek position w/ memory-mapped files
; YY = total length of file
; MM = far mem page address (only w/ mmap files)
; O  = mode flag with which file was opened

; local var used for temporary storage of `zw` system var
; values passed in `zw` should not modify it!
zz !byte 0,0

BlockLfn = 30          ; fixed Lfn for block read/write
CommandLfn = 31        ; fixed Lfn for commands

getFileinfoChan = * ;(.X=fcb) : .A=device
  txa
  asl
  asl
  asl
  tax
  lda fileinfoTable,x
  rts

setFileinfoChan = * ;(.A=device, .X=fcb, openMode) : .A=device
  pha
  pha
  txa
  asl
  asl
  asl
  tax
  pla
  sta fileinfoTable,x
  ; init bytes to $FFFF as a flag to indicate
  ; size is not yet known.
  lda #$ff
  inx
  sta fileinfoTable,x
  inx
  sta fileinfoTable,x
  inx
  inx
  inx
  inx
  inx
  lda openMode
  sta fileinfoTable,x
  pla
  rts

getFileinfoMode = * ;(.X=fcb) : .A=mode
  inx
  txa
  asl
  asl
  asl
  tax
  dex
  lda fileinfoTable,x
  rts

!macro getFileinfoLength {
  pha
  txa
  asl
  asl
  asl
  clc
  adc #1
  tax
  lda fileinfoTable,x
  sta zz
  inx
  lda fileinfoTable,x
  sta zz+1
  pla
}
; This gets and sets both the length and the remaining bytes.
setFileinfoLength = * ;(.X=fcb) : zz=16-bit file length
  txa
  pha
  ; TALK
  jsr getFileinfoChan
  jsr talkChan
  jsr pidChOut
  ; SECOND logical filenum
  pla
  tax
  jsr pidGetlfn
  ora #$60
  jsr pidChOut
  ; recv length (LSB, MSB)
- jsr pidChIn
  bcs -
  sta zz
- jsr pidChIn
  bcs -
  sta zz+1
  txa
  asl
  asl
  asl
  clc
  adc #1
  tax
  lda zz
  sta fileinfoTable,x
  inx
  inx
  sta fileinfoTable,x
  lda zz+1
  dex
  sta fileinfoTable,x
  inx
  inx
  sta fileinfoTable,x
  jsr pidDoUntalk
  rts

updateFileinfoBytes = *
  txa
  asl
  asl
  asl
  clc
  adc #1
  tax
  lda fileinfoTable,x
  sec
  sbc zz
  sta fileinfoTable,x
  inx
  lda fileinfoTable,x
  sbc zz+1
  sta fileinfoTable,x
  bne +
  dex
  ora fileinfoTable,x
  bne +
  lda #$ff
  ldx readFcb
  sta eoftable,x
+ rts

!macro closeFileinfo {
  pha
  tya
  pha
  txa
  asl
  asl
  asl
  tax
  lda #0
  ldy #8
- sta fileinfoTable,x
  inx
  dey
  cpy #0
  bne -
  pla
  tay
  pla
}

swap_count !byte 0
pidFdswap = *   ;( .X=Fcb1, .Y=Fcb2 )
  txa
  asl
  asl
  asl
  tax
  tya
  asl
  asl
  asl
  tay
  lda #8
  sta swap_count
- lda fileinfoTable,x
  pha
  lda fileinfoTable,y
  sta fileinfoTable,x
  pla
  sta fileinfoTable,y
  inx
  iny
  dec swap_count
  bne -
  clc
  rts

; Send UNLISTEN  and get error code
pidDoUnlisten = *
  ; UNLISTEN
  lda #$3F
  jsr pidChOut
  ; Get errno
pidContUnlisten = *
- jsr pidChIn
  bcs -
  sta errno
  cmp #0
  beq +
  sec
  rts
+ lda openFcb
  clc
  rts

;*** (.X=Fcb) : .A=Lfn
pidGetlfn = *
  txa
  and #$30
  beq +
  txa
  rts
+ lda lftable,x
  rts

;*** (openDevice, openFcb, openNameScan, openMode, (zp)=name)
;    : .A=Fcb , .CS=error, errno
pidOpen = *
  ; LISTEN channel
  lda openDevice
  lsr
  lsr
  ldx openFcb
  jsr setFileinfoChan
  jsr listenChan
  jsr pidChOut
  ; OPEN logical filenum
  ldx openFcb
  jsr pidGetlfn
  ora #$A0
  jsr pidChOut
  ; send name
  ldy openNameScan
- lda (zp),y
  cmp #0
  beq +
  jsr pidChOut
  iny
  jmp -
+ lda #","
  jsr pidChOut
  lda openMode
  jsr pidChOut
  lda #0
  jsr pidChOut
  jsr pidFlushbuf
  jsr pidDoUnlisten
  bcc +
  rts
+ ldx openFcb
  lda openMode
  cmp #"p"
  bne +
  jsr setFileinfoLength
  jmp ++
+ cmp #"P"
  bne ++
  jsr setFileinfoLength
++lda openFcb
  clc
  rts

;*** (closeFd) : .CS=error, errno
pidClose = *
  ldx closeFd
  jsr getFileinfoChan
  bne +
  ; Fd is already CLOSEd
  rts
  ; LISTEN channel
+ jsr listenChan
  jsr pidChOut
  ; CLOSE logical filenum
  ldx closeFd
  jsr pidGetlfn
  ora #$80
  jsr pidChOut
  ldx closeFd
  +closeFileinfo
  jsr pidFlushbuf
  jmp pidDoUnlisten
pidCloseall = *
  lda #$5f
  jsr pidChOut
  ldx #32
  stx closeFd
- dec closeFd
  bmi +
  jsr pidClose
  jmp -
+ rts

readlentemp = *
  !byte 0,0

kernDirectRead = * ;( .X=fd, (zp)=buf, .A=# sector) : .AY=(zw)=len
  stx readFcb
  sta readMaxLen+1
  lda #0
  sta readMaxLen+0
  lda zp+0
  ldy zp+1
  sta readPtr+0
  sty readPtr+1
  jsr pidRead
  ;ignore EOF marker
  pha
- jsr pidChIn   ;read $fa
  bcs -
- jsr pidChIn   ;read $00
  bcs -
  pla
  rts  

kernDirectWrite = * ;( .X=fd, (zp)=buf, .A=# sector)
  sta writeLength+1
  lda #0
  sta writeLength+0
  lda zp+0
  ldy zp+1
  sta writePtr+0
  sty writePtr+1
  jmp pidWrite

;*** (readFcb, readPtr[readMaxLen]) : readPtr[zw], .AY=zw,
;                                               : .CS=error, .ZS=eof, errno
pidRead = *
  ; Check whether OPEN was binary mode
  ldx readFcb
  jsr getFileinfoMode
  cmp #"b"
  beq +
  cmp #"B"
  beq +
  lda #<pidReadseq
  ldy #>pidReadseq
  sta readGetbuf+1
  sty readGetbuf+2
  jmp ++
+ lda #<pidGetbuf
  ldy #>pidGetbuf
  sta readGetbuf+1
  sty readGetbuf+2
  ; TALK channel
++ldx readFcb
  jsr getFileinfoChan
  jsr talkChan
  jsr pidChOut
  ; SECOND logical filenum
  ldx readFcb
  jsr pidGetlfn
  ora #$60
  jsr pidChOut
  ; determine how much can be recv'd (readMaxLen >= zz)
  calcRecvLength = *
  ldx readFcb
  +getFileinfoLength
  lda zz+1
  sec
  sbc readMaxLen+1
  bcc ++
  beq +
  lda readMaxLen+0
  sta zz+0
  lda readMaxLen+1
  sta zz+1
  jmp ++
+ lda zz+0
  sec
  sbc readMaxLen+0
  bcc ++
  lda readMaxLen+0
  sta zz+0
  lda readMaxLen+1
  sta zz+1
  ; recv to buffer readPtr[zz]
  readLenSet = *
++lda zz+1
  sta readlentemp+1
  lda zz+0
  sta readlentemp+0
  ora zz+1
  bne +
  jmp readEnd  ; end if zz==0
  readMore = *
+ ldx #0
  cpx zz+1
  bmi readPage
  beq readLast
  jmp readEnd
  readPage = *
  jsr readGetbuf
  bcc +
  jmp pidDetectEOF
+ inc readPtr+1
  dec zz+1
  bne +
  lda zz+0
  beq readEnd
+ jsr pidDoUntalk
  ; TALK for next page
  ldx readFcb
  jsr getFileinfoChan
  jsr talkChan
  jsr pidChOut
  ; SECOND logical filenum
  ldx readFcb
  jsr pidGetlfn
  ora #$60
  jsr pidChOut
  jmp readMore
  readLast = *
  ldx zz+0
  ;WARNING passing zero to readGetbuf reads #256 bytes!
  beq readEnd
  jsr readGetbuf
  bcc readEnd
  pidDetectEOF = *
  sty zz
  jsr pidFlushbuf
  ldx readFcb
  lda #$ff
  sta eoftable,x
  jmp pidDoUntalk
  readEnd = *
  ; subtract length from remaining
  lda readlentemp
  sta zz
  lda readlentemp+1
  sta zz+1
  ldx readFcb
  jsr updateFileinfoBytes
  pidDoUntalk = *
  lda #$5F
  jsr pidChOut
  ldy zz+1
  lda zz
  clc
  rts
readGetbuf = *
  jmp pidReadseq

writeFcb !byte 0
;*** (writePtr[writeLength], .X = Fcb) : .CS=error flag, errno
pidWrite = *
  stx writeFcb
  ; LISTEN channel
  jsr getFileinfoChan
  jsr listenChan
  jsr pidChOut
  ; SECOND logical filenum
  ldx writeFcb
  jsr pidGetlfn
  ora #$60
  jsr pidChOut
  ; send length (LSB, MSB) only for "+" mode
  ldx writeFcb
  jsr getFileinfoMode
  cmp #"+"
  bne +
  lda writeLength+0
  jsr pidChOut
  lda writeLength+1
  jsr pidChOut
  ; send from buffer writePtr[writeLength]
+ lda writeLength+0
  ora writeLength+1
  bne +
  jmp writeEnd   ; end if writeLength==0
  writeMore = *
+ ldx #0
- cpx writeLength+1
  bmi writePage
  beq writeLast
  jmp writeEnd
  writePage = *
  jsr pidPutbuf
  dec writeLength+1
  inc writePtr+1
  jmp writeMore
  writeLast = *
  ldx writeLength+0
  beq writeEnd
  jsr pidPutbuf
  writeEnd = *
  lda #$fa
  jsr pidChOut
  lda #$00
  jsr pidChOut
  ; UNLISTEN
  lda #$3F
  jmp pidChOut

pidDirOpen = *
  lda #"r"
  sta openMode
  lda #2
  sta openNameScan
  jmp pidOpen

pidDirClose = *
  jmp pidClose

; : .X = dirFcb
pidDirRead = *
  stx readFcb
  ; TALK channel
  jsr getFileinfoChan
  jsr talkChan
  jsr pidChOut
  ; SECOND logical filenum
  ldx readFcb
  jsr pidGetlfn
  ora #$60
  jsr pidChOut
  ; read one entry
  lda #<aceDirentBuffer
  sta readPtr
  lda #>aceDirentBuffer
  sta readPtr+1
  ldx #36
  jsr pidGetbuf
  ; UNTALK channel
  lda #$5F
  jsr pidChOut
  lda aceDirentNameLen  ; 0 = end of directroy
  rts

;*** (bloadDevice, bloadAddress, bloadFilename, zw=limit addr.+1)
;     : .AY=end addr.+1, .CS=error, errno

BloadPgs !byte 0
BloadAddr !byte 0,0    ; temp. storage so won't be overwritten

pidBload = *
  lda bloadBank
  beq +
  ; convert to bank configuration
  asl
  asl
  asl
  asl
  asl
  asl
  ora #bkRam0
  sta bloadBank
  ; use bank-aware load routine
  lda #<pidBankload
  ldy #>pidBankload
  sta Bloader+1
  sty Bloader+2
  jmp ++
+ lda #<pidGetbuf
  ldy #>pidGetbuf
  sta Bloader+1
  sty Bloader+2
++lda bloadFilename+0
  sta zp
  lda bloadFilename+1
  sta zp+1
  lda bloadAddress+0
  sta BloadAddr+0
  lda bloadAddress+1
  sta BloadAddr+1
  ; OPEN
  lda bloadDevice
  sta openDevice
  lsr
  lsr
  sta bloadDevice
  lda #"p"
  sta openMode
  lda #0
  sta openNameScan
  lda #BlockLfn
  sta openFcb
  jsr pidOpen
  bcc +
  rts
  ; Destination address
+ lda BloadAddr+0
  sta readPtr
  lda BloadAddr+1
  sta readPtr+1
  ; Maximum read length = zw-BloadAddr
  lda zw
  sec
  sbc BloadAddr
  sta readlentemp
  lda zw+1
  sbc BloadAddr+1
  sta readlentemp+1
  ldx #BlockLfn
  +getFileinfoLength
  ; Check file length vs. space
  lda zz+1
  cmp readlentemp+1
  bcc +
  ; File too big
  lda #aceErrBloadTruncated
  sta errno
  sec
  rts
  ; READ file
+ sta BloadPgs
  ; TALK
  lda bloadDevice
  jsr talkChan
  jsr pidChOut
  ; SECOND logical filenum
  lda #BlockLfn
  ora #$60
  jsr pidChOut
  lda BloadPgs
- cmp #0
  beq lastPg
  ldx #0        ; this means read whole page (256 bytes)
  jsr Bloader
  inc readPtr+1 ; setup to read next page
  dec BloadPgs
  ldx #BlockLfn
  jsr pidDoUntalk
  ; TALK for next page
+ lda bloadDevice
  jsr talkChan
  jsr pidChOut
  lda #BlockLfn
  ora #$60
  jsr pidChOut
  clc
  lda BloadPgs
  jmp -
  lastPg = *
  ldx zz+0
  beq +
  jsr Bloader
  ldx #BlockLfn
  jsr pidDoUntalk
  ; CLOSE
+	lda #BlockLfn
  sta closeFd
	jsr pidClose
  lda readPtr+0
  clc
  adc zz+0
  sta readPtr+0
  lda readPtr+1
  adc #0
  tay
  lda readPtr+0
  clc
	rts
Bloader:
  jmp pidGetbuf

;*** convenience calls for device->channel->IEC cmd
listenChan = *
  clc
  adc #$20
  rts
talkChan = *
  clc
  adc #$40
  rts
deviceToLiChan = *
  lsr
  lsr
  jmp listenChan
deviceToTaChan = *
  lsr
  lsr
  jmp talkChan

;*** Cmd prefix var ('/','=','!','$',or '+')
cmdPrefix:
  !byte 0

;*** (.X=device, (zp)=name) : .CS=error, errno
pidRemove = *
	+ldaSCII "!"
	sta cmdPrefix
	jsr pidCommandStart
  bcs +
  jsr pidCommandFinish
  jmp pidCommandClose
+ rts

;*** (.X=device, (zp)=old_name, (zw)=new_name) : .CS=error, errno
pidRename = *
	+ldaSCII "="
	sta cmdPrefix
	jsr pidCommandStart
  bcc +
  sta errno
  rts
+ lda zw
  sta zp
  lda zw+1
  sta zp+1
  jsr pidCommandFinish
  jmp pidCommandClose

;*** (.X=device, (zp)=name) : .CS=error, errno
pidChDir = *
	+ldaSCII "/"
	sta cmdPrefix
	jsr pidCommandStart
  bcs +
  jsr pidCommandFinish
  bcs +
  jsr pidCommandClose
  lda openDevice
  sta chdirDevice
  lda #0
  sta stringBuffer+2
	jmp chdirSetName
  rts
+ pha
  jsr pidCommandClose
  pla
  sta errno
  sec
  rts

;*** (.X=mnt dev,.A=R/W val,(zp)=img name) : .CS=error, errno
_device_chan: !byte 0,0
pidMount = *
  sta openMode
  +ldaSCII "%"
  sta cmdPrefix
  stx openDevice
  jsr getDevice
  jsr deviceToTaChan
  sta _device_chan
  ; open command channel
  lda #CommandLfn
  sta openFcb
  jsr pidOpen
  bcs +
  jsr pidLocalOpCont
  jmp pidCommandClose
+ rts

;*** ( .A=src Fcb, .X=dest Fcb) : .CS=error,errno
; Prerequisites:
; 1. Both source file and destination must be virtual disk files (type #4/7)
; 2. Source file must be valid open'd Fcb
; 3. Destination must be valid, open'd Command Channel (Lfn #31) Fcb
pidCopyLocal = *
  tax
  jsr getFileinfoChan
  beq +
  jsr talkChan
  sta _device_chan
  ldx #CommandLfn
  jsr getFileinfoChan
  beq +
  asl
  asl
  sta openDevice
  lda #"w"
  sta openMode
  +ldaSCII "+"
  sta cmdPrefix
  jmp pidLocalOpCont
+ lda #aceErrIllegalDevice
  sta errno
  sec
  rts
  pidLocalOpCont = *
  lda #<_device_chan
  ldy #>_device_chan
  sta zp
  sty zp+1
  lda #0
  sta openNameScan
  jsr pidCommandSend
  jmp pidCommandFinish

pidCommandStart = *
  stx openDevice
  lda #"r"
  sta openMode
	; open command channel
	lda #CommandLfn
	sta openFcb
  jsr pidOpen
  bcs +
  pidCommandSend = *
  ; LISTEN channel
  lda openDevice
  jsr deviceToLiChan
  jsr pidChOut
  ; SECOND logical filenum
  lda #CommandLfn
  ora #$60
  jsr pidChOut
+ rts
pidCommandResponse = *
  sta .pidCmdHandler+1
  sty .pidCmdHandler+2
  jmp +
pidCommandFinish = *
  lda #<pidContUnlisten
  ldy #>pidContUnlisten
  jmp pidCommandResponse
  ; send command prefix
+ lda cmdPrefix
  jsr pidChOut
  ; followed by rest of command
  ldy openNameScan
- lda (zp),y
  cmp #0
  beq +
  jsr pidChOut
  iny
  jmp -
+ lda #","
  jsr pidChOut
  lda openMode
  jsr pidChOut
  lda #0
  jsr pidChOut
  lda #$3F
  jsr pidChOut
.pidCmdHandler:
  jmp pidContUnlisten
pidCommandClose = *
+	lda #CommandLfn
  sta closeFd
	jsr pidClose
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