-- overload 签名分派测试
-- 经过 patches/overload_dispatch 后，应该分派成更具体的类型而不是联合类型
local sc = require "simpleclass"

class "OverloadBase_7c8a" {}
class "OverloadChild_7c8a" : extends "OverloadBase_7c8a" {}

local child = OverloadChild_7c8a()

local classResult = sc.type(child)
local typeResult = sc.type("value")

---@param c class
local function take_class(c) return c end

---@param t type
local function take_type(t) return t end

-- 均不应触发 param-type-mismatch 诊断
take_class(OverloadBase_7c8a)
take_class(classResult)
take_type("string")
take_type(typeResult)
