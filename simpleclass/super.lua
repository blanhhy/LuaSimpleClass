local M = require "simpleclass.m" ---@class M

local type, setmetatable, error, next
    = type, setmetatable, error, next

local getinfo  = debug and debug.getinfo
local getlocal = debug and debug.getlocal
local getcontext, context

_ENV = nil

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
                    break
                end
            end
            objcls = objcls.__base
        end

        context[method] = funcls
        return funcls, this
    end
end

local index = M.index

---@class (exact) M.super : super<class, object>
---@field self    object|class
---@field __class class
---@operator call:nil

---@param proxy M.super
local function superinit(proxy, ...)
    return index(proxy.__class, "__init", true)(proxy.self, ...)
end

local Super = {
    __call  = superinit,
    ---@param proxy M.super
    __index = function(proxy, key)
        if key == "__init" then return superinit end
        local field = index(proxy.__class, key, true)
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

---To call superclass methods  
---eg: `super(cls, self):__init()`
---
---**Zero-argument form constraint**: `super()` locates the defining class and
---the receiver via `debug.getlocal`, so it only works when called directly from
---a colon-call method whose first parameter is the receiver — `self` for instance
---methods, or the class object for class methods (i.e. `function(self, ...)`).
---Static methods and calls outside a method have no perceivable context, so they
---cannot use the zero-argument form (same as Python's `super()`); in those cases
---use the explicit `super(cls, obj)` form instead.
---@generic cls:class, obj:object
---@param cls cls
---@param obj? obj
---@return super<cls, obj>
function M.super(cls, obj)
    if not obj and not cls and getcontext then
        cls, obj = getcontext()
    end
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

return M.super