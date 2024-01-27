;idunc: generated file ! DO NOT MODIFY !
!source "sys/toolbox.asm"

__mailbox    = $9b   ;(2)
__work       = $9d   ;(2)
__luaFd      = $02   ;(1)

jmp idunAppInit

;jump table for mailbox message handlers
__m8_jmptbl = *-1
jmp __m8_viceemu_handler
jmp m8_drawit_handler

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
   
!source "mandelbrot.app.d/drawit.m8x"

idunAppInit = *
   lda #0
   sta __mailbox
   sta __mailbox+1
   ;get app filename
   ldy #0
   jsr __getarg
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
__idun_main_menu = *
} else {
   lda #FALSE
   jsr toolStatEnable
   jsr aceWinMax
   jsr aceWinSize
   lda #$c0
   ldx #$20
   ldy toolWinPalette+0
   jsr aceWinCls
   jsr __app_init
}

__lua_init = *
   ;build lua script path
   ldy #255
-  iny 
   lda (__work),y
   sta __luaProg,y
   bne -
   ldx #255
   dey
-  inx
   iny
   lda __luaDirs,x
   sta __luaProg,y
   bne -
   ;launch lua script
   lda #<luaPath
   ldy #>luaPath
   sta zp
   sty zp+1
   lda #"W"
   jsr open
   sta __luaFd
   bcc __forever
   rts
__forever = *
   ;main application loop
   lda __mailbox
   ora __mailbox+1
   beq +
   ;handle message
   lda #<__m8_jmptbl
   clc
   adc __mailbox
   sta mb_handler_addr+0
   lda #>__m8_jmptbl
   adc __mailbox+1
   sta mb_handler_addr+1
   mb_handler_addr = *+1
   jsr __m8_jmptbl
+  jsr __app_runloop
   jmp __forever

luaPath !pet "l:"
__luaProg !fill 32,0
__luaDirs !pet ".d/main.lua",0

__getarg = *
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
   
!source "toolx/vdc/core.asm"
!source "toolx/vdc/pointer.asm"
!source "mandelbrot.app.d/app.asm"
__app_init = appInitialize
__app_runloop = appRunLoop

bssAppEnd = *
