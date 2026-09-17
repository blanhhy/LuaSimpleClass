---@diagnostic disable deprecated
local M = require "simpleclass.m" ---@class M

local load = loadstring or load
local move = table.move or function(t1, f, e, t, t2)
    for i = f, e do
        t2[t + i - f] = t1[i]
    end
    return t2
end

local unpack = table.unpack or _G.unpack
local concat = table.concat
local type, next, select, setmetatable, error
    = type, next, select, setmetatable, error

_ENV = nil

local alias = {}
local Alias = {}

setmetatable(alias, Alias)

---@param self any[]
function Alias:__index(key)
    if self == alias then
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

M.alias = alias
M.property = setmetatable({}, {
    __index = function(_, key)
        return "@simpleclass.property."..key
    end;
})

---@param clazz table
---@param base  class
---@param maxn  integer
return function(clazz, base, maxn)
    for i = 1, maxn do
        local item = clazz[i]
        local tipe = item and type(item)
        local PROP = "@simpleclass.property."
        if tipe == "table" and item[3] == Alias then
            clazz[i] = nil
            local origin = item[1]
            local target, err = Alias.getTarget(item, clazz, base)
            if target ~= nil then clazz[origin] = target
            else error(err, 3) end
        elseif tipe == "string" and item:sub(1, #PROP) == PROP then
            local key = item:sub(#PROP + 1)
            if key and key ~= "" then
                clazz[i] = nil
                clazz.__property = clazz.__property or {}
                clazz.__property[key] = true
            end
        end
    end
end
