local sc = require "simpleclass"
local alias = sc.alias

class "AliasOwnerProbe_73a1" {
    sub = function(self)
        return self
    end;
    alias.__call:sub(),
}

print(AliasOwnerProbe_73a1.__call)

local instance = AliasOwnerProbe_73a1:new()
-- expect: 15:undefined-field
print(instance.__call)
