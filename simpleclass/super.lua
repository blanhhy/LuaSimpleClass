local M = require "simpleclass.m" ---@class simpleclass

local type, setmetatable, error
    = type, setmetatable, error

local Super = {
    __mode  = 'k',
    __index = function(proxy, key)
        local field = proxy.__super[key]
        if "function" ~= type(field) then return field end
        if proxy[field] then return proxy[field] end
        local function proxy_method(self, ...)
            self = self == proxy and proxy.self or self -- 重定向 self 指针
            return field(self, ...)
        end
        proxy[field] = proxy_method -- 缓存闭包，避免对同一个函数多次创建代理
        return proxy_method
    end
}

setmetatable(Super, {__mode = 'k'})

function M.super(obj)
    local valid = obj and (Super[obj] or type(obj) == "table" and obj.__base)
    if not valid then error("super: invalid object", 2) end
    local proxy = Super[obj] or setmetatable({
        self    = obj,
        __super = obj.__base,
    }, Super)
    Super[obj] = proxy -- 缓存代理对象，防止方法反复调用后产生许多临时对象
    return proxy ---@type table
end

return M