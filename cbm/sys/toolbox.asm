; Idun Toolbox APIs, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.

; The Toolbox is a small set of reusable ML routines (~4 KiB) that are 
; available alongside the Idun Kernel routines to make it easier to develop
; text-based tools in assembly language. These tools are launched from the
; Idun Shell, and return the user to the shell when complete.
;
; By utilizing the Toolbox, tools can provide a simpler and more consistent
; user and programming experinece. There are 7 APIs for the following purposes:

; 1. user: An API for UI and decorative text
; 2. win: An API for defining window areas managed by tools that take over the screen.
; 3. stat: An API for using the status bar that appears at the top of the screen
; when tools are running.
; 4. keys: An API for programming command keys used by the tool.
; 5. mmap: An API for loading data into memory and swapping cached memory with
; working memory. 
; 6. tmo: An API for setting one-shot timeouts to invoke a callback.
; 7. sys: An API for calling System utilities

!source "sys/acehead.asm"
!source "sys/acemacro.asm"

* = aceAppAddress

jmp aceToolboxEnd
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

;=== Jump Table ===
jmp toolUserLayout
jmp toolUserNode
jmp toolUserGadget
jmp toolUserLabel
jmp toolUserSeparator
jmp toolUserEnd
jmp toolUserLayoutEnd
jmp toolUserMenu
jmp toolUserMenuItem
jmp toolUserMenuNav
jmp toolKeysSet
jmp toolKeysMacro
jmp toolKeysRemove
jmp toolKeysHandler
jmp toolWinRestore
jmp toolStatTitle		; Set title in status line
jmp toolStatMenu     ; Set pupop menu for HotkeyMenu
jmp toolStatEnable   ; Enable/disable status line
jmp toolMmapLoad
jmp toolTmoJifs
jmp toolTmoSecs
jmp toolTmoCancel
jmp toolSyscall

;=== Tool API Data Structs ===
;=== (16) toolWin settings
toolWinRegion        !fill 4,0   ;#rows, #cols, top, left
toolWinScroll 	      !fill 4,0   ;modified by vt-100 emulation (tty)
toolWinPalette       !fill 8,0

;=== Tool zero-page and ui vars 
tbwork             = $70 ;(5)    tbwork+0..4
toolUserColor      = $75 ;(1)    x|bor|x|txt
toolUserStyles     = $76 ;(1)    b|a|r|u|f|c|>|<
uiLayoutFlag       = $77 ;(1)    h|r|o|x|x|x|x|x|
uiNodeWidth        = $78 ;(1)
uiNodeHeight       = $79 ;(1)
uiNodePos          = $7a ;(2)    X, Y
uiClientRts        = $7c ;(2)    AddrL, AddrH
uiGadgetFlags      = $7e ;(1)    f|s|x|x|x|pen
joykeyCapture      = $7f ;(1) $80=capture keyb, $40=capture joys, $c0=capture both

;=== Tool constants
TRUE  = $ff
FALSE = $00

;=== Utility routines ===
sys_zp_bkup = $e00

sysZpStore = *
   ;backup syswork
   ldx #$8f
   jsr +
   ;backup tbwork
   ldx #$7f
   jsr +
   ;backup zp,zw, and mp
   ldx #$ff
+  ldy #15
-  lda $00,x
   sta sys_zp_bkup,x
   dex
   dey
   bpl -
   rts

sysZpRestore = *
   ;restore syswork
   ldx #$8f
   jsr +
   ;restore tbwork
   ldx #$7f
   jsr +
   ;restore zp,zw, and mp
   ldx #$ff
+  ldy #15
-  lda sys_zp_bkup,x
   sta $00,x
   dex
   dey
   bpl -
   rts


;=== "toolbox" window routines ===

ToolwinInit = *
   ;** set window parameters
   jsr ToolwinInit1
   ;** set up screen display
   jsr ToolwinRepaint
   ;** set console controls
+  ldx #1
   lda #$e0
   sec
   jsr aceConOption ;console attribute enable
   ldx #12
   lda #99
   sec
   jsr aceConOption ;prescroll override
   ldx #8
   lda #$ff
   sec
   jsr aceConOption ;ignore shifts in scrolling
   ldx #3
   lda #$00
   sec
   jsr aceConOption ;reset attributes
   lda #0
   sta joykeyCapture
   ; Enable Hotkey checking in acecon
   lda #<toolKeysHandler
   ldy #>toolKeysHandler
   jsr aceConSetHotkeys
   ; Start handling interrupts
   lda #<tbIrqHandler
   ldy #>tbIrqHandler
   jmp aceIrqHook

toolWinRestore = *
   ; Restore toolbox handling interrupts
   lda #<tbIrqHandler
   ldy #>tbIrqHandler
   jsr aceIrqHook
ToolwinInit1 = *
   ;** fetch color palette
   jsr aceWinPalette
   ldx #7
-  lda syswork,x
   sta toolWinPalette,x
   dex
   bpl -
   ;** window stuff
   jsr aceWinMax
   jsr aceWinSize
   sta toolWinRegion+0
   stx toolWinRegion+1
   ldy syswork+0
   sty toolWinRegion+2
   ldy syswork+1
   sty toolWinRegion+3
   ldy syswork+2
   sty statlineAddr+0
   ldy syswork+3
   sty statlineAddr+1
   sec
   sbc #1 
   ;fall-through
ToolwinInit2 = *  ;( .A=scrollRows )
   sta toolWinScroll+0
   lda toolWinRegion+1
   sta toolWinScroll+1
   lda toolWinRegion+3
   sta toolWinScroll+3
   lda toolWinRegion+2
   sta toolWinScroll+2
   inc toolWinScroll+2
   ldx #$c0
   stx statlineType
   jmp assertScrollWin

