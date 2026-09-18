-- `constructor` is only a definition-time source for `new`; the generated
-- class keeps the signature but does not expose a `constructor` field.
-- expect: 17:param-type-mismatch
-- expect: 18:undefined-field
-- expect: 26:param-type-mismatch

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

---@type ConstructorAliasChild_5a21.constructor
local makeChild = function(name)
    return ConstructorAliasChild_5a21:new(name)
end
local aliasValid = makeChild("ok")
local aliasInvalid = makeChild(123)
print(aliasValid, aliasInvalid)
