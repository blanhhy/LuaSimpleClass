---@diagnostic disable deprecated
local M = require "simpleclass.m" ---@class M

local type, setmetatable, error
    = type, setmetatable, error

_ENV = nil

local alias = {}
local Alias = {}

setmetatable(alias, Alias)

---@param self any[]
function Alias:__index(key)
    if self == alias then
        return setmetatable({key, false, false, false}, Alias)
    elseif self[2] then
        error(("bad alias: alias '%s' already bound to target '%s'; cannot chain '%s'"):
        format(self[1], self[2], key), 2)
    end
    self[2] = key
    self[3] = alias
    return self
end

function Alias:__call(this)
    if   self == alias then error("bad alias: illegal usage, specify the alias name first.", 2)
    elseif not self[2] then error("bad alias: alias '"..self[1].."' cannot be declared as a method, no target specified", 2) end
    self[4] = self == this
    return self
end

-- 1: origin
-- 2: target
-- 3: _Magic
-- 4: inherit?

M.alias = alias
M.property = setmetatable({}, {
    __index = function(_, key)
        return "@simpleclass.property."..key
    end;
})

---@param clazz table
---@param base  class
---@param maxn  integer
return function(clazz, base, maxn)
    for i = 1, maxn do
        local item = clazz[i]
        local tipe = item and type(item)
        local PROP = "@simpleclass.property."
        local prop = clazz.__property
        if tipe == "table" and item[3] == alias then
            clazz[i] = nil
            local origin = item[1]
            local target = item[2]
            local field = clazz[target]
            if field == nil and item[4] then field = base[target] end
            if field == nil then error("bad alias: '"..item[2].."' not found") end
            clazz[origin] = field
        elseif tipe == "string" and item:sub(1, #PROP) == PROP then
            local key = item:sub(#PROP + 1)
            if key and key ~= "" then
                if clazz[key] ~= nil then error("bad class definition: '" .. key .. "' cannot be both a static field and a property.", 3) end
                clazz[i] = nil
                local getk, setk = "get."..key, "set."..key
                local getp, setp = clazz[getk], clazz[setk]
                clazz[getk], clazz[setk] = nil, nil
                prop       = prop or {}
                prop [key] = getp or true
                clazz[key] = setp or false
            end
        end
        clazz.__property = prop
    end
end
