; Idun Kernel, Copyright ©2023 Brian Holdsworth
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
