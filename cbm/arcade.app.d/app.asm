;This interface shows the selectable search results
;on the left-hand side of the screen.
ResultsIntf:
	+toolUserIntfCol ~iResults, 22
	lda #0
	sta toolUserStyles
	lda #$00
	sta toolUserColor
	jsr toolUserNode
_node !byte 0,1          ;draw from 0,1
	;21 entries
_row1:
	jsr toolUserGadget        ;1
       !pet $82,"                      ",0
_bytes_per_srch_entry = *-_row1
_row2:
    jsr toolUserGadget        ;2
       !pet 0,"                      ",0
    jsr toolUserGadget        ;3
       !pet 0,"                      ",0
    jsr toolUserGadget        ;4
       !pet 0,"                      ",0
_row5:
    jsr toolUserGadget        ;5
       !pet 0,"                      ",0
    jsr toolUserGadget        ;6
       !pet 0,"                      ",0
    jsr toolUserGadget        ;7
       !pet 0,"                      ",0
    jsr toolUserGadget        ;8
       !pet 0,"                      ",0
    jsr toolUserGadget        ;9
       !pet 0,"                      ",0
    jsr toolUserGadget        ;10
       !pet 0,"                      ",0
_row11:
    jsr toolUserGadget        ;11
       !pet 0,"                      ",0
    jsr toolUserGadget        ;12
       !pet 0,"                      ",0
    jsr toolUserGadget        ;13
       !pet 0,"                      ",0
    jsr toolUserGadget        ;14
       !pet 0,"                      ",0
    jsr toolUserGadget        ;15
       !pet 0,"                      ",0
    jsr toolUserGadget        ;16
       !pet 0,"                      ",0
    jsr toolUserGadget        ;17
       !pet 0,"                      ",0
    jsr toolUserGadget        ;18
       !pet 0,"                      ",0
    jsr toolUserGadget        ;19
       !pet 0,"                      ",0
    jsr toolUserGadget        ;20
       !pet 0,"                      ",0
_row21:
    jsr toolUserGadget        ;21
       !pet 0,"                      ",0
	jsr toolUserEnd
	inc iResults            ;clear redraw
	rts

;This interface shows the selectable program list
;on the right-hand side of the screen.
ProgramsIntf:
	+toolUserIntfCol ~iPrograms, 16
	lda #0
	sta toolUserStyles
	lda #$00
	sta toolUserColor
	jsr toolUserNode
_node2 !byte 23,13			  ;draw from 23,13
	;9 entries
_prg1:
	jsr toolUserGadget        ;1
       !pet $82,"                ",0
_bytes_per_prog_entry = *-_prg1
    jsr toolUserGadget        ;2
       !pet 0,"                ",0
    jsr toolUserGadget        ;3
       !pet 0,"                ",0
    jsr toolUserGadget        ;4
       !pet 0,"                ",0
    jsr toolUserGadget        ;5
       !pet 0,"                ",0
    jsr toolUserGadget        ;6
       !pet 0,"                ",0
    jsr toolUserGadget        ;7
       !pet 0,"                ",0
    jsr toolUserGadget        ;8
       !pet 0,"                ",0
_prg9:
    jsr toolUserGadget        ;9
       !pet 0,"                ",0
	jsr toolUserEnd
	inc iPrograms            ;clear redraw
	rts

appInitialize = *
	;init vars
	lda #0
	sta rowc
	sta searchBoxPos
	lda #<_row1
	ldy #>_row1
	sta focusEntry+0
	sty focusEntry+1
	;black border/background
	lda #0
	sta $d020
	sta $d021
	;load custom character set
	lda #<chrsetBrowse
	ldy #>chrsetBrowse
	sta zp
	sty zp+1
	lda aceMemTop
	sta zw
	lda aceMemTop+1
	sta zw+1
	lda #<.charsetBuf
	ldy #>.charsetBuf
	jsr aceFileBload
	bcc +
	jmp exit
+   lda #<.charsetBuf
	ldx #>.charsetBuf
	sta syswork+0
	stx syswork+1
	ldy #5
	lda (syswork+0),y
	tay
	clc
	lda syswork+0
	adc #8
	bcc +
	inx
+   sta syswork+0
	stx syswork+1
	lda #%11100000
	cpy #$00
	beq +
	ora #%00010000
+   ldx #$00
	ldy #40
	jsr aceWinChrset
	clc
	lda syswork+0
	adc #40
	sta syswork+0
	bcc +
	inc syswork+1