ToolwinRepaint = *
   lda #$c0
   ldx #$20
   ldy toolWinPalette+0
   jsr aceWinCls
   ;fall-through

assertScrollWin = *
   lda toolWinScroll+2
   ldx toolWinScroll+3
   sta syswork+0
   stx syswork+1
   lda toolWinScroll+0
   ldx toolWinScroll+1
   jmp aceWinSet


;=== hotkey tables and dispatch routines ===

cmdDispTableBase: !byte $00,$ff,$ff,$ff,$40,$80,$ff,$ff
cmdDispatchTable = *
   !word CmdNull,CmdNotImp,CmdNotImp,CmdNotImp     ;$00-$03
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$04-$07
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$08-$0b
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$0c-$0f
   !word CmdNotImp,CmdNotImp,CmdRvs,CmdNotImp      ;$10-$13
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$14-$17
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$18-$1b
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$1c-$1f
   !word CmdNull,CmdModeReset,CmdNull,CmdNotImp    ;$80-$83
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$84-$87
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$88-$8b
   !word CmdNotImp,CmdNotImp,CmdNull,CmdNull       ;$8c-$8f
   !word CmdNotImp,CmdNotImp,CmdRvsOff,CmdNotImp   ;$90-$93
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdMode4    ;$94-$97
   !word CmdMode5,CmdNotImp,CmdNotImp,CmdMode8     ;$98-$9b
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$9c-$9f
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$a0-$a3
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$a4-$a7
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdCapKeys  ;$a8-$ab
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$ac-$af
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$b0-$b3
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$b4-$b7
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$b8-$bb
   !word CmdNotImp,CmdNotImp,CmdNotImp,CmdNotImp   ;$bc-$bf
;FIXME: Should reference addr from kernal settings
macroUserCmds = $1000

CmdNull   = *
CmdNotImp = *
   lda tbwork+0
   sec
   rts

toolKeysSet = *  ;(.A=key .XY=handler : .CS=error)
   sta tbwork
   stx tbwork+2
   sty tbwork+3
   asl
   rol
   rol
   rol
   and #$07
   tax
   lda cmdDispTableBase,x
   cmp #$ff
   bne +
   sec
   rts
+  sta tbwork+1
   lda tbwork
   and #$1f
   asl
   adc tbwork+1
   tax
   lda tbwork+2
   sta cmdDispatchTable+0,x
   lda tbwork+3
   sta cmdDispatchTable+1,x
   clc
   rts

toolKeysRemove = * ;(.A=key)
   ldx #<CmdNotImp
   ldy #>CmdNotImp
   jmp toolKeysSet

toolKeysHandler = *  ;(.A=key  : .CS=inactive hot key)
   sta tbwork
   asl
   rol
   rol
   rol
   and #$07
   tax
   lda cmdDispTableBase,x
   cmp #$ff
   bne +
   lda tbwork+0
   sec
   rts
+  sta tbwork+1
   lda tbwork
   and #$1f
   asl
   adc tbwork+1
   tax
   lda cmdDispatchTable+0,x
   sta tbwork+2
   lda cmdDispatchTable+1,x
   sta tbwork+3
   ldx #0
   jmp (tbwork+2)

toolKeysMacro = * ;(.A=key (zp)=macro) : .CS=out of mem
   sta tbwork
   asl
   rol
   rol
   rol
   and #$07
   tax
   lda cmdDispTableBase,x
   sta tbwork+1
   ;only allow key code $80-$8f, excluding $81
   lda tbwork
   cmp #$81
   bne +
-  sec
   rts
+  cmp #$80
   bcc -
   cmp #$90
   bcs -
+  lda tbwork+1
   ldx tbwork
   jsr MacroCommand
   bcs +
   lda tbwork
   and #$1f
   asl
   adc tbwork+1
   tax
   lda #<MacroHandler
   sta cmdDispatchTable+0,x
   lda #>MacroHandler
   sta cmdDispatchTable+1,x
+  rts

MacroHandler = * ;( tbwork=keycode )
   ;locate keycode and command
   ldy #255
-- iny
   lda macroUserCmds,y
   cmp tbwork
   beq +
-  iny
   cpy #0
   beq ++
   lda macroUserCmds,y
   cmp #0
   bne -
   jmp --
+  sty tbwork+14
   ;run the DOS command by injecting into console keybuf
   macroInject = *
   inc tbwork+14
   ldy tbwork+14
   lda macroUserCmds,y
   cmp #0
   beq +
   jsr aceMiscRobokey
   jmp macroInject
   ;done injecting command
+  lda #chrCR
   ldx #$ff
   jsr aceMiscRobokey
   clc
   rts
++ sec
   rts

MacroCommand = * ;( .X=keycode (zp)=command )
   stx tbwork+2
   ;check command is max. 32 chars
   ldx #0
   ldy #0
-  inx
   lda (zp),y
   beq +
   iny
   bne -
+  cpx #32
   bcs macroCommandErr
   ;find end of user commands ($00 $00)
   ldy #0
   lda macroUserCmds,y
   cmp #0
   beq +
   ldy #255
-  iny
   lda macroUserCmds,y
   cmp #0
   bne -
   iny 
   lda macroUserCmds,y
   cmp #0
   bne -
   cpy #250
   bcc +
   ;insufficient programmable key space
   macroCommandErr = *
   rts
   ;insert new command
+  lda tbwork+2
   sta macroUserCmds,y
   iny
   tya
   tax
   ldy #0
-  lda (zp),y
   sta macroUserCmds,x
   cmp #0
   beq +
   iny
   inx
   jmp -
+  clc
   rts


;=== Hotkey handlers for setting screen modes ===

