-- Getter expressions must not inherit the type of a field used inside them.

class "GetterExpression_7c8a" {
    ---@field health number
    __init = function(self, health)
        self.health = health
    end;

    property.alive;
    ['get.alive'] = function(self)
        return self.health > 0
    end;
}

local tank = GetterExpression_7c8a:new(100)
---@type boolean
local alive = tank.alive
