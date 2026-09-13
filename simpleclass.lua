---SimpleClass (runtime) but all in one file.
---@diagnostic disable: deprecated
local _, _, margs = ...
local options = {}

options.GLOBAL_IMPORT      = true;
options.INTERFACE_INCLUDED = true;
options.DEFAULT_I_FEATURE  = "general";

if type(margs) == "table" then
    for k, v in next, margs do
    if v ~= nil then options[k] = v
    end end end

--[[                    ## UNLICENSE
----
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org> ]]
local M = {}
local G = _G

local type, getmetatable, setmetatable, error, select, next, rawset
    = type, getmetatable, setmetatable, error, select, next, rawset

local unpack = table.unpack or G.unpack
local concat = table.concat

local getinfo  = debug and debug.getinfo
local getlocal = debug and debug.getlocal
local rawgetmt = debug and debug.getmetatable or getmetatable
local rawsetmt = debug and debug.setmetatable or setmetatable

local load = loadstring or load
local move = table.move or function(t1, f, e, t, t2)
    for i = f, e do
        t2[t + i - f] = t1[i]
    end
    return t2
end

_ENV = nil

local mm_names = {
    "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__idiv", "__unm",
    "__band", "__bor", "__bxor", "__bnot", "__shl", "__shr", "__eq", "__lt",
    "__le", "__concat", "__len", "__tostring", "__pairs", "__gc", "__close",
    "__index", "__newindex", "__call",
}

local class_MT = {
    __index = function(self, k) if self.__base then return self.__base[k] end end;
    __tostring = function(self) return self.__classname end;
    __call = function(self, ...) return self:new(...) end;
}

local sc_ENV = {}

local object = {
    __base = false;
    __property = false;
    __classname = "object";
    __tostring = function(self) return ("<%s object>"):format(self.__class) end;
    getClass = function(self) return self.__class end;
    toString = G.tostring;
    is = G.rawequal;
}

object.__index = object

function object:__getter(key)
    local claz = self.__class
    local prop = claz["__property"]
    local gett = prop and prop[key] and claz["get." .. key]
    if gett then return gett(self) end
    return claz[key]
end

function object:__setter(key, v)
    local clazz = self.__class
    local prope = clazz["__property"]
    if not prope or not prope[key] then
        return rawset(self, key, v)
    end
    local sett = clazz["set." .. key]
    if sett then return sett(self, v) end
end

function object:new(...)
    local inst = setmetatable({__class = self}, self)
    local ctor = self['__init']
    if ctor then ctor(inst, ...) end
    return inst
end

function object:isExtends(base)
    while type(self) == "table" do
        if self == base then return true end
        self = self.__base
    end
    return false
end

function object:isInstance(T)
    local typ = type(self)
    if typ ~= "table" or type(T) ~= "table" then
        return T == typ
    end
    local check = T.check_impl
    local clazz = self.__class
    if check then return check(T--[[@as interface]], self) end
    if clazz then return clazz:isExtends(T--[[@as class]]) end
    return false
end

function object:clone(isDeep)
    isDeep = isDeep == nil and true or isDeep
    local seen = {}
    local function copy(src, clazz)
        if seen[src] then return seen[src] end
        local c = {} seen[src] = c
        for k, v in next, src do
            if k == "__class" and v == clazz then
                c[k] = clazz
            elseif isDeep and type(v) == "table" then
                c[k] = copy(v, rawgetmt(v))
            else c[k] = v end
        end
        rawsetmt(c, clazz)
        return c
    end
    return copy(self, rawgetmt(self))
end

setmetatable(object, class_MT)
sc_ENV.object = object

local cc = {
    name = "<anonymous>";
    base = object;
}

local alias = {}
local Alias = {}

setmetatable(alias, Alias)

function cc:extends(basename)
    local base = sc_ENV[basename]
    if not base or not base.__classname then
        error(("bad extends: '%s' not found or not a class"):format(basename), 2)
    end
    self.base = base
    return self
end

function cc:def(clazz, c2)
    if self == clazz then clazz = c2 end
    local base = self.base

    for i = 1, #mm_names do
        local mm = mm_names[i]
        if not clazz[mm] then clazz[mm] = base[mm] end
    end

    if clazz.__index == base then clazz.__index = clazz end

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
    setmetatable(clazz, class_MT)

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
        if M.AUTO_GLOBAL and (nil == G[self.name] or sc_ENV[self.name] == G[self.name]) then
            G[self.name] = clazz
        end
        sc_ENV[self.name] = clazz
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
            [key] = "origin"
        }, Alias)
    end
    local key1, val1 = next(self)
    local key2, val2 = next(self, key1)
    if key1 ~= nil and key2 ~= nil then
        error(("bad alias: alias '%s' already bound to target '%s'; cannot chain '%s'"):
        format(self.origin, self.target, key), 2)
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
    local static = self  ~=  (...)
    local offset = static and 0 or 1
    local nargs = select('#', ...)
    local first = static and (...)
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

local getcontext, context