CmdModeReset = *  ;full screen
   sei
   jsr aceWinMax
   jsr ToolwinInit
   cli
   clc
   rts
   CmdDoScreen = *
   sei
   jsr aceWinScreen
   jmp CmdModeReset
CmdMode4 = *  ;40-cols
   lda #0
   ldx #40
   jmp CmdDoScreen
CmdMode5 = *  ;max rows
   lda #255
   ldx #0
   jmp CmdDoScreen
CmdMode8 = *  ;80-cols
   lda #0
   ldx #80
   jmp CmdDoScreen
CmdRvs = *
   ldx #5
   lda #$ff
   sec
   jsr aceWinOption
   clc
   rts
CmdRvsOff = *
   ldx #5
   lda #$00
   sec
   jsr aceWinOption
   clc
   rts

;=== Hotkey handlers for capturing keyboard/joysticks

CmdCapKeys = *
   lda joykeyCapture
   eor #$80
   and #$80
   sta joykeyCapture
   jsr updateStatPutCap
   ;refresh
   dec refreshStatusBar40
   dec refreshStatusBar80
   clc
   rts

;=== Status Line (Top Bar) routines ===

toolStatTitle = *    ;(.AY=title)
   sta tbwork+0
   sty tbwork+1
   ldy #0
-  lda (tbwork),y
   beq _fillWIthSpace
   jsr _copyToTitle
   bne -
   jmp updateStatline
   _copyToTitle = *
   iny
   sta _label80Title,y
   sta _label40Title,y
   cpy #16
   rts
   _fillWIthSpace = *
   lda #$20
-  jsr _copyToTitle
   bne -
   jmp updateStatline

toolStatMenu = *     ;(.AY=menu)
   cmp #0
   bne +
   cpy #0
   bne +
   ;disable menu if .AY==0
   lda #$bf    ;HotkeyCmdBackarrow
   jsr toolKeysRemove
   lda #$20
   jmp ++
   ;enable menu hotkey
+  tax
   lda #$bf    ;HotkeyCmdBackarrow
   jsr toolKeysSet
   lda #$df    ;menu symbol
++ sta _label80Title+0
   sta _label40Title+0
   rts

toolStatEnable = *   ;(.A=true || false)
   cmp #0
   bne +
   lda #$60    ;rts
-  sta _toolStatusEnableOp
   sta dispStatline
   rts
+  lda #$ea    ;nop
   jmp -

updateSeconds = *
   lda secsTimeoutVars+0
   beq updateStatline
   dec secsTimeoutVars+0
   bne updateStatline
   jsr updateStatline
   jmp (secsTimeoutVars+1)
updateStatline = *
   ;** allows status display to be enabled/disabled
_toolStatusEnableOp = *
   nop
   ;** update status and display status line
   ;** free memory
   ldx #syswork
   jsr aceMemStat
   ldx #syswork
   jsr updateStatPutKb
   ;** keyboard/joystick capture status
   jsr updateStatPutCap
   ;** date/time
   jsr updateStatPutDate
   ;mark for redraw
   dec refreshStatusBar40
   dec refreshStatusBar80
   rts


updateStatPutKb = *
   ;divn = tbwork+4
   ;carry= tbwork+14
   ;80 column mode?
   lda toolWinRegion+1
   cmp #40
   beq +
   lda #<_label80Memory
   ldy #>_label80Memory
   jmp ++
+  lda #<_label40Memory
   ldy #>_label40Memory
++ sta zp+0
   sty zp+1
   ; need to divide .X 32-bit# by 1024
   lda $0,x
   sta divn+4
   inx
   lda $0,x
   sta divn+5
   inx
   lda $0,x
   sta divn+2
   inx
   lda $0,x
   sta divn+3
   lda #$00
   sta divn
   lda #$04
   sta divn+1
   jsr div32
   ; mask out upper word of value used by aceMiscUtoa
   lda #0
   sta divn+6
   sta divn+7
   ; check if quotient=0 then just put remainder
   ora divn+4
   ora divn+5
   bne +
   ; Just put remainder (bytes)
   sta tbwork+3
   sta tbwork+2
   lda divn+3
   sta tbwork+1
   lda divn+2
   sta tbwork+0
   ldx #tbwork
   lda #5
   jsr aceMiscUtoa
   +ldaSCII " "
   sta (zp),y
   rts
   ; Put quotient .. "k"
+  lda divn+5
   sta tbwork+1
   lda divn+4
   sta tbwork+0
   lda #0
   sta tbwork+3
   sta tbwork+2
   ldx #tbwork
   lda #5
   jsr aceMiscUtoa
   +ldaSCII "k"
   sta (zp),y
   rts

updateStatPutCap = *
   bit joykeyCapture
   bpl +
   ; keyb icon=$fb $fc $fd
   lda #$fb
   sta _labelCapture+1
   lda #$fc
   sta _labelCapture+2
   lda #$fd
   sta _labelCapture+3
   jmp capstatPutDone
   ; if keyb cap off, set to 3 spaces
+  lda #$20       ;down-arrow
   sta _labelCapture+1
   sta _labelCapture+2
   sta _labelCapture+3
   bit joykeyCapture
   bvc +
   ; joys icon=$f9 $fa
   lda #$f9
   sta _labelCapture+1
   lda #$fa
   sta _labelCapture+2
   jmp capstatPutDone
   ; if joys cap off, set to 2 spaces
+  lda #$20
   sta _labelCapture+1
   sta _labelCapture+2
   capstatPutDone = *
   clc
   rts

updateStatPutDate = *
   lda #<dateBuf
   ldy #>dateBuf
   jsr aceTimeGetDate
   lda toolWinRegion+1
   cmp #40
   beq status_line_40cols
   ;** month
   lda dateBuf+2
   cmp #$10
   bcc +
   sec
   sbc #$10-10
