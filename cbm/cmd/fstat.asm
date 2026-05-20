;'fstat' cmd: display accurate file size and block count
;
;Copyright© 2026 Brian Holdsworth
; This is free software, released under the MIT License.
;
; For virtual/host files: aceFileStat gives exact bytes; blocks = ceil(bytes/254).
; For IEC disk files: directory is scanned for file type; file is read 254 bytes
; at a time to count exact bytes and blocks directly.
; Extra info for .prg: load address (hex + decimal) + machine hint.
; Extra info for .sid: type, version, title, author, released, songs+default,
;   load/init/play addresses; v2+: clock (PAL/NTSC/both), SID chip (6581/8580/both).
;
; SID file format references:
;   https://gist.github.com/cbmeeks/2b107f0a8d36fc461ebb056e94b2f4d6#file-sid-txt
;   https://hackaday.io/project/182833-sidman-player/log/218940-sid-file-structure

!source "sys/acehead.asm"
!source "sys/acemacro.asm"
* = aceToolAddress

jmp fstatMain
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

;*** zero page vars
fstatNamePtr = 2   ;(2) saved filename pointer
fstatTypePtr = 4   ;(2) pointer to type string for [] display
fstatUtoa    = 6   ;(4) 4-byte value passed to aceMiscUtoa (block count)
fstatDivN    = 10  ;(3) 24-bit dividend; replaced in-place by 16-bit quotient
fstatDivD    = 13  ;(2) 16-bit divisor (254)
fstatDivR    = 15  ;(2) 16-bit partial remainder
fstatInFile  = 17  ;(1) file handle for IEC byte-count read
fstatExact   = 18  ;(4) exact 32-bit byte count
fstatOpenMode= 22  ;(1) CBM file type byte for open (e.g. 'P','S','U')
fstatIsVirt  = 23  ;(1) 0=IEC, 1=virtual/host
fstatTmp     = 24  ;(1) multipurpose temp byte
fstatStrIdx  = 25  ;(1) string index for printSidField
fstatFieldPtr= 26  ;(2) saved field pointer for printSidField

fstatUsageMsg = *
!pet "usage: fstat <filename>",chrCR,0

;===fstat===
fstatMain = *
   lda #0
   sta fstatOpenMode
   sta fstatIsVirt
   lda aceArgc+1
   beq +
   jmp fstatUsageError
+  lda aceArgc
   cmp #2
   beq +
   jmp fstatUsageError
+  ;** get argv[1]
   lda #1
   ldy #0
   jsr getarg
   lda zp
   ldy zp+1
   sta fstatNamePtr
   sty fstatNamePtr+1
   ;** detect device: carry clear=IEC, carry set=virtual/host
   jsr aceMiscDeviceInfo
   bcc fstatIEC
   lda #1
   sta fstatIsVirt
   jmp fstatVirtual

;--- IEC: aceFileStat for type; read file 254 bytes at a time ---
fstatIEC = *
   lda fstatNamePtr
   ldy fstatNamePtr+1
   sta zp
   sty zp+1
   jsr aceFileStat
   bcc +
   jmp fstatStatError
+  lda aceDirentType
   sta fstatOpenMode
   lda #<aceDirentType
   sta fstatTypePtr
   lda #>aceDirentType
   sta fstatTypePtr+1
   lda #0
   sta fstatUtoa+0
   sta fstatUtoa+1
   sta fstatUtoa+2
   sta fstatUtoa+3
   lda fstatNamePtr
   ldy fstatNamePtr+1
   sta zp
   sty zp+1
   lda fstatOpenMode
   jsr open
   bcc +
   jmp fstatOpenError
+  sta fstatInFile
   lda #0
   sta fstatExact+0
   sta fstatExact+1
   sta fstatExact+2
   sta fstatExact+3
fstatReadLoop = *
   lda #<readBuf
   ldy #>readBuf
   sta zp
   sty zp+1
   lda #254
   ldy #0
   ldx fstatInFile
   jsr read
   bcc +
   jmp fstatReadError
