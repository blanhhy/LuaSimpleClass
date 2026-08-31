---@meta simpleclass
---Types declare for simpleclass module





---@class class<T>                    # A reflection of a class
---@field __classname string          # The name of the class
---@field __class T                   # The class type
---@field __base class|false          # The base class
---@field __init function?            # The constructor
---@operator call:class.instance
local Class = {}

---@class class.instance<T> : class<T>

---Create a new object of the class
---@generic T
---@return class.instance<T>
function Class:new() end

---Check if the class extends the base class
---@param base class
---@return boolean
function Class:isExtends(base) end

---Check if the class implements the interface
---@param interface interface
---@return boolean  ok
---@return integer? arg_index if not ok
function Class:isImplements(interface) end

---Check if the object is an instance of the class or interface  
---(also compatible with lua type)
---@param cls class|interface|type
---@return boolean
function Class:isInstance(cls) end

---Convert the class to a string
---@return string
function Class:toString() end





---Base class of all classes
---@class object : class
---@field __class object
---@field __base false
object = {__classname = "object"}

---Instantiate
---@return object
function object:new() end

---Get the class of the object
---@return object
function object:getClass() end

object.is = rawequal





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
---@param name? `T`
---@return _ClassCreator<T>|_ClassDefiner<T>
function class(name) end

---@param body table
---@return object
function class(body) end





---@class super<T>
---@field self T
---@field __class T
---@field [string] unknown

---To call superclass methods  
---eg: `super(cls, self):__init()`
---@generic T:object
---@param cls T
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
---@param name? string
---@return interface
function interface(name) end





isinstance = Class.isInstance
issubclass = Class.isExtends