+  tay
   lda monthStr+0,y
   sta _label80DateTime+7
   lda monthStr+13,y
   sta _label80DateTime+8
   lda monthStr+26,y
   sta _label80DateTime+9
   ;** day
   ldx #4
   lda dateBuf+3
   jsr putDigits
   ;** hour
   status_line_40cols = *
   +ldaSCII "a"
   sta tbwork+0
   lda dateBuf+4
   cmp #$00
   bne +
   lda #$12
   jmp putHour
+  cmp #$12
   bcc putHour
   +ldaSCII "p"
   sta tbwork+0
   lda dateBuf+4
   cmp #$12
   beq putHour
   sed
   sec
   sbc #$12
   cld
   putHour = *
   pha
   lda toolWinRegion+1
   cmp #40
   beq +
   ldx #19
   lda tbwork+0
   sta _label80DateTime,x
   ldx #11
   jmp ++
+  ldx #4
++ pla
   jsr putDigits
   ;** minute
   lda dateBuf+5
   inx
   inx
   jsr putDigits
   lda toolWinRegion+1
   cmp #40
   beq +
   ;** second
   lda dateBuf+6
   inx
   inx
   jsr putDigits
   ;** day of week
+  lda dateBuf+7
   and #$07
   tay
   lda dowStr+0,y
   sta _label80DateTime+0
   sta _label40DateTime+0
   lda dowStr+8,y
   sta _label80DateTime+1
   sta _label40DateTime+1
   lda dowStr+16,y
   sta _label80DateTime+2
   sta _label40DateTime+2
   rts

   putDigits = *  ;( .A=num, .X=offset )
   pha
   lsr
   lsr
   lsr
   lsr
   ora #$30
   sta tbwork+0
   pla
   and #$0f
   ora #$30
   sta tbwork+1
   lda toolWinRegion+1
   cmp #40
   beq +
   lda tbwork+0
   sta _label80DateTime,x
   lda tbwork+1
   inx
   sta _label80DateTime,x
   rts
+  lda tbwork+0
   sta _label40DateTime,x
   lda tbwork+1
   inx
   sta _label40DateTime,x
   rts

dateBuf    !fill 8,0
dowStr = *
   !pet "SMTWTFSX"
   !pet "uouehrax"
   !pet "nneduitx"
monthStr = *
   !pet "XJFMAMJJASOND"
   !pet "xaeapauuuecoe"
   !pet "xnbrrynlgptvc"

   _dispStatGetAddress = *
   clc
   lda statlineAddr+0
   adc uiNodePos
   sta syswork+0
   lda statlineAddr+1
   adc #0
   sta syswork+1
   rts

dispStatline = *
   ;nop here is modified by toolStatEnable
   nop 
   ;status bar overrides layout settings
   ldx #$c0
   stx uiLayoutFlag ;horizontal, retained layout
   lda #1
   sta uiNodeHeight
   ldy #$ff
   sty uiNodeWidth
   lda #2
   sta toolUserColor
   lda #$21
   sta toolUserStyles ;reverse chars, align left
   ;status bar is special- can draw outside active window
   lda #<_dispStatGetAddress
   sta _toolOverrideWindow+1
   lda #>_dispStatGetAddress
   sta _toolOverrideWindow+2

   ;80 column mode?
   lda toolWinRegion+1
   cmp #40
   bne +
   bit refreshStatusBar40
   bmi refreshStatusBar40+1
   jmp _dispStatDone
+  bit refreshStatusBar80
   bmi refreshStatusBar80+1
   jmp _dispStatDone

refreshStatusBar80 !byte 0
   jsr toolUserNode
!byte 0,0   ;redraw at 0,0
   ;add title to status bar
   jsr toolUserLabel
_label80Title        !pet " xxxxxxxxxxxxxxxx                       M:",0
   ;add free mem to status bar
   jsr toolUserLabel
_label80Memory       !pet "-----k        ",0
   ;add date/time to status bar
   jsr toolUserLabel
_label80DateTime     !pet "Sat 23 May 04:10:00p",0
   jmp _dispStatCont

refreshStatusBar40 !byte 0
   jsr toolUserNode
!byte 0,0   ;redraw at 0,0
   ;add title to status bar
   jsr toolUserLabel
_label40Title        !pet " xxxxxxxxxxxxxxxx M:",0
   ;add free mem to status bar
   jsr toolUserLabel
_label40Memory       !pet "-----k ",0
   ;add date/time to status bar
   jsr toolUserLabel
_label40DateTime     !pet "Sat 04:10",0
   _dispStatCont = *
   ;add capture status to status bar
   jsr toolUserLabel
_labelCapture        !pet "  ^^",0
   ;end node and layout
   jsr toolUserEnd
   ;mark as redrawn
   inc refreshStatusBar40
   inc refreshStatusBar80

   _dispStatDone = *
   ;put window back to nomal
   lda #<aceWinPos
   sta _toolOverrideWindow+1
   lda #>aceWinPos
   sta _toolOverrideWindow+2
   rts

statlineAddr !byte 0,0
statlineType !byte 0    ;status line type: $80=used, $c0=rvs, $00=unused

;=== ui routines ===
; An API for decorative ui using layout, alignment, colors, styles, and borders.

_menuParameters   = tbwork+0  ;(2)
_menuRefresh      = 0   ;(1)
_menuItemFirst    = 1   ;(2)
_menuItemOffset   = 3   ;(1)
_menuItemCount    = 4   ;(1)
_menuItemRetcode  = 5   ;(1)
_menuSelectPos    = tbwork+4

