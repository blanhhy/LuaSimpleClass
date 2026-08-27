local M      = require "simpleclass.m" ---@class simpleclass
local cc     = M.creator               ---@class simpleclass.creator
local object = M.object

local type, setmetatable, error
    = type, setmetatable, error

local Interface

---@class simpleclass.interface : interface
Interface = {
    _ENV = M._ENV;
    global = _G; ---@class _G
    __iname = "<anonymous>";
}

Interface.__index = Interface

---@param ... interface
---@return interface
function Interface:extends(...)
    if M.I_FEATURE == "lexical" then return self end
    local bases = {...}
    local iface, mname
    for j = 1, #bases do
        iface = bases[j]
        for i = 1, #iface do
            mname = iface[i]
            if not self[mname] then
            self[#self+1] = mname
            self[mname] = true
        end end
    end
    return self
end

function Interface:check_impl(clazz)
    if M.I_FEATURE ~= "general" then return true end
    ---@diagnostic disable-next-line: inject-field
    clazz.__implemented = clazz.__implemented or {}
    if clazz.__implemented[self] then return true end
    for i = 1, #self do
        if type(clazz[self[i]]) ~= "function" then
        return false, self[i]
    end end
    clazz.__implemented[self] = true
    return true
end

function Interface:__call(mnames)
    if type(mnames) ~= "table" then
        error("interface cannot instantiate", 2)
    end
    if M.I_FEATURE == "lexical" then return self end
    local mname
    for i = 1, #mnames do
        mname = mnames[i]
        if not self[mname] then
        self[#self+1] = mname
        self[mname] = true
    end end
    return self
end

function Interface:__tostring()
    if M.I_FEATURE == "lexical" then return "" end
    return ("<interface '%s'>")
    :format(self.__iname)
end

---Define a new interface
---@param name? string|table
---@return interface
function M.interface(name)
    if M.I_FEATURE == "lexical" then return setmetatable({}, Interface) end
    local typ = type(name)
    if typ == "table" then
        local iface = name ---@type interface
        local count = 0
        for i = 1, #iface do
            local mname = iface[i]
            if not iface[mname] then
            iface[count+1] = mname
            iface[mname] = true
            count = count + 1
        end end
        iface.__iname = "<anonymous>"
        return setmetatable(iface, Interface)
    elseif typ ~= "string" then
        return setmetatable({
        __iname = "<anonymous>"
        }, Interface)
    end
    local iface = {__iname = name}
    if nil == Interface.global[name] or Interface._ENV[name] then
        Interface.global[name] = iface
    end
    Interface._ENV[name] = iface
    return setmetatable(iface, Interface)
end

---Implements the interfaces
---@param ... interface
function cc:implements(...)
    if M.I_FEATURE == "lexical" then return self end
    self.ifaces = (...) and {...} or nil
    return self
end

function cc:onDef_impl_check(clazz)
    if M.I_FEATURE ~= "general" then return true end
    if not self.ifaces then return true end
    for i = 1, #self.ifaces do
        local iface = self.ifaces[i]
        local ok, mname = iface:check_impl(clazz)
        if not ok then return false,
        ("class %s implements %s but dose not implement method '%s'.")
        :format(self.name, iface, mname, iface)
    end end
    return true
end

---@return boolean
---@return integer? arg_index if false
function object:isImplements(...)
    if M.I_FEATURE ~= "general" then return true end
    local ifaces = {...}
    for i = 1, #ifaces do
        if not ifaces[i]:check_impl(self) then
        return false, i
    end end
    return true
end

return M.interface
