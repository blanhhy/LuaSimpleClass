local sc = require "simpleclass"

class "RuntimeConstructorAlias_5a21" {
    constructor = function(self, value)
        self.value = value
    end;
}

local constructorInstance = RuntimeConstructorAlias_5a21:new("constructor")
assert(constructorInstance.value == "constructor")
assert(RuntimeConstructorAlias_5a21.constructor == nil)
assert(RuntimeConstructorAlias_5a21.__init ~= nil)

class "RuntimeInitAlias_5a21" {
    __init = function(self, value)
        self.value = value
    end;
}

local initInstance = RuntimeInitAlias_5a21:new("init")
assert(initInstance.value == "init")
assert(RuntimeInitAlias_5a21.constructor == nil)

class "RuntimeConstructorDiscarded_5a21" {
    __init = function(self)
        self.value = "init"
    end;
    constructor = function(self)
        self.value = "constructor"
    end;
}

local discarded = RuntimeConstructorDiscarded_5a21:new()
assert(discarded.value == "init")
assert(RuntimeConstructorDiscarded_5a21.constructor == nil)

return true
