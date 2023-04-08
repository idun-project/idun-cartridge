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
;IDUN: Deprecate support for RAMLink
;aceRamlinkStart   = aceStatB+92  ;(2)
;aceRamlinkBanks   = aceStatB+94  ;(1)
;aceRamlinkCur     = aceStatB+95  ;(1)
;aceRamlinkAccess  = aceStatB+96  ;(1)
;IDUN: Store System Type (128/64)
aceSystemType 	= aceStatB+92  ;(1)   ;$80=C128,$40=C64
aceRestoreStack   = aceStatB+101 ;(1)
aceSoft80Allocated = aceStatB+102 ;(1)  ;$ff=yes,$00=no
aceCharSetPage    = aceStatB+103 ;(1)
aceVic40Page      = aceStatB+104 ;(1)
;IDUN: Deprecate support for SwiftLink
;aceModemSendPage  = aceStatB+105 ;(1)
;aceModemRecvPage  = aceStatB+106 ;(1)
;aceModemRecvHigh  = aceStatB+107 ;(1)   ;high page + 1
;aceModemType      = aceStatB+108 ;(1)   ;$ff=swifty,$40=user-port,$00=none
;aceModemIoPage    = aceStatB+109 ;(1)
aceTpaLimit       = aceStatB+110 ;(1)
;IDUN: Deprecate support for RAMLink
;aceReuRlSpeedTry  = aceStatB+111 ;(1)   ;whether reu visible when rl active
;aceReuRlSpeedPage = aceStatB+112 ;(4)   ;pointer to reu-rl copying page/null
;IDUN: Deprecate support for SwiftLink
;aceModemConfig    = aceStatB+116 ;(1)   ;$0x=baudrate, $x0=bits+parity+stop
aceSuperCpuFlag   = aceStatB+117 ;(1)   ;SuperCPU/normal flag
aceNmiWork        = aceStatB+118 ;(2)   ;for redirecting NMIs on the C64
aceCurDirName     = aceStatB+128 ;(128) ;name of current directory

aceMemTypes       = 4
;===end of kernel header info===
