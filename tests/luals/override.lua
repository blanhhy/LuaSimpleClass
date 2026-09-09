-- @override 诊断：合法方法可重写，父类不存在的方法应报警
-- expect: 13:invalid-override
require "simpleclass"

class "Base" {
    present = function(self) return self end;
}

class "Child" : extends "Base" {
    ---@override
    present = function(self) return self end;
    ---@override
    missing = function(self) return self end;
}

interface "OverrideContract_7f31" {"move"}

class "InterfaceChild_7f31" : implements(OverrideContract_7f31) {
    ---@override
    move = function(self) return self end;
    ---@override
    missing = function(self) return self end;
}

class "NoOverrideTarget_7f31" {
    ---@override
    lonely = function(self) return self end;
}

class "OverrideGrandBase_7f31" {
    inherited = function(self) return self end;
}

class "OverrideMiddle_7f31" : extends "OverrideGrandBase_7f31" {}

class "OverrideGrandChild_7f31" : extends "OverrideMiddle_7f31" {
    ---@override
    inherited = function(self) return self end;
}

-- expect: 22:invalid-override
-- expect: 27:invalid-override
