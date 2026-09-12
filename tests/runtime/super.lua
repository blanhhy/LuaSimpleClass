require "simpleclass"

local function expect(actual, expected, message)
    assert(actual == expected, ('%s: expected %s, got %s')
        :format(message, tostring(expected), tostring(actual)))
end

local trace = {}

class "RuntimeSuperBase_7f21" {
    __init = function(self, value)
        self.value = value
    end;
    visit = function(self)
        trace[#trace + 1] = 'base'
        return 'base', self
    end;
}

class "RuntimeSuperMiddle_7f21" : extends "RuntimeSuperBase_7f21" {
    __init = function(self, value)
        super():__init(value .. ':middle')
    end;
    visit = function(self)
        local result, same = super():visit()
        trace[#trace + 1] = 'middle'
        expect(same, self, 'middle super self')
        return result .. '>middle', same
    end;
}

class "RuntimeSuperChild_7f21" : extends "RuntimeSuperMiddle_7f21" {
    __init = function(self, value)
        super():__init(value .. ':child')
    end;
    visit = function(self)
        local result, same = super():visit()
        trace[#trace + 1] = 'child'
        expect(same, self, 'child super self')
        return result .. '>child', same
    end;
}

local child = RuntimeSuperChild_7f21:new('root')
expect(child.value, 'root:child:middle', 'chained __init')

local result, same = child:visit()
expect(result, 'base>middle>child', 'chained super result')
expect(same, child, 'chained super return self')
expect(table.concat(trace, '>'), 'base>middle>child', 'chained super order')

class "RuntimeSuperExplicit_7f21" : extends "RuntimeSuperBase_7f21" {
    visit = function(self)
        local result, same = super(RuntimeSuperExplicit_7f21, self):visit()
        return result .. '>explicit', same
    end;
}

local explicit = RuntimeSuperExplicit_7f21('explicit')
local explicitResult, explicitSelf = explicit:visit()
expect(explicitResult, 'base>explicit', 'explicit super result')
expect(explicitSelf, explicit, 'explicit super self')

local inheritedTrace = {}

class "RuntimeSuperDefinitionBase_7f21" {
    foo = function(self)
        inheritedTrace[#inheritedTrace + 1] = 'base'
        return 'base'
    end;
}

class "RuntimeSuperDefinitionMiddle_7f21" : extends "RuntimeSuperDefinitionBase_7f21" {
    foo = function(self)
        inheritedTrace[#inheritedTrace + 1] = 'middle'
        return super():foo() .. '>middle'
    end;
}

class "RuntimeSuperDefinitionChild_7f21" : extends "RuntimeSuperDefinitionMiddle_7f21" {}

local inherited = RuntimeSuperDefinitionChild_7f21:new()
expect(inherited:foo(), 'base>middle',
    'zero-argument super must start from the method definition class')
expect(table.concat(inheritedTrace, '>'), 'middle>base',
    'inherited override must not execute twice')

return true
