; Idun Cartridge
; Booter program & I/O Hook for the Commodore 128.

; Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
!if computer-64 {
    useC128 = 1
    useC64  = 0
    LOADADDR = $1300
    RAMR = $0f00    ; kernel hooks page
    CHRGET = $0380
    CHRGOT = $0386
    RUNMOD = $7f
    TXTPTR = $3d
    KEYBUF = $34a
    RUNR_BASE = $800
    RUNR_MAX = $850
    NDX = $d0
    basicWarmStart = $a00
    PATCH_ROM_JUMP = $e600   ;for patched ROMs
    jump_offset    = $0b
} else {
    useC128 = 0
    useC64  = 1
    LOADADDR = $c000
    RAMR = $cf00    ; kernel hooks page
    CHRGET = $73
    CHRGOT = $79
    MSGFLG = $9d
    TXTPTR = $7a
    KEYBUF = $277
    RUNR_BASE = $2a7
    RUNR_MAX = $2ff
    NDX = $c6
    basicWarmStart = $a002
    PATCH_ROM_JUMP = $f730   ;for patched ROMs
    jump_offset    = $0b
}
TXTBUF = $200
TOK_RUN = $8a
TOK_GO = $cb
; Local vars stored at the end of RAM-resident block
RAMVAR      = RAMR+$f8
temp        = RAMVAR+0  ;(2)
kernalOpen  = RAMVAR+2  ;(2)
kernalLoader= RAMVAR+4  ;(2)
kernalSaver = RAMVAR+6  ;(2)

; These parameters may be altered by booter.
; Note: $9b/$9c are used by kernal tape loader
MyDevice    = $9b       ;(1)
IdunDrive   = $9c       ;(1)

;** ROM entry points
HOOK_ROM_JUMP  = $8000   ;for EXROM
hookOpen       = jump_offset+0
hookLoad       = jump_offset+3
hookSave       = jump_offset+6
hookClose      = jump_offset+9
hookCatalog    = jump_offset+12

;** kernal vectors
ILOAD = $0330
IOPEN = $031A
ISAVE = $0332
IERROR= $0300

;** kernal entry points
kernelRESTOR    = $ff8a
kernelChrin     = $ffcf
kernelChrout    = $ffd2
kernelStop      = $ffe1
kernelSetnam    = $ffbd
kernelSetmsg    = $ff90
kernelLoad      = $ffd5
kernelOpen      = $ffc0
kernelClose     = $ffc3
kernelClrchn    = $ffcc
kernelSetlfs    = $ffba
kernelChkin     = $ffc6
kernelChkout    = $ffc9

;** kernal vars
kStatus     = $90 ; I/O status var
kVerify     = $93 ; load or verify flag
kFileaddr   = $ac
kCurraddr   = $ae
kFnlen      = $b7
kSecaddr    = $b9
kLastDevice = $ba
kFnaddr     = $bb ; address of the filename
!if useC128 {
    bkRam0              = $3f
    bkExtrom            = %00001010
    bkKernel            = $00
    bkSelect            = $ff00
    kFnbank             = $c7 ; bank of the filename stored probably 1

    kernelINDFET        = $ff74
    kernelINDSTA        = $ff77
    kernelSetbnk        = $ff68
    basicPrompt         = $4d37
    basicRun            = $af99
    basicNew            = $af84
    basicError          = $4d3f
    basicAddr           = $1c01
} else {
    bkExtrom            = $37
    bkKernel            = $37
    bkSelect            = $01
    basicPrompt         = $a474
    basicError          = $e38b     ;$a43a
    basicAddr           = $801
    basicNew            = $a642
}

;Handy macros
!macro incTXTPTR {
    inc TXTPTR
    bne +
    inc TXTPTR+1
+   nop
}
!macro decTXTPTR {
    lda TXTPTR
    bne +
    dec TXTPTR+1
+   dec TXTPTR
}

* = LOADADDR
    jmp main
