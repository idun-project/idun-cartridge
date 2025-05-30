* = aceToolboxEnd

jmp GfxInit
!byte aceID1,aceID2,aceID3
!byte 64,0  ;** stack,reserved

; Jump table
xGrInit:        jmp GfxInit
xGrMode:        jmp xVdcGrMode
xGrExtents:     jmp xVdcGrExtents
xGrOp:          jmp xVdcGrOp
xGrAttr:        jmp xVdcGrAttr
xGrClear:       jmp xVdcMemClear
xGrDblBuffer:   jmp xVdcDblBuffer
xGrBufswap:     jmp xVdcBufswap
xGrBitmapAddr:  jmp notImpl
xGrScreenAddr:  jmp notImpl
xPlot:          jmp xVdcPlot
xPolygon:       jmp xVdcPolygon

!source "toolx/vdc/core.asm"
!source "toolx/vdc/draw.asm"
!source "toolx/vic/core.asm"

!zone xGfx
WIN_DRIVER_VDC      = %10001000
WIN_DRIVER_VIC80    = %10000010
notImpl = *
   lda #aceErrNotImplemented
   sta errno
   sec
   rts

xVicGfx !word xVicGrMode,notImpl,xVicGrOp,notImpl,GrFill,notImpl,notImpl,BitmapAddr,ColorAddr,notImpl,notImpl
GfxInit = *
    jsr aceMiscSysType
    cmp #WIN_DRIVER_VDC
    bne +
    jmp GfxToolxEnd
+   ldx #16
    jsr aceConOption
    and WIN_DRIVER_VIC80
    bne +
    ; Cannot use Gfx with text mode VIC-II driver on C64
    lda #<xGrMode
    ldy #>xGrMode
    sta syswork
    sty syswork+1
    ldy #32
-   lda #>notImpl
    sta (syswork),y
    dey
    lda #<notImpl
    sta (syswork),y
    dey
    dey
    bpl -
    jmp GfxToolxEnd
+   lda #<xGrMode
    ldy #>xGrMode
    sta syswork
    sty syswork+1
    ldx #(GfxInit-xVicGfx-1)
    ldy #32
-   lda xVicGfx,x
    sta (syswork),y
    dey
    dex
    lda xVicGfx,x
    sta (syswork),y
    dey
    dey
    dex
    bpl -
GfxToolxEnd = *
