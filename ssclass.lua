---SimpleClass but without any optional features.
---@diagnostic disable: deprecated
--[[                    ## UNLICENSE
----
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE. ]]
local M = {}
local G = _G

local type, getmetatable, setmetatable, error, next, rawset
    = type, getmetatable, setmetatable, error, next, rawset

local rawgetmt = debug and debug.getmetatable or getmetatable
local rawsetmt = debug and debug.setmetatable or setmetatable

_ENV = nil

local mm_names = {
    "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__idiv", "__unm",
    "__band", "__bor", "__bxor", "__bnot", "__shl", "__shr", "__eq", "__lt",
    "__le", "__concat", "__len", "__tostring", "__pairs", "__gc", "__close",
    "__index", "__newindex", "__call",
}

local class_MT = {
    __index = function(self, k) if self.__base then return self.__base[k] end end;
    __tostring = function(self) return self.__classname end;
    __call = function(self, ...) return self:new(...) end;
}

local sc_ENV = {}

local object = {
    __base = false;
    __property = false;
    __classname = "object";
    __tostring = function(self) return ("<%s object>"):format(self.__class) end;
    getClass = function(self) return self.__class end;
    toString = G.tostring;
    is = G.rawequal;
}

object.__index = object

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

function object:new(...)
    local inst = setmetatable({__class = self}, self)
    local ctor = self['__init']
    if ctor then ctor(inst, ...) end
    return inst
end

function object:isExtends(base)
    while type(self) == "table" do
        if self == base then return true end
        self = self.__base
    end
    return false
end

function object:isInstance(T)
    local typ = type(self)
    if typ ~= "table" or type(T) ~= "table" then
        return T == typ
    end
    local cls = self.__class
    if cls then return cls:isExtends(T) end
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

setmetatable(object, class_MT)
sc_ENV.object = object

local cc = {
    name = "<anonymous>";
    base = object;
}

local alias = {}
local Alias = {}

setmetatable(alias, Alias)

function cc:extends(basename)
    local base = sc_ENV[basename]
    if not base or not base.__classname then
        error(("bad extends: '%s' not found or not a class"):format(basename), 2)
    end
    self.base = base
    return self
end

function cc:def(clazz, c2)
    if self == clazz then clazz = c2 end
    local base = self.base

    for i = 1, #mm_names do
        local mm = mm_names[i]
        if not clazz[mm] then clazz[mm] = base[mm] end
    end

    if clazz.__index == base then clazz.__index = clazz end

    for i = 1, #clazz do
        local item = clazz[i]
        local tipe = item and type(item)
        local PROP = "@simpleclass.property."
        if tipe == "table" and item[3] == Alias then
            clazz[i] = nil
            local origin = item[1]
            local target = clazz[item[2]]
            if target == nil then target = base[item[2]] end
            if target == nil then
                error(("bad alias: '%s' not found"):
                format(item[2]), 2)
            end
            clazz[origin] = target
        elseif tipe == "string" and item:sub(1, #PROP) == PROP then
            local key = item:sub(#PROP + 1)
            if key and key ~= "" then
                clazz[i] = nil
                clazz.__property = clazz.__property or {}
                clazz.__property[key] = true
            end
        end
    end

    local pp1 = clazz.__property
    local pp2 = base["__property"]
    if pp1 and pp2 then
        for k, v in next, pp2 do pp1[k] = v end
    end
    clazz.__property = pp1 or pp2

    local ctor = clazz.constructor
    local init = clazz.__init or ctor
    clazz.__init = init
    clazz.constructor = nil

    clazz.new = clazz.new or base.new

    clazz.__base = base
    clazz.__classname = self.name
    setmetatable(clazz, class_MT)

    if clazz.__property then
        clazz.__index = clazz.__index ~= clazz and clazz.__index or clazz.__getter
        clazz.__newindex = clazz.__newindex or clazz.__setter
    end

    if self.name ~= "<anonymous>" then
        if M.AUTO_GLOBAL and (nil == G[self.name] or sc_ENV[self.name] == G[self.name]) then
            G[self.name] = clazz
        end
        sc_ENV[self.name] = clazz
    end
    return clazz
end

cc.__call = cc.def

function cc:__index(key)
    local keywd = cc[key]
    if keywd ~= nil then return keywd end
    return cc.extends(self, key)
end

function Alias:__index(key)
    if self == alias then
        return setmetatable({
            key, false, false
        }, Alias)
    end
    if self[2] then
        error(("bad alias: alias '%s' already bound to target '%s'; cannot chain '%s'"):
        format(self[1], self[2], key), 2)
    end
    self[2] = key
    self[3] = Alias
    return self
end

function Alias:__call() return self end

local function superinit(proxy, ...)
    return proxy.__class.__base.__init(proxy.self, ...)
end

local Super = {
    __call  = superinit,
    __index = function(proxy, key)
        if key == "__init" then return superinit end
        local clazz = proxy.__class
        local field = clazz.__base[key]
        if "function" ~= type(field) then return field end
        local self = proxy.self
        return function(_,...) return field(self, ...) end
    end,
    __tostring = function(proxy)
        return ("super<%s, %s>"):format(
            proxy.__class,
            proxy.self
        )
    end
}

M.AUTO_GLOBAL = true
M._ENV = sc_ENV
M.creator = cc
M.alias = alias

M.property = setmetatable({}, {
    __index = function(_, key)
        return "@simpleclass.property."..key
    end;
})

M.object = object
M.isinstance = object.isInstance
M.issubclass = object.isExtends

function M.type(v)
    local  t = type(v)
    return t == "table" and v.__class or t
end

function M.class(name)
    local typ = type(name)
    if typ == "table" then
        return cc:def(name)
    end
    return setmetatable({
        name = type(name) == "string" and name ~= '' and
        name or "<anonymous>"
    }, cc)
end

function M.super(cls, obj)
    if not obj then obj = cls end
    if type(cls)        ~= "table"
    or type(cls.__base) ~= "table"
    or not  cls.__base.__classname then
        error(("super: bad arguments: %s, %s"):
        format(cls, obj), 2)
    end
    return setmetatable({
        self    = obj,
        __class = cls,
    }, Super)
end

function M.env_import(fields, env)
    env = env or G
    for k, v in next, fields do
        if M[v] then env[v] = M[v]
    elseif M[k] then env[v] = M[k]
    end end end

return M