configDrv !byte 3
configIec !byte 10
main = *
    jsr Install
    lda #bkKernel
    sta bkSelect
    jmp Basic
Catalog = *
    lda #"R"
    ldx #hookOpen
    jsr romcall
    ;get length of dir listing
    jsr getLoadlen
    ;read/output listing
    lda temp+1
--  beq ++
    ldy #0
-   jsr idunChIn
    bcs -
    cmp #$0d
    bne +
    jsr kernelStop
    beq +++
    lda #$0d
+   jsr kernelChrout
    dey
    bne -
    jsr talk
    dec temp+1
    beq ++
    jmp --
++  lda temp
--  beq +++
-   jsr idunChIn
    bcs -
    jsr kernelChrout
    dec temp
    jmp --
+++ ldx #hookClose
    jsr romcall
    lda #$40
    sta kStatus
    clc
    rts
getLoadlen = *
    jsr talk
-   jsr idunChIn
    bcs -
    sta temp
    lda idDataport
    sta temp+1
    rts
talk = *
    lda #$01
    bit $6c
    beq +
    lda #$5f
    jsr idunChOut
    inc $6c
+   lda IdunDrive
    ;send OPEN command
    ora #$40
    jsr idunChOut
    lda #$7e    ;Lfn=30
    jsr idunChOut
    inc $6c
    rts
ChDir = *
    ;bank in I/O
    lda bkSelect
    pha
    lda #bkExtrom
    sta bkSelect
    ;(TXTPTR),y points to dirname
    sty nameOffset
    lda (TXTPTR),y
    cmp #"."
    bne +
    ;back to configured drive?
    lda configDrv
    cmp IdunDrive
    beq ++
    sta IdunDrive
    jmp ReturnBasic
+   cmp #":"
    bne ++
    inc nameOffset
    jsr idunMount
    jmp ReturnBasic
++  jsr idunChDir
    ;fall-through
ReturnBasic = *
    ;restore bank
    pla
    sta bkSelect
    ;set status to Ok
    lda #$40
    sta kStatus
    clc
    jmp basicPrompt
idunChDir = *
    lda #"/"
    jsr idunCmdSend
    beq +
    jmp idunCmdError
+   rts
idunMount = *
    ;set kernel filename=image file
    ldy nameOffset
-   lda (TXTPTR),y
    beq +
    cmp #$22
    beq +
    iny
    jmp -
+   tya
    sec
    sbc nameOffset
    pha
    lda TXTPTR
    clc
    adc nameOffset
    tax
    lda TXTPTR+1
    adc #0
    tay 
    pla
    jsr kernelSetnam
    ;open image file
    lda #"R"
    ldx #hookOpen
    jsr romcall
    beq +
    jmp idunCmdError
    ;mount image file
+   lda IdunDrive
    sta configDrv
    lda #4
    sta IdunDrive   ;d: device
    jsr idunCmdOpen
    beq +
    jmp idunCmdError
+   lda IdunDrive
    ora #$20
    jsr idunChOut
    lda #$7f    ;Lfn=31
    jsr idunChOut
    lda #"%"
    jsr idunChOut
    lda configDrv
    clc
    adc #"@"
    jsr idunChOut
    lda #","
    jsr idunChOut
    lda #"w"        ;mount as read/write
    jsr idunChOut
    lda #0
    jsr idunChOut
    lda #$3F
    jsr idunChOut
    ;Get errno
-   jsr idunChIn
    bcs -
    pha
    ;Close command channel
    ldx #hookClose
    jsr romcall
    ;close image file
    lda IdunDrive
    pha
    lda configDrv
    sta IdunDrive
    ldx #hookClose
    jsr romcall
    pla
    sta IdunDrive
    pla
    beq +
    jmp idunCmdError
+   rts
idunCmdOpen = *
    ;send OPEN
    lda IdunDrive
    ora #$20
    jsr idunChOut
    lda #$bf    ;Lfn=31
    jsr idunChOut
    jsr sendDirname
    lda #$3F
    jsr idunChOut
    ; Get errno
