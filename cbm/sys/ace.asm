; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)
;
; Idun Kernel is the first binary that gets loaded and 
; provides the device drivers and API's for use by Idun
; tools and applications, such as the Shell.

;* system zero-page memory usage:
;*   $02-$7f = application work area
;*   $80-$8f = system work area
;*   $f8-$ff = system parameter area

;* regular RAM0 organization
;*   $0100-$01ff = processor stack (0.25K)
;*   $0200-$0eff = system storage (3.25K)
;*   $0f00-$0fff = kernel-interface variables (0.25K)
;*   $1000-$12ff = system storage / free on the C64 (0.75K)
;*   $1300-$6fff = ACE kernel and device drivers (23.25K)
;*   $7000-$bfff = application area & stack (20K / configurable size)
;*   $c000-$eeff = free memory (11.25K)
;*   $ef00-$efff = modem transmit buffer (0.25K)
;*   $f000-$f7ff = regular character set (2K)
;*   $f800-$fbff = vic 40-column screen (1K)
;*   $fc00-$feff = free memory (0.75K)
;*   $ff00-$ffff = system storage (0.25K)

;* high-RAM0 organization for C64 with soft-80 screen configured:
;*   $c000-$c2ff = free memory (0.75K)
;*   $c300-$c3ff = modem transmit buffer (0.25K)
;*   $c400-$cbff = soft-80 char storage (2K)
;*   $cc00-$cfff = vic 40-column screen (1K)
;*   $d000-$d7ff = regular character set (2K)
;*   $d800-$dfff = soft-80 4-bit character set (2K)
;*   $e000-$ff3f = bitmapped screen (7.81K)
;*   $ff40-$ffff = system storage (0.19K)

;*** Essential header files
!source "sys/acehead.asm"
!source "sys/kernhead.asm"
!source "sys/acemacro.asm"

!if computer-64 {
   useC128 = 1
   useC64  = 0
   useVdc  = 1
   useVic  = 1
   useSoft80 = 0  ;;can't use on C128
   useExtKeyboard = 1
   useFastClock = 1
} else {
   useC64  = 1
   useC128 = 0 ;no
   useVdc  = 0
   useVic  = 1
   useSoft80 = 0
   useExtKeyboard = 0
   useFastClock = 0 ;don't use--crashes on C64
}

;*** Start of kernel code
* = $1300
jmp entryPoint

;***jump table

jmp kernFileOpen
jmp kernFileClose
jmp kernFileRead
jmp kernFileWrite
jmp kernFileLseek
jmp kernFileBload
jmp kernFileRemove
jmp kernFileRename
jmp kernFileInfo
jmp kernFileIoctl
jmp notImp  ;kernFileSelect
jmp notImp  ;kernFileBlock

jmp kernDirOpen
jmp kernDirClose
jmp kernDirRead
jmp kernDirIsdir
jmp kernDirChange
jmp kernDirMake
jmp kernDirRemove
jmp kernDirName

jmp kernWinScreen
jmp kernWinMax
jmp kernWinSet
jmp kernWinSize
jmp kernWinCls
jmp kernWinPos
jmp kernWinPut
jmp kernWinGet
jmp kernWinScroll
jmp kernWinCursor
jmp kernWinPalette
jmp kernWinChrset
jmp kernWinOption

jmp kernConWrite
jmp kernConPutlit
jmp kernConPos
jmp kernConGetpos
jmp kernConInput
jmp kernConStopkey
jmp kernConGetkey
jmp kernConKeyAvail
jmp kernConKeyMat
jmp kernConMouse
jmp kernConJoystick
jmp kernConOption
jmp kernConGamepad
jmp kernGrExit
jmp kernConDebugLog
jmp kernHashTag

jmp kernProcExec
jmp kernProcExecSub
jmp kernProcExit

jmp kernMemZpload
jmp kernMemZpstore
jmp kernMemFetch
jmp kernMemStash
jmp kernMemAlloc
jmp kernMemFree
jmp kernMemStat

