-- 一种比较intersting的轻量class实现

local G = _G                      ---@class _G
local M = require "simpleclass.m" ---@class simpleclass

local type, setmetatable, error
    = type, setmetatable, error

---@class class_creator
local cc = {
    name = "<anonymous>";
    base = require("simpleclass.object");
}

function cc:extends(basename)
    self.base = M.env[basename]
    return self
end

---@param clazz table
function cc:def(clazz)
    local base = self.base

    for i = 1, #M.mms do
        local mm = M.mms[i]
        if not clazz[mm] then clazz[mm] = base[mm] end
    end

    clazz.__classname = self.name
    clazz.__index = clazz
    clazz.__base = base

    setmetatable(clazz, M.cmt)

    if self.onDef_impl_check then
        local ok, err = self:onDef_impl_check(clazz)
        if not ok then error(err, 2) end
    end

    if self.name ~= "<anonymous>" then
        -- 自动注册为全局变量，但不覆盖已存在的非类全局变量
        if nil == G[self.name] or M.env[self.name] then
            G[self.name] = clazz
        end
        M.env[self.name] = clazz
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
    return setmetatable({
        name = type(name) == "string" and name ~= '' and
        name or "<anonymous>"
    }, cc)
end

return M