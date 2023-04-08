; Idun Browse, Copyright© 2021 Brian Holdsworth, MIT License.

;This application provides a simple full-screen app for 
;browsing the current device directory, changing to and
;browsing sub-directorines, and launching applications.

!source "sys/acehead.asm"
!source "sys/acemacro.asm"
!source "sys/toolhead.asm"

* = aceToolAddress

jmp main
!byte aceID1,aceID2,aceID3
!byte 64,0 ;*stack,reserved

; Constants
chrQuote = 34
;needs room for 16 char dirname, trailing
;asterisk, and null termination (18 chars.)
currDir: !pet ".:",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
saveDir: !fill 18,0

; Zp Vars
dirFcb 		= $2  	;(1)
currEntry  	= $3  	;(2)
focusEntry  = $5     ;(2)
moveSrc     = $7     ;(2)
moveDst     = $9     ;(2)
keyEvent    = $0b    ;(1)
currColumn  = $0c    ;(1)
maxColumns  = $0d    ;(1)
;for loading prg file
loadFd      = $15    ;(1)
loadDevType = $16    ;(1)
;for navigating into images
currDevice  = $17    ;(1)
currDevType = $18    ;(1)
focusRow    = $19    ;(1)
saveDevice  = $1a    ;(1)

ColumnIntf:
   ;Layout per column
   +toolUserIntfCol ~iColumn, 20
   lda #0
   sta toolUserStyles
	jsr toolUserNode
_node !byte 0,0          ;draw from 0,0
	;24 entries per column
_row1:
	jsr toolUserGadget        ;1
       !pet $82,"                ",$20,0
_bytes_per_entry = *-_row1
_row2:
   jsr toolUserGadget        ;2
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;3
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;4
       !pet 0,"                ",$20,0
_row5:
   jsr toolUserGadget        ;5
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;6
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;7
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;8
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;9
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;10
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;11
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;12
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;13
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;14
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;15
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;16
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;17
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;18
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;19
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;20
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;21
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;22
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;23
       !pet 0,"                ",$20,0
_row24:
   jsr toolUserGadget        ;24
       !pet 0,"                ",$20,0
	jsr toolUserEnd
   inc iColumn            ;clear redraw
	rts

;Backing store for area obscured by menus
MenuRestore = *
   lda #$40               ;vertical layout, retained
   ldx #20                ;chars wide
   jsr toolUserLayout
   lda #0
   sta toolUserStyles
   jsr toolUserNode
!byte 0,0
   ;5 entries to cover popup area
_menu_restore_buf = *
   jsr toolUserGadget        ;1
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;2
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;3
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;4
       !pet 0,"                ",$20,0
   jsr toolUserGadget        ;5
       !pet 0,"                ",$20,0
   jsr toolUserEnd
   rts
MenuBackup = *
   lda #<_menu_restore_buf
   sta moveDst+0
   ldy #>_menu_restore_buf
   sty moveDst+1
   lda #<_row1
   sta moveSrc+0
   ldy #>_row1
   sty moveSrc+1
-- ldy #3
-  lda (moveSrc),y
   sta (moveDst),y
   iny
   cpy #21
   bne -
   ldx #moveSrc
   jsr _next_menu_restore_row
   bcs +
   ldx #moveDst
   jsr _next_menu_restore_row
   jmp --
+  rts
_next_menu_restore_row = *
   lda $00,x
   cmp #<_row5
   bne +
   lda $01,x
   cmp #>_row5
   bne +
   sec
   rts
+  clc
   lda $00,x
   adc #_bytes_per_entry
   sta $00,x
   lda $01,x
   adc #0
   sta $01,x
   rts

;Popup menu for PRG
Popup1 = *
   +toolUserIntfMenu 2, 11, menu1, ~menu1_refresh_ctr, ~menu1_code
   lda #$80
   sta toolUserStyles
   lda #$22
   sta toolUserColor
   jsr toolUserNode