jmp kernTimeGetDate
jmp kernTimeSetDate
jmp kernIrqHook

jmp kernMiscUtoa
jmp kernMiscIoPeek
jmp kernMiscIoPoke

jmp kernFileFdswap
jmp kernConRead
jmp kernConPutchar
jmp kernConPutctrl
jmp kernConSetHotkeys
jmp kernModemAvail
jmp kernModemGet
jmp kernModemPut
jmp kernTagAlloc
jmp kernTagStash
jmp kernTagFetch
jmp kernTagRealloc
jmp kernMiscSysType
jmp kernMiscRobokey
jmp kernMountImage
jmp kernMiscDeviceInfo
jmp kernCopyHost
jmp kernRestart
jmp kernMapperCommand
jmp kernMapperProcmsg
jmp kernWinGrChrPut
jmp kernDirectRead
jmp kernDirectWrite
jmp kernViceEmuCheck
jmp kernSearchPath

!byte $ff,$fe,$3c,$e2,$fc

;***global declarations

maxZpUse     = $90
stringBuffer = $400  ;(256 bytes)
keylineBuf   = $500  ;(256 bytes)
fileinfoTable= $600  ;(256 bytes)
tagMemTable  = $700  ;(256 bytes)
freemap      = $800  ;(256 bytes)
ram0FreeMap  = $900  ;(256 bytes)
aceSharedBuf = $b00  ;(256 bytes)
configBuf    = $c00  ;(256 bytes)
ESP          = $d00  ;(512 bytes)
funkeyDef    = $1000 ;(256 bytes) user programmed "hotkey" defs

!if useC128 {
   unusedMem = $1100 ;unused (512 bytes)- usually C128 BASIC work area
   bkACE = $0e
   bkApp = $0e
   bkRam0 = $3f
   bkRam0io = $3e
   bkKernel = $00
   bkCharset = $0f
   bkExtrom = %00001010 ; Bank in Kernal ROM
                        ; BIT 0   : $D000-$DFFF (0 = I/O Block)
                        ; BIT 1   : $4000-$7FFF (1 = RAM)
                        ; BIT 2/3 : $8000-$BFFF (10 = External ROM)
                        ; BIT 4/5 : $C000-$CFFF/$E000-$FFFF (00 = Kernal ROM)
                        ; BIT 6/7 : RAM used. (00 = RAM 0)
   bkSelect = $ff00
   kernelIrqHandler = $fa65
   kernelBrkHandler = $b003
   kernelNmiHandler = $fa40
   kernelStopHandler = $f66e
   nmiRedirect = $318
   nmiExit = $ff33
   CHRGET = $380
} else {
   unusedMem = $1100 ;unused (512 bytes)
   basicZpSave  = $a00  ;("maxZpUse" bytes ($90))
   bkSelect = $01
   bkACE = $36
   bkApp = $36
   bkRam0 = $30
   bkRam0io = $35
   bkKernel = $37
   bkCharset = bkRam0
   bkExtrom = $37
   kernelIrqHandler = $ea31
   kernelBrkHandler = $fe66
   kernelNmiHandler = $fe47
   kernelStopHandler = $f6ed
   CHRGET = $73
}

vic   = $d000
vdc   = $d600
sid   = $d400
cia1  = $dc00
cia2  = $dd00
st    = $90
true  = $ff
false = $00
chrQuote = $22
scpuHwOn  = $d07e
scpuHwOff = $d07f
scpuMrMode = $d0b4
scpuMrAll = $d077 ;mirror all
scpuMrOff = $d076 ;mirror only BASIC screen

fcbCount = 16
lftable   =$f00
devtable  =$f10
satable   =$f20
eoftable  =$f30
pidtable  =$f40
lfnull = $ff
cmdlf  = 66
fcbNull = $ff
minDisk = 8
regsave !fill 3,0

newlf !byte 0

