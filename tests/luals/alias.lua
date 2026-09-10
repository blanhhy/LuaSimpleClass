local sc = require "simpleclass"
local exported = sc.alias

class "AliasTypeCheck_73a1" {
    ---@param value string
    ---@return string
    echo = function(self, value)
        return value
    end;
    exported.shortEcho:echo(),
    exported.fixedEcho:echo("fixed"),
}

local instance = AliasTypeCheck_73a1:new()
local text = instance:shortEcho("ok")
---@type string
local valid = text

-- expect: 20:param-type-mismatch
local invalid = instance:shortEcho(123)

class "AliasStaticTypeCheck_73a1" {
    ---@static
    ---@param left integer
    ---@param right integer
    ---@return integer
    add = function(left, right)
        return left + right
    end;
    exported.addFive.add(5),
}

local sum = AliasStaticTypeCheck_73a1.addFive(7)
---@type integer
local validSum = sum

-- expect: 38:param-type-mismatch
local invalidSum = AliasStaticTypeCheck_73a1.addFive("7")
