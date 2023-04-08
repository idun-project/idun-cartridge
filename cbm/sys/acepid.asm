; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.

; Uses `fileinfoTable` defined as 256-byte table in idunk. 
; 8 bytes per Fcb #0-31 as `CXXYYMMU`
;
; C  = pid device channel (#31 is reserved for memory-mapped files)
; XX = bytes remaining for read w/ virtual disk files
;      -or- current seek position w/ memory-mapped files
; YY = total length of file
; MM = far mem page address (only w/ mmap files)
; U  = unused byte

; local var used for temporary storage of `zw` system var
; values passed in `zw` should not modify it!
zz !byte 0,0

getFileinfoChan = * ;(.X=fcb) : .A=device
  txa
  asl
  asl
  asl
  tax
  lda fileinfoTable,x
  rts

!macro setFileinfoChan {
  sta zz+0
  txa
  asl
  asl
  asl
  tax
  lda zz+0
  sta fileinfoTable,x
  ; init bytes to $FFFF as a flag to indicate
  ; size is not yet known.
  lda #$ff
  inx
  sta fileinfoTable,x
  inx
  sta fileinfoTable,x
  lda zz+0
}
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
; This sets both the length and the remianing bytes to
; the initial value given by zz.
setFileinfoLength = * ;(.X=fcb, zz=16-bit len.)
  pha
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
  pla
  rts

!macro updateFileinfoBytes {
  pha
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
  pla
}
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
!macro fileinfoEof {
  txa
  asl
  asl
  asl
  tax
  inx
  lda fileinfoTable,x
  inx
  ora fileinfoTable,x
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

;*** (openDevice, openFcb, openNameScan, openMode, (zp)=name)
;    : .A=Fcb , .CS=error, errno
pidOpen = *
  ; LISTEN channel
  lda openDevice
  lsr
  lsr
  ldx openFcb
  +setFileinfoChan
  jsr listenChan
  jsr pidChOut
  ; OPEN logical filenum
  lda openFcb
  clc
  adc #$A0
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
  jmp pidDoUnlisten

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
  lda closeFd
  clc
  adc #$80
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
  sta zz+1
  dec zz+1
  lda #0
  sta zz+0
  +updateFileinfoBytes
  lda zp+0
  ldy zp+1
  sta readPtr+0
  sty readPtr+1
  ; TALK channel
  ldx readFcb
  jsr getFileinfoChan
  jsr talkChan
  jsr pidChOut
  ; SECOND logical filenum
  lda readFcb
  clc
  adc #$60
  jsr pidChOut
  jmp readMore

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
  ; Check for EOF
  ldx readFcb
  +fileinfoEof
  bne +
  clc
  ldy #0
  lda #0
  rts
  ; TALK channel
+ ldx readFcb
  jsr getFileinfoChan
  jsr talkChan
  jsr pidChOut
  ; SECOND logical filenum
  lda readFcb
  clc
  adc #$60
  jsr pidChOut
  ; recv length (LSB, MSB), if not previously received
  ldx readFcb
  +getFileinfoLength
  lda zz+1
  cmp #$ff
  bne +
  eor zz+0
  bne +
- jsr pidChIn
  bcs -
  sta zz
- jsr pidChIn
  bcs -
  sta zz+1
  ldx readFcb
  jsr setFileinfoLength
  ; determine how much can be recv'd (readMaxLen >= zz)
  calcRecvLength = *
+ ldx readFcb
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
  jsr pidGetbuf
  dec zz+1
  inc readPtr+1
  jsr pidDoUntalk
  ; TALK for next page
  ldx readFcb
  jsr getFileinfoChan
  jsr talkChan
  jsr pidChOut
  ; SECOND logical filenum
  lda readFcb
  clc
  adc #$60
  jsr pidChOut
  jmp readMore
  readLast = *
  ldx zz+0
  ;WARNING passing zero to pidGetbuf reads #256 bytes!
  beq readEnd
  jsr pidGetbuf
  readEnd = *
  ; subtract length from remaining
  lda readlentemp
  sta zz
  lda readlentemp+1
  sta zz+1
  ldx readFcb
  +updateFileinfoBytes
  pidDoUntalk = *
  lda #$5F
  jsr pidChOut
  ldy zz+1
  lda zz
  clc
  rts

;*** (writePtr[writeLength], .X = Fcb) : .CS=error flag, errno
pidWrite = *
  txa
  pha
  ; LISTEN channel
  jsr getFileinfoChan
  jsr listenChan
  jsr pidChOut
  ; SECOND logical filenum
  pla
  clc
  adc #$60
  jsr pidChOut
  ; send length (LSB, MSB)
  lda writeLength+0
  jsr pidChOut
  lda writeLength+1
  jsr pidChOut
  ; send from buffer writePtr[writeLength]
  lda writeLength+0
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
  lda readFcb
  clc
  adc #$60
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
BloadFcb !byte 30      ; fixed Fcb for Bload
BloadAddr !byte 0,0    ; temp. storage so won't be overwritten

pidBload = *
  lda bloadFilename+0
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
  lda #"r"
  sta openMode
  lda #0
  sta openNameScan
  lda BloadFcb
  sta openFcb
  jsr pidOpen
  bcc +
  rts
  ; Destination address
+ lda BloadAddr+0
  sta readPtr
  lda BloadAddr+1
  sta readPtr+1
  ; READ file size
  lda bloadDevice
  jsr talkChan
  jsr pidChOut
  ; SECOND logical filenum
  lda BloadFcb
  clc
  adc #$60
  jsr pidChOut
  ; Maximum read length = zw-BloadAddr
  lda zw
  sec
  sbc BloadAddr
  sta readlentemp
  lda zw+1
  sbc BloadAddr+1
  sta readlentemp+1
  ; recv length (LSB, MSB)
- jsr pidChIn
  bcs -
  sta zz
- jsr pidChIn
  bcs -
  sta zz+1
  ldx BloadFcb
  jsr setFileinfoLength
  ; Check file is not Too Big
  clc
  lda zz+1
  cmp readlentemp+1
  bmi +
  sec
  lda #aceErrInsufficientMemory
  rts
  ; READ rest of file
+ sta BloadPgs
- cmp #0
  beq lastPg
  ldx #0        ; this means read whole page (256 bytes)
  jsr pidGetbuf
  inc readPtr+1 ; setup to read next page
  dec BloadPgs
  ldx BloadFcb
  jsr pidDoUntalk
  ; TALK for next page
+ lda bloadDevice
  jsr talkChan
  jsr pidChOut
  lda BloadFcb
  clc
  adc #$60
  jsr pidChOut
  clc
  lda BloadPgs
  jmp -
  lastPg = *
  lda zz+0
  beq +
  tax
  jsr pidGetbuf
  ldx BloadFcb
  jsr pidDoUntalk
  ; CLOSE
+	lda BloadFcb
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
  lda #31
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
  ldx #31
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
	lda #31
	sta openFcb
  jsr pidOpen
  bcs +
  pidCommandSend = *
  ; LISTEN channel
  lda openDevice
  jsr deviceToLiChan
  jsr pidChOut
  ; SECOND logical filenum
  lda #31
  clc
  adc #$60
  jsr pidChOut
+ rts
pidCommandFinish = *
  ; send command prefix
  lda cmdPrefix
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
  jmp pidDoUnlisten
pidCommandClose = *
+	lda #31
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