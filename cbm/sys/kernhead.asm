;===kernel header declarations===
aceStackPtr       = aceMemTop    ;(2)
aceFramePtr       = aceStatB+64  ;(2)
aceStackTop       = aceStatB+66  ;(2)
aceCurrentDevice  = aceStatB+68  ;(1)
aceDate           = aceStatB+70  ;(4) YYYY:MM:DD
aceDOW            = aceStatB+74  ;(1) 1-7,1=Sun
aceProcessID      = aceStatB+75  ;(1)
aceFreeMemory     = aceStatB+76  ;(4)
aceTotalMemory    = aceStatB+80  ;(4)
aceInternalBanks  = aceStatB+84  ;(1)
aceInternalCur    = aceStatB+85  ;(1)
aceRam0Freemap    = aceStatB+86  ;(2)
aceRam1Freemap    = aceStatB+88  ;(1)
aceReuStart       = aceStatB+89  ;(1)
aceReuBanks       = aceStatB+90  ;(1)
aceReuCur         = aceStatB+91  ;(1)
aceSystemType 	  = aceStatB+92  ;(1)   ;$80=C128,$40=C64
aceRestoreStack   = aceStatB+93  ;(1)
aceSoft80Allocated= aceStatB+94  ;(1)  ;$ff=yes,$00=no
aceCharSetPage    = aceStatB+95  ;(1)
aceVic40Page      = aceStatB+96  ;(1)
aceTpaLimit       = aceStatB+97  ;(1)
aceSuperCpuFlag   = aceStatB+98  ;(1)   ;SuperCPU/normal flag
aceNmiWork        = aceStatB+99  ;(2)   ;for redirecting NMIs on the C64
aceCurDirName     = aceStatB+101 ;(3)   ;name of current directory
;===end of aceStatB ($f00 - $f90 used; max $faf)

aceMemTypes       = 4
;===end of kernel header info===