toolUserMenu = *
   ;enable redraw interrupt
   lda tbActiveLayout+0
   ldy tbActiveLayout+1
   sta tbTempLayout+3
   sty tbTempLayout+4
   pla
   sta uiClientRts
   pla
   sta uiClientRts+1
   jsr toolUserLayoutEnd
   jsr layoutSetInterrupt
   ;save previous layout params
   lda uiLayoutFlag
   sta tbTempLayout+0
   lda uiNodeHeight
   sta tbTempLayout+1
   lda uiNodeWidth
   sta tbTempLayout+2
   ;setup menu layout
   stx uiNodeWidth
   ldy #$ff
   sty uiNodeHeight
   lda #$60
   sta uiLayoutFlag
   ;get menu parameters address
   lda uiClientRts
   clc
   adc #7
   sta _menuParameters+0
   lda uiClientRts+1
   adc #0
   sta _menuParameters+1
   ;set focus 1st item
   ldy #0
   sty _menuSelectPos
   ;init joystick delay counter
   lda #0
   sta joyDelayCounter
   jsr _toolJoyDelay
   ;refresh menu
   _menuDisplayRefresh = *
   jsr _menuSetFocus
   ldy #_menuRefresh
   lda (_menuParameters),y
   sbc #1
   sta (_menuParameters),y
   ;wait for input
   jsr toolUserMenuNav
   cmp #$0d    ;HotkeyReturn
   beq _menuDone
   cmp #$11    ;HotkeyDown
   bne +
   inc _menuSelectPos
+  cmp #$91    ;HotkeyUp
   bne +
   dec _menuSelectPos
+  cmp #$5f    ;Backarrow
   beq +
   jmp _menuDisplayRefresh
+  ldy #_menuItemRetcode
   sta (_menuParameters),y
   ;cleanup and return
   _menuDone = *
   jsr toolUserLayoutEnd
   lda tbTempLayout+0
   sta uiLayoutFlag
   lda tbTempLayout+1
   sta uiNodeHeight
   lda tbTempLayout+2
   sta uiNodeWidth
   sei
   lda tbTempLayout+3
   ldy tbTempLayout+4
   sta tbActiveLayout+0
   sty tbActiveLayout+1
   cli
   lda uiClientRts+1
   pha
   lda uiClientRts
   pha
   rts
   _menuSetFocus = *
   ;unset focus first
   lda #_menuItemCount
   jsr _menuGetParam1
   tax
+  lda #_menuItemFirst
   jsr _menuGetParam2
-  dex
   bmi +
   ldy #1
   lda (tbwork+2),y
   and #$7f
   sta (tbwork+2),y
   lda #_menuItemOffset
   jsr _menuGetParam1
   clc
   adc tbwork+2
   sta tbwork+2
   lda tbwork+3
   adc #0
   sta tbwork+3
   jmp -
   ;0 <= position <= count
+  lda _menuSelectPos
   bpl +
   inc _menuSelectPos
+  lda #_menuItemCount
   jsr _menuGetParam1
   cmp _menuSelectPos
   bne +
   dec _menuSelectPos
   ;focus selected item
+  lda #_menuItemFirst
   jsr _menuGetParam2
   ldx _menuSelectPos
-  dex
   bmi +
   lda #_menuItemOffset
   jsr _menuGetParam1
   clc
   adc tbwork+2
   sta tbwork+2
   lda tbwork+3
   adc #0
   sta tbwork+3
   jmp -
+  ldy #0
   lda (tbwork+2),y
   ldy #_menuItemRetcode
   sta (_menuParameters),y
   ldy #1
   lda (tbwork+2),y
   ora #$80
   sta (tbwork+2),y
   rts
   _menuGetParam1 = *
   tay
   lda (_menuParameters),y
   rts
   _menuGetParam2 = *
   jsr _menuGetParam1
   sta tbwork+2
   iny
   lda (_menuParameters),y
   sta tbwork+3
   rts

;for joystick controls
joy1save !byte $ff
joy2save !byte $ff
joyDelayCounter !byte 0
_toolJoyDelay = *
   ldx #10
   clc
   jsr aceConOption
   asl
   asl
   asl
   cmp joyDelayCounter
   bne +
   ldx #11
   clc
   jsr aceConOption
   asl 
   asl 
   asl 
+  sta joyDelayCounter
   rts

_toolJoystick = *
   tax
   and #$10
   bne +
   clc
   lda #$0d    ;HotkeyReturn
   ldx #0
   rts
+  txa
   lsr
   bcs +
   lda #$91    ;HotkeyUp
   rts
+  lsr
   bcs +
   lda #$11    ;HotkeyDown
   rts 
   ;check joy1 left
+  lsr
   bcs +
   lda #$9d    ;HotkeyLeft
+  rts

toolUserMenuNav = *
   ;prevent FIRE button repeating
   jsr aceConJoystick
   cmp #$ef
   beq toolUserMenuNav
   txa
   cmp #$6f
   beq toolUserMenuNav
_toolReadInput = *
   jsr aceConKeyAvail
   bcs +
   jmp aceConGetkey
+  jsr aceConJoystick
   ;check joy1
   cmp #$ff
   beq ++
   cmp joy1save
   beq +
   sta joy1save
   jsr _toolJoyDelay
-  jsr _toolJoystick
   bcs _toolReadInput
   rts
   ;repeat delay
+  dec joyDelayCounter
   bne _toolReadInput
   jmp -
   ;check joy2
++ txa
   cmp #$ff
   beq _toolReadInput
   cmp joy2save
   beq +
   sta joy2save
   jsr _toolJoyDelay
   ;repeat delay
+  dec joyDelayCounter
   bne _toolReadInput
   jmp -

toolUserLayout = *
   sta uiLayoutFlag
   ldy #$ff
   ;set Width/Height according to layout direction
   bit uiLayoutFlag
   bpl +
   stx uiNodeHeight
   sty uiNodeWidth
   jmp ++
+  stx uiNodeWidth
   sty uiNodeHeight