menu1 !byte 0,0
   jsr toolUserMenuItem
       !pet HotkeyCmd3,0,"Load    ",0
   jsr toolUserMenuItem
       !pet HotkeyCmd2,0,"Go64    ",0
   jsr toolUserEnd
   inc menu1_refresh_ctr
   rts

;Popup menu for disk image
Popup2 = *
   +toolUserIntfMenu 2, 11, menu2, ~menu2_refresh_ctr, ~menu2_code
   lda #$80
   sta toolUserStyles
   lda #$22
   sta toolUserColor
   jsr toolUserNode
menu2 !byte 0,0
   jsr toolUserMenuItem
       !pet HotkeyCmd6,0,"Mount D:",0
   jsr toolUserMenuItem
       !pet HotkeyCmd2,0,"Go64    ",0
   jsr toolUserEnd
   inc menu2_refresh_ctr
   rts

menuPopup = *
   ldy #3
   lda (focusEntry),y
   and #$07
   cmp #5
   bne +
   jsr Popup1
   lda menu1_code
   jmp menuPopupHandler
+  cmp #1
   bne +
   jsr Popup2
   lda menu2_code
   jmp menuPopupHandler
+  rts
menuPopupHandler:
   pha
   jsr MenuRestore
   jsr toolUserLayoutEnd
   jsr ColumnIntf
   pla
   cmp #HotkeyCmd2
   bne +
   jmp callGo64
+  cmp #HotkeyCmd3
   bne +
   jmp doLoadFile
+  cmp #HotkeyCmd6
   bne +
   jmp doMountImg
+  rts

; clear the window
clearScr = *
  lda #$c0
  ldx #$20
  jmp aceWinCls
	
main = *
   lda toolWinRegion+1
   cmp #80
   bne +
   ;setup for 80 columns
   lda #4
   sta maxColumns
   jmp ++
   ;setup for 40 columns
+  lda #2
   sta maxColumns
   ;setup zero page vars
++ lda #0
   sta currColumn
   sta currDevice
   sta saveDevice
   jsr clearScr
   lda #<menuPopup
   ldy #>menuPopup
   jsr toolStatMenu
   ;check for init directory arg
   ldy #0
   lda #2
   cmp aceArgc
   bne +
   lda #1
   jsr getarg
   jsr dirChangeZp
   jmp dirPause
+  jsr dirAddColumn
   jsr MenuBackup
   dirPause = *
   jsr toolUserMenuNav
   jsr toolKeysHandler
   bcc dirPause
   sta keyEvent
   cmp #HotkeyDown
   beq +
   cmp #HotkeyUp
   beq +
   cmp #HotkeyLeft
   beq select_parent
   cmp #HotkeyStop
   beq exit
   cmp #HotkeyReturn
   bne dirPause
   ;FIXME: aceCon returns keycode=$0d with shiftValue=$20
   ;when the down arrow is repeating and this app is
   ;delayed due to scrolling. Check this condition!
   cpx #0
   bne dirPause
   jsr selectEvent
   jmp dirPause
+  jsr focusEvent
   bcc dirPause
   lda dirFcb
   beq dirPause
   lda keyEvent
   cmp #HotkeyDown
   bne dirPause
   ;scroll if there are more dir entries
   ldx dirFcb
   beq dirPause
   jsr aceDirRead
   bne +
   jsr dirDone
   jmp dirPause
+  php
   jsr dirScrollDown
   plp
   jsr dirAddNext
   jmp dirPause

select_parent = *
   jsr selectEventParentDir
   jmp dirPause

exit = *
   lda dirFcb
   beq +
   jsr aceDirClose
   ;disable layout & menu
+  jsr toolUserLayoutEnd
   lda #0
   ldy #0
   jsr toolStatMenu
   jmp clearScr
fail = *
   jsr exit
   jmp aceProcExit

dirAddColumn = *
   lda #<currDir
   ldy #>currDir
   sta zp+0
   sty zp+1
   jsr aceMiscDeviceInfo
   stx currDevType
   jsr aceDirOpen
   bcc +
   jmp fail
