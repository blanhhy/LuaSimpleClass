---@diagnostic disable: lowercase-global
---@diagnostic disable-next-line: unused-local
local mname, murl -- Standard lua `require` arguments
    , margs = ... -- Reserved for user custom extension

---@class M.INIT_OPTIONS
local options = {}

--==================================== INIT OPTIONS ====================================--

options.GLOBAL_IMPORT      = true;
options.INTERFACE_INCLUDED = true;
options.DEFAULT_I_FEATURE  = "general";

--==================================== INIT OPTIONS ====================================--

-- Merge import options
if type(margs) == "table" then
    for k, v in next, margs do
        if v ~= nil then
            options[k] = v
        end
    end
end

local M   = require "simpleclass.m" ---@class M
            require "simpleclass.object"
            require "simpleclass.class"
            require "simpleclass.super"

---Whether to register classes as global variables automatically.  
---Default true when import globally, false otherwise. Could be overridden in runtime.
---@type boolean
M.AUTO_GLOBAL = false

---Interface feature to use, meaningless if interface module not included.  
---**Warning**: switch in "general" & "nocheck" is safe, BUT "lexical" skipping definition is irreversible.
---@type simpleclass.I_FEATURE
M.I_FEATURE = options.DEFAULT_I_FEATURE

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
function M.env_import(fields, env)
    env = env or _G
    for k, v in next, fields do
        if M[v] then -- eg. { "class" }
            env[v] = M[v]
        elseif M[k] then -- eg. { "cls_type" = "type" }
            env[v] = M[k]
        end
    end
end

---Include interface module
if options.INTERFACE_INCLUDED then
    require "simpleclass.interface"
end

---Global import
if options.GLOBAL_IMPORT then
    M.AUTO_GLOBAL = true
    M.env_import {
        "class",
        "super",
        "interface",
        "object",
        "isinstance",
        "issubclass",
    }
end

return M