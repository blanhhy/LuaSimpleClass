-- 非全局导入：用临时自定义 searcher 把 { GLOBAL_IMPORT = false } 传给 init.lua 的 margs 槽，
-- 使模块不注册全局接口，需手动 local class/super，且 AUTO_GLOBAL 随之关闭。
-- 插件应照常分析手动 local 的 class（OnTransformAst 已识别 getlocal "class"）。
-- 预期：self.field 被推导为 string → probe 里 self.field.missing 触发 undefined-field（line 29）。
-- expect: 28:undefined-field
do
    ---@diagnostic disable-next-line: deprecated
    local searchers = package.searchers or package.loaders
    table.insert(searchers, 1, function(name)
        if name ~= "simpleclass" then return nil end
        local path = assert(package.searchpath(name, package.path))
        local chunk = assert(loadfile(path))
        -- 标准 require 以 (name) 调用返回的 loader；这里用 options 作为 margs 重新调用模块
        return function()
            return chunk(name, path, { GLOBAL_IMPORT = false })
        end
    end)
end

local sc = require "simpleclass" -- 局部导入
local class = sc.class           -- 手动 local class

class "NonGlobal_mn1" {
    __init = function(self)
        self.field = "x"
    end;
    probe = function(self)
        return self.field.missing
    end;
}

-- 强制向下转型（从 _ENV 取只能得到 object）
local MyClass = sc._ENV.NonGlobal_mn1 ---@cast MyClass NonGlobal_mn1
local obj = MyClass()
print(obj:probe())