+  sta dirFcb
   ;clear existing layout data
   jsr dirEmptyAll
   ;enable layout
   clc
   lda #0
   ldy currColumn
-  dey
   bmi +
   adc #20
   jmp -
+  sta _node
   jsr toolUserLayoutEnd
   jsr ColumnIntf
   ;first read header
   ldx dirFcb
   jsr aceDirRead
   ;set title bar from header
   lda #<aceDirentName
   ldy #>aceDirentName
   jsr toolStatTitle
   ;set header row to ".."
   lda #2
   sta _row1+3
   lda #"."
   sta _row1+4
   sta _row1+5
   ;set current and focus to row2
   lda #<_row2
   ldy #>_row2
   sta currEntry+0
   sty currEntry+1
   sta focusEntry+0
   sty focusEntry+1
   lda #$80
   ldy #3
   sta (focusEntry),y
   lda #1
   sta focusRow
   ;continue reading dir
   dirNext = *
   ldx dirFcb 
   jsr aceDirRead
   dirAddNext = *
   bcs dirDone
   beq dirDone
   lda aceDirentName+0
   beq dirDone
   lda aceDirentUsage
   and #%00010000
   bne dirNext    ;hide "hidden" entry
   jsr dirAddEntry
   dec iColumn ;set redraw
   bcc dirNext
   rts
   dirDone = *
   lda dirFcb
   jsr aceDirClose
   lda #0
   sta dirFcb
   ;fill column to bottom
   jsr dirEmptyEntries
   clc
   rts

nextRow = *
   ;check already last row
   lda $00,x
   cmp #<_row24
   bne +
   lda $01,x
   cmp #>_row24
   bne +
   sec
   rts
+  clc
   lda $00,x
   adc #_bytes_per_entry
   sta $00,x
   lda $01,x
   adc #0
   sta $01,x
   rts

focusRedraw = *
   ldy #3
   lda (focusEntry),y
   ora #$80
   sta (focusEntry),y
   and #2   ;check for dir focused
   beq +
   ldy #20
   lda #$3e
   sta (focusEntry),y
+  dec iColumn      ;set redraw
   rts

focusMoveDown = *
   ldx #focusEntry
   jsr nextRow
   php
   jsr focusRedraw
   plp
   lda focusRow
   cmp #23
   beq +
   inc focusRow
+  rts

focusMoveUp = *
   ;check top of column-
   lda focusEntry+1
   cmp #>_row1
   bne +
   lda focusEntry+0
   cmp #<_row1
   bne +
   jsr focusRedraw
   sec
   rts
+  sec
   lda focusEntry+0
   sbc #_bytes_per_entry
   sta focusEntry+0
   lda focusEntry+1
   sbc #0
   sta focusEntry+1
   jsr focusRedraw
   dec focusRow
   clc
   rts

focusEvent = *    ;(.A=event/key)
   pha 
   ;unfocus currently focused gadget
   ldy #3
   lda (focusEntry),y
   and #$7f
   sta (focusEntry),y
   ldy #20
   lda #$20
   sta (focusEntry),y
   ;uddate focus
   pla
   cmp #HotkeyDown
   bne +
   jmp focusMoveDown
+  cmp #HotkeyUp
   bne +
   jmp focusMoveUp
+  clc
   rts

dirFocusParent = *
   ldy #4
   lda (focusEntry),y
   cmp #"."
   bne +
   iny
   lda (focusEntry),y
   cmp #"."
   bne +
   sec
   rts
+  clc
   rts

dirFromSaved = *
   lda saveDevice
   sta currDevice
   sta currDir+0
   lda #":"
   sta currDir+1
   ldx #0
   ldy #2
-  lda saveDir,x
   sta currDir,y
   inx
   iny
   cpx #17
   bne -
   rts

