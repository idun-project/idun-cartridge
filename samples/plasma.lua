local ease = require('ease')
local minisock = require('minisock')

local curve = arg[1]
local f = ease[curve]
local count = 128.0
local step = 1.0/count
local idx = 1
local graph = {}
local result = ""

-- Fill 1st half of graph/result
for x = 0.0+step, 1.0, step do
    local y = math.floor(f(x)*255)
    graph[idx] = y
    result = result..string.pack("B", y)
    idx = idx + 1
end
-- 2nd half is just the reverse
for i = 128, 1, -1 do
    result = result..string.pack("B", graph[i])
end
-- Send result
minisock.write(redirect.stdout, result)
