--[[
idunc directives:
!set TOOLBAR=1
!set TOOLMENU=1
!set main_menu = {
    "1" = {
        text = "Restart"
        code = 0x20
    }
    "2" = {
        text = "Exit to Shell"
        code = 0x03
    }
}

]]--
local m8 = require("m8api")

local function primeGenerator()
    local _cand = 0;
    local _lstbp = 3;
    local _lstsqr = 9
    local _composites = {};
    local _bps = nil
    local _self = {}
    function _self.next()
        if _cand < 9 then
            if _cand < 1 then
                _cand = 1;
                return 2
            elseif _cand >= 7 then
                -- advance aux source base primes to 3...
                _bps = primeGenerator()
                _bps.next();
                _bps.next()
            end
        end
        _cand = _cand + 2
        if _composites[_cand] == nil then -- may be prime
            if _cand >= _lstsqr then -- if not the next base prime
                local adv = _lstbp + _lstbp -- if next base prime
                _composites[_lstbp * _lstbp + adv] = adv -- add cull seq
                _lstbp = _bps.next();
                _lstsqr = _lstbp * _lstbp -- adv next base prime
                return _self.next()
            else
                return _cand
            end -- is prime
        else
            local v = _composites[_cand]
            _composites[_cand] = nil
            local nv = _cand + v
            while _composites[nv] ~= nil do nv = nv + v end
            _composites[nv] = v
            return _self.next()
        end
    end
    return _self
end

local function checkRestart()
    local type, id, _ = m8.waitevent()
    if type == 0xff and id == 2 then
        return true
    else
        return false
    end
end

local function main()
    local line = ""
    local prime = 1
    local gen = primeGenerator()
    while prime < 100000 do
        prime = gen.next()
        line = line .. prime .. " "
        if line:len() >= 75 then
            if m8.writeln(line) == nil and checkRestart() then
                gen = primeGenerator()
            end
            line = ""
        end
    end
    m8.writeln(line)
end

main()
