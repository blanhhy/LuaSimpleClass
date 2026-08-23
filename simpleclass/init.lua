---@diagnostic disable: lowercase-global
---@diagnostic disable-next-line: unused-local
local mname, murl -- Standard lua `require` arguments
    , margs = ... -- Reserved for user custom extension

---@class simpleclass.INIT_OPTIONS
local options = type(margs) == "table" and margs or {}

--==================================== INIT OPTIONS ====================================--

options.GLOBAL_IMPORT      = true;
options.INTERFACE_INCLUDED = true;
options.DEFAULT_I_FEATURE  = "general";

--==================================== INIT OPTIONS ====================================--

local M   = require "simpleclass.m" ---@class simpleclass
            require "simpleclass.object"
            require "simpleclass.class"
            require "simpleclass.super"

---Whether to register classes as global variables automatically.  
---Default true when import globally, false otherwise. Could be overridden in runtime.
---@type boolean
M.AUTO_GLOBAL = false

---@alias simpleclass.I_FEATURE
---| "general"  Full interface feature.
---| "nocheck"  Skip interface checking. 
---| "lexical"  Only interface syntax. (for LS analysis)

---Interface feature to use, meaningless if interface module not included.  
---**Warning**: switch in "general" & "nocheck" is safe, BUT "lexical" skipping definition is irreversible.
---@type simpleclass.I_FEATURE
M.I_FEATURE = options.DEFAULT_I_FEATURE

---Include interface module
if options.INTERFACE_INCLUDED then
    require "simpleclass.interface"
end

---Global import
if options.GLOBAL_IMPORT then
    M.AUTO_GLOBAL = true

    class = M.class
    super = M.super
    interface = M.interface
    cls_type = M.type

    object = M.object ---@type object
    isinstance = object.isInstance
    issubclass = object.isExtends
end

return M