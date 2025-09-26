local m8 = require("m8api")
local cairo = require("oocairo")
require("m8x")

-- Constants
XTILES = 18
YTILES = 14

-- Parameter checking for m8 extension - nframe()
local function check_tile_cnt(bitmap)
  assert(#bitmap == XTILES*YTILES*8, "tileset size")
end

local floor,cos,pi,sin = math.floor,math.cos,math.pi,math.sin
local L = 0.5
local cube = {
  verts = { {L,L,L}, {L,-L,L}, {-L,-L,L}, {-L,L,L}, {L,L,-L}, {L,-L,-L}, {-L,-L,-L}, {-L,L,-L} },
  rotate = function(self, rx, ry)
    local cx,sx = cos(rx),sin(rx)
    local cy,sy = cos(ry),sin(ry)
    for _,v in ipairs(self.verts) do
      local x,y,z = v[1],v[2],v[3]
      v[1], v[2], v[3] = x*cx-z*sx, y*cy-x*sx*sy-z*cx*sy, x*sx*cy+y*sy+z*cx*cy
    end
  end,
}

-- Create an A8 (8-bit alpha) Cairo surface and context
local function create_surface(width, height)
    local surface = cairo.image_surface_create("a8", width, height)
    local cr = cairo.context_create(surface)

    -- Disable antialias pixels
    cr:set_antialias("none")

    -- Draw with solid "on" pixels
    cr:set_source_rgba(1, 1, 1, 1)  -- white in alpha channel = "set pixel"
    cr:set_line_width(1.0)

    return surface, cr
end

local render = function(ctxt, shape, focal, width, height)
  local ox, oy = 72,56
  local mx, my = width/2, height/2
  local rpverts = {}

  -- Clear surface (set all pixels to 0)
  ctxt:set_operator("clear")
  ctxt:paint()
  ctxt:set_operator("over")

  -- Set "ink" to white (1)
  ctxt:set_source_rgba(1, 1, 1, 1)

  -- Calculate the edges
  for i,v in ipairs(shape.verts) do
    local x,y,z = v[1],v[2],v[3]
    local px = ox + mx * (focal*x)/(focal-z)
    local py = oy + my * (focal*y)/(focal-z)
    rpverts[i] = { floor(px), floor(py) }
  end
  
  -- Draw the edges
  local m = rpverts[1]
  local l = rpverts[2]
  ctxt:move_to(m[1], m[2])
  ctxt:line_to(l[1], l[2])
  l = rpverts[3]
  ctxt:line_to(l[1], l[2])
  l = rpverts[4]
  ctxt:line_to(l[1], l[2])
  ctxt:line_to(m[1], m[2])

  m = rpverts[5]
  l = rpverts[6]
  ctxt:move_to(m[1], m[2])
  ctxt:line_to(l[1], l[2])
  l = rpverts[7]
  ctxt:line_to(l[1], l[2])
  l = rpverts[8]
  ctxt:line_to(l[1], l[2])
  ctxt:line_to(m[1], m[2])

  for i = 1,4 do
    local m,l = rpverts[i], rpverts[i+4]
    ctxt:move_to(m[1], m[2])
    ctxt:line_to(l[1], l[2])
  end
  ctxt:stroke()
end

-- Shallow copy function for duplicating array
local function acopy(input)
  local out = {}
  for i = 1, #input do
    out[i] = input[i]
  end
  return out
end

-- Convert the raster bitmap to VIC-II order
local function get_tiles(bm, tilerow, cols)
  local tiles = {}
  cols = cols or XTILES
  tilerow = tilerow - 1
  for c = 0,cols-1 do
    local ri, ci = tilerow*8+1, c+1
    for y = 0,7 do
      local bmrow = ri + y
      local pixels = bm[bmrow][ci]
      table.insert(tiles, pixels)
    end
  end
  return tiles
end

local function rasterize(surface, width, height, threshold)
  local raw = surface:get_data()
  local bm1,tileset = {},{}
  threshold = threshold or 128

  -- Convert 8bpp grayscale to 1bpp bitmap
  local stride = math.ceil(width / 8) -- bytes per row
  for y = 0, height - 1 do
      local row = {}
      for bx = 0, stride - 1 do
          local byte = 0
          for bit = 0, 7 do
              local x = bx * 8 + bit
              if x < width then
                  local idx = y * width + x + 1 -- Lua string index is 1-based
                  local val = raw:byte(idx)
                  if val >= threshold then
                      byte = byte | (1 << (7 - bit))
                  end
              end
          end
          table.insert(row, byte)
      end
      table.insert(bm1, acopy(row))
  end

  -- Convert the bitmap to VIC-II tileset
  for tilerow = 1, YTILES do
    local t = get_tiles(bm1, tilerow)
    table.insert(tileset, acopy(t))
  end

  return tileset
end

local surface,context = create_surface(XTILES*8, YTILES*8)
while true do
  cube:rotate(pi/30, pi/45)
  render(context, cube, 2.0, XTILES*8, YTILES*8)
  local vic_tileset = rasterize(surface, XTILES*8, YTILES*8)
  m8.nframe(vic_tileset, check_tile_cnt)
end
