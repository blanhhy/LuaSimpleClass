-- Interface requirements must include fields resolved through interface inheritance.
-- expect: 8:missing-implements
require "simpleclass"

interface "IndirectBase_73a1" {"eat", "fly"}
interface "IndirectChild_73a1" : extends(IndirectBase_73a1) {"spawn"}

class "IndirectImpl_73a1" : implements(IndirectChild_73a1) {
    spawn = function(self) return self end;
}

class "OrderBase_73a1" {
    ping = function(self) return self end;
}
class "OrderImpl_73a1" : implements(IndirectChild_73a1) : extends "OrderBase_73a1" {
    eat = function(self) return self end;
    fly = function(self) return self end;
    spawn = function(self) return self end;
}

---@param value OrderBase_73a1
local function acceptOrderBase(value) end
acceptOrderBase(OrderImpl_73a1())