+  sta zw
   sty zw+1
   ora zw+1
   beq fstatReadDone
   ;** save first min(zw,124) bytes to hdrBuf on block 0
   lda fstatUtoa+0
   ora fstatUtoa+1
   bne fstatReadCount
   lda zw
   cmp #124
   bcc +
   lda #124
+  tay
   dey
-  lda readBuf,y
   sta hdrBuf,y
   dey
   bpl -
fstatReadCount = *
   clc
   lda fstatExact+0
   adc zw
   sta fstatExact+0
   lda fstatExact+1
   adc zw+1
   sta fstatExact+1
   lda fstatExact+2
   adc #0
   sta fstatExact+2
   lda fstatExact+3
   adc #0
   sta fstatExact+3
   inc fstatUtoa+0
   bne +
   inc fstatUtoa+1
+  lda zw
   cmp #254
   beq fstatReadLoop
fstatReadDone = *
   lda fstatInFile
   jsr close
   jsr fstatPrint
   jmp fstatExtra

;--- virtual/host: aceFileStat gives exact bytes; compute blocks = ceil(bytes/254) ---
fstatVirtual = *
   lda fstatNamePtr
   ldy fstatNamePtr+1
   sta zp
   sty zp+1
   jsr aceFileStat
   bcc +
   jmp fstatStatError
+  lda #<aceDirentType
   sta fstatTypePtr
   lda #>aceDirentType
   sta fstatTypePtr+1
   lda aceDirentBytes+0
   sta fstatExact+0
   lda aceDirentBytes+1
   sta fstatExact+1
   lda aceDirentBytes+2
   sta fstatExact+2
   lda aceDirentBytes+3
   sta fstatExact+3
   clc
   lda fstatExact+0
   adc #253
   sta fstatDivN+0
   lda fstatExact+1
   adc #0
   sta fstatDivN+1
   lda fstatExact+2
   adc #0
   sta fstatDivN+2
   jsr div24by254
   lda fstatDivN+0
   sta fstatUtoa+0
   lda fstatDivN+1
   sta fstatUtoa+1
   lda #0
   sta fstatUtoa+2
   sta fstatUtoa+3
   jsr fstatPrint
   jmp fstatExtra

;--- print: "<name>: <bytes> bytes [<type>] (<blocks> blocks)" ---
fstatPrint = *
   lda fstatNamePtr
   ldy fstatNamePtr+1
   jsr puts
   lda #<colonMsg
   ldy #>colonMsg
   jsr puts
   lda #<numbuf
   ldy #>numbuf
   sta zp
   sty zp+1
   ldx #fstatExact
   lda #1
   jsr aceMiscUtoa
   lda #<numbuf
   ldy #>numbuf
   jsr puts
   lda #<bytesBracketMsg
   ldy #>bytesBracketMsg
   jsr puts
   lda fstatTypePtr
   ldy fstatTypePtr+1
   jsr puts
   lda #<bracketParenMsg
   ldy #>bracketParenMsg
   jsr puts
   lda #<numbuf
   ldy #>numbuf
   sta zp
   sty zp+1
   ldx #fstatUtoa
   lda #1
   jsr aceMiscUtoa
   lda #<numbuf
   ldy #>numbuf
   jsr puts
   lda #<blocksMsg
   ldy #>blocksMsg
   jsr puts
   rts

;--- dispatch extra info based on file extension ---
fstatExtra = *
   jsr fstatDetectExt
   cmp #1
   beq fstatPrgExtra
   cmp #2
   bne +
   jmp fstatSidExtra
+  rts

;--- detect .prg (1) or .sid (2) extension; 0=none ---
fstatDetectExt = *
   lda fstatNamePtr
   ldy fstatNamePtr+1
   sta zp
   sty zp+1
   lda #$ff
   sta fstatTmp
   ldy #$ff