+   lda #%10001010
	ldx #$00
	ldy #0
	jsr aceWinChrset
	;copy color RAM
	lda #<$d800
	ldy #>$d800
	sta zp+0		;dest
	sty zp+1
	lda #<screen_colors
	ldy #>screen_colors
	sta syswork+0	;src
	sty syswork+1
	lda #0
	sta syswork+2	;row
--	ldy #39			;col
-	lda (syswork),y
	sta (zp),y
	dey
	bpl -
	inc syswork+2
	lda syswork+2
	cmp #25
	beq +
	lda zp+0
	clc
	adc #40
	sta zp+0
	lda zp+1
	adc #0
	sta zp+1
	lda syswork+0
	clc
	adc #40
	sta syswork+0
	lda syswork+1
	adc #0
	sta syswork+1
	jmp --
	;populate screen/fields
+	lda rowc
	ldx #0
	jsr aceWinPos
	lda #40
	sta syswork+5
	lda #0
	sta syswork+6
	lda #<screen_codes
	ldy #>screen_codes
	sta syswork+2
	sty syswork+3
-	lda #$80
	ldx #40
	jsr aceWinPut
	inc rowc
	lda rowc
	cmp #25
	beq +
	ldx #0
	jsr aceWinPos
	lda syswork+2
	clc
	adc #40
	sta syswork+2
	lda syswork+3
	adc #0
	sta syswork+3
	jmp -
	;setup key handling
+	ldx #<exit
	ldy #>exit
	lda #HotkeyStop
	jsr toolKeysSet
	ldx #<prevPage
	ldy #>prevPage
	lda #HotkeyCtrlUp
	jsr toolKeysSet
	ldx #<nextPage
	ldy #>nextPage
	lda #HotkeyCtrlDown
	jsr toolKeysSet
	ldx #<getRecents
	ldy #>getRecents
	lda #HotkeyF1
	jsr toolKeysSet
	ldx #<getFavorites
	ldy #>getFavorites
	lda #HotkeyF3
	jsr toolKeysSet
	ldx #<setFavorite
	ldy #>setFavorite
	lda #HotkeyF7
	jsr toolKeysSet
	;draw UI
	jsr ResultsIntf
	jmp updateSearchBox
chrsetBrowse !pet "z:chrset-browse",0

checkSearchInput = *
	jsr aceConKeyAvail
	bcc +
	rts
+	cmp #chrBS
	bne ++
	jsr aceConGetkey
	dec searchBoxPos
	bpl +
	ldx #0
	stx searchBoxPos
+	jmp contSearchInput
++	cmp #$20
	bcs +		;check if printable ($20-$5f, $c1-$df)
	sec
	rts
+	cmp #$5f
	bcc ++
	cmp #$c1
	bcs +
	sec
	rts
+	cmp #$df
	bcc ++
	rts
++	jsr aceConGetkey
	ldx searchBoxPos
	cpx #SEARCH_FIELD_SZ
	bne +
	clc
	rts
+	sta search_box,x
	inc searchBoxPos
	contSearchInput = *
	ldx #TKEY
	ldy #ID_SEARCH
	jsr m8_send_event
	lda #<RESULTS_MBOX
	ldy #>RESULTS_MBOX
	jsr m8_wait_mailbox
	clc
	rts

updateSearchBox = *
	ldx searchBoxPos
	bne +
	lda #$20
	sta $f800+search_box-screen_codes+1
	jmp ++
+	lda #<($f800+search_box-screen_codes)
	ldy #>($f800+search_box-screen_codes)
	sta syswork+0
	sty syswork+1
	lda #<search_box
	ldy #>search_box
	sta syswork+2
	sty syswork+3
	lda #$20
	sta syswork+4
	lda #SEARCH_FIELD_SZ+1
	sta syswork+5
	lda #$c0
	ldy toolWinPalette+0
	jsr aceWinPut	;put text
++	lda #<($f800+search_box-screen_codes)
	ldy #>($f800+search_box-screen_codes)
	clc
	adc searchBoxPos
	sta syswork+0
	tya
	adc #0
	sta syswork+1
	lda #$e0
	sta syswork+4
	lda #$c0
	ldx #1
	stx syswork+5
	ldx #0
	ldy toolWinPalette+4
	jsr aceWinPut	;put cursor
	rts

