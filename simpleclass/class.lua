-- 一种比较intersting的轻量class实现

local G = _G                      ---@class _G
local M = require "simpleclass.m" ---@class simpleclass

local type, setmetatable, error
    = type, setmetatable, error

---@class simpleclass.creator<T> : _ClassCreator<T>
local cc = {
    name = "<anonymous>";
    base = require("simpleclass.object");
}

---Single inheritance keyword
---@generic T
---@param basename? string
---@return _ClassCreator<T>
function cc:extends(basename)
    self.base = M._ENV[basename]
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

    if self.onDef_impl_check then
        local ok, err = self:onDef_impl_check(clazz)
        if not ok then error(err, 2) end
    end

    if M.AUTO_GLOBAL and self.name ~= "<anonymous>" then
        -- 自动注册为全局变量，但不覆盖已存在的非类全局变量
        if nil == G[self.name] or M._ENV[self.name] then
            G[self.name] = clazz
        end
        M._ENV[self.name] = clazz
    end

    return clazz
end

cc.__index = cc
cc.__call  = cc.def

M.creator = cc

---Define a new class  
---eg:
---```lua
---class "MyClass" : extends "MyBaseClass" {
---    __init = function(self)
---        super(self):__init()
---    end
---}
---```
---or anonymous:
---```lua
---local cls = class {}
---```
---@generic T
---@param name `T`
---@return _ClassCreator<T>|_ClassDefiner<T>
---@overload fun(body:table):class
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