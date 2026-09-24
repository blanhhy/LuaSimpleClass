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
local M = {} ---@class _M
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
    "__index", "__newindex", "__call", "__ipairs"
}

local class_MT = {
    __tostring = function(self) return self.__classname end;
    __call = function(self, ...) return self:new(...) end;
}

local sc_ENV = {}

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

function object:new(...)
    local inst = setmetatable({__class = self}, self)
    local ctor = self["__init"]
    if ctor then ctor(inst, ...) end
    return inst
end

function object:isInstance(T)
    local t = type(self)
    if t ~= "table" or type(T) ~= "table" then return T == t end
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
            or v end
    rawsetmt(c, cls)
    return c
end

function object:clone(isDeep)
    local clazz = rawgetmt(self)
    if isDeep == nil or isDeep then
    return deep(self, clazz, {})end
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
        format(self[1], self[2], key), 2) end
    self[2] = key
    self[3] = alias
    return self
end

function Alias:__call(this)
    if   self == alias then error("bad alias: illegal usage, specify the alias name first.", 2)
    elseif not self[2] then error("bad alias: alias '"..self[1].."' cannot be declared as a method, no target specified", 2) end
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

function cc:extends(name)
    local base = sc_ENV[name]
    if not base or not base.__classname then error("bad extends: '"..name.."' not found or not a class", 2) end
    self.base = base
    return self
end

local function getitem(self, key)
    local claz = self.__class
    local getr = claz.__property[key]
    if not getr then return claz[key] end
    if getr ~= true then return getr(self) end
end

local function setitem(self, k, v)
    local claz = self.__class
    local prop = claz["__property"]
    if not prop[k] then return rawset(self, k, v) end
    local setr = claz[k]
    if setr then return setr(self, v) end
    error("cannot set property."..k..", no setter defined.")
end

function cc:def(clazz, c2)
    if self == clazz then clazz = c2 end
    local base = self.base
    clazz.new = clazz.new or base.new

    for i = 1, #mm_names do
        local mm = mm_names[i]
        if not clazz[mm] then clazz[mm] = base[mm] end
    end

    local isTrivial = base == clazz.__index
    local isDirectD = base == object
    if isTrivial then clazz.__index = clazz end

    if isDirectD then
        clazz.is         = clazz.is         or object.is
        clazz.clone      = clazz.clone      or object.clone
        clazz.getClass   = clazz.getClass   or object.getClass
        clazz.toString   = clazz.toString   or object.toString
        clazz.isInstance = clazz.isInstance or object.isInstance
    end

    for i = 1, #clazz do
        local item = clazz[i]
        local tipe = item and type(item)
        local PROP = "@simpleclass.property."
        local prop = clazz.__property
        if tipe == "table" and item[3] == alias then
            clazz[i] = nil
            local origin = item[1]
            local target = item[2]
            local field = clazz[target]
            if field == nil and item[4] then field = base[target] end
            if field == nil then error("bad alias: '"..item[2].."' not found") end
            clazz[origin] = field
        elseif tipe == "string" and item:sub(1, #PROP) == PROP then
            local key = item:sub(#PROP + 1)
            if key and key ~= "" then
                if clazz[key] ~= nil then error("bad class definition: '" .. key .. "' cannot be both a static field and a property.", 3) end
                clazz[i] = nil
                local getk, setk = "get."..key, "set."..key
                local getp, setp = clazz[getk], clazz[setk]
                clazz[getk], clazz[setk] = nil, nil
                prop       = prop or {}
                prop [key] = getp or true
                clazz[key] = setp or false
            end
        end
        clazz.__property = prop
    end

    local this_c, base_c = clazz, base
    local base_p = base_c["__property"]
    local this_p = this_c["__property"] or (base_p and {})
    this_c["__property"] = this_p
    if this_p then
        if base_p then for k in next, base_p do
        this_p[k] = this_p[k] or base_p[k]
        this_c[k] = this_c[k] or base_c[k]
        end end
        this_c.__newindex = this_c.__newindex or setitem
        this_c.__index = isTrivial and getitem or this_c.__index
    end

    local ctor = clazz.constructor
    local init = clazz.__init or ctor
    clazz.__base = base
    clazz.__init = init
    clazz.constructor = nil
    clazz.__classname = self.name

    local cmt = class_MT
    if not isDirectD then
        cmt = base["__cmt"] or {
            __call = cmt.__call;
            __tostring = cmt.__tostring;
            __index = base;
        }
        base["__cmt"] = cmt
    end
    setmetatable(clazz, cmt)
    clazz.__cmt = false

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
    return clazz
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
    __mode  = "v",
    __call  = function(proxy, self, ...)
        if proxy == self then return proxy[3](proxy[2], ...) end
        return proxy[1]["__base"]["__init"](proxy[2], self, ...)
    end,
    __index = function(proxy, key)
        local field = proxy[1]["__base"][key]
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
        end extend(this, base, seens)
    end return self
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
        field = clazz[meths[i]]
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
    local t = type(name)
    if t == "table" then return cc:def(name) end
    return setmetatable({
        name = t == "string" and name ~= "" and
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
