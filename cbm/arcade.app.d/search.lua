--[[
    search.setdb = function(db)
        Setup the fuzzy search input
    search.get = function(str)
        Start a new search
--]]
local search, fzfin = {}, ""

search.setdb = function(data)
    for i,v in ipairs(data['alpha']) do
        fzfin = fzfin .. string.format("%d  %s\n", i, v[1])
    end
end

search.get = function(str)
    local cmd = string.format('echo -e "%s" | fzf --filter="%s" --with-nth=2', fzfin, str)
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
