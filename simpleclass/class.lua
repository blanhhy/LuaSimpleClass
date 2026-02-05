-- 一种比较intersting的轻量class实现

local type, setmetatable
    = type, setmetatable

local Object = {
    __classname = "Object";
    __class = false;
    __base = false;
    __tostring = function(self) return ("<%s object>"):format(self.__class) end;
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
    while type(self) == "table" do
        if self == base then return true end
        self = self.__base
    end
    return false
end

function Object:isInstance(cls)
    if not cls then return false end
    local typ = type(self)
    if cls == typ then return true end
    local obj_cls = typ == "table" and self.__class
    return obj_cls and obj_cls:isExtends(cls)
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

---@class class_creator
local class = {
    env = {};
    mms = mm_names;
    cmt = class_MT;

    name = "<anonymous>";
    base = Object;
    global = _G; ---@class _G

    type = function(val)
        local typ = type(val)
        if typ == "table" and val.__class then
            return val.__class
        end
        return typ
    end;
}

function class:extends(basename)
    self.base = self.env[basename]
    return self
end

---@param clazz table
function class:def(clazz)
    local base = self.base

    for i = 1, #self.mms do
        local mm = self.mms[i]
        if not clazz[mm] then clazz[mm] = base[mm] end
    end

    clazz.__classname = self.name
    clazz.__index = clazz
    clazz.__base = base

    setmetatable(clazz, self.cmt)

    if self.onDef_impl_check then
        local ok, err = self:onDef_impl_check(clazz)
        if not ok then error(err, 2) end
    end

    if self.name ~= "<anonymous>" then
        -- 自动注册为全局变量，但不覆盖已存在的非类全局变量
        if nil == self.global[self.name] or self.env[self.name] then
            self.global[self.name] = clazz
        end
        self.env[self.name] = clazz
    end

    return clazz
end

local class_callable = {
    __call = function(self, name)
        local typ = type(name)
        if typ == "table" then
            return self:def(name)
        end
        return setmetatable({
            name = type(name) == "string" and name ~= '' and
            name or "<anonymous>"
        }, self)
    end
}

class.__index = class
class.__call  = class.def

return setmetatable(class, class_callable)