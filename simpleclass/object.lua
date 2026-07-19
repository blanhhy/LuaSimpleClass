local M = require "simpleclass.m" ---@class simpleclass

local type, setmetatable
    = type, setmetatable

local object = {
    __classname = "object";
    __class = false;
    __base = false;
    __tostring = function(self) return ("<%s object>"):format(self.__class) end;
    getClass = function(self) return self.__class end;
    toString = tostring;
    is = rawequal;
}

function object:__index(key)
    local getter = type(key) == "string" and self.__class["get." .. key]
    if getter and type(getter) == "function" then
        return getter(self)
    end
    return self.__class[key]
end

function object:__newindex(key, value)
    local setter = type(key) == "string" and self.__class["set." .. key]
    if setter and type(setter) == "function" then
        setter(self, value)
    end
    return rawset(self, key, value)
end

---@classmethod
function object:new(...)
    local obj = setmetatable({__class = self}, self)
    local init = self.__init
    if type(init) == "function" then init(obj,...) end
    return obj
end

---@classmethod
---@return boolean
function object:isExtends(base)
    while type(self) == "table" do
        if self == base then return true end
        self = self.__base
    end
    return false
end

function object:isInstance(cls)
    local typ = type(self)

    if typ ~= "table" or type(cls) ~= "table" then
        return cls == typ
    end

    if cls.check_impl then
        ---@cast cls interface
        return cls:check_impl(self)
    end

    local obj_cls = self.__class

    if obj_cls then
        return obj_cls:isExtends(cls) ---@type boolean
    end

    return false
end

setmetatable(object, M._CMT)
M._ENV.object = object
M.object = object

return object