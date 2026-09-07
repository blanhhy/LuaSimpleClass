-- 类内可以访问 private 字段，类外访问必须被 LuaLS 拒绝。
local sc = require "simpleclass"

class "PrivateProbe_6c91" {
    ---@field private value number
    __init = function(self, value)
        self.value = value
    end;
    getValue = function(self)
        return self.value
    end;
}

local probe = PrivateProbe_6c91(1)
print(probe:getValue())
print(probe.value)
-- expect: 16:invisible
