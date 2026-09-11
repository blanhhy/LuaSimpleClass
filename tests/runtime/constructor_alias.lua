local sc = require "simpleclass"

class "RuntimeConstructorAlias_5a21" {
    constructor = function(self, value)
        self.value = value
    end;
}

local constructorInstance = RuntimeConstructorAlias_5a21:new("constructor")
assert(constructorInstance.value == "constructor")
assert(RuntimeConstructorAlias_5a21.constructor == RuntimeConstructorAlias_5a21.__init)

class "RuntimeInitAlias_5a21" {
    __init = function(self, value)
        self.value = value
    end;
}

local initInstance = RuntimeInitAlias_5a21:new("init")
assert(initInstance.value == "init")
assert(RuntimeInitAlias_5a21.constructor == RuntimeInitAlias_5a21.__init)

return true
