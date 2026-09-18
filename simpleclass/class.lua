-- 一种比较intersting的轻量class实现
local M = require "simpleclass.m" ---@class M
local G = _G                      ---@class _G

local type, setmetatable, error, next
    = type, setmetatable, error, next

local interpret = require("simpleclass.declare")
local object    = require("simpleclass.object")
local index     = M.index

_ENV = nil

---@class M.creator<T> : _ClassCreator<T>
local cc = {
    name = "<anonymous>";
    base = object;
}

---Single inheritance keyword
---@generic T
---@param basename? string
---@return _ClassCreator<T>
function cc:extends(basename)
    local base = M._ENV[basename] ---@class class
    if not base or not base.__classname then
        error(("bad extends: '%s' not found or not a class"):format(basename), 2)
    end
    self.base = base
    return self
end

-- P1: 自身已定义
-- P2: 基类已定义
-- P3: 未定义→平凡（自身或 M.index）

local function check_index(clazz, base)
    if clazz.__index then return 1, clazz.__index end
    if not base.__index or base.__index == base or base.__index == index then return 3, index end
    return 2, base.__index
end

---Define the class body
---@generic T
---@param clazz table
---@return T
function cc:def(clazz, c2)
    if self == clazz then clazz = c2 end
    local base = self.base
    local indexdef, __index = check_index(clazz, base)

    -- 继承元方法（元方法只能由raw字段触发）
    for i = 1, #M._MMS do
        local mm = M._MMS[i]
        if not clazz[mm] then clazz[mm] = base[mm] end
    end

    if base == object then
        -- 对于 object 的直接派生类，由于 object 结构不变
        -- 可以直接本地化少量实例方法，而不真正继承
        -- 采用自身作为平凡 __index
        clazz.__index    = clazz.__index    or clazz
        clazz.is         = clazz.is         or object.is
        clazz.clone      = clazz.clone      or object.clone
        clazz.getClass   = clazz.getClass   or object.getClass
        clazz.isInstance = clazz.isInstance or object.isInstance
    else
        -- 深继承时，采用 M.index 作为平凡 __index
        clazz.__index = __index
    end

    -- 类不继承，必要方法须自持
    clazz.new      = clazz.new      or base.new
    clazz.toString = clazz.toString or base.toString

    local narr = #clazz
    if narr > 0 then interpret(clazz, base, narr) end

    local pp1 = clazz.__property
    local pp2 = base["__property"]
    if pp1 and pp2 then
        for k, v in next, pp2 do pp1[k] = v end
    end
    clazz.__property = pp1 or pp2

    local ctor = clazz.constructor
    local init = clazz.__init or ctor
    clazz.__base = base
    clazz.__init = init
    clazz.constructor = nil
    clazz.__classname = self.name

    if clazz.__property then
        -- 自定义 index&newindex 优先，未定义时框架自动实现 getter&setter 访问逻辑
        clazz.__newindex = clazz.__newindex or object.__setter
        clazz.__index = indexdef == 3 and object.__getter or clazz.__index
    end

    if self.ifaces and self.iCheck then
        local ok, er = self:iCheck(clazz)
        if not ok then error(er, 2) end
    end

    if self.name ~= "<anonymous>" then
        -- 自动注册为全局变量，但不覆盖已存在的非类全局变量
        -- 解释：G.<name> 不存在时允许注册，或已经存在且是类时也允许注册（覆盖）
        if M.AUTO_GLOBAL and (nil == G[self.name] or M._ENV[self.name] == G[self.name]) then
            G[self.name] = clazz
        end
        M._ENV[self.name] = clazz
    end

    return setmetatable(clazz, M._CMT)
end

cc.__call = cc.def

function cc:__index(key)
    local keywd = cc[key]
    if keywd ~= nil then return keywd end
    return cc.extends(self, key)
end

M.creator = cc

---Define a new class  
---eg:
---```lua
---class "MyClass" : MyBase {
---    __init = function(self)
---        super():__init()
---    end
---}
---```
---or anonymous:
---```lua
---local cls = class {}
---```
---@generic T:string
---@param name? `T`.class
---@return _ClassCreator<T>|_ClassDefiner<T>
---@overload fun(tbl:table):class
function M.class(name)
    local typ = type(name)
    if typ == "table" then
        return cc:def(name)
    end
    ---@generic T
    ---@type _ClassCreator<T>
    return setmetatable({
        name = typ == "string" and name ~= '' and
        name or "<anonymous>"
    }, cc)
end

return M.class
