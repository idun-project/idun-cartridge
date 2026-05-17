local util = require('idun-util')
-- Important variables used
local sidhdr = ""			-- header bytes of sid
local sidprg  				-- relocated program of sid
local sidplay = {}

local function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

local function relocSid(fname)
	local RELOCCMD = "sidreloc -s -t 0 -p 71 -z 02-5f --frames 20000 -q "
	local TMPFNAME = "/tmp/sidreloc.sid"

	-- Check extension
	if (not fname) or (not ends_with(fname, ".sid")) then
		return 4
	end

	-- Check type is PSID
	local psid = io.open(fname, "r")
	if not psid then return 4 end
	local prefix = psid:read(4)
	psid:close()
	if prefix ~= "PSID" then
		return 4
	end

	-- Run `sidreloc` command
	local retval = os.execute(RELOCCMD..fname.." "..TMPFNAME)
	if retval then
		local sid = io.open(TMPFNAME, "rb")
		if not sid then return 2 end
		local data = sid:read("*all")
		sid:close()
		-- Check PSID version and load addr
		if data:sub(1, 4) ~= "PSID" then
			return 2
		end
		if data:byte(5) ~= 0x00 or data:byte(6) ~= 0x02 or data:byte(8) ~= 0x7c then
			return 2 	-- Must be PSIDv2
		end
		if data:byte(9) ~= 0x00 or data:byte(10) ~= 0x00 then
			return 2 	-- Must be 0x7100 load addr
		end
		if data:byte(125) ~= 0x00 or data:byte(126) ~= 0x71 then
			return 2 	-- Must be 0x7100 load addr
		end
		sidhdr = string.sub(data, 1, 0x7e)
		sidprg = string.sub(data, 0x7f)
		return 0
	else
		return 3
	end
end

sidplay.load = function(packed)
	local sidfile = string.unpack('s2', packed)
	sidfile = util.pet2asc(sidfile)
	-- Open and relocate sid file on first request
	local res = relocSid(sidfile)
	io.write(string.format("relocSid on %s returns %d\n", sidfile, res))
	if res > 0 then
		m8.err(res)
	else
		m8.ret(sidhdr)
	end
end

sidplay.getsid = function()
	m8.ret(sidprg)
end

return sidplay
