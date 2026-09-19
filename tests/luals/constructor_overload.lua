-- Constructor overloads may omit the known receiver in source annotations.
-- expect: 15:param-type-mismatch
-- expect: 28:param-type-mismatch

class "ConstructorOverload_7c8a" {
    ---@param ... number
    ---@overload fun(stop: integer)
    ---@overload fun(start: integer, stop: integer, step?: integer)
    __init = function(self, ...)
    end;
}

local one = ConstructorOverload_7c8a:new(10)
local many = ConstructorOverload_7c8a:new(1, 10, 2)
local badNew = ConstructorOverload_7c8a:new("bad")

---@param value ConstructorOverload_7c8a
local function accept(value) end
accept(ConstructorOverload_7c8a:new(10))

---@type ConstructorOverload_7c8a.constructor
local make = function(...)
    return ConstructorOverload_7c8a:new(...)
end

local aliasOne = make(10)
local aliasMany = make(1, 10, 2)
local badAlias = make("bad")
print(one, many, badNew, aliasOne, aliasMany, badAlias)
