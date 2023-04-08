--[[
idunc directives:
!use "toolx.vdc"
!use "toolx.vdc.draw"
!m8x nframe(verts)

]]--

local m8 = require("m8api")
require("m8x")

-- Parameter checking for m8 extension - nframe()
local function check_vertex_cnt(vlist)
    assert(#vlist == 16*4, "vertex list size")
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

local render = function(shape, focal, width, height)
  local ox, oy = width/2, height/2
  local mx, my = width/3, height/3
  local rpverts = {}
  for i,v in ipairs(shape.verts) do
    local x,y,z = v[1],v[2],v[3]
    local px = ox + mx * (focal*x)/(focal-z)
    local py = oy + my * (focal*y)/(focal-z)
    local modx = floor(px)//8*256 + floor(px)%8
    rpverts[i] = { modx, floor(py) }
  end
  return rpverts
end

while true do
  cube:rotate(pi/30, pi/45)
  local verts = render(cube, 2.5, 320, 256)
  m8.nframe(verts, check_vertex_cnt)
end
