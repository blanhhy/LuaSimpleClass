local M = require "simpleclass.m" ---@class M

local type, setmetatable, error, next
    = type, setmetatable, error, next

local getinfo  = debug and debug.getinfo
local getlocal = debug and debug.getlocal
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
                    break
                end
            end
            objcls = objcls.__base
        end

        context[method] = funcls
        return funcls, this
    end
end

local function superinit(proxy, ...)
    return proxy.__class.__base.__init(proxy.self, ...)
end

local Super = {
    __mode  = 'k',
    __call  = superinit,
    __index = function(proxy, key)
        if key == "__init" then return superinit end
        local clazz = proxy.__class
        local field = clazz.__base[key]
        if "function" ~= type(field) then return field end
        if proxy[field] then return proxy[field] end
        local proxy_method = function(self, ...)
            self = self == proxy and proxy.self or self -- 重定向 self 指针
            return field(self, ...)
        end
        proxy[field] = proxy_method -- proxy 存在期间会缓存闭包
        return proxy_method
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
    local proxy = setmetatable({
        self    = obj,
        __class = cls,
        __super = true
    }, Super)
    return proxy
end

return M.super