selectEvent = *
   ;is a dir selected?
   ldy #3
   lda (focusEntry),y
   and #2
   beq _file_select
   ;was parent selected?
   jsr dirFocusParent
   bcc ++
   ;selected parent dir- clear column
   selectEventParentDir = *
   jsr dirEmptyAll
   dec currColumn
   bpl +
   lda #0
   sta currColumn
   ;reload previous (parent) dir
+  lda dirFcb
   beq +
   jsr aceDirClose
+  lda currDevice
   cmp #$1e    ; ^: device?
   beq +
   lda #$40
   jmp dirDoChange
+  jsr dirFromSaved
   jmp dirChangeCont
   ;not parent selected
   ;is there room to add column?
++ inc currColumn
   lda currColumn
   cmp maxColumns
   bne _dir_load
   ;no more room
   jsr clearScr
   lda #0
   sta currColumn
   ;change to dir
   _dir_load = *
   lda dirFcb
   beq +
   jsr aceDirClose
+  jmp dirChange
   ;menu shown for prg or image
   _file_select = *
   jmp menuPopup

dirChange = *
   ldy #20
   lda #$20
   sta (focusEntry),y
   ldx #0
   ldy #4
-  lda (focusEntry),y
   sta currDir,x
   cpx #15
   beq +
   iny
   inx
   jmp -
+  nop
-  lda currDir,x
   cmp #$20
   bne +
   lda #0
   sta currDir,x
   dex
   jmp -
+  cpx #15
   bmi dirChangeCont
   inx
   lda #"*"
   sta currDir,x
   dirChangeCont = *
   lda #<currDir
   ldy #>currDir
   sta zp+0
   sty zp+1
   dirChangeZp = *
   lda #0
   dirDoChange = *
   jsr aceDirChange
   +ldaSCII "."
   sta currDir+0
   +ldaSCII ":"
   sta currDir+1
   lda #0
   sta currDir+2
   jsr dirAddColumn
   lda currColumn
   bne +
   jsr MenuBackup
+  rts

dirScrollDown = *
   ;move _row2 and below up one
   lda #<_row1
   sta moveDst+0
   ldy #>_row1
   sty moveDst+1
   lda #<_row2
   sta moveSrc+0
   ldy #>_row2
   sty moveSrc+1
-- ldy #3
-  lda (moveSrc),y
   sta (moveDst),y
   iny
   cpy #21
   bne -
   ldx #moveSrc
   jsr nextRow
   bcs +
   ldx #moveDst
   jsr nextRow
   jmp --
   ;set unfocus for next-to-last row
+  ldy #3
   lda (moveDst),y
   and #$7f
   sta (moveDst),y
   ldy #20
   lda #$20
   sta (moveDst),y
   ;set focus for last row
   jsr focusRedraw
   lda currColumn
   bne +
   jsr MenuBackup
+  rts

dirAddEntry = *
   jsr dirGetEntryType
   ldy #3
   lda (currEntry),y
   and #$f8
   sta (currEntry),y
   txa
   ora (currEntry),y
   sta (currEntry),y
	;copy dir entry name to current row
   iny
	ldx #0
-	lda aceDirentName,x
	beq +
 	sta (currEntry),y
   inx
   iny
	cpx #16
   beq +
	jmp -
   ;pad with spaces
+  cmp #0
   bne +
   lda #$20
-  sta (currEntry),y
   inx
   iny
   cpx #16
   beq +
   jmp -
	;move pointer
+  ldx #currEntry
   jmp nextRow

dirEmptyAll = *
   lda #<_row1
   ldy #>_row1
   sta currEntry+0
   sty currEntry+1
   jmp +
dirEmptyEntries = *
   ;move pointer
   ldx #currEntry
   jsr nextRow
   bcs ++
   ;fill empty rows with blank names
+  ldy #20
   ldx #17
   lda #$20
-  sta (currEntry),y
   dey
   dex
   bmi +
   jmp -
+  jmp dirEmptyEntries
++ dec iColumn
   rts

dirGetEntryType = *  ;(aceDirent*) : .X=type
   ;type code- dir=2,prg=5,img=1,other=0
   jsr isImageFilename
   bcs ++
   ldx #1
   cpx currDevType
   bne +
   ldx #2   ;treat image file as dir for native device (sd2iec)