fstatExtScan = *
   iny
   lda (zp),y
   beq fstatExtCheck
   cmp #$2e            ;'.'
   bne fstatExtScan
   sty fstatTmp
   jmp fstatExtScan
fstatExtCheck = *
   lda fstatTmp
   cmp #$ff
   beq fstatExtNone
   ldy fstatTmp
   iny
   lda (zp),y          ;first char after dot
   +cmpASCII "p"
   bne fstatExtChkSid
   iny
   lda (zp),y
   +cmpASCII "r"
   bne fstatExtNone
   iny
   lda (zp),y
   +cmpASCII "g"
   bne fstatExtNone
   iny
   lda (zp),y
   bne fstatExtNone
   lda #1
   rts
fstatExtChkSid = *
   +cmpASCII "s"
   bne fstatExtNone
   iny
   lda (zp),y
   +cmpASCII "i"
   bne fstatExtNone
   iny
   lda (zp),y
   +cmpASCII "d"
   bne fstatExtNone
   iny
   lda (zp),y
   bne fstatExtNone
   lda #2
   rts
fstatExtNone = *
   lda #0
   rts

;--- PRG: read 2-byte load address, print hex + decimal + machine hint ---
fstatPrgExtra = *
   lda fstatIsVirt
   beq +
   lda #2
   jsr fstatOpenHeader
   bcc +
   rts
+  lda #<prgLoadMsg
   ldy #>prgLoadMsg
   jsr puts
   lda #$24            ;'$'
   jsr putchar
   lda hdrBuf+1        ;hi byte (little-endian in PRG)
   jsr puthexbyte
   lda hdrBuf+0        ;lo byte
   jsr puthexbyte
   lda #$20            ;' '
   jsr putchar
   lda #$28            ;'('
   jsr putchar
   lda hdrBuf+0
   sta fstatUtoa+0
   lda hdrBuf+1
   sta fstatUtoa+1
   lda #0
   sta fstatUtoa+2
   sta fstatUtoa+3
   lda #<numbuf
   ldy #>numbuf
   sta zp
   sty zp+1
   ldx #fstatUtoa
   lda #1
   jsr aceMiscUtoa
   lda #<numbuf
   ldy #>numbuf
   jsr puts
   lda #$29            ;')'
   jsr putchar
   ;** machine hint based on load address
   lda hdrBuf+1       ;hi byte
   cmp #$08
   bne fstatPrgHi1
   lda hdrBuf+0
   cmp #$01
   bne fstatPrgNoHint
   lda #<hintC64
   ldy #>hintC64
   jmp fstatPrgPutHint
fstatPrgHi1 = *
   cmp #$1c
   bne fstatPrgHi2
   lda hdrBuf+0
   cmp #$01
   bne fstatPrgNoHint
   lda #<hintC128
   ldy #>hintC128
   jmp fstatPrgPutHint
fstatPrgHi2 = *
   cmp #$10
   bne fstatPrgHi3
   lda hdrBuf+0
   cmp #$01
   bne fstatPrgNoHint
   lda #<hintVic20u
   ldy #>hintVic20u
   jmp fstatPrgPutHint
fstatPrgHi3 = *
   cmp #$04
   bne fstatPrgHi4
   lda hdrBuf+0
   cmp #$01
   bne fstatPrgNoHint
   lda #<hintPetVic3k
   ldy #>hintPetVic3k
   jmp fstatPrgPutHint
fstatPrgHi4 = *
   cmp #$12
   bne fstatPrgNoHint
   lda hdrBuf+0
   cmp #$01
   bne fstatPrgNoHint
   lda #<hintVic8k
   ldy #>hintVic8k
fstatPrgPutHint = *
   jsr puts
   rts
fstatPrgNoHint = *
   lda #chrCR
   jsr putchar
   rts

;--- SID: read 124-byte header, validate magic, print metadata ---
fstatSidExtra = *
   lda fstatIsVirt
   beq +
   lda #124
   jsr fstatOpenHeader
   bcc +
   rts
