--[[
    search.setdb = function(db)
        Setup the fuzzy search input
    search.get = function(str)
        Start a new search
--]]
local search, fzfin = {}, '/tmp/arcade-fzf'

search.setdb = function(data)
    local f,_ = io.open(fzfin, 'w')
    assert(f, "Failed to create fzf search file")

    for i,v in ipairs(data['alpha']) do
        f:write(string.format("%d  %s\n", i, v[1]))
    end
    f:close()
end

search.get = function(str)
    local cmd = string.format('fzf --filter="%s" --with-nth=2 < "%s"', str, fzfin)
    local f = assert(io.popen(cmd, 'r'))
    local matches = {}

    for l in f:lines() do
        local m = l:match('^(%d+).+$')
        table.insert(matches, tonumber(m))
    end

    f:close()
    return matches
end

return search
