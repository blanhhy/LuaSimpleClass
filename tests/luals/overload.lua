-- overload 签名分派测试
-- 经过 patches/overload_dispatch 后，应该分派成更具体的类型而不是联合类型
local sc = require "simpleclass"

class "OverloadBase_7c8a" {}
class "OverloadChild_7c8a" : extends "OverloadBase_7c8a" {}

local child = OverloadChild_7c8a:new()

local classResult = sc.type(child) -- 应为 class<OverloadChild_7c8a> 而非 class|type
local typeResult = sc.type("value") -- 应为 type 而非 class|type
local anonymousClass = class{} -- 应为 class 而非 _ClassCreator<T:string>|_ClassDefiner<T:string>|class

---@param c class
local function take_class(c) return c end

---@param t type
local function take_type(t) return t end

-- 均不应触发 param-type-mismatch 诊断
take_class(OverloadBase_7c8a)
take_class(classResult)
take_class(anonymousClass)
take_type("string")
take_type(typeResult)

---@class OverloadValueBase_7c8a
---@class OverloadValueChild_7c8a : OverloadValueBase_7c8a
local overloadValue = {} ---@type OverloadValueChild_7c8a

---@param value OverloadValueBase_7c8a
---@return "base"
---@overload fun(value: OverloadValueChild_7c8a): "child"
---@diagnostic disable-next-line: missing-return
local function chooseSubtype(value) end

---@param value "child"
local function takeChild(value) end
takeChild(chooseSubtype(overloadValue))

---@param value string
---@return "string"
---@overload fun(value: "special"): "literal"
---@diagnostic disable-next-line: missing-return
local function chooseLiteral(value) end

---@param value "literal"
local function takeLiteral(value) end
takeLiteral(chooseLiteral("special"))

---@alias OverloadScalar_7c8a string|number
---@param value OverloadScalar_7c8a
---@return "scalar"
---@overload fun(value: string): "string"
---@diagnostic disable-next-line: missing-return
local function chooseUnion(value) end

---@param value "string"
local function takeString(value) end
takeString(chooseUnion("text"))

---@param value any
---@return "fallback"
---@overload fun(value: integer): "integer"
---@diagnostic disable-next-line: missing-return
local function chooseFallback(value) end

---@param value "integer"
local function takeInteger(value) end
takeInteger(chooseFallback(1))
