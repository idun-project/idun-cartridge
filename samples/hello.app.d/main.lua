--[[
idunc directives:
!set TOOLBAR=1
!set TOOLMENU=1
!set main_menu = {
    "1" = {
        text = "Exit to Shell"
        code = 0x03
    }
}

]]--
local m8 = require("m8api")
local util = require("idun-util")

for i = 1,25 do
    m8.writeln(util.asc2pet("Hello, world!"))
end