+  lda hdrBuf+0
   cmp #$50            ;'P'
   beq fstatSidChkRest
   cmp #$52            ;'R'
   bne fstatSidBad
fstatSidChkRest = *
   lda hdrBuf+1
   cmp #$53            ;'S'
   bne fstatSidBad
   lda hdrBuf+2
   cmp #$49            ;'I'
   bne fstatSidBad
   lda hdrBuf+3
   cmp #$44            ;'D'
   bne fstatSidBad
   jmp fstatSidValid
fstatSidBad = *
   rts

fstatSidValid = *
   ;** "  type: PSID v2" (or RSID)
   lda #<sidTypeMsg
   ldy #>sidTypeMsg
   jsr puts
   lda hdrBuf+0       ;'P' or 'R'
   jsr putchar
   lda #$53            ;'S'
   jsr putchar
   lda #$49            ;'I'
   jsr putchar
   lda #$44            ;'D'
   jsr putchar
   lda #<sidVerMsg
   ldy #>sidVerMsg
   jsr puts
   lda hdrBuf+5       ;version lo byte (big-endian, hi=0 for v1-4)
   clc
   adc #$30            ;'0'
   jsr putchar
   lda #chrCR
   jsr putchar
   ;** "  title: <name>"
   lda #<sidTitleMsg
   ldy #>sidTitleMsg
   jsr puts
   lda #<(hdrBuf+22)
   ldy #>(hdrBuf+22)
   sta zp
   sty zp+1
   lda #32
   sta fstatTmp
   jsr printSidField
   lda #chrCR
   jsr putchar
   ;** "  author: <author>"
   lda #<sidAuthorMsg
   ldy #>sidAuthorMsg
   jsr puts
   lda #<(hdrBuf+54)
   ldy #>(hdrBuf+54)
   sta zp
   sty zp+1
   lda #32
   sta fstatTmp
   jsr printSidField
   lda #chrCR
   jsr putchar
   ;** "  released: <released>"
   lda #<sidRelMsg
   ldy #>sidRelMsg
   jsr puts
   lda #<(hdrBuf+86)
   ldy #>(hdrBuf+86)
   sta zp
   sty zp+1
   lda #32
   sta fstatTmp
   jsr printSidField
   lda #chrCR
   jsr putchar
   ;** "  songs: N (default: M)"
   lda #<sidSongsMsg
   ldy #>sidSongsMsg
   jsr puts
   lda hdrBuf+15      ;songs lo (big-endian)
   sta fstatUtoa+0
   lda hdrBuf+14      ;songs hi
   sta fstatUtoa+1
   lda #0
   sta fstatUtoa+2
   sta fstatUtoa+3
   lda #<numbuf
   ldy #>numbuf
   sta zp
   sty zp+1
   ldx #fstatUtoa
   lda #1
   jsr aceMiscUtoa
   lda #<numbuf
   ldy #>numbuf
   jsr puts
   lda #<sidDefaultMsg
   ldy #>sidDefaultMsg
   jsr puts
   lda hdrBuf+17      ;startSong lo
   sta fstatUtoa+0
   lda hdrBuf+16      ;startSong hi
   sta fstatUtoa+1
   lda #0
   sta fstatUtoa+2
   sta fstatUtoa+3
   lda #<numbuf
   ldy #>numbuf
   sta zp
   sty zp+1
   ldx #fstatUtoa
   lda #1
   jsr aceMiscUtoa
   lda #<numbuf
   ldy #>numbuf
   jsr puts
   lda #$29            ;')'
   jsr putchar
   lda #chrCR
   jsr putchar
   ;** "  load: $XXXX  init: $XXXX  play: $XXXX"
   lda #<sidAddrMsg
   ldy #>sidAddrMsg
   jsr puts
   lda hdrBuf+8       ;loadAddress hi
   jsr puthexbyte
   lda hdrBuf+9       ;loadAddress lo
   jsr puthexbyte
   lda #<sidInitMsg
   ldy #>sidInitMsg
   jsr puts
   lda hdrBuf+10      ;initAddress hi
   jsr puthexbyte
   lda hdrBuf+11      ;initAddress lo
   jsr puthexbyte
   lda #<sidPlayMsg
   ldy #>sidPlayMsg
   jsr puts
   lda hdrBuf+12      ;playAddress hi
   jsr puthexbyte
   lda hdrBuf+13      ;playAddress lo
   jsr puthexbyte
   lda #chrCR
   jsr putchar
   ;** version 2+: print clock and SID chip
   lda hdrBuf+5
   cmp #2
   bcc fstatSidDone
   jmp fstatSidFlags
