; Idun Cartridge
; Booter program & I/O Hook for the Commodore 128.

; Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
!if computer-64 {
    useC128 = 1
    useC64  = 0
    LOADADDR = $1300
    RAMR = $0e00    ; kernel hooks page
} else {
    useC128 = 0
    useC64  = 1
    LOADADDR = $c000
    RAMR = $cf00    ; kernel hooks page
}
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
JUMP_ROM    = $800b
hookOpen    = <JUMP_ROM+0
hookLoad    = <JUMP_ROM+3
hookSave    = <JUMP_ROM+6
hookClose   = <JUMP_ROM+9

;** kernal vectors
ILOAD = $0330
IOPEN = $031A
ISAVE = $0332
IERROR= $0300

;** kernal entry points
kernelRESTOR    = $ff8a
kernelChrout    = $ffd2
kernelStop      = $ffe1
kernelSetnam    = $ffbd
kernelSetmsg    = $ff90

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
    kernelSTA           = $f7bf
    kernelSetbnk        = $ff68
    basicPrompt         = $4d37
    basicRun            = $af99
    basicError          = $4d3f
    basicAddr           = $1c01
} else {
    bkExtrom            = $37
    bkKernel            = $37
    bkSelect            = $01
    basicPrompt         = $a474
    basicError          = $e38b     ;$a43a
    basicAddr           = $801
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
    ;send OPEN
    lda IdunDrive
    ora #$20
    jsr idunChOut
    lda #$bf    ;Lfn=31
    jsr idunChOut
    ldy #1
    jsr sendDirname
    lda #$3F
    jsr idunChOut
    ; Get errno
-   jsr idunChIn
    bcs -
    ;send "/" COMMAND
    lda IdunDrive
    ora #$20
    jsr idunChOut
    lda #$7f    ;Lfn=31
    jsr idunChOut
    ldy #0
    jsr sendDirname
    lda #$3F
    jsr idunChOut
    ; Get errno
-   jsr idunChIn
    bcs -
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
    lda #$40
    sta kStatus
    clc
    rts
sendDirname = *
    cpy kFnlen
    beq +
!if useC128 {
    ldx kFnbank
    lda #kFnaddr
    jsr kernelINDFET
} else {
    lda (kFnaddr),y
}
    beq +
    jsr idunChOut
    iny
    jmp sendDirname
+   lda #$2c    ; ","
    jsr idunChOut
    lda #"R"
    jsr idunChOut
    lda #0
    jsr idunChOut
    rts
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
!if useC128 {
idunkLen !byte 8
idunk !pet "idunk128"
} else {
idunkLen !byte 5
idunk !pet "idunk"
}

Install = *
; Install hook driver
    ; lda #bkKernel
    ; sta bkSelect
    lda configDrv
    sta IdunDrive
    lda configIec
    sta MyDevice
    jsr kernelRESTOR
    sei
    lda ILOAD+0
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
    lda #<IError
    ldy #>IError
    sta IERROR+0
    sty IERROR+1
    cli
    ;** copy RAM-resident part
    ldx #0
-   lda RAM_START,x
    sta RAMR,x
    inx
    cpx #<RAMVAR    ;stop when reach vars area
    bne -
    rts

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
    lda basicLength+0   ;size
    sta temp+0
    lda basicLength+1
    sta temp+1
-   beq +
    lda (kFileaddr),y
    sta (kCurraddr),y
    iny
    jmp -
+   inc kFileaddr+1
    inc kCurraddr+1
    dec temp+1
    beq +
    jmp -
+   lda temp+0
    pha
-   beq +
    lda (kFileaddr),y
    sta (kCurraddr),y
    iny
    dec temp+0    
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
    jsr $af87   ;C128 lnkprg
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
    ;copy "magic" exit routine
magic = *
    ldx #6
-   lda exit_magic,x
    sta $277,x
    dex
    bpl -
    lda #4
    sta $c6
    lda #0
    jmp $27b
    ;Here's how we exit:
    ;JMP ($a002)
    ;and keyb buffer contains "RUN\r"
exit_magic !pet "run",13,$6c,$02,$a0
}

