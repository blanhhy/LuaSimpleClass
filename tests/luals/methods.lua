class "TestMethods_cfrhc5f4" {
    str1 = "";

    ---@static
    str_static = "class static";

    ---@param str string
    __init = function(self, str)
        self.str2 = str;
    end;

    method_foo = function(self)
        return self.str1 .. self.str2;
    end;

    method_bar = function(this)
        print(this.str1)
        print(this.str2)
    end;

    ---@static
    method_static = function()
        return TestMethods_cfrhc5f4.str_static;
    end;

    ---@static
    method_class_self = function(self)
        print(self.str_static, self.noSuchField)
    end;

    ---@static
    method_class_cls = function(cls)
        return cls.str_static;
    end;

    ---@param other TestMethods_cfrhc5f4
    ---@return string
    __concat = function(self, other)
        return self.str2 .. other.str2;
    end;

    ---@param other TestMethods_cfrhc5f4
    ---@return boolean
    __eq = function(self, other)
        return self.str2 == other.str2;
    end;

    mytoString = tostring;

    ---@static
    myprint = print;
}

---预期：
---TestMethods_cfrhc5f4.class 持有 str_static、new、method_static、method_class_self、method_class_cls、__concat、myprint
---其中 method_class_self 和 __concat 是用冒号语法标注的
---TestMethods_cfrhc5f4 持有 str1、str2、__init、method_foo、method_bar、mytoString
---其中 method_foo 是用冒号语法标注的
---TestMethods_cfrhc5f4 还能使用 .. 来得到 string

-- ===== 成员挂载位置验证 =====

local tm = TestMethods_cfrhc5f4:new("hello")

-- 正向：实例持有实例成员
print(tm.str1)
print(tm.str2)
print(tm:method_foo())
tm:method_bar()
print(tm.mytoString)

-- 正向：类对象持有类成员
print(TestMethods_cfrhc5f4.str_static)
TestMethods_cfrhc5f4.method_static()
TestMethods_cfrhc5f4:method_class_self()
TestMethods_cfrhc5f4:method_class_cls()
print(TestMethods_cfrhc5f4.myprint)
print(TestMethods_cfrhc5f4.__concat)

-- 负向：实例不应持有类成员
print(tm.str_static)
print(tm.method_static)
print(tm.myprint)
print(tm.__concat)

-- 负向：类对象不应持有实例成员
print(TestMethods_cfrhc5f4.str1)
print(TestMethods_cfrhc5f4.method_foo)
print(TestMethods_cfrhc5f4.mytoString)

-- @operator 正确作用在实例上
print((tm .. tm).noSuchField)
print((TestMethods_cfrhc5f4 .. TestMethods_cfrhc5f4).noSuchField)

-- 验证无 @operator 的元方法也归属正确
print(TestMethods_cfrhc5f4.__eq)
print(tm.__eq)

-- 负向诊断预期（成员挂载位置验证）
-- method_class_self 的 self 应绑定为类对象类型
-- expect: 28:undefined-field
-- expect: 81:undefined-field
-- expect: 82:undefined-field
-- expect: 83:undefined-field
-- expect: 84:undefined-field
-- expect: 87:undefined-field
-- expect: 88:undefined-field
-- expect: 89:undefined-field
-- expect: 92:undefined-field
-- expect: 97:undefined-field
