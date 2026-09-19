---SimpleClass (runtime) but all in one file.
---@diagnostic disable: deprecated
local _, _, margs = ...
local options = {}

options.GLOBAL_IMPORT      = true;
options.INTERFACE_INCLUDED = true;
options.DEFAULT_I_FEATURE  = "general";

if type(margs) == "table" then
    for k, v in next, margs do
    if v ~= nil then options[k] = v
    end end end

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

local type, getmetatable, setmetatable, error, select, next, rawset
    = type, getmetatable, setmetatable, error, select, next, rawset

local getinfo  = debug and debug.getinfo
local getlocal = debug and debug.getlocal
local rawgetmt = debug and debug.getmetatable or getmetatable
local rawsetmt = debug and debug.setmetatable or setmetatable

_ENV = nil

local mm_names = {
    "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__idiv", "__unm",
    "__band", "__bor", "__bxor", "__bnot", "__shl", "__shr", "__eq", "__lt",
    "__le", "__concat", "__len", "__tostring", "__pairs", "__gc", "__close",
    "__newindex", "__call", "__ipairs"
}

local class_MT = {
    __tostring = function(self) return self.__classname end;
    __call = function(self, ...) return self:new(...) end;
    __metatable = "class";
}

local sc_ENV = {}

local function index(this, key, super)
    if not this or key == nil then return end
    local clazz = this.__class or this
    local field
    if super then clazz = clazz["__base"] end
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"] if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"] if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"] if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"] if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"] if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"] if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"] if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"] if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"] if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"] if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"] if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    while clazz do
        field = clazz[key]
        if field ~= nil then return field end
        clazz = clazz["__base"]
    end
end

local function issub(this, base)
    while this do
        if this == base then return true end
        this = this["__base"]
    end return false
end

local object = {
    __base = false;
    __property = false;
    __classname = "object";
    __tostring = function(self) return ("<%s object>"):format(self.__class) end;
    getClass = function(self) return self.__class end;
    toString = G.tostring;
    is = G.rawequal;
}

function object:__getter(key)
    local clazz = self.__class
    local prope = clazz["__property"]
    if prope and prope[key] then
        local getkey = "get." .. key
        local getter = clazz[getkey] or index(clazz, getkey, true)
        if getter then return getter(self) end
    end
    return index(self, key)
end

function object:__setter(key, v)
    local clazz = self.__class
    local prope = clazz["__property"]
    if not prope or not prope[key] then return rawset(self, key, v) end
    local setkey = "set." .. key
    local setter = clazz[setkey] or index(clazz, setkey, true)
    if setter then return setter(self, v) end
    error("cannot set property."..key..", no setter defined.")
end

function object:new(...)
    local inst = setmetatable({__class = self}, self)
    local ctor = self["__init"] or index(inst, "__init", true)
    if ctor then ctor(inst, ...) end
    return inst
end

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

object.__index = object
sc_ENV.object = object
setmetatable(object, class_MT)

local alias = {}
local Alias = {}
setmetatable(alias, Alias)

function Alias:__index(key)
    if self == alias then
        return setmetatable({key, false, false, false}, Alias)
    elseif self[2] then
        error(("bad alias: alias '%s' already bound to target '%s'; cannot chain '%s'"):
        format(self[1], self[2], key), 2)
    end
    self[2] = key
    self[3] = alias
    return self
end

function Alias:__call(this)
    if self == alias then
        error("bad alias: illegal usage, specify the alias name first.", 2)
    elseif not self[2] then
        error(("bad alias: alias '%s' cannot be declared as a method, no target specified"):
        format(self[1]), 2)
    end
    self[4] = self == this
    return self
end

local cc = {
    name = "<anonymous>";
    base = object;
    impl = false;
    iCheck = false;
    ifaces = false;
    implements = false;
}

function cc:extends(basename)
    local base = sc_ENV[basename]
    if not base or not base.__classname then
        error(("bad extends: '%s' not found or not a class"):format(basename), 2)
    end
    self.base = base
    return self
