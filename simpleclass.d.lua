---@meta
---Types declare for simpleclass module




---A reflection of a class
---@class class
local Class = {}

---Check if the class extends the base class (class method)
---@param base class
---@return boolean
function Class:isExtends(base) end

---Check if the class implements the interface
---@param interface interface
---@return boolean  ok
---@return integer? arg_index if not ok
function Class:isImplements(interface) end

---Convert the object to a string
---@return string
function Class:toString() end





---The base class of all classes
---@class object.class : class
---@operator call: object
object = {__classname = "object"}

---@return object
function object:new() end

---@class object
---@field __class object.class
object.__proto = {}

---Get the class of the object
---@return class
function object.__proto:getClass() end

---Check if the object is an instance of the class or interface  
---(also compatible with lua type)
---@param cls class|interface|type
---@return boolean
function object.__proto:isInstance(cls) end

---Convert the object to a string
---@return string
function object.__proto:toString() end

object.__proto.is = rawequal





---@alias _ClassDefiner<T> fun(tbl: table): T
---@class _ClassCreator<T>
local _CC = {}

---Single inheritance keyword
---@generic T
---@param basename? string
---@return _ClassCreator<T>|_ClassDefiner<T>
function _CC:extends(basename) end

---Implements the interfaces
---@generic T
---@param ... interface
---@return _ClassCreator<T>|_ClassDefiner<T>
function _CC:implements(...) end

---Define the class body
---@generic T
---@param tbl table
---@return T
function _CC:def(tbl) end

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
---@generic T:string
---@param name? `T`.class
---@return _ClassCreator<T>|_ClassDefiner<T>
function class(name) end

---@param body table
---@return class
function class(body) end





---@class super<T>
---@field self T
---@field __class class
---@field [string] unknown

---To call superclass methods  
---eg: `super(cls, self):__init()`
---@generic T:object
---@param cls class
---@param obj? T
---@return super<T>
function super(cls, obj) end





---@class interface
---@field __iname string?
local Interface = {}

---Check if the class implements the interface
---@param clazz class
---@return boolean ok
---@return string? method_name if not ok
function Interface:check_impl(clazz) end

---Extend the interface with other interfaces
---@param ... interface
---@return interface
function Interface:extends(...) end

---Define a new interface
---@param name string
---@return interface
function interface(name) end

---Define a new interface
---@param body? table
---@return interface
function interface(body) end



isinstance = object.__proto.isInstance
issubclass = Class.isExtends
