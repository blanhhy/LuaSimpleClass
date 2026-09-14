local M      = require "simpleclass.m" ---@class M
local cc     = M.creator               ---@class M.creator
local object = M.object

local type, setmetatable, error
    = type, setmetatable, error

local G = _G ---@class _G
local I = {} ---@class M.interface : interface

_ENV = nil
I.__index = I

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

---@param ... interface
---@return interface
function I:extends(...)
    if M.I_FEATURE == "lexical" then return self end
    local bases, iface = {...}, nil
    for j = 1, #bases do
        iface = bases[j]
        if type(iface) ~= "table" or not iface.__iname then
            error(("bad interface extends: interface expected, got %s at #%d"):
            format(iface, j), 2)
        end
        extend(self, iface, self)
    end
    return self
end

function I:check_impl(clazz)
    if M.I_FEATURE ~= "general" then return true end
    for i = 1, #self do
        if type(clazz[self[i]]) ~= "function" then
        return false, self[i]
    end end
    return true
end

function I:__call(body)
    if type(body) ~= "table" then
        error("interface cannot instantiate", 2)
    end
    if M.I_FEATURE == "lexical" then return self end
    return extend(self, body, self)
end

function I:__tostring()
    return ("<interface '%s'>")
    :format(self.__iname or '?')
end

---Define a new interface
---@param name? string|table
---@return interface
function M.interface(name)
    if M.I_FEATURE == "lexical" then return setmetatable({}, I) end
    local typ = type(name)
    if typ == "table" then
        local iface = {__iname = "<anonymous>"}
        extend(iface, name, iface)
        return setmetatable(iface, I)
    elseif typ ~= "string" or name == "" then
        return setmetatable({
        __iname = "<anonymous>"
        }, I)
    end
    local iface = {__iname = name}
    if M.AUTO_GLOBAL and (nil == G[name] or M._ENV[name] == G[name]) then
        G[name] = iface
    end
    M._ENV[name] = iface
    return setmetatable(iface, I)
end

cc.ifaces = false

---Implements the interfaces
---@param ... interface
function cc:implements(...)
    if M.I_FEATURE == "lexical" then return self end
    self.ifaces = (...) and {...} or nil
    return self
end

cc.impl = cc.implements

---@param clazz class
---@return boolean ok
---@return string? err error message
function cc:check_impl(clazz)
    if M.I_FEATURE ~= "general" then return true end
    if not self.ifaces then return true end
    for i = 1, #self.ifaces do
        local iface = self.ifaces[i]
        if not iface or not iface.__iname or not iface.check_impl then
            error(("bad implements: interface expected, got %s at #%d"):
            format(iface, i), 2)
        end
        local ok, mname = iface:check_impl(clazz)
        if not ok then return false,
        ("class %s implements %s but does not implement method '%s'.")
        :format(self.name, iface, mname)
    end end
    return true
end

---@return boolean
---@return integer? arg_index if false
function object:isImplements(...)
    if M.I_FEATURE ~= "general" then return true end
    local ifaces = {...}
    for i = 1, #ifaces do
        if not ifaces[i].check_impl
        or not ifaces[i]:check_impl(self)
        then return false, i
    end end
    return true
end

return M.interface
