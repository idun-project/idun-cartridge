; Idun Toolbox APIs, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.

;=== Toolbox Interface calls ===
toolCallB 	= aceAppAddress + 8
!ifndef toolUserLayout {
toolUserLayout 	= toolCallB + 0   ;(.A=layout flags .X=width or height)
toolUserNode 	= toolCallB + 3 	;requires embedded args!
toolUserGadget 	= toolCallB + 6 	;requires embedded args!
toolUserLabel 	= toolCallB + 9 	;requires embedded args!
toolUserSeparator = toolCallB + 12
toolUserEnd 	= toolCallB + 15
toolUserLayoutEnd = toolCallB + 18
toolUserMenu      = toolCallB + 21
toolUserMenuItem  = toolCallB + 24  ;requires embedded args!
toolUserMenuNav   = toolCallB + 27
toolKeysSet 	= toolCallB + 30  ;(.A=key .XY=handler)
toolKeysMacro	= toolCallB + 33  ;(.A=key (zp)=macro) : .CS=out of mem
toolKeysRemove 	= toolCallB + 36  ;(.A=key)
toolKeysHandler 	= toolCallB + 39  ;(.A=key)  : .CS=inactive hot key
toolWinRestore	= toolCallB + 42
toolStatTitle 	= toolCallB + 45     ;(.AY=title)
toolStatMenu   = toolCallB + 48     ;(.AY=menu)
toolStatEnable = toolCallB + 51     ;(.A=true || false)
toolTmoJifs	= toolCallB + 54	      ;(.AY=callback, .X=jifs)
toolTmoSecs	= toolCallB + 57	      ;(.AY=callback, .X=seconds)
toolTmoCancel 	= toolCallB + 60
toolSyscall    = toolCallB + 63     ;( (zp)=system cmd, .AY=args)
}

;=== Tool zero-page and ui vars
toolUserColor    = $6f         ;(1)    x|bor|x|txt
toolUserStyles   = $70         ;(1)    b|a|r|u|f|c|>|<
uiLayoutFlag     = $71         ;(1)    h|r|o|x|x|x|x|x|
uiNodeWidth      = $72         ;(1)
uiNodeHeight     = $73         ;(1)
uiNodePos        = $74         ;(2)    X, Y
uiClientRts      = $76         ;(2)    AddrL, AddrH
uiGadgetFlags    = $78         ;(1)    f|s|x|x|x|pen

;=== Tool Data Structs ===
toolWinB		= toolCallB + 66
toolWinRegion     = toolWinB+0  ;(4)
toolWinScroll 	= toolWinB+4  ;(4)
toolWinPalette    = toolWinB+8  ;(8)

;=== Tool Macros ===
!macro toolUserIntfCol ~.refresh, .cols {
   lda #$40             	;vertical layout, retained
   ldx #.cols           	;chars wide
   jsr toolUserLayout
   bit *+6
   bmi *+4
   rts
.refresh: !byte 0 		;refresh counter
}
!macro toolUserIntfRow ~.refresh, .rows {
   lda #$c0             	;horiz. layout, retained
   ldx #.rows           	;chars tall
   jsr toolUserLayout
   bit *+6
   bmi *+4
   rts
.refresh: !byte 0 		;refresh counter
}
!macro toolUserIntfMenu .num, .size, .start, ~.refresh, ~.keycode {
   ldx #.size
   jsr toolUserMenu
   bit *+6
   bmi *+9
   rts
   ;menu and item parameters
.refresh: !byte 0       ;refresh counter
!word .start+5          ;first menu item ptr
!byte .size+3           ;offset to each additional item
!byte .num              ;number of menu items
.keycode: !byte 0       ;item keycode returned by menu
}

;=== Tool constants
TRUE  = $ff
FALSE = $00
; C= + alpha key
HotkeyCmdAt       = $a0
HotkeyCmdA        = $a1
HotkeyCmdB        = $a2
HotkeyCmdC        = $a3
HotkeyCmdD        = $a4
HotkeyCmdE        = $a5
HotkeyCmdF        = $a6
HotkeyCmdG        = $a7
HotkeyCmdH        = $a8
HotkeyCmdI        = $a9
HotkeyCmdJ        = $aa
HotkeyCmdK        = $ab
HotkeyCmdL        = $ac
HotkeyCmdM        = $ad
HotkeyCmdN        = $ae
HotkeyCmdO        = $af
HotkeyCmdP        = $b0
HotkeyCmdQ        = $b1
HotkeyCmdR        = $b2
HotkeyCmdS        = $b3
HotkeyCmdT        = $b4
HotkeyCmdU        = $b5
HotkeyCmdV        = $b6
HotkeyCmdW        = $b7
HotkeyCmdX        = $b8
HotkeyCmdY        = $b9
HotkeyCmdZ        = $ba
HotkeyCmdLbracket = $bb
HotkeyCmdBslash   = $bc
HotkeyCmdRbracket = $bd
HotkeyCmdUparrow  = $be
HotkeyCmdBackarrow= $bf
; C= + cursor keys
HotkeyCmdUp       = $0c
HotkeyCmdDown     = $0f
HotkeyCmdLeft     = $10
HotkeyCmdRight    = $15
HotkeyCmdDel      = $08
; no modifier keys
HotkeyUp          = $91
HotkeyDown        = $11
HotkeyLeft        = $9d
HotkeyRight       = $1d
HotkeyF1          = $85
HotkeyF2          = $89
HotkeyF3          = $86
HotkeyF4          = $8a
HotkeyF5          = $87
HotkeyF6          = $8b
HotkeyF7          = $88
HotkeyF8          = $8c
HotkeyClr         = $93
HotkeyRun         = $83
HotkeyHome        = $13
HotkeyDel         = $14
; special and C128 keys
HotkeyReturn 	= $0d
HotkeyEscape	= $1b
HotkeyHelp        = $04
HotkeyMenu        = $0a
HotkeyRvs         = $12
HotkeyRvsOff      = $92
HotkeyInsert      = $94
HotkeyStop        = $03
HotkeyTab	= $09
HotkeyBackTab     = $02
; C= + numeric keys
HotkeyCmd1        = $81
HotkeyCmd2        = $95
HotkeyCmd3        = $96
HotkeyCmd4        = $97
HotkeyCmd5        = $98
HotkeyCmd6        = $99
HotkeyCmd7        = $98
HotkeyCmd8        = $9b
; additional modified keys
HotkeyCtrl1     	= $90
HotkeyCtrl2     	= $05
HotkeyCtrl3     	= $1c
HotkeyCtrl4     	= $9f
HotkeyCtrl5     	= $9c
HotkeyCtrl6     	= $1e
HotkeyCtrl7     	= $1f
HotkeyCtrl8     	= $9e
HotkeyCtrlReturn	= $01
HotkeyCtrlUp     	= $16
HotkeyCtrlDown  	= $17
HotkeyCtrlLeft  	= $19
HotkeyCtrlRight  	= $1a
HotkeyCtrlTab  	= $18
HotkeyShiftLeft   = $06
HotkeyShiftRight  = $0b
HotkeyShiftHelp	= $84
HotkeyShiftReturn	= $8d
HotkeyShiftMenu   = $07
HotkeyShiftEscape = $0e


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