fstatSidDone = *
   rts

fstatSidFlags = *
   ;** "  clock: PAL/NTSC/both/unknown"
   lda #<sidClockMsg
   ldy #>sidClockMsg
   jsr puts
   lda hdrBuf+119     ;flags lo byte (offset $77)
   and #$0c            ;bits 2-3
   lsr                 ;→ 0,2,4,6
   tax
   lda sidClockTable,x
   ldy sidClockTable+1,x
   jsr puts
   lda #chrCR
   jsr putchar
   ;** "  SID: 6581/8580/both/unknown"
   lda #<sidChipMsg
   ldy #>sidChipMsg
   jsr puts
   lda hdrBuf+119
   and #$30            ;bits 4-5
   lsr
   lsr
   lsr                 ;→ 0,2,4,6
   tax
   lda sidChipTable,x
   ldy sidChipTable+1,x
   jsr puts
   lda #chrCR
   jsr putchar
   rts

;--- print null-terminated SID field: (zp)=field, fstatTmp=max chars ---
printSidField = *
   ldy #0
-  cpy fstatTmp
   bcs +
   lda (zp),y
   beq +
   iny
   bne -
+  tya
   beq fstatSFret
   ldy #0
   ldx #stdout
   jsr write
fstatSFret = *
   rts

;--- open file, read .A bytes → hdrBuf, close; C=error (virtual path only) ---
fstatOpenHeader = *
   sta fstatTmp
   lda fstatNamePtr
   ldy fstatNamePtr+1
   sta zp
   sty zp+1
   lda fstatIsVirt
   bne +
   lda fstatOpenMode
   bne ++
+  lda #$52            ;'R' = virtual read mode (ldaSCII "r")
++ jsr open
   bcs fstatOHDone
   sta fstatInFile
   lda #<hdrBuf
   ldy #>hdrBuf
   sta zp
   sty zp+1
   lda fstatTmp
   ldy #0
   ldx fstatInFile
   jsr read
   pha
   lda fstatInFile
   jsr close
   pla
   cmp fstatTmp
   bcs fstatOHok
   sec
   rts
fstatOHok = *
   clc
fstatOHDone = *
   rts

;--- error handlers ---
fstatUsageError = *
   lda #<fstatUsageMsg
   ldy #>fstatUsageMsg
   jmp eputs

fstatStatError = *
   lda #<statErrMsg
   ldy #>statErrMsg
   jsr eputs
   lda fstatNamePtr
   ldy fstatNamePtr+1
   jsr eputs
   jmp eputcr

fstatOpenError = *
   lda #<openErrMsg
   ldy #>openErrMsg
   jsr eputs
   lda fstatNamePtr
   ldy fstatNamePtr+1
   jsr eputs
   jmp eputcr

fstatReadError = *
   lda fstatInFile
   jsr close
   lda #<readErrMsg
   ldy #>readErrMsg
   jmp eputs

;--- string constants ---
colonMsg        !pet ": ",0
bytesBracketMsg !pet " bytes [",0
bracketParenMsg !pet "] (",0
blocksMsg       !pet " blocks)",chrCR,0
statErrMsg      !pet "error: cannot stat: ",0
openErrMsg      !pet "error: cannot open: ",0
readErrMsg      !pet "error: read failed",chrCR,0