-   jsr idunChIn
    bcs -
    rts
idunCmdSend = *
    ;send COMMAND
    pha
    lda IdunDrive
    ora #$20
    jsr idunChOut
    lda #$7f    ;Lfn=31
    jsr idunChOut
    pla
    jsr idunChOut
    jsr sendDirname
    lda #$3F
    jsr idunChOut
    ; Get errno
-   jsr idunChIn
    bcs -
    pha
    ;send CLOSE
    lda #$5f
    jsr idunChOut
    lda IdunDrive
    ora #$20
    jsr idunChOut
    lda #$9f    ;Lfn=31
    jsr idunChOut
    lda #$3F
    jsr idunChOut
-   jsr idunChIn
    bcs -
    pla
    rts
idunCmdError = *
    pha
    ldx #0
-   lda errorMessage,x
    jsr kernelChrout
    inx
    cpx #(sendDirname-errorMessage)
    bne -
    pla
    clc
    adc #$30
    jsr kernelChrout
    lda #13
    jsr kernelChrout
    lda configDrv
    sta IdunDrive
    rts
errorMessage !pet "I/O error #"
sendDirname = *
    ldy nameOffset
-   lda (TXTPTR),y
    beq +
    cmp #$22
    beq +
    jsr idunChOut
    iny
    jmp -
+   lda #$2c    ; ","
    jsr idunChOut
    lda #"R"
    jsr idunChOut
    lda #0
    jsr idunChOut
    rts
nameOffset !byte 0

idDataport = $de00
idRxBufLen = $de01
idunChIn = *
    ; preserve X, Y
    lda idRxBufLen
    bne +
    sec
    rts
+   lda idDataport
    clc
    rts
idunChOut = *
    sta idDataport
    clc
    rts

;BASIC extensions handled via Wedge (use '@' prefix)
idunWedge = *
    +incTXTPTR
    ;direct/immediate mode?
!if useC128 {
    lda RUNMOD
    beq +
} else {
    lda MSGFLG
    bne +
}
    ;entered RUN mode; disable wedge
    lda #$e6
    sta CHRGET
    lda #TXTPTR
    sta CHRGET+1
    lda #$d0
    sta CHRGET+2
    jmp CHRGOT
    ;is direct mode, check for "@" or "%"
+   ldy #0
    lda (TXTPTR),y
    cmp #"%"
    bne +
    jmp runProg
+   cmp #"@"
    bne wedgeOut
    ;might be a wedge command
    +incTXTPTR
    lda (TXTPTR),y
    cmp #"#"
    beq wedgeIecAddr
    cmp #"$"
    beq wedgeDir
    cmp #"@"
    bcc wedgeOut
    cmp #"_"
    bcs wedgeOut
    ldx iecAddress
    bne wedgeIecCmd
wedgeSelect = *
    sec
    sbc #"@"
    ;check if valid virtual disk
    tay
    asl
    asl
    tax
    lda RAM_START,x
    cmp #4
    beq ++
    cmp #7
    beq ++
    ;not a valid virtual disk
    ldx #0
-   lda invdiskMsg,x
    beq +
    jsr kernelChrout
    inx
    jmp -
+   jmp basicPrompt
    ;reset current & configured drive
++  tya
    sta configDrv
    sta IdunDrive
    jmp basicPrompt
wedgeOut = *
    jmp CHRGOT
wedgeDir = *
    ldx #<dirSymbol
    ldy #>dirSymbol
    lda #1
    jsr kernelSetnam
    ldx #hookCatalog
    jsr romcall
    jmp basicPrompt
wedgeIecAddr = *
    +incTXTPTR
    jsr +
    bcs wedgeOut
    cmp #1
    bne setIecAddr
    +incTXTPTR
    jsr +
    bcs wedgeOut
    adc #10

    setIecAddr = *
    sta iecAddress
    jmp basicPrompt

+   lda (TXTPTR),y
    cmp #$2f
    bcs +
    sec
    rts
