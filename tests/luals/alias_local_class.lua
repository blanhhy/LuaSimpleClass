-- Alias target references must work while the class object is not a global.
local sc = require "simpleclass"
local alias = sc.alias

local AliasLocalClass_73a1 = class "AliasLocalClass_73a1" {
    next = function(self)
        return self
    end;
    alias.__call.next();
}

local instance = AliasLocalClass_73a1:new()
local result = instance()
print(result)
