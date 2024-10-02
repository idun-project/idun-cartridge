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
local pf128 = 'kernal128.patch'
local pf64 = 'kernal64.patch'
-- Output files
local of128 = '/home/idun/U35.rom'
local of64 = '/home/idun/U32.rom'
local ofcombo = '/home/idun/U32.rom'
-- Mssage text
local msg_k128_16k = 'Making patched C128 kernal ROM U35'
local msg_k64_16k = 'Making patched C64 kernal ROM U32'
local msg_k128_32k = 'Making patched C128 combined kernal ROM U32'
-- Patched ROM checksums
local md5_U35 = 'f3fa9ce4b04c31f3e120aa75bc95bcf4'
local md5_U32 = '536a206b1b986074ce113491d629f43d'
local md5_U32_combo = '01d98366e151ff09b022d2af753e46f1'
-- Critical ROM offsets
local KERNAL_128_OFFS = 0x6001
local KERNAL_64_OFFS = 0x2001
local KERNAL_ADDR = 0xe000

------------------
-- Helpers
------------------
-- shortcut for output
local function out(s)
	if #s>0 then minisock.write(redirect.stdout, s) end
    -- if #s>0 then io.write(s) end
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

local function patchRom(roms, patchs, outf, koff)
    local addr, count
    local offs = koff
    local i = 1
    while i<string.len(patchs) do
        addr = string.byte(patchs,i)+string.byte(patchs,i+1)*256
        count = string.byte(patchs,i+2)+string.byte(patchs,i+3)*256
        i = i+4
        addr = addr-KERNAL_ADDR
        -- Write original ROM code
        outf:write(string.sub(roms, offs, koff+addr-1))
        offs = koff + addr + count
        -- Write patch code
        outf:write(string.sub(patchs, i, i+count-1))
        i = i+count
    end
    outf:write(string.sub(roms, offs, koff+0x1fff))
end

local function make16k(roms)
    outlf(1, eansi('${green}'..msg_k64_16k))
    -- Open files for c64 kernal patch
    local outf = assert(io.open(of64, 'wb'))
    local patchf = assert(io.open(pf64, 'rb'))
    -- Read in the c64 patch file
    local patchs = patchf:read("*all")
    patchf:close()
    -- Write first 8kb of original ROM unchanged
    outf:write(string.sub(roms, 1, 0x2000))
    -- Apply the c64 patch
    patchRom(roms, patchs, outf, KERNAL_64_OFFS)
    outf:close()
    -- Open files for c128 kernal patch
    outlf(1, eansi('${green}'..msg_k128_16k))
    outf = assert(io.open(of128, 'wb'))
    patchf = assert(io.open(pf128, 'rb'))
    -- Read in the c128 patch file
    local patchs = patchf:read("*all")
    patchf:close()
    -- Write first 8kb of original ROM unchanged
    outf:write(string.sub(roms, 0x4001, 0x6000))
    -- Apply the c128 patch
    patchRom(roms, patchs, outf, KERNAL_128_OFFS)
    outf:close()
    return of64,of128
end

local function make32k(roms)
    local outf = assert(io.open(ofcombo, 'wb'))
    -- Read in the c64 kernal patch file
    local patchf = assert(io.open(pf64, 'rb'))
    local patchs = patchf:read("*all")
    patchf:close()
    -- Write first 8kb of original ROM unchanged
    outf:write(string.sub(roms, 1, 0x2000))
    -- Apply the c64 kernal patch
    patchRom(roms, patchs, outf, KERNAL_64_OFFS)
    -- Read in the c128 kernal patch file
    patchf = assert(io.open(pf128, 'rb'))
    patchs = patchf:read("*all")
    patchf:close()
    -- Write next 8kb of original ROM unchanged
    outf:write(string.sub(roms, 0x4001, 0x6000))
    -- Apply the c128 kernal patch
    patchRom(roms, patchs, outf, KERNAL_128_OFFS)
    outf:close()
    return ofcombo
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
sys.chdir(os.getenv('IDUN_SYS_DIR')..'/sys')

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
    outlf(1, eansi('${green}Patched ROM saved to '..prom_fname))
    out(eansi('${green}Verifying patched ROM checksum...'))
    if md5(prom_fname)==md5_U32_combo then
        outlf(1, eansi('${green}PASSED'))
    else
        outlf(1, eansi('${red}FAILED!'))
    end
else
    rom1_fname,rom2_fname = make16k(roms)
    outlf(1, eansi('${green}Patched ROMs saved to '..rom1_fname..' and '..rom2_fname))
    out(eansi('${green}Verifying patched ROM checksums...'))
    if md5(rom1_fname)==md5_U32 and md5(rom2_fname)==md5_U35 then
        outlf(1, eansi('${green}PASSED'))
    else
        outlf(1, eansi('${red}FAILED!'))
    end
end

outlf(1)
outlf(1, 'Press any key to exit.')
