--[[
    search.setdb = function(db)
        Set the game database to 'db'
    search.get = function(str)
        Start a new search using a single word
    search.incremental = function(previous, keyword)
        Continue to refine search with additional keyword
--]]
local db = {}
local first, last = 0, 0

local function collect(matches, word, s, e)
    local result = {}
    if #matches == 0 then
        local maybe = db['keyword'][word]
        for _,entry in ipairs(maybe) do
            local row = tonumber(entry)
            if row<s or row>=e then
                table.insert(result, row)
            end
        end
    else
        for _,entry in ipairs(db['keyword'][word]) do
            local row = tonumber(entry)
            if row<s or row>=e then
                for _,v in ipairs(matches) do
                    if row==v then
                        table.insert(result, row)
                        break
                    else
                        if v>row then break end
                    end
                end
            end
        end
    end
    return result
end

local search = {}
search.setdb = function(data)
    db = data
end

search.get = function(str)
    local result = {}
    -- Find first alphabetic exact match
    local match = 0
    first, last = 0, 0
    for i,v in ipairs(db['alpha']) do
        match,_ = v[1]:find(str, 1, true)
        if match==1 then
            first = i
            break
        end
    end
    -- Get first to last exact matches
    local last = first
    local max = #db['alpha']
    while match and last>0 and last<max do
        table.insert(result, last)
        last = last+1
        match,_ = db['alpha'][last][1]:find(str, 1, true)
    end
    -- Find the keyword matches
    local matches = {}
    local kw = string.lower(str)
    if db['keyword'][kw] then
        matches = collect(matches, kw, first, last)
        for _,v in ipairs(matches) do
            table.insert(result, v)
        end
    end
    return result
end

search.incremental = function(previous, keyword)
    local matches = {}
    local kw = string.lower(keyword)
    if db['keyword'][kw] then
        matches = collect(previous, kw, first, last)
        return matches
    end
    return previous
end

return search
