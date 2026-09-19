---@diagnostic disable: lowercase-global
local sc = require "simpleclass"

local ctype = sc.type
local alias = sc.alias
local floor = math.floor

local type, select, error
    = type, select, error

-- 通过同时给类对象标注 .class 和 .constructor 类型
-- 可以实现 cls() 语法也像 cls:new() 一样拥有签名检查

-- 仿 Python 的 range 类
---@type range.constructor|range.class
local range = class "range" {
    ---@field private   _i          number
    ---@field private   _LEN        number
    ---@field protected START       number
    ---@field protected STOP        number
    ---@field protected STEP        number
    ---@field protected IS_INCREASE boolean

    ---@param ... number
    ---@overload fun(self:range, stop:integer)
    ---@overload fun(self:range, start:integer, stop:integer, step?:integer)
    __init = function(self, ...)
        local n, i, j, s = select("#", ...)
        if n == 0 then error("bad argument to range, value expected.", 3) end
        if n == 1 then
            i = 1
            s = 1
            j = ...
            if type(j) ~= "number" then
                error(("bad argument #1 to range, number expected. got %s."):
                format(ctype(j)), 3)
            end
        elseif n == 2 then
            i, j = ...
            s = 1
            if type(i) ~= "number" then
                error(("bad argument #1 to range, number expected. got %s."):
                format(ctype(i)), 3)
            end
            if type(j) ~= "number" then
                error(("bad argument #2 to range, number expected. got %s."):
                format(ctype(j)), 3)
            end
        else
            i, j, s = ...
            if type(i) ~= "number" then
                error(("bad argument #1 to range, number expected. got %s."):
                format(ctype(i)), 3)
            end
            if type(j) ~= "number" then
                error(("bad argument #2 to range, number expected. got %s."):
                format(ctype(j)), 3)
            end
            if type(s) ~= "number" then
                error(("bad argument #3 to range, number expected. got %s."):
                format(ctype(s)), 3)
            end
            if s == 0 then error("bad range: step cannot be 0.", 3) end
        end

        self.START = i
        self.STOP = j
        self.STEP = s
        self.IS_INCREASE = s > 0

        self._i = i
    end;

    property.length;
    ['get.length'] = function(self)
        if not self._LEN then
            self._LEN = floor((self.STOP - self.START) / self.STEP) + 1
        end
        return self._LEN
    end;

    __len = function (self) return self.length end;

    __tostring = function (self)
        return ("range(%d, %d, %d)"):format(self.START, self.STOP, self.STEP)
    end;

    ---@return number?
    next = function(self)
        local current = self._i
        if self.IS_INCREASE == (current > self.STOP) then -- 同或
            return nil
        end
        self._i = current + self.STEP
        return current
    end;

    -- 确保可以被 for 直接调用
    alias.__call.next();

    -- 重置迭代器
    wind = function (self)
        self._i = self.START
        return self
    end
}

if ... then return range end

for i in range(1, 10, 2) do
    print(i)
end

-- Outputs:
-- 1
-- 3
-- 5
-- 7
-- 9
--

local r = range(1, 10, 2)
print(r)  --> range(1, 10, 2)
print(#r) --> 5                 # Lua 5.2+
