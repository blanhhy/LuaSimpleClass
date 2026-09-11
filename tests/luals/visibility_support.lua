local sc = require "simpleclass"

class "AccessControl_6c91" {
    ---@field private   private_value   number
    ---@field protected protected_value string
    __init = function(self, val1, val2)
        self.private_value   = val1
        self.protected_value = val2
    end;
    getPrivateValue = function(self)
        return self.private_value
    end;
    getProtectedValue = function(self)
        return self.protected_value
    end;
    ---@private
    getSecretInfo = function(self)
        return "secret_info"
    end;
    ---@protected
    getProtectedInfo = function(self)
        return "protected_info"
    end;
}

local obj = AccessControl_6c91:new(1, "protected")
print(obj:getPrivateValue())
print(obj.private_value)
-- expect: 28:invisible

-- 参数类型推断支持带访问限定符的字段声明
local bad1 = AccessControl_6c91:new("1", "protected")
local bad2 = AccessControl_6c91:new(1, 2)
-- expect: 32:param-type-mismatch
-- expect: 33:param-type-mismatch

-- LuaLS 访问控制语义绑定正常
class "AccessControlChild_6c91" : extends "AccessControl_6c91" {
    ---@override
    getPrivateValue = function(self)
        return self.private_value       -- 不合法，子类不能访问父类的私有字段
    end;
    ---@override
    getProtectedValue = function(self)
        return self.protected_value     -- 合法，子类可以访问父类的保护字段
    end;
    seeInfo = function(self)
        print(self:getProtectedInfo())  -- 合法，子类可以访问父类的保护方法
        print(self:getSecretInfo())     -- 不合法，子类不能访问父类的私有方法
    end;
}

local child = AccessControlChild_6c91:new(1, "protected")
child:seeInfo()
-- expect: 41:invisible
-- expect: 49:invisible
