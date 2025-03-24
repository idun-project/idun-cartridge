; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Original version from the ACE-128/64 system,
; by Craig Bruce, 1992-97 (http://csbruce.com/cbm/ace/)
;
; System-interface declarations

aceStatB      = $f00   ;(176)
; IDUN: This block re-purposed for various data-sharing uses
aceSharedBuf  = $b00            ;(256)
mailboxB      = aceSharedBuf
aceExitData   = aceSharedBuf
; Kernel jump table
aceCallB      = $1303   ;(267)
; Load addresses for apps and tools
aceAppAddress = $6000
aceToolAddress= $6d00

zp      = $f8  ;(2)
zw      = $fa  ;(2)
mp      = $fc  ;(4)
syswork = $80  ;(16)

errno            = aceStatB+0          ;(1)
aceArgc          = aceStatB+4          ;(2)
aceArgv          = aceStatB+6          ;(2)
aceMemTop        = aceStatB+8          ;(2)
aceDirentBuffer  = aceStatB+10         ;(aceDirentLength)
aceDirentBytes   = aceDirentBuffer+0   ;(4)
aceDirentDate    = aceDirentBuffer+4   ;(8) = YY:YY:MM:DD:HH:MM:SS:TW
aceDirentType    = aceDirentBuffer+12  ;(4)
aceDirentFlags   = aceDirentBuffer+16  ;(1) = drwx*e-t
aceDirentUsage   = aceDirentBuffer+17  ;(1) = ulshb---
aceDirentNameLen = aceDirentBuffer+18  ;(1)
aceDirentName    = aceDirentBuffer+19  ;(17)
aceDirentLength  = 36
aceMouseLimitX   = aceStatB+46         ;(2)
aceMouseLimitY   = aceStatB+48         ;(2)
aceMouseScaleX   = aceStatB+50         ;(1)
aceMouseScaleY   = aceStatB+51         ;(2)
joykeyCapture    = aceStatB+53         ;(1) $80=capture keyb, $40=capture joys, $c0=capture both
;free public kernel vars from +54 through +63
;private kernel vars from +64 through +103
aceZpIrqsave     = aceStatB+104        ;(40) toolbox Irq stash Zp here.

open          = aceCallB+0   ;( (zp)=name, .A=mode[rwaWA] ) : .A=fd
close         = aceCallB+3   ;( .A=fd )
read          = aceCallB+6   ;( .X=fd, (zp)=buf, .AY=len ) : .AY=(zw)=len, .Z
write         = aceCallB+9   ;( .X=fd, (zp)=buf, .AY=len )
seek          = aceCallB+12  ;( .X=fd, .AY=newpos : .CS=error,errno)
aceFileBload  = aceCallB+15  ;( (zp)=name, .AY=loadAddr, (zw)=limit+1):.AY=end+1
aceFileRemove = aceCallB+18  ;( (zp)=name )
aceFileRename = aceCallB+21  ;( (zp)=oldName, (zw)=newName )
aceFileStat   = aceCallB+24  ;( (zp)=path ) : .AY=filesz,.CS=error,errno,fills aceDirentBuffer
aceFileIoctl  = aceCallB+27  ;( .X=virt. device, (zp)=io cmd ) : .CS=error,errno
aceReserved1  = aceCallB+30
aceFileBkload = aceCallB+33  ;( .X=bank (zp)=name, .AY=loadAddr, (zw)=limit+1):.AY=end+1

aceDirOpen    = aceCallB+36  ;( (zp)=dirName ) : .A=fd
aceDirClose   = aceCallB+39  ;( .A=fd )
aceDirRead    = aceCallB+42  ;( .X=fd ) : direntBuffer, .Z=eof
aceDirIsdir   = aceCallB+45  ;( (zp)=name ) : .A=dev, .X=isDisk, .Y=isDir
aceDirChange  = aceCallB+48  ;( (zp)=dirName, .A=flags($80=home) )
aceDirMake    = aceCallB+51  ;( (zp)=newDirName, .AY=suggestedEntries )
aceDirRemove  = aceCallB+54  ;( (zp)=dirName )
aceDirName    = aceCallB+57  ;( .A=sysdir, (zp)=buf ) : buf, .Y=len
                             ; .A:0=curDir, 1=homeDir, 2=execSearchPath,
                             ;    3=configSearchPath, 4=tempDir

aceWinScreen = aceCallB+60  ;( .A=MinRows, .X=MinCols )
aceWinMax    = aceCallB+63  ;( )
aceWinSet    = aceCallB+66  ;( .A=rows, .X=cols, sw+0=scrRow, sw+1=scrCol )
aceWinSize   = aceCallB+69  ;( ) : <above>+ ,(sw+2)=addr,(sw+4)=rowinc
aceWinCls    = aceCallB+72  ;( .A=char/color/attrFlags, .X=char, .Y=color )
aceWinPos    = aceCallB+75  ;( .A=row, .X=col ) : (sw+0)=addr
aceWinPut    = aceCallB+78  ;( .A=attr,.Y=color,.X=len,(sw+0)=addr,(sw+2)=chPtr,
                            ;  sw+4=fillChar, sw+5=fieldLen, sw+6=extattr )
aceWinGet    = aceCallB+81  ;( .A=attr, .X=len, (sw+0)=scr, (sw+2)=charPtr,
                            ;  (sw+4)=colorPtr, (sw+6)=attrPtr )
aceWinScroll = aceCallB+84  ;( .A=attr+$08:up+$04:dn,.X=rows,sw+4=chr,.Y=color)
aceWinCursor = aceCallB+87  ;( (sw+0)=addr, .Y=color, .A=$ff:on/$00:off)
aceWinPalette = aceCallB+90 ;( ) : sw+0...sw+7=palette [8 colors]
aceWinChrset = aceCallB+93  ;( (sw+0)=addr,.A=flags,.X=start,.Y=len):.A=flags
aceWinOption = aceCallB+96  ;( .X=op, .A=arg, .CS=set ) : .A=return

aceConWrite    = aceCallB+99  ;( (zp)=Buf, .AY=Len, .X=prescroll ) : .X=scroll
aceConPutlit   = aceCallB+102 ;( .A=char )
aceConPos      = aceCallB+105 ;( .A=row, .X=col )
aceConGetpos   = aceCallB+108 ;( ) : .A=rowOfCursor, .X=colOfCursor
aceConInput    = aceCallB+111 ;( (zp)=buf/initstr,.Y=initStrLen):.Y=len,.CS=excp
aceConStopkey  = aceCallB+114 ;( ) : .CC=notPressed
aceConGetkey   = aceCallB+117 ;( ) : .A=key
aceConKeyAvail = aceCallB+120 ;( ) : .CC=keyIsAvailable, .A=keyboardType
aceConKeyMat   = aceCallB+123 ;( (zp)=keymatrixPtr )
aceConMouse    = aceCallB+126 ;( ) : .A=buttons:l/r:128/64, (sw+0)=X, (sw+2)=Y
aceConJoystick = aceCallB+129 ;( ) : .A=joy1, .X=joy2
aceConOption   = aceCallB+132 ;( .X=op, .A=arg, .CS=set ) : .A=return
aceConGamepad  = aceCallB+135 ;( .AY=buf) : .AY[0-1]=gamepad1 ,AY[2-3]=gamepad2
aceGrExit      = aceCallB+138 ;( )
aceConDebugLog = aceCallB+141 ;( (zp)=msg,(.AY)=byte vars,.X=num vars)
aceHashTag     = aceCallB+144 ;( (.AY)=name : .A=tag hash)
aceProcExec = aceCallB+147 ;( (zp)=execName, (zw)=argv,.AY=argCnt,[mp]=saveArea,
                           ; .X=reftch):.A=exitCode,.X=exitDataLen,[mp]=saveArea
aceProcExecSub = aceCallB+150 ;( (zp)=execAddr, ...) rest same as aceProcExec
                              ;  : .A=exitCode, .X=exitDataLen, [mp]=saveArea
aceProcExit    = aceCallB+153 ;( .A=exitCode, .X=exitBufDataLen, exitData )

aceMemZpload  = aceCallB+156 ;( [mp]=Source, .X=ZpDest, .Y=Length )
aceMemZpstore = aceCallB+159 ;( .X=ZpSource, [mp]=Dest, .Y=Length )
aceMemFetch   = aceCallB+162 ;( [mp]=FarSource, (zp)=Ram0Dest, .AY=Length )
aceMemStash   = aceCallB+165 ;( (zp)=Ram0Source, [mp]=FarDest, .AY=length )
aceMemAlloc   = aceCallB+168 ;( .A=PageCount, .X=StartTyp,.Y=EndTyp):[mp]=FarPtr
aceMemFree    = aceCallB+171 ;( [mp]=FarPointer, .A=PageCount )
aceMemStat    = aceCallB+174 ;( .X=zpOff) : .A=procID, [.X+0]=free, [.X+4]=total

aceTimeGetDate = aceCallB+177 ;( (.AY)=dateString ) : dateString
aceTimeSetDate = aceCallB+180 ;( (.AY)=dateString )

; IDUN: Add Irq hooking mechanism for apps
aceIrqHook     = aceCallB+183 ;( .AY=<hook> )

aceMiscUtoa      = aceCallB+186 ;( $0+X=value32,(zp)=buf,.A=minLen):buf,.Y=len
aceMiscIoPeek    = aceCallB+189 ;( (zw)=ioaddr, .Y=offset ) : .A=data
aceMiscIoPoke    = aceCallB+192 ;( (zw)=ioaddr, .Y=offset, .A=data )

aceFileFdswap    = aceCallB+195 ;( .X=fd1, .Y=fd2 )
aceConRead       = aceCallB+198 ;( (zp)=Buf, .AY=Len ) : .AY=(zw)=Len, .Z
aceConPutchar    = aceCallB+201 ;( .A=char )
aceConPutctrl    = aceCallB+204 ;( .A=char, .X=aux )
aceConSetHotkeys = aceCallB+207 ;( .AY=handler, =$00 if none)
; IDUN: New TTY functions to use VirtualConsole 
aceTtyAvail      = aceCallB+210 ;( :.A=avail )
aceTtyGet        = aceCallB+213 ;( .AY=RecvBuffer, .X=RecvBytes,
                                ;  : .CS, error
aceTtyPut        = aceCallB+216 ;( .AY=SendBuffer, .X=SendBytes,
                                ;  : .CS, error
; IDUN: New API far memory management with ERAM
new              = aceCallB+219 ;( (.AY)=data, .X=$ff?, zw=#bytes : (mp), .CS=error )
                                ;set .X=$ff to mmap to system area
memtag           = aceCallB+222 ;( (.AY)=tag, (mp) : .CS=error )
mmap             = aceCallB+225 ;( (.AY)=tag, (zp)=fname, .X=$ff? : .CS=error)
                                ;set .X=$ff to mmap to system area
aceReserved2     = aceCallB+228
; IDUN: Add function to get key system type values
aceMiscSysType   = aceCallB+231 ;( : .A=model, .X=int. banks, .Y=eram banks)
; IDUN: Add function to inject keystrokes; support user-defined macro keys
aceMiscRobokey   = aceCallB+234 ;( .A=key )
; IDUN: Add function to mount a disk image file (from Virtual Drives only!)
aceMountImage    = aceCallB+237 ;( (zp)=image file, .X=target device,
                                ;  .A=read/write flag) : .CS, errno
; IDUN: Add function to retrieve device attributes
aceMiscDeviceInfo= aceCallB+240 ;( (zp)=path: .A=iec addr,.X=type,
;                                  sw=flags,sw+1=device,.CS=virt.dev )
; IDUN: Fast,local copy of (large) files between virtual drives ONLY!
aceFileCopyHost  = aceCallB+243 ;( .A=src Fcb, .X=dest Fcb) : .CS=error,errno
; IDUN: Software restart with various outcomes
; Restart flags
aceRestartWarmReset     = $80
aceRestartApplReset     = $81
aceRestartExitBasic     = $82
aceRestartLoadPrg       = $83
aceRestart       = aceCallB+246 ;(.A=flag,.X=device,(zp)=appname) : no RTS!
; IDUN: Communicate with the RPi Memory Mapper process
aceMapperSetreg = aceCallB+249  ;(.X=Register, .AY=Value)
aceMapperCommand = aceCallB+252 ;(.X=Command, .A=Param)
aceMapperProcmsg  = aceCallB+255 ;(.AY=proc callback)
; IDUN: Put characters from graphical set
aceWinGrChrPut  = aceCallB+258
; IDUN: Read/write by Track/Sector to Virtual Floppy devices
aceDirectRead   = aceCallB+261 ;( .X=fd, (zp)=buf, .A=# sector) : .AY=(zw)=len, .CS=error
aceDirectWrite  = aceCallB+264 ;( .X=fd, (zp)=buf, .A=# sector) : .CS=error
; IDUN: Detect when running in emulator.
; Custom version of Vice Emulator can connect
; to Idun services over the network.
aceViceEmuCheck = aceCallB+267 ;() : .ZS=emulator detected
; IDUN: Use search path to determine full filename
aceSearchPath   = aceCallB+270 ;( (zp)=filename, .X=PathPos ) : (zp)=lname, .X=nextPathPos,
                               ;                                .CS=end of path
aceID1 = $cb
aceID2 = $06
aceID3 = 16

aceMemNull     = $00
aceMemInternal = $01
aceMemERAM     = $02

aceErrStopped = 0
aceErrTooManyFiles = 1
aceErrFileOpen = 2
aceErrFileNotOpen = 3
aceErrFileNotFound = 4
aceErrDeviceNotPresent = 5
aceErrFileNotInput = 6
aceErrFileNotOutput = 7
aceErrMissingFilename = 8
aceErrIllegalDevice = 9
aceErrInvalidFilePos = 10
aceErrWriteProtect = 26
aceErrFileExists = 63
aceErrFileTypeMismatch = 64
aceErrNoChannel = 70
aceErrDiskFull = 72
aceErrInsufficientMemory = 128
aceErrOpenDirectory = 129
aceErrMemorySize = 130
aceErrDiskOnlyOperation = 131
aceErrNullPointer = 132
aceErrInvalidFreeParms = 133
aceErrFreeNotOwned = 134
aceErrInvalidWindowParms = 135
aceErrInvalidConParms = 136
aceErrInvalidFileMode = 137
aceErrNotImplemented = 138
aceErrBloadTruncated = 139
aceErrPermissionDenied = 140
aceErrNoGraphicsSpace = 141
aceErrBadProgFormat = 142
aceAppFileOpen      = 192
;commonly used character codes
chrBEL = $07  ;bell
chrTAB = $09  ;tab
chrBOL = $0a  ;beginning of line (return)
chrCR  = $0d  ;carriage return (newline)
chrVT  = $11  ;vertical tab (down, linefeed)
chrBS  = $14  ;backspace (del)
chrCLS = $93  ;clear screen (form feed)
; Graphics chars for drawing borders (and other).
; Draw the glyphs using aceWinGrChrPut routine.
; Note: not all character sets support all glyphs.
chrBUL   = $00    ;__bullet___
chrVL    = $01    ;__v_line___
chrHL    = $02    ;__h_line___
chrCRS   = $03    ;___cross___
chrTL    = $04    ;_tl_corner_
chrTR    = $05    ;_tr_corner_
chrBL    = $06    ;_bl_corner_
chrBR    = $07    ;_br_corner_
chrLT    = $08    ;___l_tee___
chrRT    = $09    ;___r_tee___
chrTT    = $0a    ;___t_tee___
chrBT    = $0b    ;___b_tee___
chrHRT   = $0c    ;___heart___
chrDIA   = $0d    ;__diamond__
chrCLU   = $0e    ;___club____
chrSPA   = $0f    ;___spade___
chrSCI   = $10    ;_s_circle__
chrOCI   = $11    ;__circle___
chrLBS   = $12    ;___pound___
chrCHK   = $13    ;_CLS/check_
chrPI    = $14    ;____pi_____
chrPM    = $15    ;____+/-____
chrDIV   = $16    ;__divide___
chrDEG   = $17    ;__degree___
chrCHE1  = $18    ;_c_checker_
chrCHE2  = $19    ;_f_checker_
chrSOL   = $1a    ;_solid_sq__
chrCRE   = $1b    ;__cr_char__
chrUP    = $1c    ;_up_arrow__
chrDWN   = $1d    ;_down_arro_
chrLA    = $1e    ;_left_arro_
chrRA    = $1f    ;_right_arr_
; default file IO handles
stdin  = 0
stdout = 1
stderr = 2
;===end of ace interface declarations===

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