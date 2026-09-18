-- The environment-dependent diagnostic is silent when debug is enabled.
class "SuperDebugBase_7c8a" {
    run = function(self)
        return "base"
    end;
}

class "SuperDebugChild_7c8a" : extends "SuperDebugBase_7c8a" {
    run = function(self)
        return super():run()
    end;
}

local value = SuperDebugChild_7c8a:new():run()
print(value)
