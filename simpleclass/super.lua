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

---@class (exact) M.super : super<class, object>
---@field [1] object|class
---@field [2] class
---@field [3] function?

local Super = {
    __mode  = "v", -- 不应影响被代理对象和方法的生命周期
    ---@param proxy M.super
    __call  = function(proxy, self, ...)
        if proxy == self then return proxy[3](proxy[2], ...) end
        return proxy[1]["__base"]["__init"](proxy[2], self, ...)
    end,
    ---@param proxy M.super
    __index = function(proxy, key)
        local field = proxy[1]["__base"][key]
        if "function" ~= type(field) then return field end
        proxy[3] = field -- 直接复用 super 对象作为 method 语义，避免 FNEW
        return proxy
    end,
    __tostring = function(p)
        return p[3]
        and ("bound<%s, %s>"):format(p[2], p[3])
        or  ("super<%s, %s>"):format(p[1], p[2])
    end
}

-- 1: cls
-- 2: obj
-- 3: method

---To call superclass methods  
---eg: `super(cls, self):__init()`
---@generic cls:class, obj:object
---@param cls cls
---@param obj? obj
---@return super<cls, obj>
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


return M.super
