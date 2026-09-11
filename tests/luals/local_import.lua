---@diagnostic disable: undefined-global
---@simpleclass local-import

-- 假设有一个能带参数的通用导入器（非实际实现）
---@return simpleclass
local function import(name, options)
    return require "simpleclass.with" (options)
end

local sc = import("simpleclass", {GLOBAL_IMPORT = false})
local class = sc.class

local Good = class "LocalImportGood_9d31" {}
local value = Good:new()
print(sc.isinstance(value, Good))

-- This must be reported by the file-local diagnostic even if simpleclass.d.lua
-- declares `isinstance` as a workspace global.
-- expect: 20:simpleclass-missing-import
print(isinstance(value, Good))