kernelClall  = $ffe7
kernelSetbnk = $ff68
kernelSetmsg = $ff90
kernelReadst = $ffb7
kernelSetlfs = $ffba
kernelSetnam = $ffbd
kernelOpen   = $ffc0
!if useC128 {
kernelClose  = $ffc3
}
kernelChkin  = $ffc6
kernelChkout = $ffc9
kernelClrchn = $ffcc
kernelChrin  = $ffcf
kernelChrout = $ffd2
kernelLoad   = $ffd5
kernelStop   = $ffe1
kernelGetin  = $ffe4
kernelScrorg = $ffed
kernelSwapper = $ff5f
kernelRestor = $ff8a

notImp = *
   lda #aceErrNotImplemented
   sta errno
   sec
   rts

!if useC64 {
;*** kernel close with pseudo-close for disk command channel for the 64
kernelClose = *
   bcs +
   jmp $ffc3
+  ldx $98
-  dex
   bmi kernelCloseExit
   cmp $259,x
   bne -
   beq +
   brk
   ;** found entry; copy last entry on top if it
+  ldy $98
   dey
   lda $259,y   ;move lfn
   sta $259,x
   lda $263,y   ;move dev num
   sta $263,x
   lda $26d,y   ;move sec addr
   sta $26d,x
   dec $98
   kernelCloseExit = *
   clc
   rts
}

;*** entrypoint()

entryPoint = *
   ;After bootstrapping from ROM code, this
   ;code disables the EXROM soft-switch; causes
   ;ROM bootstrap code to be replaced with NMI
   ;handler code (dynamically loaded).
   lda #bkExtrom
   sta bkSelect
   lda #0
   pha
   plp
   sta $de7e
!if useFastClock {
   ldx vic+$30
   sta vic+$30
}
   lda $81ff
   lda $8000
!if useFastClock {
   stx vic+$30
}
   jsr kernelRestor
   ;remove wedge
   lda #$e6
   sta CHRGET+0
!if useC128 {
   lda #$3d
} else {
   lda #$7a
}
   sta CHRGET+1
   lda #$d0
   sta CHRGET+2
   ;start ace
   lda #bkACE
   sta bkSelect
   jmp main

;*** startup()

aceBootstrap = *
   php
   sei
   ldx #2
-  lda $00,x
   sta basicZpSave,x
   lda #0
   sta $00,x
   inx
   cpx #maxZpUse
   bcc -
   lda #%01111111
   sta $dc0d
   lda #%01111111
   sta $dd0d
   bit $dc0d
   bit $dd0d
   lda #%00000000
   sta vic+$1a
   lda #<irqHandler
   ldy #>irqHandler
   sta $314
   sty $315
   lda #<brkHandler
   ldy #>brkHandler
   sta $316
   sty $317
   lda #<nmiHandler
   ldy #>nmiHandler
   sta $318
   sty $319
;   lda #<stopHandler
;   ldy #>stopHandler
;   sta $328
;   sty $329
   lda #<nmiContinue
   ldy #>nmiContinue
   sta nmiRedirect+0   ;redundant on C128
   sty nmiRedirect+1
   lda aceSuperCpuFlag
   pha
   ldx #127
   lda #0
-  sta errno,x
   dex
   bpl -
   pla
   sta aceSuperCpuFlag
   lda #$68  ;"z:"
   sta aceCurrentDevice
   lda #0
   jsr kernelSetmsg
!if useC128 {
   lda #0
   ldx #0
   jsr kernelSetbnk
}
   jsr kernelClall
   lda vic+$20
   sta colorSave+0
   lda vic+$21
   sta colorSave+1
   plp
   rts
colorSave !fill 4,0

aceConfig = *
   ; IDUN: Config "app" now built-in at kernel startup.
   lda #<configBuf
   ldy #>configBuf
   sta 2
   sty 3
   lda #<ram0FreeMap
   ldy #>ram0FreeMap
   sta 6
   sty 7
   ldx #>aceBssEnd
   lda #<aceBssEnd
   beq +
   inx
