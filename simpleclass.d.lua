---@meta simpleclass
---Types declare for simpleclass module

---@class simpleclass
local sc = {}

---@class class
---@class object
---@class object.class : class
---@operator call: object

---@class interface
---@field __iname string?

---@class super<cls, obj>
---@field self obj
---@field __class cls
---@field [string] unknown


-----------------------------------------------------------------------------------------------------


---A reflection of a class
---@class class
local c

---Check if the class extends the base class
---@param base class
---@return boolean
function c:isExtends(base) end

---Check if the class implements the interface
---@param interface interface
---@return boolean  ok
---@return integer? arg_index if not ok
function c:isImplements(interface) end

---Convert the object to a string
---@return string
function c:toString() end


-----------------------------------------------------------------------------------------------------

---The base class of all classes
---@class object.class
local o = {__classname = "object"}

---@return object
function o:new() end

---@class object
---@field __class object.class
o.__proto = {}

---Get the class of the object
---@return class
function o.__proto:getClass() end

---Check if the object is an instance of the class or interface  
---(also compatible with lua type)
---@param cls class|interface|type
---@return boolean
function o.__proto:isInstance(cls) end

---Convert the object to a string
---@return string
function o.__proto:toString() end

o.__proto.is = rawequal


-----------------------------------------------------------------------------------------------------


---@alias _ClassDefiner<T> fun(tbl: table): T
---@class _ClassCreator<T>
local cc = {}

---Single inheritance keyword
---@generic T
---@param basename? string
---@return _ClassCreator<T>|_ClassDefiner<T>
function cc:extends(basename) end

---Implements the interfaces
---@generic T
---@param ... interface
---@return _ClassCreator<T>|_ClassDefiner<T>
function cc:implements(...) end

---Define the class body
---@generic T
---@param tbl table
---@return T
function cc:def(tbl) end


-----------------------------------------------------------------------------------------------------


---@class interface
local i

---Check if the class implements the interface
---@param clazz class
---@return boolean ok
---@return string? method_name if not ok
function i:check_impl(clazz) end

---Extend the interface with other interfaces
---@param ... interface
---@return interface
function i:extends(...) end


-----------------------------------------------------------------------------------------------------


---Get the type of a value, considering classes as special types  
---eg: 
---```lua
---simpleclass.type(Eagle()) => Eagle
---simpleclass.type("Hello") => "string"
---```
---@param obj object
---@return class
function sc.type(obj) end

---@param v any
---@return type
function sc.type(v) end

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
function sc.class(name) end

---@param body table
---@return class
function sc.class(body) end

---Define a new interface
---@param name string
---@return interface
function sc.interface(name) end

---@param body? table
---@return interface
function sc.interface(body) end

---To call superclass methods  
---eg: `super(cls, self):__init()`
---@generic cls:class, obj:object
---@param cls cls
---@param obj? obj
---@return super<cls, obj>
function sc.super(cls, obj) end

sc.isinstance = o.__proto.isInstance
sc.issubclass = c.isExtends
sc.object = o

---The environment of the classes and interfaces
---@type {object: object.class, [string]: class|interface}
sc._ENV = {object = o}


-----------------------------------------------------------------------------------------------------


---@alias simpleclass.I_FEATURE
---| "general"  Full interface feature.
---| "nocheck"  Skip interface checking. 
---| "lexical"  Only interface syntax. (for LS analysis)

---@alias simpleclass.FIELD
---| "class"
---| "super"
---| "interface"
---| "type"
---| "object"
---| "isinstance"
---| "issubclass"

---Whether to register classes as global variables automatically.  
---Default true when import globally, false otherwise. Could be overridden in runtime.
---@type boolean
sc.AUTO_GLOBAL = false

---Interface feature to use, meaningless if interface module not included.  
---**Warning**: switch in "general" & "nocheck" is safe, BUT "lexical" skipping definition is irreversible.
---@type simpleclass.I_FEATURE
sc.I_FEATURE = "general"

---Import fields from simpleclass module to environment.  
---eg:
---```
---simpleclass.env_import({
---    "class",
---    "super",
---    ["type"] = "cls_type"
---}, _ENV)
---```
---which means:
---```python
---from simpleclass import
---    class,
---    super,
---    type as cls_type
---```
---@param fields {[simpleclass.FIELD]?: string, [integer]?: simpleclass.FIELD}
---@param env? table Default to `_G` if missing.
function sc.env_import(fields, env) end

class = sc.class
super = sc.super
interface = sc.interface
isinstance = sc.isinstance
issubclass = sc.issubclass

object = sc.object


-----------------------------------------------------------------------------------------------------


return sc
