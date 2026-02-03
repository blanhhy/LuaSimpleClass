-- 一种比较intersting的轻量class实现

local type, setmetatable
    = type, setmetatable

local Object = {
    __classname = "Object";
    __class = "class";
    __base = false;
    __tostring = function(self) return ("<%s object>"):format(self.__class) end;
    isInstance = function(self, cls) return self.__class:isExtends(cls) end;
    getClass = function(self) return self.__class end;
    toString = tostring;
    is = rawequal;
}

Object.__index = Object

---@classmethod
function Object:new(...)
    local obj = setmetatable({__class = self}, self)
    local init = self.__init
    if type(init) == "function" then init(obj,...) end
    return obj
end

---@classmethod
function Object:isExtends(base)
    repeat if
        self == base
    then return true end
        self = self.__base
    until not self
    return false
end

local mm_names = {
    "__add", "__sub", "__mul", "__div", "__idiv", "__mod", "__pow",
    "__unm", "__band", "__bor", "__bxor", "__bnot", "__shl", "__shr",
    "__concat", "__len", "__eq", "__lt", "__le", "__call", "__gc",
    "__tostring"
}

local class_MT = {
    __index = function(self, key) return self.__base and self.__base[key] end;
    __tostring = function(self) return self.__classname end;
    __call = function(self, ...) return self:new(...) end;
}

setmetatable(Object, class_MT)

local class = setmetatable({
    env = _G; ---@class _G
    mms = mm_names;
    cmt = class_MT;

    base = Object;

    type = function(val)
        local typ = type(val)
        if typ == "table" and val.__class then
            return val.__class
        end
        return typ
    end;

    extends = function(self, basename)
        self.base = self.env[basename]
        return self
    end;

    __call = function(self, clazz)
        local base = self.base

        for i = 1, #self.mms do
            local mm = self.mms[i]
            if not clazz[mm] then clazz[mm] = base[mm] end
        end

        clazz.__classname = self.name
        clazz.__index = clazz
        clazz.__base = base

        if self.name ~= "<anonymous>" then
            self.env[self.name] = clazz
        end

        return setmetatable(clazz, self.cmt)
    end;
}, {
    __call = function(self, name)
        name = name or "<anonymous>"
        return setmetatable({name = name}, self)
    end
})

class.__index = class

return class