++ bvc +
   ;link retained layout into refresh interupt
   pla
   sta uiClientRts
   pla
   sta uiClientRts+1
   jsr layoutSetInterrupt
   ;other parameters default to 0
   lda #0
   sta toolUserColor
   sta toolUserStyles
   sta uiNodePos
   sta uiNodePos+1
   ;restore correct rts addr
   lda uiClientRts+1
   pha
   lda uiClientRts
   pha
   ;and return
   jmp +
   layoutSetInterrupt = *
   sei
   clc
   lda uiClientRts
   adc #1
   sta tbActiveLayout+0
   lda uiClientRts+1
   adc #0
   sta tbActiveLayout+1
   cli
+  rts

toolUserLayoutEnd = *
   sei
   lda #<_inactiveLayout
   sta tbActiveLayout+0
   lda #>_inactiveLayout
   sta tbActiveLayout+1
   cli
   rts

node_pos_save !byte 0,0
toolUserNode = *
   pla
   sta uiClientRts
   pla
   sta uiClientRts+1
   bit uiLayoutFlag
   bvc +
   lda uiClientRts
   clc
   adc #1
   sta tbwork+2
   lda uiClientRts+1
   adc #0
   sta tbwork+3
   lda #2
   clc
   adc uiClientRts
   sta uiClientRts
   lda uiClientRts+1
   adc #0
   sta uiClientRts+1
   ldy #0
   lda (tbwork+2),y
   tax
   iny
   lda (tbwork+2),y
   tay
   ;store node attributes
+  lda toolUserStyles
   pha
   lda toolUserColor
   pha
   ;restore rts addr
   lda uiClientRts+1
   pha
   lda uiClientRts
   pha
   bit uiLayoutFlag
   bvc +
   stx uiNodePos
   stx node_pos_save+0
   sty uiNodePos+1
   sty node_pos_save+1
   jmp ++
+  jsr aceConGetpos
   stx uiNodePos
   sta uiNodePos+1
   ; draw top border, if on
++ lda toolUserStyles
   bpl +
   jsr _bordDrawTop
+  rts

toolUserEnd = *
   pla
   sta uiClientRts
   pla
   sta uiClientRts+1
   ;restore node attributes
   pla
   sta toolUserColor
   pla
   sta toolUserStyles
   ;restore rts addr
   lda uiClientRts+1
   pha
   lda uiClientRts
   pha
   ; draw bottom border, if on
   lda toolUserStyles
   bpl +
   jsr _bordDrawBottom
+  rts

toolUserSeparator = *
   bit uiLayoutFlag
   bvc +
   ;no vertial separators (yet?)
   rts
+  lda toolUserStyles
   bpl _toolDrawSeparator
   ; border on, use left-T
   lda #chrLT
   jsr _bordDraw
   _toolDrawSeparator = *
   lda uiNodePos
   cmp uiNodeWidth
   beq +
   lda #chrHL
   jsr _bordDraw
   jmp _toolDrawSeparator
+  lda toolUserStyles
   bpl +
   ; border on, use right-T
   lda #chrRT
   jsr _bordDraw
   jmp _toolCheckScroll
+  lda #chrHL
   jsr _bordDraw

   _toolCheckScroll = *
   inc uiNodePos+1
   bit uiLayoutFlag
   bvs ++
   lda toolWinScroll+0
   cmp uiNodePos+1
   bne +
   lda #$20
   sta syswork+4
   lda #$0
   sta syswork+6
   ldy #0
   lda #$c8
   ldx #1
   jsr aceWinScroll
   dec uiNodePos+1
+  ldx #0
   stx uiNodePos
   lda uiNodePos+1
   jmp aceConPos
++ ldx node_pos_save+0
   stx uiNodePos
   rts

_menuItemKeycode !byte 0
toolUserMenuItem = *
   ;first parameter is menu keycode
   tsx
   inx
   lda $100,x
   clc
   adc #1
   sta tbwork+0
   inx
   lda $100,x
   adc #0
   sta tbwork+1
   ldy #0
   lda (tbwork),y
   sta _menuItemKeycode
   ;move stack addr up one byte
   lda tbwork+1
   sta $100,x
   dex
   lda tbwork+0
   sta $100,x
   ;continue by using the gadget routine
toolUserGadget = *
   ;first parameter is gadget flags
   tsx
   inx
   lda $100,x
   clc
   adc #1
   sta tbwork+0
   inx
   lda $100,x
   adc #0
   sta tbwork+1
   ldy #0
   lda (tbwork),y
   sta uiGadgetFlags
   ;move stack addr up one byte
   lda tbwork+1
   sta $100,x
   dex
   lda tbwork+0
   sta $100,x
   ;continue by using the label routine
   jmp +
toolUserLabel = *
   ;if entry here, then not a gadget
   lda #0
   sta uiGadgetFlags
   ;temp. disable statline
+  lda dispStatline
   sta _tbStatlinesave
   lda #$60
   sta dispStatline
   ;first parameter is string
   tsx
   inx
   lda $100,x
   clc
   adc #1
   sta tbwork+2
   inx
   lda $100,x
   adc #0
   sta tbwork+3
   ;determine length of string param
   ldy #255
-  iny
   lda (tbwork+2),y
   bne -
   sty tbwork+4
   ;fix-up the rts addr
   tya
   clc
   adc tbwork+2
   dex
   sta $100,x
   lda tbwork+3
   adc #0
   inx
   sta $100,x
   ;save uiNodePos, restore before return
   lda uiNodePos+0
   sta node_pos_save+0
   lda uiNodePos+1
   sta node_pos_save+1
   ;draw border?
   lda toolUserStyles
   bpl +
   lda #chrVL
   jsr _bordDraw
