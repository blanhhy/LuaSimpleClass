-- 短继承语法解析测试
class "ShortExtendsBase_73a1" {
    ---@field inherited string
}

class "ShortExtendsChild_73a1" : ShortExtendsBase_73a1 {}

local child = ShortExtendsChild_73a1()
print(child.inherited) -- 预期零诊断
