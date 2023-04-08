--[[
Lua script for displaying Idun help text in the termimal.
Uses the "eansi" module for text decoration.
--]]

local eansi = require "eansi"
local minisock = require("minisock")
-- luacheck:globals redirect sys

-- table to hold command help text
local helptxt = {}
local rows, columns = redirect.rows, redirect.columns

-- ansi shortcuts
eansi.palette("title","yellow")
eansi.palette("comment","faint")
local clear = "\27[H\27[2J\27[H"

---------------
-- Word wrap
---------------
local function splittokens(s)
    local res = {}
    for w in s:gmatch("%S+") do
        res[#res+1] = w
    end
    return res
end

local function textwrap(text, linewidth)
    if not linewidth then
        linewidth = 80
    end

    local spaceleft = linewidth
    local res = {}
    local line = {}

    for _, word in ipairs(splittokens(text)) do
        if #word + 1 > spaceleft then
            table.insert(res, table.concat(line, ' '))
            line = {word}
            spaceleft = linewidth - #word
        else
            table.insert(line, word)
            spaceleft = spaceleft - (#word + 1)
        end
    end

    table.insert(res, table.concat(line, ' '))
    return table.concat(res, '\r\n')
end

------------------
-- Helpers
------------------
-- shortcut for output
local function out(s)
	if #s>0 then minisock.write(redirect.stdout, s) end
end

-- shortcut for output with n linefeeds
local function outlf(n, s)
	out(s)
	out(string.rep("\r\n",n))
end

local function curpos(r, c)
	out(string.format("\27[%d;%dH", r, c))
end

local function waitkey()
	local erase = "\27[2K"
	local key

	out('Any key to continue?')
	repeat
		key = minisock.read(redirect.stdin, 10000)  --10 sec timeout
	until key ~= nil
	out(erase)
	curpos(rows, 1)
end

-- list commands w/ short help
local function lc(cmd)
	local short = string.gsub(helptxt[cmd]['short'], '\n', '')
	return eansi('${green}'..cmd..'${white}'..' -'..short)
end

-- full command helptext
local function fc(msg)
	if string.sub(msg, 1, 1)=='<' then
		local f = io.open('sys/'..string.sub(msg, 2), 'r')
		local count = 1
		local line = f:read('*l')
		out(clear)
		while line do
			outlf(1, eansi(line))
			count = count + 1
			if count==rows-1 then
				waitkey()
				count = 1
			end
			line = f:read('*l')
		end
		f:close()
	else
		outlf(1, '')
		outlf(2, eansi(textwrap(msg, columns)))
	end
end

---------------------
-- Display help text
---------------------
local function loadtxt()
	local f = io.open('sys/commands.hlp', 'r')
	local cmd = f:read('*l')
	while cmd do
		local next = {}
		next['short'] = f:read('*l')
		next['long'] = f:read('*l')
		helptxt[cmd] = next
		cmd = f:read('*l')
	end
	f:close()
end

local function cmd_iter()
	local i = {}
	for k in next, helptxt do
		table.insert(i, k)
	end
	table.sort(i)
	return function()
		local k = table.remove(i, 1)
		if k ~= nil then return k, helptxt[k] end
	end
end

local function cmdhelp(a_cmd)
	if a_cmd and #a_cmd>0 and a_cmd~='l' and a_cmd~='list' then
		-- show full help for a_cmd
		if helptxt[a_cmd] then
			fc(helptxt[a_cmd]['long'])
		else
			outlf(1, '')
			outlf(1, eansi('${red}Not recognized${white}'))
		end
	else
		-- show list of commands
		out(clear)
		local count, col = 1, 1
		for k in cmd_iter() do
			if columns<80 then
				outlf(1, lc(k))
				count = count+1
			elseif col==1 then
				out(lc(k))
				col = 40
			else
				curpos(count, 40)
				outlf(1, lc(k))
				col = 1
				count = count+1
			end
			if columns<80 and count==rows then
				waitkey()
				count = 1
			end
		end
		outlf(1, '')
	end
end

------------------
-- Main loop
------------------
local mycmd = arg[1]
-- Switch to directory with .hlp files
local path = os.getenv('IDUN_SYS_DIR')
sys.chdir(path)
loadtxt()

repeat
	local input, count, quit

	if not mycmd then mycmd='list' end
	mycmd = string.gsub(mycmd, '%s+', '')
	cmdhelp(mycmd)

	mycmd = ''
	curpos(rows, 1)
	out("Enter command, or 'l'ist, or 'q'uit? ")
	count = 0
	repeat
		input = minisock.read(redirect.stdin, 10000)  --10 sec timeout
		if input then
			out(input)
			count = count+1
			mycmd = mycmd..input
		end
		quit = (count==1 and input=='q') or mycmd=='quit'
	until quit or input=='\r'
until quit
outlf(1, '')