end

local function check_index(clazz, base)
    if clazz.__index then return 1, clazz.__index end
    if not base.__index or base.__index == base or base.__index == index then return 3, index end
    return 2, base.__index
end

function cc:def(clazz, c2)
    if self == clazz then clazz = c2 end
    local base = self.base
    local indexdef, __index = check_index(clazz, base)

    for i = 1, #mm_names do
        local mm = mm_names[i]
        if not clazz[mm] then clazz[mm] = base[mm] end
    end

    if base == object then
        clazz.__index    = clazz.__index    or clazz
        clazz.is         = clazz.is         or object.is
        clazz.clone      = clazz.clone      or object.clone
        clazz.getClass   = clazz.getClass   or object.getClass
        clazz.isInstance = clazz.isInstance or object.isInstance
    else clazz.__index = __index end

    clazz.new      = clazz.new      or base.new
    clazz.toString = clazz.toString or base.toString

    for i = 1, #clazz do
        local item = clazz[i]
        local tipe = item and type(item)
        local PROP = "@simpleclass.property."
        if tipe == "table" and item[3] == alias then
            clazz[i] = nil
            local origin = item[1]
            local target = item[2]
            local field = clazz[target]
            if field == nil and item[4] then field = index(base, target) end
            if field == nil then return
                error(("bad alias: '%s' not found"):
                format(item[2]), 2)
            end
            clazz[origin] = field
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
    clazz.__base = base
    clazz.__init = init
    clazz.constructor = nil
    clazz.__classname = self.name

    if clazz.__property then
        clazz.__newindex = clazz.__newindex or object.__setter
        clazz.__index = indexdef == 3 and object.__getter or clazz.__index
    end

    if self.ifaces and self.iCheck then
        local ok, er = self:iCheck(clazz)
        if not ok then error(er, 2) end
    end

    if self.name ~= "<anonymous>" then
        if M.AUTO_GLOBAL and (nil == G[self.name] or sc_ENV[self.name] == G[self.name]) then
            G[self.name] = clazz
        end
        sc_ENV[self.name] = clazz
    end
    return setmetatable(clazz, class_MT)
end

cc.__call = cc.def

function cc:__index(key)
    local keywd = cc[key]
    if keywd ~= nil then return keywd end
    return cc.extends(self, key)
end

local getcontext, context

if getinfo and getlocal then
    function getcontext()
        context = context or setmetatable({}, {__mode = 'kv'})
        local wt = "f"
        local _, this = getlocal(3, 1)
        local imethod = getinfo(3, wt)

        local objcls = this.__class or this
        local method = imethod.func
        local funcls = context[method]
        if funcls then return funcls, this end

        while not funcls and objcls do
            for _, v in next, objcls do
            if v == method then
            funcls = objcls
            break end end
            objcls = objcls.__base
        end

        context[method] = funcls
        return funcls, this
    end
end

local Super = {
    __call  = function(proxy, self, ...)
        if proxy == self then return proxy[3](proxy[2], ...) end
        return index(proxy[1], "__init", true)(proxy[2], self, ...)
    end,
    __index = function(proxy, key)
        local field = index(proxy[1], key, true)
        if "function" ~= type(field) then return field end
        proxy[3] = field
        return proxy
    end,
    __tostring = function(p)
        return p[3]
        and ("bound<%s, %s>"):format(p[2], p[3])
        or  ("super<%s, %s>"):format(p[1], p[2])
    end
}

local interface, isimpl, isimplements, _iR
if options.INTERFACE_INCLUDED then
local ic = {}
local iR = {}
setmetatable(iR, {__mode="kv"})

