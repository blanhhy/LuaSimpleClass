-- Interface requirements must include fields resolved through interface inheritance.
-- expect: 8:missing-implements
require "simpleclass"

interface "IndirectBase_73a1" {"eat", "fly"}
interface "IndirectChild_73a1" : extends(IndirectBase_73a1) {"spawn"}

class "IndirectImpl_73a1" : implements(IndirectChild_73a1) {
    spawn = function(self) return self end;
}
