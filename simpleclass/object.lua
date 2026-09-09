local M = require "simpleclass.m" ---@class M

local type, setmetatable
    = type, setmetatable

---@class M.object : object.class, object
local object = {
    __base = false;
    __classname = "object";
    __tostring = function(self) return ("<%s object>"):format(self.__class) end;
    getClass = function(self) return self.__class end;
    toString = tostring;
    is = rawequal;
}

function object:__index(key)
    local field = self.__class[key]
    if field ~= nil then return field end
    local getter = type(key) == "string" and self.__class["get." .. key]
    if getter and type(getter) == "function" then
        return getter(self)
    end
end

function object:__newindex(key, value)
    local setter = type(key) == "string" and self.__class["set." .. key]
    if setter and type(setter) == "function" then
        return setter(self, value)
    end
    return rawset(self, key, value)
end

---@return object
function object:new(...)
    local inst = setmetatable({__class = self}, self)
    local ctor = self['__init']
    if type(ctor) == "function" then ctor(inst, ...) end
    return inst
end

---Check if the class extends the base class (class method)
---@param base class
---@return boolean
function object:isExtends(base)
    while type(self) == "table" do
        if self == base then return true end
        self = self.__base
    end
    return false
end

---Check if the object is an instance of the class or interface  
---(also compatible with lua type)
---@param T class|interface|type
function object:isInstance(T)
    local typ = type(self)
    if typ ~= "table" or type(T) ~= "table" then
        return T == typ
    end
    local check = T.check_impl
    local clazz = self.__class
    if check then return check(T--[[@as interface]], self) end
    if clazz then return clazz:isExtends(T--[[@as class]]) end
    return false
end

setmetatable(object, M._CMT)
M._ENV.object = object

M.object = object
M.isinstance = object.isInstance
M.issubclass = object.isExtends

return object