+  stx 8
!if useC128 {
   lda #128
} else {
   lda #64
}
   sta 9
   lda #<charset4bit
   ldy #>charset4bit
   sta 10
   sty 11
   lda #<conKeymapNormal
   ldy #>conKeymapNormal
   sta 12
   sty 13
   lda #$00
!if useVdc {
   ora #$80
}
!if useVic {
   ora #$40
}
!if useSoft80 {
   ora #$20
}
   sta 14
   jsr configMain
   rts

aceStartup = *
   lda #<kernHookIrqNone
   ldy #>kernHookIrqNone
   jsr kernIrqHook
   ldx #fcbCount-1
-  lda #lfnull
   sta lftable,x
   lda #0
   sta devtable,x
   sta satable,x
   sta eoftable,x
   sta pidtable,x
   dex
   bpl -
   lda #0
   sta newlf
   jsr initStack
   lda aceCurrentDevice
   lsr
   lsr
   ora #$40
   sta aceCurDirName+0
   +ldaSCII ":"
   sta aceCurDirName+1
   lda #0
   sta aceCurDirName+2
   lda #1
   sta aceProcessID
   jmp pidCloseall

initStack = *
   lda #0
   ldy aceTpaLimit
   sta aceStackTop+0
   sty aceStackTop+1
   sta aceMemTop+0
   sty aceMemTop+1
   sta aceFramePtr+0
   sty aceFramePtr+1
   rts

;*** shutdown()

kernShutdownSystem = *
   ;** shut down the screens
   lda #25
   ldx #0
   jsr kernWinScreen
   jsr winShutdown
   ;** shutdown system
aceShutdown = *
   lda #bkACE
   sta bkSelect
   ldx #2
-  lda basicZpSave,x
   sta $00,x
   inx
   cpx #maxZpUse
   bcc -
   php
   sei
   lda #<kernelIrqHandler
   ldy #>kernelIrqHandler
   sta $314
   sty $315
   lda #<kernelBrkHandler
   ldy #>kernelBrkHandler
   sta $316
   sty $317
   lda #<kernelStopHandler
   ldy #>kernelStopHandler
   sta $328
   sty $329
   cli
!if useC128 {
   lda #%01111111
   sta $dc0d
   lda #%01111111
   sta $dd0d
   bit $dc0d
   bit $dd0d
   lda #%00000001
   sta vic+$1a
} else {
   lda #%10000001
   sta $dc0d
   lda #%01111111
   sta $dd0d
   bit $dc0d
   bit $dd0d
   lda #%00000000
   sta vic+$1a
}
   lda colorSave+0
   sta vic+$20
   lda colorSave+1
   sta vic+$21
   plp
   rts

resetIntDispatch = *  ;for C64 only, RAM0
   ldx #$ff
   sei
   txs
   cld
   lda #bkKernel
   sta bkSelect
   jmp $fce2

nmiIntDispatch = *  ;for C64 only, RAM0, replica of ROM
   sei
   jmp ($318)

nmiHandler = *
!if useC64 {
   cld            ;This code gives the C64 and C128 the same
   pha            ;semantics and the same number of cycles
   txa            ;of NMI dispatching overhead (including
   pha            ;the return).  Although, the C128 is in
   tya            ;its Kernal bank when entering, and the
   pha            ;C64 is in bkACE.
   lda bkSelect
   pha
   lda #bkACE
   sta bkSelect
   nmiRedirect = *+1
   jmp nmiContinue
}
nmiContinue = *
   cld               ;2
!if useC128 {
   lda #$7f          ;2
   sta $dd0d         ;4
   ldy $dd0d         ;4
   bmi +             ;3
   lda #$7f
   sta $dc00
   lda $ff
   sta $d02f
-  lda $dc01
   cmp $dc01
   bne -
   and #$80
   bmi +
   ;STOP-RESTORE restart the shell
   jmp nmiStopRestore
} else {
   lda #$7f
   sta $dd0d
   ldy $dd0d
   bmi +
   lda #$7f
   sta $dc00
-  lda $dc01
   cmp $dc01
   bne -
   and #$80
   bmi +
   ;STOP-RESTORE restart the shell
   jmp nmiStopRestore
}
+  jmp nmiExit
   nmiStopRestore = *
   sei
   ldx #$ff
   txs
   lda #0
   sta zp
   sta zp+1
   lda #bkACE
   sta bkSelect
   lda #aceRestartApplReset
   cli
   jmp kernRestart

