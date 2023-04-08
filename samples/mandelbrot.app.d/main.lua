--[[
idunc directives:
!use "toolx.vdc"
!use "toolx.vdc.pointer"
!m8x drawit(bitmap)

]]--

local m8 = require("m8api")
require("m8x")

-- Parameter checking for m8 extension - drawit()
local function check_bitmap_sz(bitmap)
    assert(bitmap:len() == 9216, "drawit() bitmap size")
end

-- mandelbrot dimensions
local N = 256
local W, H, M, limit2 = N, N, 64, 4.0
-- mandelbrot compute parameters
local fscale, xmin, ymax = 2.0, -1.5, 1.0
local palcbm = {
    string.char(0x01),      -- Black
    string.char(0xa0),      -- Dark Purple
    string.char(0x20),      -- Dark Blue
    string.char(0x40),      -- Dark Green
    string.char(0x60),      -- Dark Cyan
    string.char(0xc0),      -- Dark Yellow
    string.char(0x80),      -- Dark Red
    string.char(0x10),      -- Dark Gray
    string.char(0xba),      -- Light Purple
    string.char(0x32),      -- Light Blue
    string.char(0x54),      -- Light Green
    string.char(0x76),      -- Light Cyan
    string.char(0xdc),      -- Light Yellow
    string.char(0x98),      -- Light Red
    string.char(0xed),      -- Light Gray
    string.char(0xfe)       -- White
}

-- Convert mandelbrot iteration values to palette entries
local attr = ""
local function attrcolor(i)
    local c = (M - i) / (M / 16)
    attr = attr .. palcbm[math.floor(c) + 1]
end

-- Compute low-res color mandelbrot to overlay mono image
local function do_colormap(width, height, colorfn)
    local scale = fscale / width
    for y = 0, height - 1 do
        local Ci = y * scale - ymax
        for x = 0, width - 1 do
            local Cr = x * scale + xmin
            local Zr, Zi, Zrq, Ziq = Cr, Ci, Cr * Cr, Ci * Ci
            local member = true
            for i = 1, M do
                Zi = Zr * Zi * 2 + Ci
                Zr = Zrq - Ziq + Cr
                Ziq = Zi * Zi
                Zrq = Zr * Zr
                if Zrq + Ziq > limit2 then
                    colorfn(i)
                    member = false
                    break
                end
            end
            if member then colorfn(M) end
        end
    end
end

-- Compute a monochrome bitmap mandelbrot image
local function monomap(width, height)
    local ba, bb = 2 ^ (width % 8 + 1) - 1, 2 ^ (8 - width % 8)
    local scale = fscale / width
    local bitmap = ""
    for y = 0, height - 1 do
        local Ci, b, buf = y * scale - ymax, 1, ""
        for x = 0, width - 1 do
            local Cr = x * scale + xmin
            local Zr, Zi, Zrq, Ziq = Cr, Ci, Cr * Cr, Ci * Ci
            b = b + b
            for _ = 1, M do
                Zi = Zr * Zi * 2 + Ci
                Zr = Zrq - Ziq + Cr
                Ziq = Zi * Zi
                Zrq = Zr * Zr
                if Zrq + Ziq > limit2 then
                    b = b + 1;
                    break
                end
            end
            if b >= 256 then
                buf = buf .. string.char(511 - b);
                b = 1;
            end
        end
        if b ~= 1 then
            buf = buf .. string.char((ba - b) * bb);
        end
        bitmap = bitmap .. buf
    end
    return bitmap
end

local views = {}

local function compute()
    local bmap = monomap(W, H)
    attr = ""
    do_colormap(32, 32, attrcolor)
    bmap = bmap .. attr
    m8.drawit(bmap, check_bitmap_sz)
end

-- main loop
compute()
while true do
    local btn,x,y = m8.waitevent()
    if btn and btn == m8.EVENT.POINTER.LMB_CLICK then
        -- Zoom In by scaling by 2x and re-centering
        table.insert(views, {fscale, xmin, ymax})
        local xc = xmin + (fscale / 256) * x
        local yc = ymax - (fscale / 256) * y
        fscale = fscale / 2
        xmin = xc - fscale / 2
        ymax = yc + fscale / 2
        compute()
    elseif btn and btn == m8.EVENT.POINTER.RMB_CLICK then
        -- Zoom out to previous view
        if #views > 0 then
            local pop = table.remove(views)
            fscale, xmin, ymax = pop[1], pop[2], pop[3]
            compute()
        end
    end
end