+   cmp #$3a
    bcc +
    rts
+   sec
    sbc #$30
    clc
    rts
wedgeIecCmd = *
    lda #15             ; Logical file number (15 for command channel)
    ldx iecAddress      ; Device number
    ldy #15             ; Secondary address (15 for command channel)
    jsr kernelSetlfs
    lda #0              ; Filename length (0 for direct commands)
    jsr kernelSetnam
    jsr kernelOpen
    ldx #15             ; Logical file number
    jsr kernelChkout
-   lda (TXTPTR),y
    beq +
    jsr kernelChrout
    +incTXTPTR
    jmp -
+   lda #13             ; <cr> to end command
    jsr kernelChrout

    iecCmdResponse = *
    jsr kernelClrchn
    ldx #15
    jsr kernelChkin
-   jsr kernelChrin
    jsr kernelChrout
    cmp #13
    bne -
    lda #15             ; Logical file number
    jsr kernelClose
    jsr kernelClrchn
    jmp basicPrompt
dirSymbol !pet "$"
invdiskMsg !pet "?not a virtual disk",13,0
iecAddress !byte 0

;BASIC extensions handled via IError trap
locateName = *
    ldx #0
    ldy #0
    ;find open quote
-   inx
    lda TXTBUF,x
    beq +
    cmp #$22
    bne -
    inx
    stx nameOffset
    ;find close quote or NUL
+   txa
    tay
-   lda TXTBUF,y
    beq +
    cmp #$22
    beq +
    iny
    jmp -
+   lda #0
    sta TXTBUF,y
    rts

OnSyntaxErr = *
    ldy #0
    lda (TXTPTR),y
    cmp #$22    ;a quote
    bne OnTypeErr
    ;check for "CD" cmd
    ldx #0
-   inx
    +decTXTPTR
    lda (TXTPTR),y
    cmp #$20    ;skip spaces
    beq -
    cmp #"D"
    beq +
    jmp OnTypeErr
+   inx
    +decTXTPTR
    lda (TXTPTR),y
    cmp #"C"
    beq +
    jmp OnTypeErr
+   inx
    txa
    tay
    jmp ChDir

OnTypeErr = *
    lda TXTBUF
    cmp #TOK_GO
    bne ++
    jsr locateName
    ;copy the app name to aceSharedBuf ($b00)
    ldy #0
-   lda TXTBUF,x
    sta $b00,y
    beq +
    inx
    iny
    jmp -
+   jmp Go
++  jmp basicError

OnUndefErr = *
!if useC64 {
    lda TXTBUF
    cmp #TOK_RUN
    bne +
    jmp runProg
}
+   jmp basicError
IError = *
    cpx #$0b    ;is syntax error?
    bne +
    jmp OnSyntaxErr
+   cpx #$11    ;is undef'd statement error?
    bne +
    jmp OnUndefErr
+   cpx #$16    ;is type mismatch error?
    bne +
    jmp OnTypeErr
+   jmp basicError

Basic = *
    ;** copy basic startup code
    ldy #0
    lda #<basicStart    ;from
    sta kFileaddr+0
    lda #>basicStart
    sta kFileaddr+1
    lda #<basicAddr     ;to
    sta kCurraddr+0
    lda #>basicAddr
    sta kCurraddr+1
-   beq +
    lda (kFileaddr),y
    sta (kCurraddr),y
    iny
    jmp -
+   inc kFileaddr+1
    inc kCurraddr+1
    dec basicLength+1
    beq +
    jmp -
+   lda basicLength+0
    pha
-   beq +
    lda (kFileaddr),y
    sta (kCurraddr),y
    iny
    dec basicLength+0    
    jmp -
+   pla
    clc
    adc kCurraddr+0
    sta kCurraddr+0
    bcc +
    inc kCurraddr+1
+   nop 
    ;** start basic program
