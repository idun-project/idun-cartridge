--[[
    info.get = function(path)
        Parse the VERSION.NFO file in 'path' and return
        a table of attributes for the game.
--]]

local info = {}
local keys = {"Unique-ID","Published","Developer","Coding","Graphics","Music",
    "Language","Genre","Players","Control","Trainers"}
local vlen = {6, 16, 16, 16, 16, 16, 13, 16, 2, 8, 2}

local function parse_genre(gen, length)
    local i, _ = gen:find(' -', 1, true)
    if not i then
        return gen
    else
        local res = string.sub(gen, 1, i-1)
        res = res .. ":" .. string.sub(gen, i+3)
        if res:len()>length then res = string.sub(res, 1, length) end
        return res
    end
end

local function parse_control(ctl, length)
    local i, j = ctl:find('Joystick ', 1, true)
    if i==1 then
        return string.sub(ctl, j+1, j+length)
    else
        return ctl
    end
end

info.get = function(path)
    local result = {}

    path = path..'VERSION.NFO'
    local finfo, _ = io.open(path)
    if not finfo then
        io.write("Failed to open "..path.."\n")
        return result
    end

    local l = finfo:read('*l')
    local k = 1
    while l do
        local pat = keys[k]..': '
        local i,j = l:find(pat, 1, true)
        if i==1 then
            local v
            if k==8 then
                v = parse_genre(string.sub(l, j+1), vlen[k])
            elseif k==9 and string.sub(l, j+1, j+5)=='1 - 2' then
                v = '2P'
            elseif k==10 then
                v = parse_control(string.sub(l, j+1), vlen[k])
            else
                v = string.sub(l, j+1, j+vlen[k])
            end
            assert(v)
            if v:find('(None)', 1, true)~=1 and v:find('(Unknown)', 1, true)~=1 then
                if string.byte(v, -1) == 13 then v = string.sub(v, 1, -2) end
                result[keys[k]] = v
            end
            k = k+1
            if k>#keys then break end
        end
        l = finfo:read('*l')
    end
    finfo:close()

    -- Don't be too redundant
    if result['Graphics']==result['Coding'] then result['Graphics']=nil end
    return result
end

return info