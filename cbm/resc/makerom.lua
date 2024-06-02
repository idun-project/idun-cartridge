--[[
Lua script for creating patched kernal rom.
--]]
local eansi = require "eansi"
local minisock = require("minisock")
-- luacheck:globals redirect sys

-- Link for download
local kcombolink = 'http://www.zimmers.net/anonftp/pub/cbm/firmware/computers/c128/complete.318023-02.bin'
-- Local storage for downloads
local kcomborom = '/tmp/318023-02.rom'
-- Patch files
local pfile = 'sys/kernal128.patch'
-- Output files
local ofile = '/home/idun/U35.rom'
local ocombofile = '/home/idun/U32.rom'
-- Mssage text
local msg_k128_16k = 'Making patched C128 kernal ROM U35'
local msg_k128_32k = 'Making patched C128 kernal ROM U32'
-- Patched ROM checksums
local md5_U35 = '6e84d38652c147d57d320c97d75717c3'
local md5_U32 = '4c3a5d94e6cf1f094fd4a3cc6022b9be'
-- Critical ROM offsets
local KERNAL_OFFS = 0x6001
local KERNAL_ADDR = 0xe000

------------------
-- Helpers
------------------
-- shortcut for output
local function out(s)
	if #s>0 then minisock.write(redirect.stdout, s) end
    -- TESTING if #s>0 then io.write(s) end
end

-- shortcut for output with n linefeeds
local function outlf(n, s)
	if s~=nil then out(s) end
	out(string.rep("\r\n",n))
end

local function fetchRom(dest, src)
    out(eansi('${yellow}Getting standard ROM...'))
	local retval = os.execute("wget -q -O "..dest.." "..src)
    if retval ~= true then
        outlf(1)
        outlf(1, eansi('${red}Failed getting ROM file. Aborting.'))
    else
        outlf(1, eansi('${green}Done.'))
    end
    return retval
end

local function patchRom(roms, patchs, outf)
    local addr, count
    local offs = KERNAL_OFFS
    local i = 1
    while i<string.len(patchs) do
        addr = string.byte(patchs,i)+string.byte(patchs,i+1)*256
        count = string.byte(patchs,i+2)+string.byte(patchs,i+3)*256
        i = i+4
        addr = addr-KERNAL_ADDR
        -- Write original ROM code
        outf:write(string.sub(roms, offs, KERNAL_OFFS+addr-1))
        offs = KERNAL_OFFS + addr + count
        -- Write patch code
        outf:write(string.sub(patchs, i, i+count-1))
        i = i+count
    end
    outf:write(string.sub(roms, offs, 0x8000))
end

local function make16k(roms)
    local outf = assert(io.open(ofile, 'wb'))
    local patchf = assert(io.open(pfile, 'rb'))
    -- Read in the patch file
    local patchs = patchf:read("*all")
    patchf:close()
    -- Write first 8kb of original ROM unchanged
    outf:write(string.sub(roms, 0x4001, 0x6000))
    -- Apply the patch
    patchRom(roms, patchs, outf)
    outf:close()
    return ofile
end

local function make32k(roms)
    local outf = assert(io.open(ocombofile, 'wb'))
    local patchf = assert(io.open(pfile, 'rb'))
    -- Read in the patch file
    local patchs = patchf:read("*all")
    patchf:close()
    -- Write first 24kb of original ROM unchanged
    outf:write(string.sub(roms, 1, 0x6000))
    -- Apply the patch
    patchRom(roms, patchs, outf)
    outf:close()
    return ocombofile
end

local function md5(fname)
    local cmd = 'openssl dgst -md5 '..fname
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    return string.match(s,'^MD5%(%g+%)= (%x+)')
end

-- Main
local wants32k = false
local prom_fname, md5sum
sys.chdir(os.getenv('IDUN_SYS_DIR'))

-- Ensure we have unpatched rom file
local romf = io.open(kcomborom, 'rb')
if romf == nil then
    if fetchRom(kcomborom, kcombolink) then
        romf = assert(io.open(kcomborom, 'rb'))
    else
        os.exit(-1)
    end
end

-- Read in unpatched rom
local roms = romf:read("*all")
romf:close()

if arg[1] then
    wants32k = string.find(arg[1], '/32', 1, true)==1
end
if wants32k then
    outlf(1, eansi('${green}'..msg_k128_32k))
    prom_fname = make32k(roms)
    md5sum = md5_U32
else
    outlf(1, eansi('${green}'..msg_k128_16k))
    prom_fname = make16k(roms)
    md5sum = md5_U35
end

outlf(1, eansi('${green}Patched ROM saved to '..prom_fname))
out(eansi('${green}Verifying patched ROM checksum...'))
if md5(prom_fname)==md5sum then
    outlf(1, eansi('${green}PASSED'))
else
    outlf(1, eansi('${red}FAILED!'))
end
outlf(1)
outlf(1, 'Press any key to exit.')
