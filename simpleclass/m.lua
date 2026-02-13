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
    "__tostring"
}

---@class simpleclass
local M = {
    env = {};
    mms = mm_names;
    cmt = class_MT;
}

function M.type(val)
    local typ = type(val)
    if typ == "table" and val.__class then
        return val.__class
    end
    return typ
end

return M