getRecents = *
	lda #HotkeyF1
	jmp sendHotkey
getFavorites = *
	lda #HotkeyF3
sendHotkey = *
	ldx #TKEY
	ldy #ID_HOTKEY
	jsr m8_send_event
	lda #<RESULTS_MBOX
	ldy #>RESULTS_MBOX
	jsr m8_wait_mailbox
	rts
setFavorite = *
	lda #HotkeyF7
	ldx #TKEY
	ldy #ID_HOTKEY
	jmp m8_send_event

appRunLoop = *
	lda rowc
	bne +
	jmp resetResults
+	jsr aceConKeyAvail
	bcs ++
	jsr checkSearchInput
	bcs +
	jsr updateSearchBox
	jmp ++
+	jsr aceConGetkey
	cmp #HotkeyDown
	beq selectNext
	cmp #HotkeyUp
	beq selectPrev
	cmp #HotkeyReturn
	beq selectItem
	jsr toolKeysHandler
++	rts
	;controlling which ui gadgets are active
	select_ui_results = *
	jsr toolUserLayoutEnd
	lda #<results_next
	sta select_ui_next+0
	lda #>results_next
	sta select_ui_next+1
	lda #<results_prev
	sta select_ui_prev+0
	lda #>results_prev
	sta select_ui_prev+1
	lda #<select_result
	sta select_item+0
	lda #>select_result
	sta select_item+1
	; jsr resetResults
	ldx #<exit
	ldy #>exit
	lda #HotkeyStop
	jsr toolKeysSet
	jsr ResultsIntf
	dec iResults
	rts
	select_ui_programs = *
	jsr toolUserLayoutEnd
	jsr clearPrograms
	lda #<_prg1
	ldy #>_prg1
	sta focusEntry+0
	sty focusEntry+1
	lda #<programs_next
	sta select_ui_next+0
	lda #>programs_next
	sta select_ui_next+1
	lda #<programs_prev
	sta select_ui_prev+0
	lda #>programs_prev
	sta select_ui_prev+1
	lda #<select_program
	sta select_item+0
	lda #>select_program
	sta select_item+1
	jsr setFocus
+	ldx #<unselect_ui_programs
	ldy #>unselect_ui_programs
	lda #HotkeyStop
	jsr toolKeysSet
	jmp ProgramsIntf
	selectNext = *
	select_ui_next = *+1
	jmp results_next
	selectPrev = *
	select_ui_prev = *+1
	jmp results_prev
	selectItem = *
	select_item = * + 1
	jmp select_result

select_result = *
	ldx #TKEY
	ldy #ID_HOTKEY
	lda #HotkeyReturn
	jsr m8_send_event
	lda #<PROGRAMS_MBOX
	ldy #>PROGRAMS_MBOX
	jsr m8_wait_mailbox
	dec iPrograms
	rts

select_program = *
	ldx #TGADGET
	ldy #ID_SELECT_GAME
	lda rowc
	jsr m8_send_event
	lda #<LAUNCH_MBOX
	ldy #>LAUNCH_MBOX
	jsr m8_wait_mailbox
	rts

results_next = *
	lda rowc
	cmp endRow
	bcc ++
	cmp #RES_INTF_NUM_ROWS
	beq +
	rts
+	jmp nextPage
++	inc rowc
	jsr clearFocus
	ldx #focusEntry
	jsr nextResult
	jsr setFocus
	jmp updateInfo

results_prev = *
	dec rowc
	bne +
	jmp prevPage
+	jsr clearFocus
	ldx #focusEntry
	jsr prevResult
	jsr setFocus
	updateInfo = *
    ldx #TGADGET
	ldy #ID_SELECT_SEARCH
	lda rowc 		  ;param
	jsr m8_send_event
	lda #<INFORM_MBOX
	ldy #>INFORM_MBOX
	jsr m8_wait_mailbox
	dec iResults      ;set redraw
	rts

programs_next = *
	lda rowc
	cmp numProgs
	bcc +
	rts
+	inc rowc
	jsr clearFocus
	ldx #focusEntry
	jsr nextProgram
	jsr setFocus
	dec iPrograms		;set redraw
	rts

programs_prev = *
	dec rowc
	bne +
	inc rowc
	rts
+	jsr clearFocus
	ldx #focusEntry
	jsr prevProgram
	jsr setFocus
	dec iPrograms		;set redraw
	rts

