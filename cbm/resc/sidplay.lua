-- Important variables used
local sidhdr = ""			-- header bytes of sid
local sidprg  				-- relocated program of sid
local useMock = false   -- Mock IO for testing
local handler = require("idun-handler")

local function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

local function relocSid(fname)
	local RELOCCMD = "sidreloc -s -t 0 -p 71 -z 02-5f --frames 20000 -q "
	local TMPFNAME = "/tmp/sidreloc.sid"
	assert(fname, "missing argument: sid file")

	-- Check extension
	if not ends_with(fname, ".sid") then
		return 4
	end

	-- Check type is PSID
	local psid = io.open(fname, "r")
	local prefix = psid:read(4)
	psid:close()
	if prefix ~= "PSID" then
		return 4
	end

	-- Run `sidreloc` command
	local retval = os.execute(RELOCCMD..fname.." "..TMPFNAME)
	if retval then
		local sid = io.open(TMPFNAME, "rb")
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

function handler.handleRequest(req)
	-- Open and relocate sid file on first request
	if string.len(sidhdr) == 0 then
	  local res = relocSid(arg[1])
     io.write(string.format("relocSid on %s returns %d\n", arg[1], res))
	  if res > 0 then
	     return nil, res
	  end
	end

	-- Allowed requests: "H"=get sid header, "P"=get sid program
	if req == "H" then
		return sidhdr
	elseif req == "P" then
		-- Prepend with the size
		local resp = string.pack("<H", #sidprg)
		return resp .. sidprg
	else
		return nil, 3  	-- Bad request
	end
end

handler.run(useMock)
