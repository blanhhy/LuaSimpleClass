local sc = require "simpleclass"

class "ProtectedInit_6c91" {
    ---@field protected name string
    ---@field protected health number

    __init = function(self, name, health)
        self.name = name
        self.health = health
    end;
}

-- expect: 14:param-type-mismatch
local bad = ProtectedInit_6c91:new(123, true)
print(bad)