+  rts
++ bit aceDirentFlags
   bpl +
   ;directory
   ldx #2
   rts
+  lda aceDirentType
   +cmpASCII "p"
   bne +
   ldx #5
   rts
+  ldx #0
   rts

isImageFilename = *
   ;locate last "." in filename
   ldy #0
-  iny
   lda aceDirentName,y
   bne -
   dey
-  lda aceDirentName,y
   +cmpASCII "."
   beq +
   dey
   bne -
+  tya
   beq isNotImage    ;no "." in name
   ;check if suffix indicates an image file
+  iny
   lda aceDirentName,y
   and #$7f
   +cmpASCII "t"
   beq +
   +cmpASCII "d"
   bne isNotImage
+  ldx #0
   iny
   ;aceDirentName,y starts as first char after last "."
-  lda image_file_id,x
   beq isNotImage
   lda aceDirentName,y
   and #$7f
   cmp image_file_id,x
   beq +
   inx
   inx
   jmp -
+  inx
   iny
   lda aceDirentName,y
   and #$7f
   cmp image_file_id,x
   bne isNotImage
   clc
   rts
   isNotImage = *
   sec 
   rts
image_file_id !pet "6471",0

doLoadFile = *
   jsr getFileArg
   jsr fileIsAppl
   bcs +
   jsr startAppl
+  lda #<FileArg
   ldy #>FileArg
   sta zp+0
   sty zp+1
   +ldaSCII "r"
   jsr open
   sta loadFd
   jsr aceMiscDeviceInfo
   sta $102
   stx loadDevType
   cpx #1
   beq closeIec
   lda syswork+1
   lsr
   lsr
   ldx #255            ;CMD_STREAM_CHANNEL
   jsr aceMapperCommand
   jmp loaderRestart
   ;close Iec device only. Pid device stays open
   ;for use by the MemMapper.
   closeIec = *
   lda loadFd
   jsr close
   loaderRestart = *
   jsr toolUserLayoutEnd
   ldx loadDevType
   lda #aceRestartLoadPrg
   jmp aceRestart

   fileIsAppl = *
   ;check if name ends is .app
   ldy #0
-  lda FileArg,y
   beq +
   iny
   jmp -
+  ldx #4
-  dey
   dex
   lda FileArg,y
   cmp cmd_app_suffix,x
   bne failAppName
   cpx #0
   beq +
   jmp -
   failAppName = *
   sec
   rts
   ;check for App binary (1st 8 bytes)
+  lda #<FileArg
   sta zp+0
   lda #>FileArg
   sta zp+1
   +ldaSCII "r"
   jsr open
   bcc +
   rts
+  sta loadFd
   tax
   lda #<is_app_sign
   ldy #>is_app_sign
   sta zp
   sty zp+1
   lda #8
   ldy #0
   jsr read
   bcs failAppSign
   ldx #8
-  dex
   bmi passAppSign
   lda is_app_sign,x
   cmp aceAppAddress,x
   bne failAppSign
   jmp -
passAppSign:
   lda loadFd
   jsr close
   clc
   rts
failAppSign:
   lda loadFd
   jsr close
   sec
   rts
is_app_sign !fill 8,0
cmd_app_suffix !pet ".app"

   startAppl = *
   lda #<FileArg
   sta zp
   lda #>FileArg
   sta zp+1
   lda #aceRestartApplReset
   jmp aceRestart
FileArgLen !byte 0

   doOpenImg = *
   jsr mountImageTemp
   bcs errorMessage
   ;save current dir so we can go back
   ldx #17
   ldy #17