+  lda tbwork+4
   ldx uiNodeWidth
   bpl +
   sta syswork+5
   jmp ++
+  stx syswork+5
++ ldx #0
   stx syswork+6
   ldx tbwork+2
   stx syswork+2
   ldx tbwork+3
   stx syswork+3
   jsr _textDraw
   lda uiNodePos
   clc
   adc syswork+5
   sta uiNodePos
   ; border?
   lda toolUserStyles
   bpl +
   lda uiNodeWidth
   clc
   adc node_pos_save+0
   sta uiNodePos
   lda #chrVL
   jsr _bordDraw
+  lda uiLayoutFlag
   bpl +
   lda node_pos_save+1
   sta uiNodePos+1
   jmp ++
+  jsr _toolCheckScroll
   lda node_pos_save+0
   sta uiNodePos+0
++ lda _tbStatlinesave
   sta dispStatline
   rts
_tbStatlinesave !byte $ea

   _bordDrawTop = *
   ; top-left
   lda #chrTL
   jsr _bordDraw
   ; horizontal line
   lda uiNodeWidth
   sec
   sbc #2
   sta tbwork+2
-  lda #chrHL
   jsr _bordDraw
   dec tbwork+2
   bpl -
   ; top-right
   lda #chrTR
   jsr _bordDraw
   jmp _toolCheckScroll

   _bordDrawBottom = *
   ; bottom-left
   lda #chrBL
   jsr _bordDraw
   ; horizontal line
   lda uiNodeWidth
   sec
   sbc #2
   sta tbwork+2
-  lda #chrHL
   jsr _bordDraw
   dec tbwork+2
   bpl -
   ; bottom-right
   lda #chrBR
   jsr _bordDraw
   jmp _toolCheckScroll

   _textDrawColor = *   ;(<none>: .A=rgbi)
   bit uiGadgetFlags
   bvc +
   lda uiGadgetFlags
   jmp ++
+  lda toolUserColor
++ and #$07
   tay
   lda toolWinPalette,y
   rts

   _bordDrawColor = *   ;(<none>: .A=rgbi)
   lda toolUserColor
   lsr
   lsr
   lsr
   lsr
   and #$07
   tay
   lda toolWinPalette,y
   rts

   _textDraw = *        ;(sw+2=str,sw+5=width,.A=len)
   pha
   jsr _preDraw
   jsr _textDrawColor
   tay
   pla
   tax
   lda #$e0
   jmp aceWinPut
   _preDraw = *
   ldx uiNodePos
   lda uiNodePos+1
   jsr _toolOverrideWindow
   lda toolUserStyles
   asl
   bit uiGadgetFlags
   bpl +
   ora #$40      ;focused gadget = rev. text
+  sta syswork+6
   lda #$20
   sta syswork+4
   rts
   ;This can be overriden, such as by the status bar
   ;to allowing drawing outside of the active window.
   _toolOverrideWindow = *
   jmp aceWinPos

_bordchr !byte 0
   _bordDraw = *       ;(.A=char)
   sta _bordchr
   lda #<_bordchr
   ldy #>_bordchr
   sta syswork+2
   sty syswork+3
   lda #1
   sta syswork+5
   jsr _preDraw
   lda #0
   sta syswork+6
   inc uiNodePos
   jsr _bordDrawColor
   tay
   ldx #1
   lda #$e0
   jmp aceWinGrChrPut


divn !fill 8,0
carry !byte 0
;=== 32-bit divider (for calc Kb from 32-bit bytes quantity) ===
div32 = *
  sec             ; Detect overflow or /0 condition.
  lda     divn+2  ; Divisor must be more than high cell of dividend.  To
  sbc     divn    ; find out, subtract divisor from high cell of dividend;
  lda     divn+3  ; if carry flag is still set at the end, the divisor was
  sbc     divn+1  ; not big enough to avoid overflow. This also takes care
  bcs     +       ; of any /0 condition.  Branch if overflow or /0 error.
                  ; We will loop 16 times; but since we shift the dividend
  ldx     #$11    ; over at the same time as shifting the answer in, the
                  ; operation must start AND finish with a shift of the
                  ; low cell of the dividend (which ends up holding the
                  ; quotient), so we start with 17 (11H) in X.