if getinfo and getlocal then
    function getcontext()
        context = context or setmetatable({}, {__mode = 'kv'})
        local wt = "f"
        local _, this = getlocal(3, 1)
        local imethod = getinfo(3, wt)

        local objcls = this.__class or this
        local method = imethod.func
        local funcls = context[method]
        if funcls then return funcls, this end

        while not funcls and objcls do
            for _, v in next, objcls do
            if v == method then
            funcls = objcls
            break end end
            objcls = objcls.__base
        end

        context[method] = funcls
        return funcls, this
    end
end

local function superinit(proxy, ...)
    return proxy.__class.__base.__init(proxy.self, ...)
end

local Super = {
    __call  = superinit,
    __index = function(proxy, key)
        if key == "__init" then return superinit end
        local clazz = proxy.__class
        local field = clazz.__base[key]
        if "function" ~= type(field) then return field end
        return function(self, ...)
            self = self == proxy and proxy.self or self
            return field(self, ...)
        end
    end,
    __tostring = function(proxy)
        return ("super<%s, %s>"):format(
            proxy.__class,
            proxy.self
        )
    end
}

local interface
if options.INTERFACE_INCLUDED then

local I = {}
I.__index = I

function I:__tostring()
    return ("<interface '%s'>")
    :format(self.__iname or '?')
end

function I:extends(...)
    if M.I_FEATURE == "lexical" then return self end
    local bases = {...}
    local iface, mname
    for j = 1, #bases do
        iface = bases[j]
        if type(iface) ~= "table" or not iface.__iname then
            error(("bad interface extends: interface expected, got %s at #%d"):
            format(iface, j), 2)
        end
        for i = 1, #iface do
            mname = iface[i]
            if not self[mname] then
            self[#self+1] = mname
            self[mname] = true
        end end
    end
    return self
end

function I:__call(mnames)
    if type(mnames) ~= "table" then
        error("interface cannot instantiate", 2)
    end
    if M.I_FEATURE == "lexical" then return self end
    local mname
    for i = 1, #mnames do
        mname = mnames[i]
        if not self[mname] then
        self[#self+1] = mname
        self[mname] = true
    end end
    return self
end

function I:check_impl(clazz)
    if M.I_FEATURE ~= "general" then return true end
    for i = 1, #self do
        if type(clazz[self[i]]) ~= "function" then
        return false, self[i]
    end end
    return true
end

function interface(name)
    if M.I_FEATURE == "lexical" then return setmetatable({}, I) end
    local typ = type(name)
    if typ == "table" then
        local iface = name
        local count = 0
        for i = 1, #iface do
            local mname = iface[i]
            if not iface[mname] then
            iface[count+1] = mname
            iface[mname] = true
            count = count + 1
        end end
        iface.__iname = "<anonymous>"
        return setmetatable(iface, I)
    elseif typ ~= "string" or name == "" then
        return setmetatable({
        __iname = "<anonymous>"
        }, I)
    end
    local iface = {__iname = name}
    if M.AUTO_GLOBAL and (nil == G[name] or sc_ENV[name] == G[name]) then
        G[name] = iface
    end
    sc_ENV[name] = iface
    return setmetatable(iface, I)
end

cc.ifaces = false

function cc:implements(...)
    if M.I_FEATURE == "lexical" then return self end
    self.ifaces = (...) and {...} or nil
    return self
end

cc.impl = cc.implements

function cc:check_impl(clazz)
    if M.I_FEATURE ~= "general" then return true end
    if not self.ifaces then return true end
    for i = 1, #self.ifaces do
        local iface = self.ifaces[i]
        if not iface or not iface.__iname or not iface.check_impl then
            error(("bad implements: interface expected, got %s at #%d"):
            format(iface, i), 2)
        end
        local ok, mname = iface:check_impl(clazz)
        if not ok then return false,
        ("class %s implements %s but does not implement method '%s'.")
        :format(self.name, iface, mname)
    end end
    return true
end

function object:isImplements(...)
    if M.I_FEATURE ~= "general" then return true end
    local ifaces = {...}
    for i = 1, #ifaces do
        if not ifaces[i].check_impl
        or not ifaces[i]:check_impl(self)
        then return false, i
    end end
    return true
end

end --# options.INTERFACE_INCLUDED

M.AUTO_GLOBAL = false
M.I_FEATURE = options.DEFAULT_I_FEATURE

M._ENV = sc_ENV

M.creator = cc
M.alias = alias

M.property = setmetatable({}, {
    __index = function(_, key)
        return "@simpleclass.property."..key
    end;
})

M.object = object
M.isinstance = object.isInstance
M.issubclass = object.isExtends

function M.type(v)
    local  t = type(v)
    return t == "table" and v.__class or t
end

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

function M.super(cls, obj)
    if not obj and not cls and getcontext then
        cls, obj = getcontext()
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
    }, Super)
    return proxy
end

M.interface = interface

function M.env_import(fields, env)
    env = env or G
    for k, v in next, fields do
        if M[v] then env[v] = M[v]
    elseif M[k] then env[v] = M[k]
    end end end

if options.GLOBAL_IMPORT then
    M.AUTO_GLOBAL = true
    M.env_import {
        "class", "super", "object",
        "interface", "property",
        "isinstance", "issubclass",
    }
end

return M
