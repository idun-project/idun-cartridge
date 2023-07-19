-- Constant
local util = require('idun-util')
local gamelist = require('gamelist')
local serpent = require('serpent')
local search = require('search')
local info = require('info')
local lfs = require('lfs')
local d64 = require('d64reader')
require ('iconv')

local m8
local gamedb, found, prglist = {}, {}, {}
local result_start, _ = 0, nil
local searchstr, select_gid, select_path, disk_image_path = "", "", "", ""

-- Helper function to split search string
local function splittokens(s)
    local res = {}
    for w in s:gmatch("%S+") do
        res[#res+1] = w
    end
    return res
end

-- Helper function to pad strings + nul char
local function pads(str, length)
    local pad = string.format('%-'..length..'s', str)
    if pad:len()>length then pad = string.sub(pad, 1, length) end
    return string.pack('c'..length..'b', pad, 0)
end

-- Helper function to get PRG names from P64 files
local function parse_p64(path, fname)
    local _, e = string.find(fname, "%.[Pp]0%d")
    if e ~= fname:len() then return false, nil end
    local file = io.open(path..'/'..fname, "rb")
    assert(file, "Failed opening P64 file: "..fname)
    local hdr = file:read(26)
    local s, _, prgname = string.find(hdr, "C64File%z([%w%p%s]+)%z")
    assert(s==1, "Failed parsing P64 file")
    return true, prgname
end

-- Parameter checking for m8 extensions
local function check_results_sz(msg)
    assert(msg:len()==1+10+21*23, "results() msg error")
end

local function check_inform_sz(msg)
    assert(msg:len()==140, "inform() msg error")
end

local function check_prglist_sz(msg)
    assert(msg:len()==9*17+2, "programs() msg error")
end

local function update_search_results(start, total, sz)
    local asc = ""
    if not sz then sz = math.min(#found-start+1, 21) end
    local msg = string.pack('b', sz)
    -- Append the overall results/count
    msg = msg .. string.format("%4d/%-5d", start, total)
    -- Append the search results
    for i = start, start+sz-1 do
        asc = pads(gamedb['alpha'][found[i]][1], 22)
        msg = msg .. util.asc2pet(asc)
    end
    -- Pad the unused rows with blank entries
    for i = sz+1, 21 do
        msg = msg .. pads(' ', 22)
    end
    m8.results(msg, check_results_sz)
    result_start = start
end

local function update_program_list()
    local disk = 0x00
    if disk_image_path ~= '' then
        disk = 0xff
    end
    local sz = math.min(#prglist, 9)
    -- First byte is TRUE when it's a D64 image
    local msg = string.pack('BB', disk, sz)
    for i = 1, sz do
        msg = msg .. pads(prglist[i], 16)
    end
    -- Pad the unused rows with blank entries
    for i = sz+1, 9 do
        msg = msg .. pads(' ', 16)
    end
    m8.programs(msg, check_prglist_sz)
end

local function clearsearch(n)
    -- Set found to first 21 gamelist entries
    found = {}
    for i = n,n+20 do
        found[i] = i
    end
    update_search_results(n, #gamedb['alpha'], 21)
end

-- Event handlers
function Ev_key_search(c)
    if c == 0x14 then   -- Backspace
        if searchstr:len() > 1 then
            searchstr = string.sub(searchstr, 1, -2)
        else
            searchstr = ''
            clearsearch(1)
            return
        end
    else
        local ch = string.char(c)
        searchstr = searchstr..ch
    end

    local terms = splittokens(util.pet2asc(searchstr))
    found = search.get(terms[1])
    local i = 2
    while i <= #terms do
        found = search.incremental(found, terms[i])
        i = i+1
    end
    if #found>0 then update_search_results(1, #found) else clearsearch(1) end
end

function Ev_key_hotkey(c)
    if c == 0x16 or c == 0x17 then
        if c == 0x16 then
            -- previous page
            result_start = math.max(result_start-21, 1)
        else
            -- next page
            result_start = result_start+21
        end

        if result_start <= #found then
            update_search_results(result_start, #found)
        else
            clearsearch(result_start)
        end
        return
    end
    if c == 0x0d then
        prglist = {}
        disk_image_path = ''
        for file in lfs.dir(select_path) do
            local ufile = string.upper(file)
            if string.sub(ufile, -4) == ".D64" then
                -- list only PRG files
                local dirlist = d64.directory(select_path..file, 0x82)
                for _, v in pairs(dirlist) do
                    table.insert(prglist, v.name)
                end
                disk_image_path = ':'..select_path..file
                break
            elseif string.sub(ufile, -4) == ".PRG" then
                table.insert(prglist, util.asc2pet(file))
            else
                local p00, prgname = parse_p64(select_path, file)
                if p00 then table.insert(prglist, prgname) end
            end
        end
        update_program_list()
    end
    if c == 0x85 then   --F1 key
        -- Show Recents
        local r = gamelist.recents()
        if not r or #r==0 then
            clearsearch(1)
        else
            found = {}
            for i = 1,#r do
                found[i] = gamedb['byid'][r[i]]
            end
            update_search_results(1, #found)
        end
    end
    if c == 0x86 then   --F3 key
        -- Show Favorites
        local f = gamelist.favorites()
        if not f or #f==0 then
            clearsearch(1)
        else
            found = {}
            for i = 1,#f do
                found[i] = gamedb['byid'][f[i]]
            end
            update_search_results(1, #found)
        end
    end
    if c == 0x88 then   --F7 key
        gamelist.favorite(select_gid)
    end
end

function Ev_select_results(s)
    s = s + result_start - 1
    assert(found[s], string.format("No result slected by %d",s))
    select_gid = gamedb['alpha'][found[s]][3]
    select_path = string.toutf8(gamedb['alpha'][found[s]][2])
    local i = info.get(select_path)
    local inf = string.format("%4d", s)
    if i['Published'] then
        inf = inf..util.asc2pet(pads(i['Published'], 16))
    else
        inf = inf..util.asc2pet(pads("   (Unknown)", 16))
    end
    local bylines = 3
    if i['Developer'] then
        inf = inf..util.asc2pet(pads(i['Developer'], 16))
        bylines = bylines-1
    end
    if i['Coding'] then
        inf = inf..util.asc2pet(pads(i['Coding'], 16))
        bylines = bylines-1
    end
    if i['Graphics'] then
        inf = inf..util.asc2pet(pads(i['Graphics'], 16))
        bylines = bylines-1
    end
    if i['Music'] and bylines>0 then
        inf = inf..util.asc2pet(pads(i['Music'], 16))
        bylines = bylines-1
    end
    while bylines > 0 do
        inf = inf..pads(' ', 16)
        bylines = bylines-1
    end
    if i['Language'] then
        inf = inf..util.asc2pet(pads("in "..i['Language'], 16))
    else
        inf = inf..util.asc2pet(pads("in (Unknown)", 16))
    end
    if i['Genre'] then
        inf = inf..util.asc2pet(pads(i['Genre'], 16))
    else
        inf = inf..pads(' ', 16)
    end
    if i['Players'] and i['Control'] then
        local ctl = pads(i['Players'].."  "..i['Control'], 16)
        inf = inf..util.asc2pet(ctl)
    else
        inf = inf..pads(' ', 16)
    end
    if i['Trainers'] then
        inf = inf..util.asc2pet(pads("Trainers:"..i['Trainers'], 16))
    else
        inf = inf..util.asc2pet(pads("Trainers:0", 16))
    end
    m8.inform(inf, check_inform_sz)
end

function Ev_select_gamefiles(s)
    local i = tonumber(s)
    local path = select_path
    if disk_image_path ~= '' then
        path = disk_image_path
    end
    local msg = string.pack("zz", util.asc2pet(path), prglist[i])
    -- Add to recents list
    gamelist.recent(select_gid)
    m8.launch(msg)
end

-- Only import these after defining Event handlers
m8 = require('m8api')
require('m8x')

local function load_game_data()
    local fidx, _ = io.open('gamelist.idx')
    local db
    if not fidx then
        io.write("Generating index...")
        db = gamelist.load()
        fidx, _ = io.open('gamelist.idx', 'w')
        assert(fidx, "Error creating game index")
        fidx:write(serpent.dump(db))
        fidx:close()
    else
        local ok
        local dumpstr = fidx:read('*a')
        ok, db = serpent.load(dumpstr)
        assert(ok, "Error loading game index")
    end
    return db
end

m8.VERBOSE = false
-- Load the gamelist
sys.chdir("g:")
gamedb = load_game_data()
search.setdb(gamedb)

-- Main application initialize
clearsearch(1)

-- Main application loop
while true do
    local type, id, p = m8.waitevent()
    if type then
        assert(type <= #m8.EVENT, "Invalid event type:"..type)
        local ev = m8.EVENT[type]
        assert(id <= #ev, "Invalid event id:"..id)
        ev[id](p)
    end
end
