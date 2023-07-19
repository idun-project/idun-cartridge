;IDUNC: generated code ! DO NOT MODIFY !

;Mailbox Constants
VICEEMU_MBOX = 1
RESULTS_MBOX = 4
INFORM_MBOX  = 7
PROGRAMS_MBOX= 10
LAUNCH_MBOX  = 13
;Event Constants
TKEY                = 1 ;key input event type
ID_SEARCH           = 1 ;key input id=search
ID_HOTKEY           = 2 ;key input id=hotkey
TGADGET             = 2 ;ui gadget event type
ID_SELECT_SEARCH    = 1 ;gadget select id=search
ID_SELECT_GAME      = 2 ;gadget select id=game

;END-IDUNC: generated code

;Application definition below OK
;UI constants
RES_INTF_NUM_ROWS = 21
RES_INTF_NUM_COLS = 23
PRG_INTF_NUM_ROWS = 9
;zero-page vars
rowc 		= $02	;1
searchBoxPos= $03	;1
focusEntry	= $04	;2
endRow		= $06	;1
numProgs    = $07   ;1