!if useC128 {
    ;$1210 must point to top of basic text
    lda kCurraddr+0
    sta $1210
    lda kCurraddr+1
    sta $1211
    lda #0
    sta $f8
    sta $f9     ;edit flags
    lda #$14
    sta 2604
    sta $d018   ;VIC-II char base
    lda #0
    sta 208     ;empty the key buffer
    jmp basicRun
} else {
    jsr $e453   ;basic INITV
    lda #<IError
    ldy #>IError
    sta IERROR+0
    sty IERROR+1
    jsr $e3bf   ;basic INITCZ
    ;$2d (VARTAB) must point to top of basic text
    lda kCurraddr+0
    sta $2d
    lda kCurraddr+1
    sta $2e
    jsr $a533   ;lnkprg
    jmp magic
}
!if useC128 {
idunk !pet "idun128"
} else {
idunk !pet "idun-64"
}

; RAM-resident part
RAM_START = *

!pseudopc (RAMR) {
Go = *
    ; boot idun kernel
    lda IdunDrive
    pha
    lda #26     ;Z:
    sta IdunDrive
    lda MyDevice
    sta kLastDevice
    lda #1
    sta kSecaddr
    lda #7
    ldx #<idunk
    ldy #>idunk
    jsr kernelSetnam
!if useC128 {
    lda #bkRam0
    ldx #bkKernel
    jsr kernelSetbnk
}
    ; load kernel and jump
    ldx #$00
    ldy #$12
    lda #0
!if useC128 {
    jsr kernelLoad
} else {
    jsr ILoader     ;avoids "go" undef'd error on C64
}
    pla
    sta IdunDrive
    jmp $1200
IOpen = *
    lda kLastDevice
    cmp MyDevice
    beq +
    jmp (kernalOpen)
+   jsr FnIsdir
    bne +
    ldx #hookCatalog
    jsr romcall
+   jmp basicPrompt
ILoader = *
    pha
    lda kLastDevice
    cmp MyDevice
    beq +
    pla
    jmp (kernalLoader)
+   pla
    sta kVerify
    jsr FnIsdir
    bne +
    ldx #hookLoad
    jmp romcall
+   ldx #hookLoad
    jmp romcall   
ISaver = *
    lda kLastDevice
    cmp MyDevice
    beq +
    jmp (kernalSaver)
+   ldx #hookSave
    jmp romcall
romcall = *
    tay
    lda #$c0
    jsr kernelSetmsg
enPatchRom = *+1
    jmp *+3
!if useC128 {
    ;select 1MHz
    lda $d030
    sta $0a37
    lda #0
    sta $d030
}
    lda bkSelect
    pha
    lda #bkExtrom
    sta bkSelect
    tya
    stx *+4
    jsr HOOK_ROM_JUMP
    tay
    pla
    sta bkSelect
!if useC128 {
    ;restore 2MHz
    lda $0a37
    sta $d030
}
    tya
    rts
patchcall = *
!if useC64 {
    txa
    clc
    adc #$30
    tax
}
    tya
    stx *+4
    jmp PATCH_ROM_JUMP
FnIsdir = *
    ldy #0
!if useC128 {
	ldx kFnbank
	lda #kFnaddr
	jsr kernelINDFET
} else {
    lda (kFnaddr),y
}
    cmp #"$"
    rts
magic = *
    ldx #4
-   lda exit_magic,x
    sta KEYBUF,x
    dex
    bpl -
    lda #5
    sta NDX
    lda #0
    jmp (basicWarmStart)
    ;Here's how we exit:
    ;JMP ($a002)
    ;and keyb buffer contains "RUN:\r"
exit_magic !pet "run:",13
}   ;END RAM-resident part

!if *-RAM_START > 248 {
    !error "RAM resident driver exceeds one page limit!"
} else {
    !ifndef first_time_warning {
        !set first_time_warning = 1
        !warn "RAM resident driver: ",RAMR," - ",RAMR+(*-RAM_START)
        !warn "BASIC extension: ",LOADADDR," - ",RAM_START-1
        !warn "Configuration Page: ",RAM_START
    }
}

