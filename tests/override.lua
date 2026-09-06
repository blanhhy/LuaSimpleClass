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
