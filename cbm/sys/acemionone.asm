; Idun Kernel, Copyright ©2023 Brian Holdsworth
; This is free software, released under the MIT License.
;
; Stand-in mio* implementation for platforms with no IEC/serial-bus drive
; support at all (useIec=0, see sys/ace.asm) -- the "no drive" counterpart
; to sys/acemioc64.asm's C64/128 IEC implementation. A future platform
; with its own physical drive support would provide a sibling file (e.g.
; sys/acemiomega65.asm) instead of using this one.
;
; Aliases every mio* entry point that acecall.asm's +jmpMio call sites
; reference to mioUnsupported, so those macro calls -- which need a defined
; label in every build, since ACME evaluates macro arguments eagerly --
; still resolve, just straight to the "illegal device" error instead of
; real drive code.

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
