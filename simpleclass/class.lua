-- 一种比较intersting的轻量class实现

local G = _G                      ---@class _G
local M = require "simpleclass.m" ---@class M

local type, setmetatable, error, select, next
    = type, setmetatable, error, select, next

local move = table.move or function(t1, f, e, t, t2)
    for i = f, e do
        t2[t + i - f] = t1[i]
    end
    return t2
end

---@diagnostic disable-next-line: deprecated
local load = loadstring or load

---@diagnostic disable-next-line: deprecated
local unpack = table.unpack or G.unpack
local concat = table.concat
local object = require("simpleclass.object")

_ENV = nil

---@class M.creator<T> : _ClassCreator<T>
local cc = {
    name = "<anonymous>";
    base = object;
}

local alias = {}
local Alias = {}

setmetatable(alias, Alias)

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

--[[
类独立字段，必须在定义时显示置为非nil值以阻断继承
__classname：类名，占位"<anonymous>" 
__base：基类，（仅object内）占位false
__index：实例方法提供器，占位该类自身
__property：属性集合，需合并基类，占位false
]]

---Define the class body
---@generic T
---@param clazz table
---@return T
function cc:def(clazz, c2)
    if self == clazz then clazz = c2 end
    local base = self.base

    -- 继承元方法（元方法只能由raw字段触发）
    for i = 1, #M._MMS do
        local mm = M._MMS[i]
        if not clazz[mm] then clazz[mm] = base[mm] end
    end

    -- 如果基类的 __index 是平凡的，子类的 __index 也要是平凡的
    if clazz.__index == base then clazz.__index = clazz end

    for i = 1, #clazz do
        local item = clazz[i]
        local tipe = item and type(item)
        local PROP = "@simpleclass.property."
        if tipe == "table" and item[3] == Alias then
            clazz[i] = nil
            local origin = item[1]
            local target, err = Alias.getTarget(item, clazz, base)
            if target ~= nil then clazz[origin] = target
            else error(err, 2) end
        elseif tipe == "string" and item:sub(1, #PROP) == PROP then
            local key = item:sub(#PROP + 1)
            if key and key ~= "" then
                clazz[i] = nil
                clazz.__property = clazz.__property or {}
                clazz.__property[key] = true
            end
        end
    end

    local pp1 = clazz.__property
    local pp2 = base["__property"]
    if pp1 and pp2 then
        for k, v in next, pp2 do pp1[k] = v end
    end
    clazz.__property = pp1 or pp2

    local ctor = clazz.constructor
    local init = clazz.__init or ctor
    clazz.__init = init
    clazz.constructor = nil

    clazz.new = clazz.new or base.new

    clazz.__base = base
    clazz.__classname = self.name
    setmetatable(clazz, M._CMT)

    if clazz.__property then
        clazz.__index = clazz.__index ~= clazz and clazz.__index or clazz.__getter
        clazz.__newindex = clazz.__newindex or clazz.__setter
    end

    if self.iCheck then
        local ok, err = self:iCheck(clazz)
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

cc.__call = cc.def

function cc:__index(key)
    local keywd = cc[key]
    if keywd ~= nil then return keywd end
    return cc.extends(self, key)
end

---@param self any[]
function Alias:__index(key)
    if self == alias then
        -- 我是笨蛋，不用字符串键就永远不会重名了
        return setmetatable({
            key,   false, false,
            false, false, false,
        }, Alias)
    end
    if self[2] then
        error(("bad alias: alias '%s' already bound to target '%s'; cannot chain '%s'"):
        format(self[1], self[2], key), 2)
    end
    self[2] = key
    self[3] = Alias
    return self
end

---@param self any[]
function Alias:__call(...)
    if self == alias then -- 可以在类体外使用 alias
        local func = ...
        local narg = select('#', ...)
        if narg <= 1 then return ... end
        local args = {select(2, ...)}
        args.i = 1
        args.j = narg - 1
        return Alias.partial(func, args, false, true)
    end
    local static = self  ~=  (...) -- 区分 ':' 和 '.' 语法，前者在构造偏函数时须保留 self 槽
    local offset = static and 0 or 1
    local nargs = select('#', ...)
    local first = static and (...) -- 首参为唯一参数且为表时，视作关键字参数用法
    if not static then local _ _, first = ... end
    if nargs ~= offset then
        self[5] = nargs == offset + 1 and type(first) == "table"
        self[4] = self[5] and first or {...}
        if not self[5] then
            self[4]['i'] = offset + 1
            self[4]['j'] = nargs
    end end
    self[6] = static
    return self
end

-- 1: origin
-- 2: target
-- 3: _Magic
-- 4: args
-- 5: isKwarg
-- 6: isStatic

---@param aliaz any[]
---@return function? target alias target function
---@return string?   errmsg
function Alias.getTarget(aliaz, clazz, base)
    local target = clazz[aliaz[2]]
    if target == nil then target = base[aliaz[2]] end
    if target == nil then return nil
        , ("bad alias: '%s' not found")
        : format(aliaz[2])
    end
    if not aliaz[4] then return target end
    if type(target) ~= "function" then return nil
        , ("bad alias: cannot make partial for non-function field '%s'")
        : format(aliaz[2])
    end
    return Alias.partial(target, aliaz[4], aliaz[5], aliaz[6])
end

---@param func function
---@param fixed_args table
---@param isKwarg?  boolean
---@param isStatic? boolean
function Alias.partial(func, fixed_args, isKwarg, isStatic)
    if not isKwarg then
        local partial
        local MAX_NUPS = 32 -- 避免某些情况下局部变量和上值数量的限制
        if load and fixed_args.j <= MAX_NUPS then
            local count = fixed_args.j - fixed_args.i + 1
            local stmts = {
                [1] = "local fixed, aliased = ...\n",
                [count + 2] = isStatic
                    and "return function(...) return aliased("
                    or  "return function(self, ...) return aliased(self,",
                [count + count + 3] = "...) end"
            }
            for i = 1, count do
                stmts[i + 1] = ("local arg%d = fixed[%d]\n"):format(i, i + fixed_args.i - 1)
                stmts[i + count + 2] = ("arg%d, "):format(i)
            end
            local maker = load(concat(stmts, ''))
            partial = maker and maker(fixed_args, func)
        end
        -- 参数过大或不明原因编译失败，回退旧版通用包装函数
        partial = partial or function(...)
            local narg = select('#', ...)
            local args = {...}
            local merged = {fixed_args.i == 2 and (...) }
            move(fixed_args, fixed_args.i, fixed_args.j, fixed_args.i, merged)
            move(args, fixed_args.i, narg, fixed_args.j + 1, merged)
            return func(unpack(merged, 1, narg + fixed_args.j - fixed_args.i + 1))
        end
        return partial
    end

    return isStatic and function(kwargs, ...)
        kwargs = kwargs or {}
        for k, v in next, fixed_args do kwargs[k] = v end
        return func(kwargs, ...)
    end or function(self, kwargs, ...)
        kwargs = kwargs or {}
        for k, v in next, fixed_args do kwargs[k] = v end
        return func(self, kwargs, ...)
    end
end

M.creator = cc
M.alias = alias

M.property = setmetatable({}, {
    __index = function(_, key)
        return "@simpleclass.property."..key
    end;
})

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
