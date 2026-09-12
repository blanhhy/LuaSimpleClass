-- `constructor` is only a definition-time source for `new`; the generated
-- class keeps the signature but does not expose a `constructor` field.
-- expect: 16:param-type-mismatch
-- expect: 17:undefined-field

class "ConstructorAliasBase_5a21" {
    ---@param name string
    constructor = function(self, name)
        self.name = name
    end;
}

class "ConstructorAliasChild_5a21" : extends "ConstructorAliasBase_5a21" {}

local valid = ConstructorAliasChild_5a21:new("ok")
local invalid = ConstructorAliasChild_5a21:new(123)
local discarded = ConstructorAliasChild_5a21.constructor
print(valid.name, invalid, discarded)
