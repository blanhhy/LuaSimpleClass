-- 接口约束检查：class implements 接口但缺方法 → 诊断定位到原始 implements(...) 块
-- expect: 8:missing-implements
require "simpleclass"

interface "CanEat_uebxyu21" {"eat"}
interface "CanFly_uebxyu21" {"fly"}

class "Bird_wrong_uebxyu21" : implements(CanEat_uebxyu21, CanFly_uebxyu21) {
    eat = function(self) return self end;
}

class "Bird_uebxyu21" : implements(CanEat_uebxyu21, CanFly_uebxyu21) {
    eat = function(self) return self end;
    fly = function(self) return self end;
}
