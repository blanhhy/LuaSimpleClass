local class = require "simpleclass.class"
local Object = class.base

local type, setmetatable, error
    = type, setmetatable, error

---@class interface
local Interface = {
    env = class.env;
    global = _G; ---@class _G
}

Interface.__index = Interface

function Interface:extends(...)
    local bases = {...}
    local index = 1
    local iface = bases[index]
    local mname
    while iface do
        for i = 1, #iface do
            mname = iface[i]
            if not self[mname] then
            self[#self+1] = mname
            self[mname] = true
        end end
        index = index + 1
        iface = bases[index]
    end
    return self
end

function Interface:check_impl(clazz)
    for i = 1, #self do
        if type(clazz[self[i]]) ~= "function" then
        return false, self[i]
    end end
    return true
end

function Interface:__call(mnames)
    if type(mnames) ~= "table" then
        error("interface cannot instantiate", 2)
    end
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
    return ("<interface '%s'>")
    :format(self.__iname)
end

local function interface(name)
    if not name then
    return setmetatable({
        __iname = "<anonymous>",
        classes = {}}, Interface)
    end
    local iface = {__iname = name, classes = {}}
    -- print(name, nil == Interface.global[name], Interface.env[name])
    if nil == Interface.global[name] or Interface.env[name] then
        Interface.global[name] = iface
        -- print(_G[name].__iname)
    end
    Interface.env[name] = iface
    return setmetatable(iface, Interface)
end

function class:implements(...)
    self.ifaces = (...) and {...} or nil
    -- print(...)
    return self
end

---@Decorate
function class:__call(clazz)
    if not self.ifaces then return self:create(clazz) end
    local iface
    for i = 1, #self.ifaces do
        iface = self.ifaces[i]
        local ok, mname = iface:check_impl(clazz)
        if not ok then
        error(("class %s implements %s but dose not implement method %s().")
        :format(self.name, iface, mname, iface), 2)
    end end
    return self:create(clazz)
end

function Object:isImplements(...)
    local ifaces = {...}
    for i = 1, #ifaces do
        if not ifaces[i].classes[self] then
        return false, i
    end end
    return true
end

return interface