!if useC64 {
nmiExit = *
   pla            ;4
   sta bkSelect   ;4
   pla            ;4
   tay            ;2
   pla            ;4
   tax            ;2
   pla            ;4
   rti            ;6
}

;C128 NMI overhead=76 cycles: int=7, maxLatency=6, ROMenter=33, ROMexit=30
;C64  NMI overhead=76 cycles: int=7, maxLatency=6, ROMenter=34, ROMexit=29

aceIrqInit = *
   php
   sei
!if useC64 {
   ldx #5
-  lda c64IntVecs,x
   sta $fffa,x
   dex
   bpl -
}
   lda #<irqHandler
   ldy #>irqHandler
   sta $314
   sty $315
   ;use the VIC raster interrupt as the timer
   lda vic+$11
   and #$7f
   sta vic+$11
   lda #252
   sta vic+$12
   plp
   rts

c64IntVecs = *
   !word nmiIntDispatch,resetIntDispatch,irqIntDispatch

irqIntDispatch = *  ;for C64 only, RAM0
   pha
   txa
   pha
   tya
   pha
   lda bkSelect
   pha
   lda #bkKernel
   sta bkSelect
   cld
   tsx
   lda $0105,x
   and #$10
   beq irqHandlerInt64
   jmp brkHandler

irqHandler = *  ;(.AXY already saved, 128 bank)
   cld
!if useC128 {
} else {
   lda bkSelect
   pha
}
   irqHandlerInt64 = *
   lda #bkACE
   sta bkSelect
   lda vic+$19
   bpl +
   and #$01
   beq +
   sta vic+$19
   jmp sixty
+  jmp irqExit

sixty = *
   jsr winIrqCursor
   jsr conIrqKeyscan
   irqHookRoutine = *
   jsr kernHookIrqNone
   jmp irqExit
;dummy Irq that gets overridden by calling aceIrqHook
kernHookIrqNone = *
   rts
!if useC128 {
irqExit = $ff33
} else {
irqExit = *
   pla
   sta bkSelect
   pla
   tay
   pla
   tax
   pla
   rti
}

;***aceIrqHook (.AY=<hook>)
kernIrqHook = *
   sei
   sta irqHookRoutine+1
   sty irqHookRoutine+2
   cli
   rts

brkHandler = *
   cld
   ldx #0
-  lda $00,x
   sta $0400,x
   dex
   bne -
   jsr kernShutdownSystem
!if useC128 {
   lda #0
   sta $1c00
   jsr $51d6
} else {
   lda #0
   sta $800
   jsr $a642
}
   jmp kernelBrkHandler

;These drivers in lower memory space
!source "sys/acecall.asm"
!source "idun-io.asm"

aceExitBasic = *
   lda #<kernelNmiHandler
   ldy #>kernelNmiHandler
   sta $318
   sty $319
   ;** return to basic
   ldx #0
   lda #$20
-  sta $400+000,x
   sta $400+250,x
   sta $400+500,x
   sta $400+750,x
   inx
   cpx #250
   bcc -
   lda #147
   jsr kernelChrout  ;CLS
   lda #bkKernel
   sta bkSelect      ;default mem config
!if useC128 {
   lda #0
   sta $f8
   sta $f9     ;edit flags
   lda #$14
   sta 2604
   sta $d018   ;VIC-II char base
   jsr $ff84   ;kernal IOINIT
   jsr $ff81   ;kernal CINT
   lda #0
   sta 208     ;empty the key buffer
   jsr $4251   ;init_vectors
   jsr $4045   ;init_storage- init charget & z-page
   jmp ($a00)
} else {
   lda #0
   sta $800
   sta 198
   jsr $a642
   jmp $a474
}
   brk

