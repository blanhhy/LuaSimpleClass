-- `constructor` and `__init` share the constructor signature, including inheritance.
-- expect: 14:param-type-mismatch

class "ConstructorAliasBase_5a21" {
    ---@param name string
    constructor = function(self, name)
        self.name = name
    end;
}

class "ConstructorAliasChild_5a21" : extends "ConstructorAliasBase_5a21" {}

local valid = ConstructorAliasChild_5a21:new("ok")
local invalid = ConstructorAliasChild_5a21:new(123)
print(valid.name, invalid)