local function extend(I1, I2, seen)
    local field
    for i = 1, #I2 do
        field = I2[i]
        if not seen[field] then
        seen[field] = true
        I1[#I1+1] = field
    end end
    return I1
end

local function extends(self, ...)
    if M.I_FEATURE == "lexical" then return self end
    local this, seens = self.this, self.seen
    local base, bases = nil, {...}
    for i = 1, #bases do
        base =  bases[i]
        if not base or not iR[base] then
            error(("bad interface extends: interface expected, got %s at #%d"):
            format(base, i), 2)
        end
        extend(this, base, seens)
    end
    return self
end

function ic:__call(body)
    if M.I_FEATURE == "lexical" then return end
    local name = self.name
    local this = self.this
    if M.AUTO_GLOBAL and name and (nil == G[name] or sc_ENV[name] == G[name]) then
        G[name] = this
    end
    iR[this] = name or true
    sc_ENV[name or 0] = name and this or nil
    if not body then return this end
    return extend(this, body, self.seen)
end

function interface(name)
    if M.I_FEATURE == "lexical" then
        return setmetatable({extends=extends}, ic)
    end
    local typ = type(name)
    if typ == "table" then
        local I = {}
        iR[I] = true
        return extend(I, name, name)
    end
    return setmetatable({
        extends = extends;
        this = {};
        seen = {};
        name = typ == "string" and name ~= "" and name
    }, ic)
end

function isimpl(clazz, meths)
    if M.I_FEATURE ~= "general" then return true end
    local field for i = 1, #meths do
        field = clazz[meths[i]] or index(clazz, meths[i], true)
        if type(field) ~= "function" then
        return false, meths[i]
    end end
    return true
end

function isimplements(cls, ...)
    if M.I_FEATURE ~= "general" then return true end
    local impl
    for i = 1, select('#', ...) do
        impl = select(i,   ...)
        if not impl or not iR[impl]
        or not isimpl(cls, impl)
        then return false, i
    end end
    return true
end

function cc:implements(...)
    if M.I_FEATURE == "lexical" then return self end
    self.ifaces = (...) and {...} or nil
    return self
end

function cc:iCheck(clazz)
    if M.I_FEATURE ~= "general" then return true end
    for i = 1, #self.ifaces do
        local iface = self.ifaces[i]
        if not iface or not iR[iface] then
            error(("bad implements: interface expected, got '%s' at #%d"):
            format(iface, i), 2)
        end
        local ok, mname = isimpl(clazz, iface)
        if not ok then return false,
        ("class '%s' implements interface '%s' but does not implement method '%s'.")
        :format(self.name, iR[iface] == true and "<anonymous>" or iR[iface], mname)
    end end
    return true
end

cc.impl = cc.implements
_iR = iR
end --# options.INTERFACE_INCLUDED

M.AUTO_GLOBAL = false
M.I_FEATURE = options.DEFAULT_I_FEATURE

M._iR  = _iR
M._ENV = sc_ENV

M.alias = alias
M.property = setmetatable({}, {
    __index = function(_, key)
        return "@simpleclass.property."..key
    end;
})

M.index = index
M.object = object
M.isimpl = isimpl
M.issubclass = issub
M.isinstance = object.isInstance
M.isimplements = isimplements

function M.type(v)
    local  t = type(v)
    return t == "table" and v.__class or t
end

function M.class(name)
    local typ = type(name)
    if typ == "table" then return cc:def(name) end
    return setmetatable({
        name = typ == "string" and name ~= "" and
        name or "<anonymous>"
    }, cc)
end

function M.super(cls, obj)
    if not obj and not cls and getcontext then
        cls, obj = getcontext()
    end
    if not obj then obj = cls end
    if type(cls) ~= "table" or not cls.__classname then
        error(("super: bad arguments: %s, %s"):format(cls, obj), 2)
    end
    return setmetatable({cls, obj, false}, Super)
end

M.interface = interface

function M.env_import(fields, env)
    env = env or G
    for k, v in next, fields do
        if M[v] then env[v] = M[v]
    elseif M[k] then env[v] = M[k]
    end end end

if options.GLOBAL_IMPORT then
    M.AUTO_GLOBAL = true
    M.env_import {
        "class", "super", "object", "interface", "property",
        "isinstance", "issubclass", "isimplements",
    }
end

return M
