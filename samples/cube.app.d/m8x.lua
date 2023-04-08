-- idunc: generated file ! DO NOT MODIFY !
local m8 = require("m8api")
local _ = require("mailbox")

m8.nframe = function(vlist, chkparam)
    -- Use 2 polygon quads and 4 lines to draw cube from 8 vertices
    local verts = ""
    for _,v in ipairs(vlist) do
        verts = verts .. string.pack(">H>H", v[1], v[2])
    end
    for i = 1,4 do
        verts = verts .. string.pack(">H>H>H>H",
                vlist[i][1], vlist[i][2], vlist[i+4][1], vlist[i+4][2])
    end
    if chkparam then chkparam(verts) end
    m8.mailbox(_.m8_nframe_box, verts)
    local rc = m8.Exec(_.m8_nframe_box)
    assert(rc ~= nil, "nframe() fail")
    return rc
end