* = RAM_START+256
Install = *
    lda configDrv
    sta IdunDrive
    lda configIec
    sta MyDevice
    jsr kernelRESTOR
    sei
    ;always install IError hook
    lda #<IError
    ldy #>IError
    sta IERROR+0
    sty IERROR+1
    ;check for patched ROM
    lda $ff80
    bpl +
    ;Using patched ROM
    ; disable idun boot rom
    sta $de7e
    jmp CopyRUNR
    ;Install hook driver
+   lda ILOAD+0
    ldy ILOAD+1
    sta kernalLoader+0
    sty kernalLoader+1
    lda #<ILoader
    ldy #>ILoader
    sta ILOAD+0
    sty ILOAD+1
    lda ISAVE+0
    ldy ISAVE+1
    sta kernalSaver+0
    sty kernalSaver+1
    lda #<ISaver
    ldy #>ISaver
    sta ISAVE+0
    sty ISAVE+1
    lda IOPEN+0
    ldy IOPEN+1
    sta kernalOpen+0
    sty kernalOpen+1
    lda #<IOpen
    ldy #>IOpen
    sta IOPEN+0
    sty IOPEN+1
CopyRUNR = *
    ;** copy RUN command handler to RUNR_BASE to RUNR_MAX
    ldx #0
-   lda RUN_START,x
    sta RUNR_BASE,x
    inx
    cpx #(RUNR_END-RUN_START)
    bne -
CopyRAMR = *
    ;** copy RAM-resident part
    ldx #0
-   lda RAM_START,x
    sta RAMR,x
    inx
    cpx #<RAMVAR    ;stop when reach vars area
    bne -
    ;check for patched ROM
    lda $ff80
    bpl +
    ;Using patched ROM
    ; set appropriate romcall routine
    lda #<patchcall
    ldy #>patchcall
    sta enPatchRom+0
    sty enPatchRom+1
+   cli
    ;** RAM_START area relocated, then
    ;** overwritten with the config blob
LoadConfig = *
    ; TALK channel #9
    lda #9  ;I:
    clc
    adc #$40
    jsr idunChOut
    ; SECOND $7F
    lda #$7F
    jsr idunChOut
    ; Read 256-byte config
    ldx #0
--  ldy idRxBufLen
    beq --
-   lda idDataport
    sta RAM_START,x
    inx
    beq +
    dey
    beq --
    jmp -
+   clc
    rts
RUN_START = *
!pseudopc(RUNR_BASE) {
runProg = *
    jsr locateName
    tya
    sec
    sbc nameOffset
    ldy #>$200
    jsr kernelSetnam
    lda #1
    sta kSecaddr
    ldx #hookLoad
    jsr romcall
    bcc +
    jmp basicError
    ; disable EXROM
+   sta $de7e
    jsr kernelRESTOR
!if useC128 {
    ;$1210 must point to top of basic text
    lda kCurraddr+0
    sta $1210
    lda kCurraddr+1
    sta $1211
    jmp basicRun
} else {
    ;$2d (VARTAB) must point to top of basic text
    lda kCurraddr+0
    sta $2d
    lda kCurraddr+1
    sta $2e
    jsr $a533   ;lnkprg
    jmp magic
}
}
RUNR_END = *
!if *-RUN_START > (RUNR_MAX-RUNR_BASE) {
    !error "RUN handler exceeds memory limit!"
}

InstallWedge = *
    lda #$4c
    sta CHRGET
    lda #<idunWedge
    sta CHRGET+1
    lda #>idunWedge
    sta CHRGET+2
    lda #$00    ;required for NEW
    jsr basicNew
    jmp basicPrompt
!if useC128 {
    * = $1c01
    basicStart = *
    !binary "resc/boot128.prg",,2
} else {
    basicStart = *
    !binary "resc/boot.prg",,2
}
basicLength !word *-basicStart

!ifndef wedge_install {
    !set wedge_install = 1
    !warn "Wedge install: ",InstallWedge
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