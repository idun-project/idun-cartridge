; Idun Keys, Copyright© 2020 Brian Holdsworth, MIT License.

; This application provides a simple full-screen app for mapping
; keystrokes and/or key codes to characters.

!source "sys/acehead.asm"
!source "sys/acemacro.asm"
!source "sys/toolhead.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

; Constants


; Zp Vars
addrShowkey = $02   ;(2)
inkey       = $04   ;(1)
quit        = $05   ;(1)
addrCharsets= $06   ;(32)
curChar     = $26   ;(1)
x           = $27   ;(1)

; Command keys defined
CmdKeys = *
  !byte HotkeyUp,HotkeyDown,HotkeyLeft,HotkeyRight,HotkeyStop
  !byte HotkeyReturn
  !byte 0
KeyHandlers = *
  !word Keyup,Keydown,Keyleft,Keyright,Stopquit
  !word Keyselect
KeyPtr !byte 0
KeyTmp !byte 0

HotKeyInit = *
   lda #0
   sta KeyPtr
-  asl
   tax
   lda KeyHandlers,x
   sta KeyTmp
   inx
   lda KeyHandlers,x
   tay
   ldx KeyPtr   
   lda CmdKeys,x
   beq +
   ldx KeyTmp
   jsr toolKeysSet
   inc KeyPtr
   lda KeyPtr
   jmp -  
+  rts

main = *
  lda #0
  sta quit
  jsr clearScr
  jsr setupWindow
  jsr HotKeyInit
  ; Main loop
- bit quit          ; check quit flag
  bpl +
  jsr cursorOff     ; restore defaults
  jsr clearScr
  clc
  rts
  ; Wait on keypress
+ jsr hilight
  jsr cursorOn
  jsr aceConGetkey
  ; Check for any command keys first
  jsr toolKeysHandler
  bcc -
  clc
  ; handle new input key
  sta inkey
  jsr unhilight     ; unhighlight prev input
  jsr cursorOff     ; hide cursor
  lda inkey
  sta curChar
  jsr aceConPutlit  ; show key in right window
  ; show hex codes for raw key and translated
  jsr keycode
  ldx #10
  jsr tohex
  lda inkey
  ldx #31
  jsr tohex
  jsr putKeycodes
  jmp -

keycode = *
  ; Addr for raw key codes is machine-specific
  jsr aceMiscSysType
  cmp #128
  bne +
  lda $d4   ;C128 key code
  rts
+ lda $cb   ;C64 key code
  rts

; clear the window
clearScr = *
  lda #$c0
  ldx #$20
  jmp aceWinCls

; these calls are used to highlight the last input 
; key in the left `charset` window
hilight = *
  ; highlight using revs char
  lda #$50      ; revs+blink
  sta syswork+6
  jmp hilight_cont
unhilight = *
  lda #$00      ; none
  sta syswork+6
  ; determine addr of char to highlight
  hilight_cont = *
  clc
  lda curChar
  and #$0f
  sta x
  lda curChar
  lsr
  lsr
  lsr
  lsr
  asl
  tay
  lda addrCharsets,y
  clc
  adc x
  sta syswork+0
  sta syswork+2
  iny
  lda addrCharsets,y
  adc #0
  sta syswork+1
  sta syswork+3
  lda #1        ; field length
  sta syswork+5
  lda #$60              ; mod color+attrib
  ldx #1
  ldy toolWinPalette+0
  jmp aceWinPut

; these calls control cursor display; cursor should be
; enabled while waiting for user input
cursorOn = *
  lda #$ff
  pha
  jmp cursor_onoff
cursorOff = *
  lda #$00
  pha
  cursor_onoff = *
  jsr aceConGetpos
  jsr aceWinPos
  pla
  ldy toolWinPalette+1
  jmp aceWinCursor

; show top window text with hex codes of input
putKeycodes = *
  lda addrShowkey+0 ;screen addr
  sta syswork+0
  lda addrShowkey+1
  sta syswork+1
  lda #<showKey     ;string addr
  sta syswork+2
  lda #>showKey
  sta syswork+3
  lda #$20          ;fill char
  sta syswork+4
  lda #38           ;field length
  sta syswork+5
  lda #0            ;attributes
  sta syswork+6
  lda #$c0          ;modification flags
  ldx #33           ;string length
  ldy toolWinPalette+2 ;text color
  jmp aceWinPut