clearFocus = *
	;unfocus currently focused gadget
	ldy #3
	lda (focusEntry),y
	and #$7f
	sta (focusEntry),y
	rts

setFocus = *
	ldy #3
	lda (focusEntry),y
	ora #$80
	sta (focusEntry),y
	rts

resetResults = *
	jsr clearAll
	lda #<_row1
	ldy #>_row1
	sta focusEntry+0
	sty focusEntry+1
	lda #1
	sta rowc
	jsr setFocus
	jmp updateInfo

nextResult = *
	;check already last row
	lda $00,x
	cmp #<_row21
	bne +
	lda $01,x
	cmp #>_row21
	bne +
	sec
	rts
+   clc
	lda $00,x
	adc #_bytes_per_srch_entry
	sta $00,x
	lda $01,x
	adc #0
	sta $01,x
	rts

nextProgram = *
	;check already last row
	lda $00,x
	cmp #<_prg9
	bne +
	lda $01,x
	cmp #>_prg9
	bne +
	sec
	rts
+   clc
	lda $00,x
	adc #_bytes_per_prog_entry
	sta $00,x
	lda $01,x
	adc #0
	sta $01,x
	rts

prevResult = *
	;check already first row
	lda $00,x
	cmp #<_row1
	bne +
	lda $01,x
	cmp #>_row1
	bne +
	sec
	rts
+   sec
	lda $00,x
	sbc #_bytes_per_srch_entry
	sta $00,x
	lda $01,x
	sbc #0
	sta $01,x
	rts

prevProgram = *
	;check already first row
	lda $00,x
	cmp #<_prg1
	bne +
	lda $01,x
	cmp #>_prg1
	bne +
	sec
	rts
+   sec
	lda $00,x
	sbc #_bytes_per_prog_entry
	sta $00,x
	lda $01,x
	sbc #0
	sta $01,x
	rts

nextPage = *
	ldx #TKEY
	ldy #ID_HOTKEY
	lda #HotkeyCtrlDown
	jsr m8_send_event
	jmp pagingCont

prevPage = *
	ldx #TKEY
	ldy #ID_HOTKEY
	lda #HotkeyCtrlUp
	jsr m8_send_event
	pagingCont = *
	lda #<RESULTS_MBOX
	ldy #>RESULTS_MBOX
	jsr m8_wait_mailbox
	rts

clearAll = *
	lda #<_row1
	ldy #>_row1
	sta focusEntry+0
	sty focusEntry+1
-	jsr clearFocus
	ldx #focusEntry
	jsr nextResult
	bcs +
	jmp -
clearPrograms = *
+	lda #<_prg1
	ldy #>_prg1
	sta focusEntry+0
	sty focusEntry+1
-	jsr clearFocus
	ldx #focusEntry
	jsr nextProgram
	bcs +
	jmp -
+	rts

exit = *
	jsr toolUserLayoutEnd
	lda #0
	sta zp
	sta zp+1
	lda #aceRestartApplReset
	jmp aceRestart

screen_codes:
	!byte	$86,$F1,$20,$D2,$45,$43,$45,$4E,$54,$20,$86,$F3,$20,$C6,$41,$56,$4F,$52,$49,$54,$45,$53,$65
info_header:
	!byte	$89,$8E,$84,$85
result_count:	
	!byte 	$98,$89,$8E,$87,$EE,$EE,$EE,$E0,$E0,$E0,$E0,$E0,$AE
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$20,$20,$20,$20,$B0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
publisher:
	!byte 	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$42,$59,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
byline1:
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
byline2:
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
byline3:
	!byte 	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
language:
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
genre:
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
controls:
	!byte 	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
trainers:
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
prgheader:
	!byte	$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$65,$93,$85,$81,$92,$83,$88,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$AE,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte 	$A0
search_box:
	SEARCH_FIELD_SZ=19
	!byte	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A0
	!byte	$A0,$86,$F7,$20,$C1,$44,$44,$20,$C6,$41,$56,$4F,$52,$49,$54,$45,$20,$A0
	!byte	$A1,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A3,$A1,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2,$A3

screen_colors:
	!byte	$03,$03,$00,$03,$03,$03,$03,$03,$03,$00,$03,$03,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$0F,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$00,$00,$03
	!byte	$0F,$0D,$0D,$0D,$0D,$0D,$0D,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0F,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	!byte	$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03

;=== bss ===
.charsetBuf = *

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