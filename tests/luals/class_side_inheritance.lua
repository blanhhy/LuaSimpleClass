-- Class objects inherit class and meta only; interfaces stay on the instance side.
-- expect: 32:undefined-field
-- expect: 39:undefined-field

require "simpleclass"

interface "InstanceOnly_73a1" {"describe"}

class "ClassSideBase_73a1" {
    ---@static
    kind = "base";

    ---@param other ClassSideBase_73a1
    ---@return ClassSideBase_73a1
    __add = function(self, other)
        return self
    end;

    ---@param value string
    __init = function(self, value)
        self.value = value
    end;
}

class "ClassSideChild_73a1" : extends "ClassSideBase_73a1" : implements(InstanceOnly_73a1) {
    describe = function(self)
        return self.value
    end;
}

-- Static fields do not come through the class-object chain.
print(ClassSideChild_73a1.kind)
local child = ClassSideChild_73a1:new("ok")
print(child:describe())
-- Meta methods do come through ClassSideChild.meta.
print(ClassSideChild_73a1.__add)

-- The interface member remains an instance member.
print(ClassSideChild_73a1.describe)
