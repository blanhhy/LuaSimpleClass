---@meta

---@class class                     # A reflection of a class
---@operator call:class.instance    # Instantiation
---@field __classname string        # The name of the class
---@field __base class              # The base class of the class
---@field __tostring function       # The tostring method of the class
local class = {} -- A virtual variable to declare methods

---@class class.instance : object   # Reflection of a class instance
---@field [string] any              # unknown fields

---@class object : class            # The root class
---@field __class class             # The class of the object
---@field __init function?          # The constructor
object = {} -- Base class of all classes

---Check if the class extends the base class
---@param base class
---@return boolean
function class:isExtends(base) end

---Check if the class implements the interface
---@param interface interface
---@return boolean  ok
---@return integer? arg_index if not ok
function class:isImplements(interface) end

---Check if the object is an instance of the class or interface  
---(also compatible with lua type)
---@param cls class|interface|type
---@return boolean
function class:isInstance(cls) end

---Convert the class to a string
---@return string
function class:toString() end

---Create a new object of the class
---@return object
function class:new() end

---Get the class of the object
function object:getClass() return self.__class end

object.is = rawequal