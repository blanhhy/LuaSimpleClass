local alias = require("simpleclass").alias

local function add(a, b)
    return a + b
end

local add5 = alias(add, 5)
assert(add5(2) == 7)

local fixed = {name = "fixed"}
local function readTable(value, suffix)
    assert(value == fixed)
    return value.name .. suffix
end

local readFixed = alias(readTable, fixed)
assert(readFixed(" value") == "fixed value")

local function collect(...)
    return select("#", ...), ...
end

local collectFixed = alias(collect, nil, false, 3)
local count, first, second, third = collectFixed()
assert(count == 3 and first == nil and second == false and third == 3)

assert(alias(add) == add)

return true
