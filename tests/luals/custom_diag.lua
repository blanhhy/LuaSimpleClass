-- 自定义诊断功能测试
-- 1. 诊断器工作正常：可以产生自定义诊断
-- 2. 诊断定位正常：可以定位到原始问题位置
-- 3. 注册信息正常：可以被 LS 识别并控制启用状态

interface "CustomDiagIface" {
    "required_method";
}

class "CustomDiagBase" : implements(CustomDiagIface) {}

class "CustomDiagDerived" : extends "CustomDiagBase" {
    ---@override
    not_in_base = function() end;
}

---@diagnostic disable-next-line: missing-implements
class "CustomDiagDisableBase" : implements(CustomDiagIface) {}

class "CustomDiagDisableDerived" : extends "CustomDiagDisableBase" {
    ---@diagnostic disable: invalid-override
    ---@override
    not_in_base = function() end;
    ---@diagnostic enable: invalid-override
}

-- expect: 10:missing-implements
-- expect: 14:invalid-override
