-- 一种比较intersting的轻量class实现

local G = _G                      ---@class _G
local M = require "simpleclass.m" ---@class M

local type, setmetatable, error
    = type, setmetatable, error

---@class M.creator<T> : _ClassCreator<T>
local cc = {
    name = "<anonymous>";
    base = require("simpleclass.object");
}

---Single inheritance keyword
---@generic T
---@param basename? string
---@return _ClassCreator<T>
function cc:extends(basename)
    local base = M._ENV[basename]
    if not base or not base.__classname then
        error(("bad extends: '%s' not found or not a class"):format(basename), 2)
    end
    self.base = base
    return self
end

---Define the class body
---@generic T
---@param clazz table
---@return T
function cc:def(clazz)
    local base = self.base

    for i = 1, #M._MMS do
        local mm = M._MMS[i]
        if not clazz[mm] then clazz[mm] = base[mm] end
    end

    clazz.__classname = self.name
    clazz.__base = base

    setmetatable(clazz, M._CMT)

    if self.check_impl then
        local ok, err = self:check_impl(clazz)
        if not ok then error(err, 2) end
    end

    if self.name ~= "<anonymous>" then
        -- 自动注册为全局变量，但不覆盖已存在的非类全局变量
        -- 解释：G.<name> 不存在时允许注册，或已经存在且是类时也允许注册（覆盖）
        if M.AUTO_GLOBAL and (nil == G[self.name] or M._ENV[self.name] == G[self.name]) then
            G[self.name] = clazz
        end
        M._ENV[self.name] = clazz
    end

    return clazz
end

cc.__index = cc
cc.__call  = cc.def

M.creator = cc


function M.class(name)
    local typ = type(name)
    if typ == "table" then
        return cc:def(name)
    end
    ---@generic T
    ---@type _ClassCreator<T>
    return setmetatable({
        name = type(name) == "string" and name ~= '' and
        name or "<anonymous>"
    }, cc)
end

return M.class