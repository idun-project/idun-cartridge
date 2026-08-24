; Idun Kernel, Copyright ©2026 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Stand-in mio* implementation for platforms with no IEC/serial-bus drive
; support at all (useMioCbm=0, see sys/ace.asm) -- the "no drive" counterpart
; to sys/acemiocbm.asm's C64/128 IEC implementation. A future platform
; with its own physical drive support would provide a sibling file (e.g.
; sys/acemiomega65.asm) instead of using this one.
;
; Aliases every mio* entry point that acecall.asm's shared dispatch code
; reaches with a plain `jmp mioXxx` to rtsErrIllegalDevice (acecall.asm), so
; those jumps still resolve to something -- straight to the "illegal device"
; error -- instead of an undefined symbol.

mioOpenNameSuffix = rtsErrIllegalDevice
mioClosePath      = rtsErrIllegalDevice
mioReadPath       = rtsErrIllegalDevice
mioWritePath      = rtsErrIllegalDevice
mioRemovePath     = rtsErrIllegalDevice
mioRenamePath     = rtsErrIllegalDevice
mioFileStat       = rtsErrIllegalDevice
mioDirRead        = rtsErrIllegalDevice
mioChdirPath      = rtsErrIllegalDevice
mioIecCommand     = rtsErrIllegalDevice
mioBloadPath      = rtsErrIllegalDevice
mioDirOpenRoot    = rtsErrIllegalDevice
mioCmdchClose     = rtsErrIllegalDevice

;-- mioOpenUnsupported: like rtsErrIllegalDevice, but also frees the fcb slot
;   that kernFileOpen (acecall.asm) already claimed before reaching either
;   mioOpenSa or mioOpenGotName -- both run mid-open, after the fcb is
;   allocated, so rtsErrIllegalDevice here would leak it (lftable would
;   keep the slot marked in-use forever, since the code that frees it on
;   failure never gets a chance to run)
mioOpenUnsupported = *
   ldx openFcb
   lda #lfnull
   sta lftable,x
   lda #aceErrIllegalDevice
   sta errno
   sec
   lda #fcbNull
   rts

mioOpenSa      = mioOpenUnsupported
mioOpenGotName = mioOpenUnsupported

;-- mioOpenDiskStatus: called (.A=device) after a device's open already
;   succeeded, to let a real drive implementation additionally verify
;   drive status; .CC=ok, .CS=errno set. Unlike the entry points above,
;   this isn't an operation that inherently requires drive support -- it's
;   an optional extra check on an already-successful open -- so with no
;   drive implementation at all there's nothing to verify: always .CC=ok,
;   not rtsErrIllegalDevice's error.
mioOpenDiskStatus = *
   clc
   rts
