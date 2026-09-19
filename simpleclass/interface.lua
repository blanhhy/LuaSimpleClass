---@diagnostic disable: assign-type-mismatch
local M = require "simpleclass.m" ---@class M
local c = M.creator               ---@class M.creator
local o = M.object                ---@class M.object
local G = _G

local type, setmetatable, error, select
    = type, setmetatable, error, select

_ENV = nil

local ic = {}
local iR = {} ---@type table<interface, string|true>
setmetatable(iR, {__mode="kv"})

---@alias set<T> {[T]:true}

---@class M.icreator : _InterfaceCreator
---@field name string|false
---@field this interface
---@field seen set<string>

---@generic I1:string[]
---@param I1 I1
---@param I2 string[]
---@param seen set<string>
---@return I1
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

---Extend the interface with other interfaces
---@param self M.icreator
---@param ... interface
---@return _InterfaceDefiner
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

---@param self M.icreator
---@param body? string[]
function ic:__call(body)
    if M.I_FEATURE == "lexical" then return end
    local name = self.name
    local this = self.this
    if M.AUTO_GLOBAL and name and (nil == G[name] or M._ENV[name] == G[name]) then
        G[name] = this
    end
    iR[this] = name or true
    M._ENV[name or 0] = name and this or nil
    if type(body) ~= "table" or #body == 0 then return this end
    return extend(this, body, self.seen)
end

---Define a new interface
---@generic I:string
---@param name I.`I`
---@return _InterfaceCreator<I>|_InterfaceDefiner<I>
---@overload fun(body?:string[]):interface
function M.interface(name)
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
        this = {}; ---@type interface
        seen = {}; ---@type set<string>
        name = typ == "string" and name ~= "" and name ---@type string|false
    }, ic)
end

local index = M.index

---@param clazz object.class
---@param meths string[]
local function isimpl(clazz, meths)
    if M.I_FEATURE ~= "general" then return true end
    local field for i = 1, #meths do
        field = clazz[meths[i]] or index(clazz, meths[i], true)
        if type(field) ~= "function" then
        return false, meths[i]
    end end
    return true
end

M.isimpl = isimpl
M._iR = iR

---Check if a class implements the interfaces
---@param cls object.class
---@param ... interface
---@return boolean
---@return integer? arg_index if false
function M.isimplements(cls, ...)
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

---Implements the interfaces
---@param ... interface
function c:implements(...)
    if M.I_FEATURE == "lexical" then return self end
    self.ifaces = (...) and {...} or nil
    return self
end

c.impl = c.implements

---@param clazz object.class
---@return boolean ok
---@return string? err error message
function c:iCheck(clazz)
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

return M.interface
