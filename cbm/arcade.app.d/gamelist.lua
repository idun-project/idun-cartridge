--[[
	gamelist.load = function()
	returns a 3 element table:
	['alpha'] - alphabetical array of game names with path
	['byid'] - lookup table for game id->alpha entry index
	['keyword'] - lookup table for keyword->alpha entry index

	gamelist.recents = function()
	returns table of recent game id's

	gamelist.recent = function(game_id)
	update recents table with game_id added

	gamelist.favorites = function()
	returns table of favorite game id's

	gamelist.favorite = function(game_id)
	update favorites table with game_id added
--]]
local serialize = require('serpent')

local function parse_row(input, sep, pos)
	local row = {}
	pos = pos or 1
	--io.read()
	while true do
		local c = string.sub(input,pos,pos)
		if (c == "") then break end
		if (c == '"') then
			local text = ''
			local s,e,txt,c1
			repeat
				s,e,txt,c1 = string.find(input, '^(.-")(.)', pos+1)
				text = text..txt
				pos = e
			until ((c1 == sep) or (c1 == "\r") or (c1 == "\n"))
			table.insert(row, string.sub(text,1,-2))
			c = c1
			pos = pos + 1
		else
			local s,e,text,c1 = string.find(input, "^([^%"..sep.."\r\n]-)([%"..sep.."\r\n])", pos)
			pos = e+1
			table.insert(row, text)
			c = c1
		end
		if c == "\n" then
			return row, pos
		end
		if c == "\r" then
			return row, pos+1
		end
	end
end

local cmap = {
	[0xc4] = 0x41,
	[0xc5] = 0x41,
	[0xd6] = 0x4f,
	[0xda] = 0x55,
	[0xdc] = 0x55,
	[0xfa] = 0x75,
}
local function remap(s)
	local result = s
	local sub = nil
	local c = string.byte(s, 1)
	if c > 0xbf then
		for i,v in pairs(cmap) do
			if c == i then
				sub = v
				break
			end
		end
		assert(sub ~= nil, "Character remap failed in gamelist source file")
		result = string.char(sub)..string.sub(result, 2)
	end
	return result
end

local gamelist = {}
gamelist.load = function()
    -- Remove header row
	local TMPFNAME = "/tmp/gamelist.out"
	local REMOVE1CMD = "tail -n +2 gamelist.csv > "..TMPFNAME
	local retval = os.execute(REMOVE1CMD)
	assert(retval, "Failed processing gamelist.csv file")
	-- Sort the gamelist
	retval = os.execute("sort -d "..TMPFNAME.." > gamelist.csv")
	assert(retval, "Failed processing gamelist.csv file")
	-- Load gamelist.csv and make index tables
	local f, _ = io.open('gamelist.csv')
	assert(f, "Cannot open required file gamelist.csv")
	local csv = f:read("*a")
	f:close()

	local sep = ','
	local pos = 1
    local t_alpha = {}
    local t_byid = {}
    local t_keyword = {}
    local t_idx = {}
	local row = {}
	row, pos = parse_row(csv, sep, pos)
	while row do
		local name = remap(row[1])
		table.insert(t_alpha, {name, string.gsub(row[2], '\\', '/'), row[3]})
        t_byid[row[3]] = #t_alpha
        local keywords, _ = parse_row(string.lower(name..'\n'), ' ', 1)
        for k,v in pairs(keywords) do
            if t_keyword[v] == nil then
                t_keyword[v] = {}
            end
            table.insert(t_keyword[v], #t_alpha)
        end
		row, pos = parse_row(csv, sep, pos)
	end
    t_idx['alpha'] = t_alpha
    t_idx['byid'] = t_byid
    t_idx['keyword'] = t_keyword
	return t_idx
end

gamelist.recents = function()
	local r = {}
	local f, _ = io.open('recents.idx', 'r')
	if f then
        local d = f:read('*a')
        Ok, r = serialize.load(d)
        assert(Ok, "Error loading recents index")
		f:close()
	end
	return r
end

gamelist.recent = function(game_id)
	local t = gamelist.recents()
	local is_rep = false
	if not t then t = {} end
	for _,v in ipairs(t) do
		if v == game_id then
			is_rep = true
			break
		end
	end
	if not is_rep then
		local f, _ = io.open('recents.idx', 'w')
		assert(f, "Failed to create recents index")

		table.insert(t, 1, game_id)
		-- Only save max. 42 recents
		if #t > 42 then table.remove(t) end

		f:write(serialize.dump(t))
		f:close()
	end
end

gamelist.favorites = function()
	local fav = {}
	local f, _ = io.open('favorites.idx', 'r')
	if f then
        local d = f:read('*a')
        Ok, fav = serialize.load(d)
        assert(Ok, "Error loading favorites index")
		f:close()
	end
	return fav
end

gamelist.favorite = function(game_id)
	local t = gamelist.favorites()
	local is_rep = false
	if not t then t = {} end
	for _,v in ipairs(t) do
		if v == game_id then
			is_rep = true
			break
		end
	end
	if not is_rep then
		local f, _ = io.open('favorites.idx', 'w')
		assert(f, "Failed to create favorites index")
		table.insert(t, 1, game_id)
		f:write(serialize.dump(t))
		f:close()
	end
end

return gamelist