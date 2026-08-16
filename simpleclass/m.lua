local type = type

local class_MT = {
    __index = function(self, key) return self.__base and self.__base[key] or nil end;
    __tostring = function(self) return self.__classname end;
    __call = function(self, ...) return self:new(...) end;
}

local mm_names = {
    "__add", "__sub", "__mul", "__div", "__idiv", "__mod", "__pow",
    "__unm", "__band", "__bor", "__bxor", "__bnot", "__shl", "__shr",
    "__concat", "__len", "__eq", "__lt", "__le", "__call", "__gc",
    "__tostring", "__index", "__newindex",
}

---@class simpleclass
local M = {
    _ENV = {};
    _MMS = mm_names;
    _CMT = class_MT;
}

---Get the type of a value, considering classes as special types  
---eg: 
---```lua
---cls_type(Eagle()) => Eagle
---cls_type("Hello") => "string"
---```
---@param val object
---@return class
---@overload fun(val):type
function M.type(val)
    local typ = type(val)
    if typ == "table" and val.__class then
        return val.__class
    end
    return typ
end

return M