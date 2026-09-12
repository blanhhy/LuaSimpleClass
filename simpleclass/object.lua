local M = require "simpleclass.m" ---@class M

local type, next, getmetatable, setmetatable
    = type, next, getmetatable, setmetatable

---@class M.object : object.class, object
local object = {
    __base = false;
    __classname = "object";
    __tostring = function(self) return ("<%s object>"):format(self.__class) end;
    getClass = function(self) return self.__class end;
    toString = tostring;
    is = rawequal;
}

object.__index = object

function object:__getter(key)
    local item = self.__class[key]
    if item ~= nil then return item end
    local prop = self.__class["__property"]
    local gett = prop and prop[key] and self.__class["get." .. key]
    if gett and type(gett) == "function" then
        return gett(self)
    end
end

function object:__setter(key, value)
    local prop = self.__class["__property"]
    if not prop or not prop[key] then rawset(self, key, value) end
    local set = self.__class["set." .. key]
    if set and type(set) == "function" then set(self, value) end
end

---@return object
function object:new(...)
    local inst = setmetatable({__class = self}, self)
    local ctor = self['__init'] or self['constructor']
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

local rawgetmt = debug and debug.getmetatable or getmetatable
local rawsetmt = debug and debug.setmetatable or setmetatable

---Clone the object
---@param isDeep? boolean Default `true`
---@return object
function object:clone(isDeep)
    isDeep = isDeep == nil and true or isDeep
    local clone = {}
    local clazz = rawgetmt(self)
    for k, v in next, self do
        if v == self then
            clone[k] = self
        elseif k == "__class" and v == clazz then
            clone[k] = clazz
        else
            clone[k] = (isDeep and type(v) == "table")
                and object.clone(v, true)
                or  v
        end
    end
    rawsetmt(clone, clazz)
    return clone
end

return object