prgLoadMsg      !pet "  load: ",0
hintC64         !pet " [C64/C128]",chrCR,0
hintC128        !pet " [C128]",chrCR,0
hintVic20u      !pet " [VIC-20/Plus4/C16]",chrCR,0
hintPetVic3k    !pet " [PET/VIC-20 3K]",chrCR,0
hintVic8k       !pet " [VIC-20 8K+]",chrCR,0

sidTypeMsg      !pet "  type: ",0
sidVerMsg       !pet " v",0
sidTitleMsg     !pet "  title: ",0
sidAuthorMsg    !pet "  author: ",0
sidRelMsg       !pet "  released: ",0
sidSongsMsg     !pet "  songs: ",0
sidDefaultMsg   !pet " (default: ",0
sidAddrMsg      !pet "  load: $",0
sidInitMsg      !pet "  init: $",0
sidPlayMsg      !pet "  play: $",0
sidClockMsg     !pet "  clock: ",0
sidChipMsg      !pet "  SID: ",0

sidClkUnknown   !pet "unknown",0
sidClkPAL       !pet "PAL",0
sidClkNTSC      !pet "NTSC",0
sidClkBoth      !pet "PAL+NTSC",0
sidChipUnknown  !pet "unknown",0
sidChip6581     !pet "6581",0
sidChip8580     !pet "8580",0
sidChipBoth     !pet "6581+8580",0

sidClockTable   !word sidClkUnknown, sidClkPAL, sidClkNTSC, sidClkBoth
sidChipTable    !word sidChipUnknown, sidChip6581, sidChip8580, sidChipBoth

;=== 24-bit by 16-bit division, divisor = 254 ===
div24by254 = *
   lda #<254
   sta fstatDivD+0
   lda #>254
   sta fstatDivD+1
   lda #0
   sta fstatDivR+0
   sta fstatDivR+1
   ldx #24
divLoop = *
   asl fstatDivN+0
   rol fstatDivN+1
   rol fstatDivN+2
   rol fstatDivR+0
   rol fstatDivR+1
   sec
   lda fstatDivR+0
   sbc fstatDivD+0
   tay
   lda fstatDivR+1
   sbc fstatDivD+1
   bcc divSkip
   sta fstatDivR+1
   sty fstatDivR+0
   inc fstatDivN+0
divSkip = *
   dex
   bne divLoop
   rts

;--- print byte in A as 2 hex chars ---
puthexbyte = *
   pha
   lsr
   lsr
   lsr
   lsr
   jsr puthexnibble
   pla
   jmp puthexnibble

;--- print low nibble of A as hex char ---
puthexnibble = *
   and #$0f
   cmp #10
   bcc +
   adc #$36     ;C=1 from cmp: A+$36+1=A+$37; 10→$41='A', 15→$46='F'
   jmp putchar
+  adc #$30     ;C=0: A+$30; 0→$30='0', 9→$39='9'
   jmp putchar

;*** standard library ***
puts = *
   ldx #stdout
fputs = *
   sta zp
   sty zp+1
   ldy #$ff
-  iny
   lda (zp),y
   bne -
   tya
   ldy #0
   jmp write

eputs = *
   ldx #stderr
   jmp fputs

eputcr = *
   lda #chrCR
   ldx #stderr
   jmp putc

putchar = *
   ldx #stdout
putc = *
   sta putcBuffer
   lda #<putcBuffer
   ldy #>putcBuffer
   sta zp
   sty zp+1
   lda #1
   ldy #0
   jmp write
putcBuffer !byte 0

;===fstat library===
getarg = *
   sty zp+1
   asl
   rol zp+1
   clc
   adc aceArgv+0
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
   rts

;===bss===
cpBss   = *
numbuf  = cpBss+0    ;12 bytes for 10-digit decimal + null
hdrBuf  = cpBss+12   ;128 bytes: first block cached (IEC) or read once (virtual)
readBuf = cpBss+140  ;256-byte buffer for IEC block reads

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
