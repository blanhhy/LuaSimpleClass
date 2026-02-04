local class = require "simpleclass.class"

local type, setmetatable, error
    = type, setmetatable, error

---@class abstract.method
---@field __mname string

local abstract = {} ---@type table<string, abstract.method>
local abs_m_MT = {__mode = 'v'}

function abs_m_MT:__index(name)
    return abstract[name] or setmetatable({__mname = name}, abs_m_MT)
end

function abs_m_MT:__call()
    return error(("Method '%s' is abstract."):format(self.__mname))
end

setmetatable(abstract, abs_m_MT)

---@class interface
---@field __iname string
---@field [integer] abstract.method

---@overload fun(): interface
---@overload fun(name: string): interface
---@overload fun(body: abstract.method[]): interface
---@overload fun(name: string, body: abstract.method[]): interface
local function interface(name_or_body, body)
    if type(name_or_body) == "string" then
        body = body or {} ---@class interface
        body.__iname = name_or_body
        class.env[name_or_body] = body
        return body
    else
        body = name_or_body or {} ---@class interface
        body.__iname = "<anonymous>"
        return body
    end
end