local alias = require("simpleclass").alias

local function add(a, b)
    return a + b
end

local add5 = alias(add, 5)
local result = add5(2)
---@type number
local checked = result
