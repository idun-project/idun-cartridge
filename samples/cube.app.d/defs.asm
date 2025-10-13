;Application definition below OK
;UI constants
FIRST_TILE_OFFS = 211
TILE_STRIDE     = 40
;zero-page vars
initSize     = $03   ;(1)
scrPage      = $04   ;(1)
chrPage1     = $05   ;(1)
chrPage2     = $06   ;(1)
activePage   = $07   ;(1)
scrPtr       = $08   ;(2)
cbDataSz     = $0a   ;(1)
temp         = $0b   ;(1)
;need this kernel location
aceVic40Page = aceStatB+96
