local M = require "simpleclass.m" ---@class M

local type, setmetatable, error
    = type, setmetatable, error

local getinfo  = debug and debug.getinfo
local getlocal = debug and debug.getlocal
local getcontext, pack, unpack

if getinfo and getlocal then
    function getcontext()
        local _, obj, cls, proxy
        if getinfo(4) then
            _, proxy = getlocal(4, 1)
            if type(proxy) == "table" and proxy.__super then
                obj = proxy.self
                cls = proxy.__class.__base
            end
        end
        if not obj or not cls then
            _, obj = getlocal(3, 1)
            cls = type(obj) == "table" and obj.__class
        end
        return obj, cls
    end
    local is52p = tonumber(_VERSION:sub(5)) > 5.1
    pack = is52p and table.pack or function(...)
            return {..., n = select('#', ...)}
        end
    ---@diagnostic disable-next-line: deprecated
    unpack = is52p and table.unpack or _G.unpack
end


local Super = {
    __mode  = 'k',
    __index = function(proxy, key)
        local clazz = proxy.__class
        local field = clazz.__base[key]
        if "function" ~= type(field) then return field end
        if proxy[field] then return proxy[field] end
        local proxy_method = getcontext and function (this, ...)
            local ret = pack(field(this == proxy        -- 保留调用栈，维持 super 上下文
                    and proxy.self
                    or  this, ...))
            return unpack(ret, 1, ret.n)
        end or function (self, ...)
            self = self == proxy and proxy.self or self -- 重定向 self 指针
            return field(self, ...)
        end
        proxy[field] = proxy_method                     -- proxy 存在期间会缓存闭包
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
        obj, cls = getcontext()
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