local sc = require "simpleclass"
local alias = sc.alias

class "RuntimeAlias_5a21" {
    fly = function(self)
        return self
    end;
    join = function(self, prefix, suffix)
        return prefix .. suffix
    end;
    combine = function(self, first, second, third)
        return first .. second .. third
    end;
    count = function(self, ...)
        return select('#', ...)
    end;
    countNil = function(self, ...)
        return select('#', ...), select(1, ...)
    end;
    countMany = function(self, ...)
        return select('#', ...)
    end;
    config = function(self, options)
        return options
    end;
    alias.move:fly(),
    alias.joinHello:join("hello "),
    alias.combineAB:combine("a", "b"),
    alias.countABC:count("a", "b"),
    alias.countWithNil:countNil(nil),
    alias.countManyFixed:countMany(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33),
    alias.configured:config({locked = "fixed"}),
}

local instance = RuntimeAlias_5a21:new()
assert(RuntimeAlias_5a21.move == RuntimeAlias_5a21.fly)
assert(instance:move() == instance)
assert(instance:joinHello("world") == "hello world")
assert(instance:combineAB("c") == "abc")
assert(instance:countABC("c") == 3)
local nilCount, nilValue = instance:countNil("c")
assert(nilCount == 1 and nilValue == "c")
local aliasNilCount, aliasNilValue = instance:countWithNil("c")
assert(aliasNilCount == 2 and aliasNilValue == nil)
assert(instance:countManyFixed("tail") == 34)
local passed = {locked = "passed", extra = true}
local configured = instance:configured(passed)
assert(configured == passed)
assert(passed.locked == "fixed" and passed.extra)

class "RuntimeAliasStatic_5a21" {
    add = function(left, right)
        return left + right
    end;
    count = function(...)
        return select('#', ...)
    end;
    alias.add5.add(5),
    alias.countAB.count("a", "b"),
}

assert(RuntimeAliasStatic_5a21.add5(7) == 12)
assert(RuntimeAliasStatic_5a21.countAB("c") == 3)

return true
