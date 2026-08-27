local M = require "simpleclass.m" ---@class simpleclass

local type, setmetatable, error
    = type, setmetatable, error

local Super = {
    __mode  = 'k',
    __index = function(proxy, key)
        local field = proxy.__class.__base[key]
        if "function" ~= type(field) then return field end
        if proxy[field] then return proxy[field] end
        local function proxy_method(self, ...)
            self = self == proxy and proxy.self or self -- 重定向 self 指针
            return field(self, ...)
        end
        proxy[field] = proxy_method -- proxy存在期间会缓存闭包
        return proxy_method
    end
}

setmetatable(Super, {__mode = 'k'})



---To call superclass methods  
---eg: `super(cls, self):__init()`
function M.super(cls, obj)
    if not obj then obj = cls end
    local valid = obj and (Super[obj] or type(obj) == "table" and obj.__base)
    if not valid then error("super: invalid object", 2) end
    local proxy = setmetatable({
        self    = obj,
        __class = cls,
    }, Super)
    return proxy
end

return M.super