; handlers for cursor keys
Keyup = *
  jsr unhilight
  lda curChar
  sec
  sbc #16
  jmp Keydone
Keydown = *
  jsr unhilight
  lda curChar
  clc
  adc #16
  jmp Keydone
Keyleft = *
  jsr unhilight
  lda curChar
  sec
  sbc #1
  jmp Keydone
Keyright = *
  jsr unhilight
  lda curChar
  clc
  adc #1
  Keydone = *
  sta curChar
  clc
  rts

; handler for <Stop>
Stopquit = *
  ; unset the hotkeys
  lda #HotkeyUp
  jsr toolKeysRemove
  lda #HotkeyDown
  jsr toolKeysRemove
  lda #HotkeyLeft
  jsr toolKeysRemove
  lda #HotkeyRight
  jsr toolKeysRemove
  lda #HotkeyStop
  jsr toolKeysRemove
  lda #HotkeyReturn
  jsr toolKeysRemove
  ; set `quit` flag
  lda #$ff
  sta quit
  clc
  ; restore default window
  jmp toolWinRestore

; handler for <Return>
Keyselect = *
  lda curChar
  sec
  rts 

; sets up the 4 virtual window/panels
setupWindow = *
  lda #0
  ldx #39
  jsr toolUserLayout
  lda #$81
  sta toolUserStyles
  lda #2
  sta toolUserColor
  ldx #0
  lda #0
  jsr aceConPos
  jsr toolUserNode
  jsr toolUserLabel
showKey !pet "Keycode: $        Translated: $  ",0
  jsr toolUserEnd
  ; store screen mem addr for key texts
  lda #1
  ldx #1
  jsr aceWinPos
  lda syswork+0
  sta addrShowkey+0
  lda syswork+1
  sta addrShowkey+1
leftCharset = *
  lda #0
  ldx #21
  jsr toolUserLayout
  lda #$81
  sta toolUserStyles
  lda #2
  sta toolUserColor
  ldx #0
  lda #3
  jsr aceConPos
  jsr toolUserNode
  jsr toolUserLabel
_header !pet "   0123456789ABCDEF",0
  ; FIXME: Takes too many rows. Use revs text instead.
  ;jsr toolUserSeparator
  lda #0
  sta toolUserColor
  ; loop over 16x16 characters and display
  lda #0
  sta curChar
  lda #$30
  sta showRow
  +ldaSCII ":"
  sta showRow+1
  lda #$20
  sta showRow+2
  sta showRow+3
  ldx #4
  lda #1
- sta showRow,x
  clc
  adc #1
  inx
  cpx #19
  bmi -
  ; store screen addr for each row of this table
  pha
  jsr aceConGetpos
  jsr aceWinPos
  lda syswork+0
  clc
  adc #4
  ldy curChar
  sta addrCharsets,y
  lda syswork+1
  adc #0
  inc curChar
  ldy curChar
  sta addrCharsets,y
  inc curChar
  ; output each row
  jsr toolUserLabel
showRow !pet "   0123456789ABCDEF",0
  inc showRow
  lda showRow
  cmp #$3a
  bne +
  lda #$c1
  sta showRow
+ cmp #$c7
  beq +
  pla
  ldx #3
  jmp -
+ pla
  jsr toolUserEnd
  lda #0
  sta curChar
botMsgText = *
  ; place brief instructions near bottom
  lda toolWinRegion+0
  ldx #0
  jsr aceConPos
  lda #1
  sta toolUserStyles
  lda #5
  sta toolUserColor
  jsr toolUserLabel
keysMsg !pet "<Stop> to exit",0
rightCharout = *
  ; define window for displaying input
  lda #5          ;top-left
  sta syswork+0
  lda #22
  sta syswork+1
  lda #19         ;rowsxcols
  ldx #19
  jsr aceWinSet
  ; cursor -> home
  lda #5
  ldx #22
  jmp aceConPos

; utility for converting byte-value to hex
tohex = *  ;( .A=val, .X=pos)
  pha
  lsr
  lsr
  lsr
  lsr
  jsr +
  pla
  and #$0f
+ ora #$30
  cmp #$3a
  bcc +
  adc #6
+ sta showKey,x
  inx
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