-  lda currDir,x
   sta saveDir,y
   dex
   dey
   bpl -
   ;change directory to "^:"
   lda #$5e
   sta currDir+0
   +ldaSCII ":"
   sta currDir+1
   lda #0
   sta currDir+2
   jmp dirChangeCont

   errorMessage = *
   lda #<mountErrorMsg
   ldy #>mountErrorMsg
   jmp toolStatTitle

   doMountImg = *
   jsr mountImageStd
   bcs errorMessage
   lda #<mountedMsg
   ldy #>mountedMsg
   jmp toolStatTitle

   getFileArg = *
   ;get filename arg length
   ldy #20
-  lda (focusEntry),y
   cmp #$20
   bne +
   dey
   jmp -
+  tya
   sec
   sbc #4
   sta FileArgLen
   ;copy filename arg
   ldx #0
   ldy #4
-  lda (focusEntry),y
   sta FileArg,x
   cpx FileArgLen
   beq +
   iny
   inx
   jmp -
+  inx
   lda #0
   sta FileArg,x
   rts

mountImageTemp = *
   ;mount image file read-only on "^:"
   lda #<tmpMountDev
   ldy #>tmpMountDev
   jmp mountImageCont
mountImageStd = *
   ;mount image file read-only on "d:"
   lda #<stdMountDev
   ldy #>stdMountDev
   mountImageCont = *
   sta zp
   sty zp+1
   jsr aceMiscDeviceInfo
   cpx #7
   beq +
   sec
   rts
+  ldy #0
   lda (zp),y
   and #$1f
   asl
   asl
   pha
   jsr getFileArg
   lda #<FileArg
   ldy #>FileArg
   sta zp+0
   sty zp+1
   jsr aceMiscDeviceInfo
   lda syswork+1
   lsr
   lsr
   sta saveDevice
   lda dirFcb
   beq +
   jsr aceDirClose
+  pla
   tax
   lda #FALSE
   jsr aceMountImage
   bcs +
   lda #$1e
   sta currDevice
+  rts
stdMountDev      !pet "d:",0
tmpMountDev      !pet "^:",0
mountErrorMsg    !pet "open image fail!",0
mountedMsg       !pet "mounted on d:   ",0

callGo64 = *
   jsr getFileArg
   jsr exit    ;below cmd call should not return
   lda #<go64Command
   ldy #>go64Command
   sta zp+0
   sty zp+1
   lda #<go64Ptrs
   ldy #>go64Ptrs
   ldx #(go64End-go64Ptrs)
   jmp toolSyscall
go64Ptrs !word (go64Command-go64Ptrs),(FileArg-go64Ptrs),$0000
go64Command !pet "go64",0
FileArg !fill 17,0
go64End = *

;******** standard library ********

putchar = *
   ldx #stdout
putc = *
   sta putcBuffer
   lda #<putcBuffer
   ldy #>putcBuffer
   sta zp+0
   sty zp+1
   lda #1
   ldy #0
   jmp write
putcBuffer !byte 0

getchar = *
   ldx #stdin
getc = *
   lda #<getcBuffer
   ldy #>getcBuffer
   sta zp+0
   sty zp+1
   lda #1
   ldy #0
   jsr read
   beq +
   lda getcBuffer
   rts
+  sec
   rts
getcBuffer !byte 0

eputs = *
   ldx #stderr
   jmp fputs
puts = *
   ldx #stdout
fputs = *
   sta zp+0
   sty zp+1
zpputs = *
   ldy #$ff
-  iny
   lda (zp),y
   bne -
   tya
   ldy #0
   jmp write

cls = *
   lda #chrCLS
   jmp putchar

getarg = *
   sty zp+1
   asl
   sta zp+0
   rol zp+1
   clc
   lda aceArgv+0
   adc zp+0
   sta zp+0
   lda aceArgv+1
   adc zp+1
   sta zp+1
   ldy #0
   lda (zp),y
   tax
   iny
   lda (zp),y
   stx zp+0
   sta zp+1
   ora zp+0
   rts

bss = *

;┌────────────────────────────────────────────────────────────────────────┐
;│                        TERMS OF USE: MIT License                       │
;├────────────────────────────────────────────────────────────────────────┤
;│ Copyright (c) 2021 Brian Holdsworth                                    │
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