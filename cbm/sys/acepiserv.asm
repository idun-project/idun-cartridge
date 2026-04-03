; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.

pisvcCommonGet = *
  sta readPtr+0
  sty readPtr+1
pisvcCommonTalk = *
  ; TALK channel .X
  txa
  clc
  adc #$40
  jsr pidChOut
  ; SECOND $7F
  lda #$7F
  jmp pidChOut
pisvcCommonListen = *
  ; LISTEN channel .A
  clc
  adc #$20
  jsr pidChOut
  ; SECOND $7F
  lda #$7F
  jmp pidChOut

;*** (.X=Register, zw=Value)
kernMapset = *
  ; LISTEN channel @:
  lda #0
  jsr pisvcCommonListen
  ; Send 3-byte message
  txa
  jsr pidChOut
  lda zw+0
  jsr pidChOut
  lda zw+1
  jmp pidChOut
;*** (.X=Command, .A=Param)
kernMapsys = *
  pha
  ; LISTEN channel @:
  lda #0
  jsr pisvcCommonListen
  ; Send 2-byte message
  txa
  jsr pidChOut
  pla
  jmp pidChOut
;*** (.X=Command, zw=ParamSize, zp=Params)
kernMapusr = *
  jsr kernMapset  ;send preamble and ParamSize
  ;send the Params
  lda zw+0
  ora zw+1
  bne usrSendParams
  rts               ; end if zw==0
  usrSendParams = *
  lda zp+0
  ldy zp+1
  sta writePtr+0
  sty writePtr+1
- ldx #0
  cpx zw+1
  bmi usrSendPage
  beq usrSendLast
  jmp +
  usrSendPage = *
  jsr pidPutbuf
  dec zw+1
  inc writePtr+1
  jmp -
  usrSendLast = *
  ldx zw+0
  beq +
  jsr pidPutbuf
+ rts

;*** (.AY=proc callback)
kernMapsts = *
  sta .mapper_proc_addr+0
  sty .mapper_proc_addr+1
  lda #<aceSharedBuf
  ldy #>aceSharedBuf
  ldx #0
  jsr pisvcCommonGet
  ;fetch size
- jsr pidChIn
  bcs -
  sta @zs
  sta zz
- jsr pidChIn
  bcs -
  sta @zs+1
  sta zz+1
  ;check for ERROR
  and @zs
  cmp #$ff
  beq .mapstsError
  ;READ rest of message
- lda zz+1
  cmp #0
  beq .mapperLastPg
  ldx #0        ; this means read whole page (256 bytes)
  jsr pidGetbuf
  jsr .mapperUntalk
  lda #0
  jsr .mapper_proc_callback
  dec zz+1
  ; TALK for next page
  lda #<aceSharedBuf
  ldy #>aceSharedBuf
  ldx #0
  jsr pisvcCommonGet
  jmp -
  .mapperLastPg = *
  lda zz
  beq +
  tax
  jsr pidGetbuf
  jsr .mapperUntalk
  lda zz
  jsr .mapper_proc_callback
+ lda @zs
  ldy @zs+1
  clc
  rts
  .mapperUntalk  = *
  lda #$5F
  jmp pidChOut
  .mapper_proc_callback = *
  .mapper_proc_addr = *+1
  jmp $1234
  .mapstsError = *
- jsr pidChIn
  bcs -
  sta errno
  sec
  rts
@zs !byte 0,0

;*** (.AY = configBuf[256])
; returns configBuf[256]
pisvcGetConfig = *
  ldx #9
  jsr pisvcCommonGet
  ; Get 256-byte response
  ldx #0
  jmp pidGetbuf

;*** (.AY = dateBuf[8])
; returns dateBuf[8]
pisvcTimeGetDate = *
  ldx #20
  jsr pisvcCommonGet
  ; Get 8-byte response
  ldx #8
  jmp pidGetbuf

;*** (.AY = joysBuf[4])
; returns joysBuf[4]
pisvcGetJoysticks = *
  ; LISTEN channel J:
  ldx #10
  jsr pisvcCommonGet
  ; Get 4-byte response
  ldx #4
  jmp pidGetbuf

;*** (.AY = joysConfig[10])
pisvcPutJoystick = *
  sta writePtr+0
  sty writePtr+1
  ; LISTEN channel J:
  lda #10
  jsr pisvcCommonListen
  ldx #10
  jmp pidPutbuf

;*** (.A=code/buttons, .X=modifier/mouse dX, .Y=$80(for key)/mouse dY
kernKvmCommand = *
  pha
  ; Channel K:
  lda #$2b
  jsr pidChOut
  ; Keyboard or Mouse
  cpy #$80
  bne kvmMouseCmd
  lda #$7f        ;SECOND=$7f indicates key event
  jsr pidChOut
  ; Send 2-byte keyboard message
  pla
  jsr pidChOut
  txa
  jmp pidChOut
  kvmMouseCmd = *
  lda #$7e
  jsr pidChOut    ;SECOND=$7e indicates mouse event
  ; Send 3-byte mouse message
  pla
  jsr pidChOut
  txa
  jsr pidChOut
  tya
  jsr pidChOut
  rts

;*** ( (zp)=msg, .X=0..2 param spec.
;      .A=byte param, zw=word param
pisvcPutDebugLog = *
  stx dbg_byte_count
  pha
  ;determine length of msg
  ldy #0
- lda (zp),y
  beq +
  iny
  jmp -
+ iny
  tya
  clc
  adc dbg_byte_count
  sta dbg_byte_count
  ; LISTEN channel \:
  lda #28
  jsr pisvcCommonListen
  ;send total size
  lda dbg_byte_count
  jsr pidChOut
  ;put the msg bytes
  ldy #0
- lda (zp),y
  beq +
  jsr pidChOut
  dec dbg_byte_count
  iny
  jmp -
+ jsr pidChOut
  dec dbg_byte_count
  ldx dbg_byte_count
  cpx #2
  bne +
  ;send word param
  lda zw
  jsr pidChOut
  lda zw+1
  jsr pidChOut
  jmp ++
+ cpx #1
  bne ++
  ;send byte param
  pla
  jmp pidChOut
++pla
  rts
dbg_byte_count !byte 0

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