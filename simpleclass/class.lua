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

---Define the class body
---@generic T
---@param clazz table
---@return T
function cc:def(clazz, c2)
    if self == clazz then clazz = c2 end
    local base = self.base

    for i = 1, #M._MMS do
        local mm = M._MMS[i]
        if not clazz[mm] then clazz[mm] = base[mm] end
    end

    -- 如果基类的 __index 是平凡的，子类的 __index 也要是平凡的
    if base.__index == base then clazz.__index = clazz end

    for i = 1, #clazz do
        local item = clazz[i]
        local tipe = item and type(item)
        local PROP = "@simpleclass.property."
        if tipe == "table" and item._ALIAS == Alias then
            clazz[i] = nil
            local origin = item.origin
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

    local init = clazz.__init
    local ctor = clazz.constructor
    if init ~= ctor then
        init = init or ctor
        ctor = ctor or init
    end
    if init ~= ctor then
        error("bad class definition: different '__init' and 'constructor'", 2)
    end

    clazz.__base = base
    clazz.__init = init
    clazz.constructor = ctor
    clazz.__classname = self.name

    setmetatable(clazz, M._CMT)

    if clazz.__property then
        clazz.__index = clazz.__index ~= clazz and clazz.__index or clazz.__getter
        clazz.__newindex = clazz.__newindex or clazz.__setter
    end

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

cc.__call = cc.def

function cc:__index(key)
    local keywd = cc[key]
    if keywd ~= nil then return keywd end
    return cc.extends(self, key)
end


function Alias:__index(key)
    if self == alias then
        return setmetatable({
            -- 为了避免语法解析途中 alias 的数据字段和方法名重名  
            -- 这里需要反过来将方法名作为数据字段名，而数据字段名作为值  
            -- 等待 target 名也设置完毕后，就可以正常地用字段名存储了
            [key] = "origin"
        }, Alias)
    end
    local key1, val1 = next(self)
    local key2, val2 = next(self, key1)
    if key1 ~= nil and key2 ~= nil then
        error(("bad alias: got duplicate target '%s'"):
        format(key), 2)
    end
    if key1 and val1 == "origin" then
        self[key1] = nil
        self.origin = key1
    end
    if key2 and val2 == "origin" then
        self[key2] = nil
        self.origin = key2
    end
    self.target = key
    self._ALIAS = Alias
    return self
end

function Alias:__call(...)
    if self == alias then return self end
    local static = self  ~=  (...) -- 区分 ':' 和 '.' 语法，前者在构造偏函数时须保留 self 槽
    local offset = static and 0 or 1
    local nargs = select('#', ...)
    local first = static and (...) -- 首参为唯一参数且为表时，视作关键字参数用法
    if not static then local _ _, first = ... end
    if nargs ~= offset then
        self.kwarg = nargs == offset + 1 and type(first) == "table"
        self.args  = self.kwarg and first or {...}
        if not self.kwarg then
            self.args['i'] = offset + 1
            self.args['j'] = nargs
        end
    else
        self.kwarg = false
        self.args  = false
    end
    self.isStatic = static
    return self
end

---@return function? target alias target function
---@return string?   errmsg 
function Alias.getTarget(alias, clazz, base)
    local target = clazz[alias.target]
    if target == nil then target = base[alias.target] end
    if target == nil then return nil
        , ("bad alias: '%s' not found")
        : format(alias.target)
    end

    local fixed_args = alias.args
    if not fixed_args then return target end

    if type(target) ~= "function" then return nil
        , ("bad alias: cannot make partial for non-function field '%s'")
        : format(alias.target)
    end

    if not alias.kwarg then
        local partial
        local MAX_ARGS = 32 -- 避免某些情况下局部变量和上值数量的限制
        if load and fixed_args.j <= MAX_ARGS then
            local count = fixed_args.j - fixed_args.i + 1
            local stmts = {
                [1] = "local fixed, aliased = ...\n",
                [count + 2] = alias.isStatic
                    and "return function(...) return aliased("
                    or  "return function(self, ...) return aliased(self,",
                [count + count + 3] = "...) end"
            }
            for i = 1, count do
                stmts[i + 1] = ("local arg%d = fixed[%d]\n"):format(i, i + fixed_args.i - 1)
                stmts[i + count + 2] = ("arg%d, "):format(i)
            end
            local maker = load(concat(stmts, ''))
            partial = maker and maker(fixed_args, target)
        end
        -- 参数过大或不明原因编译失败，回退旧版通用包装函数
        partial = partial or function(...)
            local narg = select('#', ...)
            local args = {...}
            local merged = {fixed_args.i == 2 and (...) }
            move(fixed_args, fixed_args.i, fixed_args.j, fixed_args.i, merged)
            move(args, fixed_args.i, narg, fixed_args.j + 1, merged)
            return target(unpack(merged, 1, narg + fixed_args.j - fixed_args.i + 1))
        end
        return partial
    end

    return alias.isStatic and function(kwargs, ...)
        kwargs = kwargs or {}
        for k, v in next, fixed_args do kwargs[k] = v end
        return target(kwargs, ...)
    end or function(self, kwargs, ...)
        kwargs = kwargs or {}
        for k, v in next, fixed_args do kwargs[k] = v end
        return target(self, kwargs, ...)
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
