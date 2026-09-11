-- Class objects inherit Base.class, while interfaces stay on the instance side.
-- expect: 30:undefined-field

require "simpleclass"

interface "InstanceOnly_73a1" {"describe"}

class "ClassSideBase_73a1" {
    ---@static
    kind = "base";

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

-- The static field and constructor are inherited through ClassSideBase.class.
print(ClassSideChild_73a1.kind)
local child = ClassSideChild_73a1:new("ok")
print(child:describe())

-- The interface member remains an instance member.
print(ClassSideChild_73a1.describe)