; bkACE
!source "sys/acemem.asm"
!source "sys/acetag.asm"
!source "sys/acewin.asm"
!if useVdc {
   !source "sys/acevdc.asm"
}
!if useVic {
aceVicColorOff !byte $b8
   !source "sys/acevic.asm"
}
   charset4bit  = $d800
!if useSoft80 {
   !source "sys/acesoft80.asm"
}
!source "sys/acecon.asm"
; Replace the local RAM drive with RPi virtual drive
!source "sys/acepid.asm"
; Access additional RPi I/O services
!source "sys/acepiserv.asm"

;*** main()

bootDevice !byte 0

main = *
   lda 186
   sta bootDevice
   lda #147
   jsr kernelChrout
   lda #14
   jsr kernelChrout
   ldx #$00
   lda $d0bc
   and #$80
   bne +
   ldx #$ff
+  stx aceSuperCpuFlag
   bit aceSuperCpuFlag
   bpl +
   sta scpuHwOn
   sta $d07b ;select 20 MHz
   sta scpuMrAll
   sta scpuHwOff
+  sei
   jsr aceBootstrap
   jsr initMemory
   ; IDUN: Init syswork vars to 0 to prevent weird side-effects
   ldy #0
   lda #0
-  sta syswork,y
   iny
   cpy #16
   bmi -
   ; IDUN: Must init RPi I/O before aceConfig since the config
   ; code will access I: and T: devices.
   jsr pidInit
   jsr aceConfig
   bcc +
   jmp configErrMainExit
+  jsr aceIrqInit
   ; IDUN: pidInit once more to ensure fileinfotable zero'd
   jsr pidInit
   jsr aceStartup
   bit aceSuperCpuFlag
   bpl +
   sta scpuHwOn
   sta scpuMrOff
   sta scpuHwOff
+  jsr initMemoryAlloc
   sei
   jsr winStartup
   jsr conInit
   ; IDUN: Init tables for function keys and tagmem
   lda #0
   ldx #0
-  sta tagMemTable,x
   sta funkeyDef,x
   inx
   bne -
   lda #$01
   sta vic+$1a     ;enable VIC raster IRQ
   cli
   lda #<charsetBuf
   ldx #>charsetBuf
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
+  sta syswork+0
   stx syswork+1
   lda #%11100000
   cpy #$00
   beq +
   ora #%00010000
+  ldx #$00
   ldy #40
   jsr kernWinChrset
   clc
   lda syswork+0
   adc #40
   sta syswork+0
   bcc +
   inc syswork+1
+  lda #%10001010
   ldx #$00
   ldy #0
   jsr kernWinChrset
!if useSoft80 {
   clc
   lda syswork+1
   adc #>2048
   sta syswork+1
   lda #%10000110
   ldx #$00
   ldy #0
   jsr kernWinChrset
}
   jsr openStdio
   cli
   ;** start designated main application/shell
   jsr shellApp
callApplication = *
   lda aceMemTop+0
   ldy aceMemTop+1
   sec
   sbc startupArgsLength
   bcs +
   dey
+  sta zw+0
   sty zw+1
   ldy startupArgsLength
   dey
-  lda startupArgs,y 
   sta (zw),y
   dey
   bpl -
   ldy #0
   lda zw
   clc
   adc #4
   sta (zw),y
   iny
   lda zw+1
   sta (zw),y
   iny 
   lda #0
   sta (zw),y
   iny
   sta (zw),y
   lda #1
   ldy #0
   jsr internProcExec
   pha
   ;close stdio files
   lda #stdin
   jsr internClose
   lda #stdout
   jsr internClose
   lda #stderr
   jsr internClose
   pla
   bmi doExit
   ldx #0
   lda #aceRestartExitBasic
