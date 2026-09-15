local M = require "simpleclass.m" ---@class M

local type, next, getmetatable, setmetatable, rawset
    = type, next, getmetatable, setmetatable, rawset

local rawgetmt = debug and debug.getmetatable or getmetatable
local rawsetmt = debug and debug.setmetatable or setmetatable

local index = M.index
local issub = M.issubclass

---@class M.object : object.class, object
local object = {
    __base = false;
    __property = false;
    __classname = "object";
    __tostring = function(self) return ("<%s object>"):format(self.__class) end;
    getClass = function(self) return self.__class end;
    toString = tostring;
    is = rawequal;
}

object.__index = object
_ENV = nil

function object:__getter(key)
    local claz = self.__class
    local prop = claz["__property"]
    local gett = prop and prop[key] and claz["get." .. key]
    if gett then return gett(self) end
    return index(self, key)
end

function object:__setter(key, v)
    local clazz = self.__class
    local prope = clazz["__property"]
    if not prope or not prope[key] then
        return rawset(self, key, v)
    end
    local sett = clazz["set." .. key]
    if sett then return sett(self, v) end
end

---@return object
function object:new(...)
    local inst = setmetatable({__class = self}, self)
    local ctor = self["__init"] or index(inst, "__init", true)
    if ctor then ctor(inst, ...) end
    return inst
end

---Check if the object is an instance of the class or interface  
---(also compatible with lua type)
---@param T class|interface|type
function object:isInstance(T)
    local typ = type(self)
    if typ ~= "table" or type(T) ~= "table" then
        return T == typ
    end
    local iR, ct = M._iR, self.__class
    if iR and iR[T] then return M.isimpl(self, T) end
    if ct then return issub(ct, T--[[@as class]]) end
    return false
end

local function deep(src, cls, seen)
    if seen[src] then return seen[src] end
    local c = {}
    seen[src] = c
    for k, v in next, src do
        c[k] = (k == "__class" and v == cls) and cls
            or (type(v) == "table") and deep(v, rawgetmt(v), seen)
            or v
    end
    rawsetmt(c, cls)
    return c
end

---Clone the object
---@param isDeep? boolean Default `true`
---@return object
function object:clone(isDeep)
    local clazz = rawgetmt(self)
    if isDeep == nil or isDeep then
        return deep(self, clazz, {})
    end
    local clone = {}
    for k, v in next, self do clone[k] = v end
    rawsetmt(clone, clazz)
    return clone
end

setmetatable(object, M._CMT)
M._ENV.object = object

M.object = object
M.isinstance = object.isInstance

return object
