--[[
	d64reader.directory = function(d64file, filter)
    d64file - full path to a valid .D64 image file
    filter - hex value of file type to include, or nil for all types

	returns a table with 2 attributes per directory entry:
    name - name of file (PETSCII)
    size - length of file in bytes
--]]

local function dir_entry(blob)
    assert(blob:len() == 32)
    local name_part = string.sub(blob, 6, 21)
    local s, _ = string.find(name_part, '\160')
    local fname
    if s then
        fname = string.sub(name_part, 1, s-1)
    else
        fname = name_part
    end
    local sz = (blob:byte(32)*256+blob:byte(31)) * 254
    -- TESTING
    -- io.write(string.format("Entry (%d), name=%s, size=%d\n", blob:len(), fname, sz))
    return {
        size = sz,
        name = fname
    }
end

local function dir_iter(dir_track, file_type_filter)
    -- Second sector of track is first directory block
    local ptr = 257
    local blk = string.sub(dir_track, ptr, ptr+256)
    local entry = 0
    return function ()
        -- TESTING
        -- io.write(string.format("Blk: %d %d\n", blk:byte(1), blk:byte(2)))
        while blk:byte(1)>=0 and blk:byte(2)>=0 do
            entry = entry + 1
            while entry <= 8 do
                local offset = (entry-1) * 32 + 1
                local ftype = blk:byte(offset+2)
                if file_type_filter and ftype == file_type_filter then
                    return dir_entry(blk:sub(offset, offset+31))
                elseif ~file_type_filter and ftype >= 0x80 and ftype < 0x85 then
                    return dir_entry(blk:sub(offset, offset+31))
                end
                entry = entry + 1
            end
            if blk:byte(1)>0 then
                ptr = blk:byte(2)*256+1
                blk = string.sub(dir_track, ptr, ptr+256)
                entry = 0
            else
                return nil
            end
        end
    end
end

local d64reader = {}
d64reader.directory = function(fname, filter)
    local result = {}
    local d64file = io.open(fname, "rb")
    assert(d64file, "Failed to open D64 file")
    -- Get track 18 data
    d64file:seek("set", 0x16500)
    local trk18 = d64file:read(0x1300)
    d64file:close()
    -- Iterate over directory
    for entry in dir_iter(trk18, filter) do
        table.insert(result, entry)
    end
    return result
end

return d64reader