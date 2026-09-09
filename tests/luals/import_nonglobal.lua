-- 非全局导入：模块不注册全局接口，class, super 等为手动 local，插件应照常分析。
-- 预期：self.field 被推导为 string → probe 里 self.field.missing 触发 undefined-field（line 29）。
-- expect: 13:undefined-field

local sc = require "simpleclass.with" {GLOBAL_IMPORT = false}
local class = sc.class

local MyClass = class "NonGlobal_mn1" {
    __init = function(self)
        self.field = "x"
    end;
    probe = function(self)
        return self.field.missing
    end;
}

local obj = MyClass()
print(assert(obj:probe() == nil))
