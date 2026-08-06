; Idun Kernel, Copyright ©2026 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Stand-in mio* implementation for platforms with no IEC/serial-bus drive
; support at all (useIec=0, see sys/ace.asm) -- the "no drive" counterpart
; to sys/acemioc64.asm's C64/128 IEC implementation. A future platform
; with its own physical drive support would provide a sibling file (e.g.
; sys/acemiomega65.asm) instead of using this one.
;
; Aliases every mio* entry point that acecall.asm's shared dispatch code
; reaches with a plain `jmp mioXxx` to mioUnsupported, so those jumps still
; resolve to something -- straight to the "illegal device" error -- instead
; of an undefined symbol.

;-- mioUnsupported: fallback for shared dispatch code's plain `jmp mioXxx`
;   sites when useIec=0 -- reached only if a device is (mis)configured as
;   an IEC drive on a build with no IEC support. sys/acemionone.asm aliases
;   every mio* entry point to this label when useIec=0, so those `jmp`s
;   always resolve to something instead of an undefined symbol
mioUnsupported = *
   lda #aceErrIllegalDevice
   sta errno
   sec
   rts

mioOpenNameSuffix = mioUnsupported
mioClosePath      = mioUnsupported
mioReadPath       = mioUnsupported
mioWritePath      = mioUnsupported
mioRemovePath     = mioUnsupported
mioRenamePath     = mioUnsupported
mioFileStat       = mioUnsupported
mioDirRead        = mioUnsupported
mioChdirPath      = mioUnsupported
mioIecCommand     = mioUnsupported
mioBloadPath      = mioUnsupported
mioDirOpenRoot    = mioUnsupported
mioCmdchClose     = mioUnsupported

;-- mioOpenUnsupported: like mioUnsupported, but also frees the fcb slot
;   that kernFileOpen (acecall.asm) already claimed before reaching either
;   mioOpenDiskSa or mioOpenGotName -- both run mid-open, after the fcb is
;   allocated, so a plain mioUnsupported here would leak it (lftable would
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

mioOpenDiskSa  = mioOpenUnsupported
mioOpenGotName = mioOpenUnsupported

;-- mioOpenDiskStatus: called (.A=device) after a device's open already
;   succeeded, to let a real drive implementation additionally verify
;   drive status; .CC=ok, .CS=errno set. Unlike the entry points above,
;   this isn't an operation that inherently requires drive support -- it's
;   an optional extra check on an already-successful open -- so with no
;   drive implementation at all there's nothing to verify: always .CC=ok,
;   not mioUnsupported's error.
mioOpenDiskStatus = *
   clc
   rts
