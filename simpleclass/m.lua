local type, next, pairs, getmetatable
    = type, next, pairs, getmetatable
_ENV = nil

-- 基本类元表，每个类元表都在此基础上改装
local class_MT = {
    __tostring = function(self) return self.__classname end;
    __call = function(self, ...) return self:new(...) end;
}

local mm_names = {
    "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__idiv", "__unm",
    "__band", "__bor", "__bxor", "__bnot", "__shl", "__shr", "__eq", "__lt",
    "__le", "__concat", "__len", "__tostring", "__pairs", "__gc", "__close",
    "__index", "__newindex", "__call", "__ipairs"
}

---@class M : simpleclass
local M = {
    _ENV = {}; ---@type table<string, class>
    _MMS = mm_names;
    _CMT = class_MT;
}

---Get the type of a value, considering classes as special types  
---eg: 
---```lua
---simpleclass.type(Eagle()) => Eagle
---simpleclass.type("Hello") => "string"
---```
---@param val any
---@return class|type
function M.type(val)
    local typ = type(val)
    if typ == "table" and val.__class then
        return val.__class
    end
    return typ
end

---Obtain an iterator for traversing all members along the class inheritance chain.
---@generic T:class, K, V
---@param this T
---@return fun(clazz: {[K]:V}, index?: K):K, V
---@return T
function M.enum(this)
    if this["__class"] ~= nil or this["__base"] == nil then
        return pairs(this)
    end
    local seen = {}
    local function iter(_, pk)
        if not this then return end
        local k, v = next(this, pk)
        if k == nil then this = this["__base"] return iter() end
        if seen [k] then return iter(nil, k) end
        seen[k] = true
        return k, v
    end
    return iter, this
end


---Check if the class extends the base class
---@param this class
---@param base class
---@return boolean
function M.issubclass(this, base)
    while this do
        if this == base then return true end
        this = this["__base"]
    end
    return false
end

---Original mixin function
---@param this   table
---@param mixins table[]
function M.mixins(this, mixins)
    local merged = {}
    -- 混入之前，先排除冲突
    for i = 1, #mixins do for k in next, mixins[i] do
        if this[k] == nil then
            if merged[k] then
                local t1, t2 = mixins[merged[k]], mixins[i]
                local m1, m2 = getmetatable(t1), getmetatable(t2)
                local s1, s2 = m1 and m1.__tostring and m1.__tostring(t1) or ("#%d"):format(merged[k])
                            ,  m2 and m2.__tostring and m2.__tostring(t2) or ("#%d"):format(i)
                return false, ("bad mixins: '%s' is defined in both %s and %s, but is not overridden.")
                            :format(k, s1, s2)
            end
            merged[k] = i
    end end end
    for k, i in next, merged do
        this[k] = mixins[i][k]
    end
    return true
end

return M