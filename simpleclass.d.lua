---@meta

---@class simpleclass.proto : table
local proto = {}

---Check if the class extends the base class
---@param base class
---@return boolean
function proto:isExtends(base) end

---Check if the class implements the interface
---@param interface interface
---@return boolean
function proto:isImplements(interface) end

---Check if the object is an instance of the class or interface
---@param cls class|interface
---@return boolean
function proto:isInstance(cls) end

---Convert the class to a string
---@return string
function proto:toString() end

---Create a new object of the class
---@return object
function proto:new() end


---@class class : simpleclass.proto, metatable  # A reflection of a class
---@field __classname string                    # The name of the class
---@field __base class                          # The base class of the class
---@field [string] any                          # The fields of the class
object = {}

---@class object : simpleclass.proto            # The root class
---@field __class class                         # The class of the object
---@field __init function?                      # The constructor
local obj = {}