local m8 = require("m8api")
local _ = require("mailbox")

local function flatten(list_of_tables)
    local parts = {}
    for i, sub in ipairs(list_of_tables) do
        parts[i] = string.char(table.unpack(sub))
    end
    return table.concat(parts)
end

m8.nframe = function(list, chkparam)
    local bm = flatten(list)
    if chkparam then chkparam(bm) end
    m8.mailbox(_.m8_nframe_box, bm)
    local rc = m8.Exec(_.m8_nframe_box)
    assert(rc ~= nil, "nframe() fail")
    return rc
end