; RAM-resident part
RAM_START = *

!pseudopc (RAMR) {
IOpen = *
    lda kLastDevice
    cmp MyDevice
    beq +
    jmp (kernalOpen)
+   ldy #0
    jsr FnIsdir
    bne +
    jsr Catalog
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
    ldy #0
    jsr FnIsdir
    bne +
    jmp Catalog
!if useC128 {
+	ldx kFnbank
	lda #kFnaddr
	jsr kernelINDFET
} else {
+   lda (kFnaddr),y
}
    cmp #"/"
    bne +
    jmp ChDir
+   ldx #hookLoad
    jmp romcall   
ISaver = *
    lda kLastDevice
    cmp MyDevice
    beq +
    jmp (kernalSaver)
+   ldx #hookSave
    jmp romcall
IError = *
    cpx #$0b    ;is syntax error?
    beq +
!if useC64 {
    cpx #$11    ;is undef'd statement error?
    beq +
}
    jmp basicError
!if useC128 {
+   cmp #"S"
    bne +
    lda $200
    cmp #$eb    ;"DOS"
    bne +
    jmp loadIdun
+   jmp basicError
} else {
+   lda $200
    cmp #$8a    ;RUN
    beq +
    cmp #"D"
    bne ++
    lda $201
    cmp #"O"
    bne ++
    lda $202
    cmp #"S"    ;DOS
    bne ++
    lda $eb
    sta $200
    jmp loadIdun
+   ldx #0
-   inx
    lda $200,x
    cmp #$20    ;skip over spaces
    beq -
    cmp #$22    ;RUN"
    bne ++
    jmp runProg
++  jmp basicError
runProg = *
    stx start_name
-   inx
    lda $200,x
    cmp #$22    ;RUN"name"
    bne -
    dex
    txa
    sec
    sbc start_name
    ldx start_name
    inx
    ldy #>$200
    jsr kernelSetnam
    ldx #hookLoad
    jsr romcall
    bcc +
    jmp basicError
    ; disable EXROM
+   lda #$00
    sta $de7e
    lda $81ff
    jsr kernelRESTOR
    jmp magic
start_name !byte 0
}
loadIdun = *
    ; boot idun kernel
    lda #26     ;Z:
    sta IdunDrive
    lda #1
    sta kSecaddr
    lda idunkLen
    ldx #<idunk
    ldy #>idunk
    jsr kernelSetnam
!if useC128 {
    lda #bkRam0
    ldx #bkKernel
    jsr kernelSetbnk
}
    ; load kernel and jump
    ldx #hookLoad
    jsr romcall
    bcc +
    rts
+   jmp $1300
FnIsdir = *
!if useC128 {
	ldx kFnbank
	lda #kFnaddr
	jsr kernelINDFET
} else {
    lda (kFnaddr),y
}
    cmp #"$"
    rts
romcall = *
    tay
    lda #$c0
    jsr kernelSetmsg
!if useC128 {
    ;select 1MHz
    lda $d030
    sta $0a37
    lda #%00
    sta $d030
}
    lda bkSelect
    pha
    lda #bkExtrom
    sta bkSelect
    tya
    stx *+4
    jsr JUMP_ROM
    pla
    sta bkSelect
!if useC128 {
    ;restore 2MHz
    lda $0a37
    sta $d030
}
    rts
}

!if *-RAM_START > 248 {
    !error "RAM resident driver exceeds one page limit!"
} else {
    !ifndef first_time_warning {
        !set first_time_warning = 1
        !warn "RAM resident driver: ",RAMR," - ",RAMR+(*-RAM_START)
    }
}

basicStart = *
!if useC128 {
    !binary "resc/boot128.bas",,2
} else {
    !binary "resc/boot.bas",,2
}
basicLength !word *-basicStart


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