require "simpleclass"

local function expect(condition, message)
    assert(condition, message)
end

class "RuntimeClone_8f31" {
    __init = function(self)
        self.value = 1
        self.nested = {value = 2}
    end;
}

local source = RuntimeClone_8f31:new()

-- Static form supports both shallow and deep cloning.
local shallow = object.clone(source, false)
expect(shallow ~= source, 'static clone must create a new object')
expect(shallow.__class == source.__class, 'static clone must preserve the class')
expect(shallow.nested == source.nested, 'shallow clone must keep nested references')

local deep = object.clone(source)
expect(deep ~= source, 'deep static clone must create a new object')
expect(deep.__class == source.__class, 'deep static clone must preserve the class')
expect(deep.nested ~= source.nested, 'deep clone must copy nested tables')
expect(deep.nested.value == 2, 'deep clone must preserve nested values')

-- Instance form uses the same implementation and default deep mode.
local instanceClone = source:clone() ---@cast instanceClone RuntimeClone_8f31
expect(instanceClone ~= source, 'instance clone must create a new object')
expect(instanceClone.__class == source.__class, 'instance clone must preserve the class')
expect(instanceClone.nested ~= source.nested, 'instance clone must deep-copy nested tables')

-- Cyclic references must terminate and preserve the graph structure.
class "RuntimeCloneCycle_8f31" {
    __init = function(self)
        self.a = {}
        self.b = {}
        self.a.next = self.b
        self.b.next = self.a
        self.me = self
    end;
}

local cyc = RuntimeCloneCycle_8f31:new()
local cycClone = cyc:clone()
expect(cycClone ~= cyc, 'clone must terminate on cyclic references')
expect(cycClone.a ~= cyc.a, 'clone must deep-copy cyclic nodes')
expect(cycClone.a.next == cycClone.b, 'clone must preserve cycle aliasing')
expect(cycClone.b.next == cycClone.a, 'clone must preserve reverse cycle')
expect(cycClone.me == cycClone, 'clone must redirect self-reference to the clone')

return true