- rol     divn+4  ; Move low cell of dividend left one bit, also shifting
  rol     divn+5  ; answer in. The 1st rotation brings in a 0, which later
                  ; gets pushed off the other end in the last rotation.
  dex
  beq     ++      ; Branch to the end if finished.

  rol     divn+2  ; Shift high cell of dividend left one bit, also
  rol     divn+3  ; shifting next bit in from high bit of low cell.
  lda     #0
  sta     carry   ; Zero old bits of CARRY so subtraction works right.
  rol     carry   ; Store old high bit of dividend in CARRY.  (For STZ
                  ; one line up, NMOS 6502 will need LDA #0, STA CARRY.)
  sec             ; See if divisor will fit into high 17 bits of dividend
  lda     divn+2  ; by subtracting and then looking at carry flag.
  sbc     divn    ; First do low byte.
  sta     divn+6  ; Save difference low byte until we know if we need it.
  lda     divn+3  ;
  sbc     divn+1  ; Then do high byte.
  tay             ; Save difference high byte until we know if we need it.
  lda     carry   ; Bit 0 of CARRY serves as 17th bit.
  sbc     #0      ; Complete the subtraction by doing the 17th bit before
  bcc     -       ; determining if the divisor fit into the high 17 bits
                  ; of the dividend.  If so, the carry flag remains set.
  lda     divn+6     ; If divisor fit into dividend high 17 bits, update
  sta     divn+2     ; dividend high cell to what it would be after
  sty     divn+3     ; subtraction.
  bcs     -       ; Always branch.  NMOS 6502 could use BCS here.

+ lda     #$ff    ; If overflow occurred, put FF
  sta     divn+2     ; in remainder low byte
  sta     divn+3     ; and high byte,
  sta     divn+4     ; and in quotient low byte
  sta     divn+5     ; and high byte.
++rts

;=== mmap routines ===
; An API for loading files and other data into extended RAM
; for fast access and transfer to/from working buffers.
toolMmapLoad = *       ;(.AY=tagname, (zp)=filename : .CS=error)
   sta tbwork+2
   sty tbwork+3
   lda zp+0
   sta tbwork+0
   lda zp+1
   sta tbwork+1
   ldy #1
   lda (tbwork),y
   +cmpASCII ":"
   bne +
   ; skip over ".:" prefix in tag name
   lda tbwork+0
   clc
   adc #2
   sta tbwork+0
   lda tbwork+1
   adc #0
   sta tbwork+1
   ;try to load the file above dos.app
+  lda aceMemTop+0
   sta zw+0
   lda aceMemTop+1
   sta zw+1
   lda #<bssAppEnd
   ldy #>bssAppEnd
   jsr aceFileBload
   bcc +
   ;fail on loading
   rts
   ;Determine size of file
+  sta zw+0
   sty zw+1
   sec
   sbc #<bssAppEnd
   sta zw+0
   lda zw+1
   sbc #>bssAppEnd
   sta zw+1
   ;alloc tagged
   lda tbwork+2
   sta zp+0
   lda tbwork+3
   sta zp+1
   jsr aceTagRealloc
   bcc +
   rts
   ;stash file in tagged memory
+  lda #<bssAppEnd
   sta zp+0
   lda #>bssAppEnd
   sta zp+1
   lda tbwork+2
   ldy tbwork+3
   jmp aceTagStash


;=== tmo routines ===
; An API for setting one-shot timeouts to invoke a callback.

; Keep track of timeouts and callbacks- defaulted setting
; updates Secs timeout and tool status line.
jifsTimeoutVars !byte 0,0,0
secsTimeoutVars !byte 0,0,0

; This handler hooks into the system Irq
tbIrqHandler = *
   jsr sysZpStore
   jsr tbFrameSync
   jsr tbHandleTmo
   jmp sysZpRestore
   tbHandleTmo = *
   lda jifsTimeoutVars+0
   beq +
   dec jifsTimeoutVars+0
   beq ++
   rts
+  ldx #59
   lda #<updateSeconds
   ldy #>updateSeconds
   stx jifsTimeoutVars+0
   sta jifsTimeoutVars+1
   sty jifsTimeoutVars+2
   rts
++ jmp (jifsTimeoutVars+1)

;*** toolTmoJifs (.AY=callback, .X=jifs)
toolTmoJifs = *
   sei
   stx jifsTimeoutVars+0
   sta jifsTimeoutVars+1
   sty jifsTimeoutVars+2
   cli
   rts

;*** toolTmoSecs (.AY=callback, .X=seconds)
toolTmoSecs = *
   sei
   stx secsTimeoutVars+0
   sta secsTimeoutVars+1
   sty secsTimeoutVars+2
   cli
   rts

;*** toolTmoCancel ()
toolTmoCancel = *
   sei
   ldx #5
   lda #0
-  sta jifsTimeoutVars,x
   dex
   bpl -
   cli
   rts

;=== sys routines ===
; An API for calling system utility as a sub-process

_syscallArgs = tbwork+0
_syscallFrame = tbwork+2
_syscallArgC !byte 0
_syscallFrameLen !byte 0

;*** toolSyscall ( (zp)=cmd, .AY=frame, .X=len(frame) )
toolSyscall = *
   sta _syscallArgs
   sty _syscallArgs+1
   stx _syscallFrameLen
   lda #0
   sta _syscallArgC
   ;create new aceProcExec frame
   lda aceMemTop+0
   ldy aceMemTop+1
   sec
   sbc _syscallFrameLen
   bcs +
   dey
+  sta _syscallFrame
   sty _syscallFrame+1
   ;copy into frame and patch arg ptrs
   ldy #0
-  lda (_syscallArgs),y
   sta tbwork+4
   iny
   lda (_syscallArgs),y
   ora tbwork+4
   beq +
   inc _syscallArgC
   lda _syscallFrame+0
   clc
   adc tbwork+4
   dey
   sta (_syscallFrame),y
   iny
   lda _syscallFrame+1
   adc #0
   sta (_syscallFrame),y
   iny
   jmp -
+  dey
   sta (_syscallFrame),y
   iny
   sta (_syscallFrame),y
   iny
   ;copy arg strings into frame
-  cpy _syscallFrameLen
   beq +
   lda (_syscallArgs),y
   sta (_syscallFrame),y
   iny
   jmp -
   ;exec command
+  lda _syscallFrame+0
   ldy _syscallFrame+1
   sta zw+0
   sty zw+1
   lda _syscallArgC
   ldy #0
   jmp aceProcExec

; This is called once per frame by the IRQ handler
tbActiveLayout = _inactiveLayout-2
tbTempLayout !byte 0,0,0,0,0
tbFrameSync = *
   jsr dispStatline
   ;restore layout settings overridden in dispStatline
   ldy #4
   ldx #toolUserColor
-  lda sys_zp_bkup,x
   sta $00,x
   inx
   dey
   bpl -
   jsr _inactiveLayout
   _inactiveLayout = *
   rts

;** these four fields MUST be retained between dos.app restarts
shellRedirectStdin  !byte 0
shellRedirectStdout !byte 0
shellRedirectStderr !byte 0
inputFd             !byte 0

!if *>aceToolAddress {
   !error "Toolbox exceeds maximum address ", aceToolAddress
} else {
   * = aceToolAddress
}
aceToolboxEnd = *


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