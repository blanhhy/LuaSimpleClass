---@diagnostic disable: undefined-global
---@simpleclass local-import
-- expect: 18:simpleclass-missing-import

local function import(name, options)
    return require(name)
end

local sc = import("simpleclass", { GLOBAL_IMPORT = false })
local class = sc.class

local Good = class "LocalImportGood_9d31" {}
local value = Good()
print(sc.isinstance(value, Good))

-- This must be reported by the file-local diagnostic even if simpleclass.d.lua
-- declares `isinstance` as a workspace global.
print(isinstance(value, Good))
