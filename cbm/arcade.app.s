;idunc: generated file ! DO NOT MODIFY !
!source "sys/toolbox.asm"
!source "sys/toolhead.asm"

__mailbox = $9b   ;(2)
__work    = $9d   ;(2)

jmp idunAppInit

;jump table for mailbox message handlers
__m8_jmptbl = *-1
jmp __m8_viceemu_handler
jmp m8_results_handler
jmp m8_inform_handler
jmp m8_programs_handler
jmp m8_launch_handler

;mailbox reset
__m8_mailbox_reset = *  ;( .A=return_code)
   ;reset message is return_code + mailbox_id
   sta __mb_reset_msgbuf
   lda __mailbox
   sta __mb_reset_msgbuf+1
   lda __mailbox+1
   sta __mb_reset_msgbuf+2
   ;send
   lda #<__mb_reset_msgbuf
   ldy #>__mb_reset_msgbuf
   ldx #3
   jsr aceTtyPut
   ;clear mailbox
   lda #0
   sta __mailbox
   sta __mailbox+1
   rts
__mb_reset_msgbuf !byte 0,0,0

;mailbox message handlers
__m8_viceemu_handler = *
   jsr aceViceEmuCheck
   bne +
   lda #1
   jmp __m8_mailbox_reset
+  lda #0
   jmp __m8_mailbox_reset

;send event interface
m8_send_event = *
   stx __m8_app_event+0
   sty __m8_app_event+1
   sta __m8_app_event+2
   lda #<__m8_app_event
	ldy #>__m8_app_event
	ldx #3
	jmp aceTtyPut
__m8_app_event !byte 0,0,0

;wait on a mailbox message
m8_wait_mailbox = *     ;.AY = mailbox
   cmp __mailbox
   bne m8_wait_mailbox
   cpy __mailbox+1
   bne m8_wait_mailbox
   jmp m8_handle_message

!source "arcade.app.d/defs.asm"
!source "arcade.app.d/results.m8x"
!source "arcade.app.d/inform.m8x"
!source "arcade.app.d/programs.m8x"
!source "arcade.app.d/launch.m8x"

idunAppInit = *
   lda #0
   sta __mailbox
   sta __mailbox+1
   ;get app filename
   ldy #0
   jsr getarg
   lda zp
   ldy zp+1
   sta __work
   sty __work+1
!ifdef TOOLBAR {
   jsr ToolwinInit
   ;set toolbar title
   lda __work
   ldy __work+1
   jsr toolStatTitle
   ;set popup menu
   lda #<__idun_main_menu
   ldy #>__idun_main_menu
   jsr toolStatMenu
   jsr __app_init
   jmp __lua_init
;__idun_main_menu = *
__idun_main_menu !word 0
} else {
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
   lda #FALSE
   jsr toolStatEnable
   lda #<tbIrqHandler
   ldy #>tbIrqHandler
   jsr aceIrqHook
   lda #$c0
   ldx #$20
   ldy toolWinPalette+0
   jsr aceWinCls
   jsr __app_init
}

__lua_init = *
   ;launch lua script
   lda #<luaPath
   ldy #>luaPath
   sta zp
   sty zp+1
   lda #"W"
   jsr open
   bcc __lua_start
   rts
__lua_start = *
   lda $d020
   pha
   lda $d021
   pha
-  inc $d020
   lda __mailbox
   ora __mailbox+1
   beq -
   pla
   sta $d021
   pla
   sta $d020
__forever = *
   ;main application loop
   lda __mailbox
   ora __mailbox+1
   beq +
   jsr m8_handle_message
   jmp +
   m8_handle_message = *
   lda #<__m8_jmptbl
   clc
   adc __mailbox
   sta mb_handler_addr+0
   lda #>__m8_jmptbl
   adc __mailbox+1
   sta mb_handler_addr+1
   mb_handler_addr = *+1
   jmp __m8_jmptbl
+  jsr __app_runloop
   jmp __forever

luaPath !pet "l:"
APPNAME !pet "arcade.app"
luaDirs !pet ".d/main.lua",0

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

!source "arcade.app.d/app.asm"
__app_init = appInitialize
__app_runloop = appRunLoop

bssAppEnd = *
