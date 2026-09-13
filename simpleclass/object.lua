local M = require "simpleclass.m" ---@class M

local type, next, getmetatable, setmetatable, rawset
    = type, next, getmetatable, setmetatable, rawset

local rawgetmt = debug and debug.getmetatable or getmetatable
local rawsetmt = debug and debug.setmetatable or setmetatable

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
    return claz[key]
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
    local ctor = self['__init']
    if ctor then ctor(inst, ...) end
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

---Clone the object
---@param isDeep? boolean Default `true`
---@return object
function object:clone(isDeep)
    isDeep = isDeep == nil and true or isDeep
    local seen = {} -- 源表 -> 克隆表，用于环检测与共享引用一致性
    local function copy(src, clazz)
        local done = seen[src]
        if done then return done end
        local c = {}
        seen[src] = c
        for k, v in next, src do
            if k == "__class" and v == clazz then
                c[k] = clazz
            elseif isDeep and type(v) == "table" then
                c[k] = copy(v, rawgetmt(v))
            else
                c[k] = v
            end
        end
        rawsetmt(c, clazz)
        return c
    end
    return copy(self, rawgetmt(self))
end

return object
