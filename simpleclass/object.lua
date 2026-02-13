local M = require "simpleclass.m" ---@class simpleclass

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

setmetatable(Object, M.cmt)
M.env.Object = Object
M.object = Object

return M