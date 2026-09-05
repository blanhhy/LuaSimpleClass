-- 接口约束检查：class implements 接口但缺方法 → 诊断定位到原始 implements(...) 块
-- expect: 8:missing-implements
require "simpleclass"

interface "CanEat" {"eat"}
interface "CanFly" {"fly"}

class "Bird_wrong" : implements(CanEat, CanFly) {
    eat = function(self) return self end;
}

class "Bird" : implements(CanEat, CanFly) {
    eat = function(self) return self end;
    fly = function(self) return self end;
}
