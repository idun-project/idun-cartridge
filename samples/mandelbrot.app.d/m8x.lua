-- idunc: generated file ! DO NOT MODIFY !
local m8 = require("m8api")
local _ = require("mailbox")

m8.drawit = function(bitmap, chkparam)
    if chkparam then chkparam(bitmap) end
    m8.mailbox(_.m8_drawit_box, bitmap)
    local rc = m8.Exec(_.m8_drawit_box)
    assert(rc ~= nil, "drawit() fail")
    return rc
end