doExit = *
   jmp kernRestart
configErrMainExit = *
   lda bootDevice
   sta 186
   ldx #0
   lda #aceRestartExitBasic
   ;** falls through to kernRestart

;=== aceRestart ===

;*** aceRestart (.A=flag,.X=device,(zp)=appname) : no RTS!
;    This call does not return to the caller!
kernRestart = *
+  cmp #aceRestartWarmReset
   bne +
   jmp ($fffc)       ;soft machine reset
+  cmp #aceRestartApplReset
   bne restartCont
   ;unwind any active apps
   ldx #$ff
   txs
   jsr aceStartup
   ;setup name and args for appl restart
   lda zp
   ldy zp+1
   bne +
   ;no appl name, so just reload prior shell
   lda shellName+0
   ldy shellName+1
+  jsr startupApp
   jsr openStdio
   jmp callApplication
   restartCont = *
   cmp #aceRestartExitBasic
   bne +
   jsr kernShutdownSystem
   jmp aceExitBasic
   ;Program Loader
   ;self-modifying code below sets native or mmap load
+  cpx #1
   bne +
!if useC128 {
   lda #1      ;native IEC device loading
} else {
   lda #65
}
   sta setparam+1
   lda #$0c
   sta romjmp+1
   jmp viceCheck
!if useC128 {
+  lda #2      ;Mmap device loading
} else {
+  lda #66
}
   sta setparam+1
   lda #$09
   sta romjmp+1
viceCheck:
   jsr kernViceEmuCheck
   beq viceemu
   jsr kernShutdownSystem
   ;For Idun hardware, use aceMapperCommand to invoke
   ;an NMI that will handle loading
   ldx #0      ;CMD_SYS_LOADER
   setparam = *
   lda #1      ;parameter=1 (iec) or 2 (mmap)
   jsr kernMapperCommand
-  nop         ;wait for NMI
   jmp -
viceemu:
   ;*** Not supported in emulator ***
   jsr kernShutdownSystem
   jmp aceExitBasic
   romjmp = *
   jmp $8009    ;into rom code

kernViceEmuCheck = *    ;() : .ZS=emulator detected
   lda $de02   ;read handled in Vice Idun support code
   cmp #$9b    ;flag == ~$64 :)
   rts

shellApp = *
   lda #<configBuf+$d0    ;configured dos app
   ldy #>configBuf+$d0
   sta shellName+0
   sty shellName+1
startupApp = *
   sta zp
   sty zp+1
   ldx #5
   ldy #0
-  lda (zp),y
   sta startupName,y
   beq +
   iny
   inx
   jmp -
+  stx startupArgsLength
   rts
startupArgsLength !byte 0
startupArgs: !byte 0,0,0,0
startupName: !fill 25,0
shellName: !word 0

openStdio = *
   ;** preserve .zp
   lda zp
   sta syswork+8
   lda zp+1
   sta syswork+9
   ;** open std files
   lda #<stdinName
   ldy #>stdinName
   sta zp+0
   sty zp+1
   +ldaSCII "r"
   jsr internOpen  ;fcb=0
   lda #<stdoutName
   ldy #>stdoutName
   sta zp
   sty zp+1
   +ldaSCII "w"
   jsr internOpen   ;fcb=1
   +ldaSCII "w"
   jsr internOpen   ;fcb=2
   lda syswork+8
   sta zp
   lda syswork+9
   sta zp+1
   rts

stdoutName !pet "s:"
           !byte 0
stdinName  !pet "k:"
           !byte 0

;*** bss: c128=144 bytes, c64=0 bytes

aceBss = *
!if useC128 {
   basicZpSave  = aceBss+0        ;("maxZpUse" bytes)
   aceBssEnd    = basicZpSave+maxZpUse
} else {
   aceBssEnd    = aceBss+0
}

!if aceBssEnd>aceAppAddress {
   !error "Kernel exceeds maximum address ",aceAppAddress, " by ", *-aceAppAddress, " bytes."
}


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