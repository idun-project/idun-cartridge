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
pisvcCommonDone = *
- jsr pidChIn
  bcs -
  sta errno
  rts

;*** (.X=Command, .A=Param)
kernMapperCommand = *
  pha
  txa
  pha
  ; LISTEN channel @:
  lda #0
  jsr pisvcCommonListen
  ; Send 2-byte message
  pla
  jsr pidChOut
  pla
  jsr pidChOut
  jmp pisvcCommonDone

;*** (.AY=proc callback)
kernMapperProcmsg = *
  sta .mapper_proc_addr+0
  sty .mapper_proc_addr+1
  lda #<mailboxBuf
  ldy #>mailboxBuf
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
  ;READ rest of message
- lda zz+1
  cmp #0
  beq .mapperLastPg
  ldx #0        ; this means read whole page (256 bytes)
  jsr pidGetbuf
  lda #0
  jsr .mapper_proc_callback
  dec zz+1
  jsr .mapperUntalk
  ; TALK for next page
  lda #<mailboxBuf
  ldy #>mailboxBuf
  ldx #0
  jsr pisvcCommonGet
  jmp -
  .mapperLastPg = *
  lda zz
  beq +
  tax
  jsr pidGetbuf
  lda zz
  jsr .mapper_proc_callback
+ jsr .mapperUntalk
  lda @zs
  ldy @zs+1
  rts
  .mapperUntalk  = *
  lda #$5F
  jmp pidChOut
  .mapper_proc_callback = *
  .mapper_proc_addr = *+1
  jmp $1234
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

;*** (conJoy1, conJoy2)
pisvcPutJoysticks = *
  ; LISTEN channel J:
  lda #10
  jsr pisvcCommonListen
  ; Send 2-byte message
  lda conJoy1
  jsr pidChOut
  lda conJoy2
  jsr pidChOut
  jmp pisvcCommonDone

;*** (keycode, shiftValue)
pisvcPutKeyboard = *
  lda keycode
  cmp prevKeycode
  beq +
  cmp #nullKey
  beq +
  ; LISTEN channel K:
  lda #11
  jsr pisvcCommonListen
  ; Send 2-byte message
  lda keycode
  sta prevKeycode
  jsr pidChOut
  lda shiftValue
  jsr pidChOut
  jsr pisvcCommonDone
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