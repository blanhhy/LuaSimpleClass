-- Interface meta methods describe instance behavior through operators.
-- expect: 8:missing-implements

require "simpleclass"

interface "Addable_73a1" {"__add"}

class "MissingAdd_73a1" : implements(Addable_73a1) {}

class "GoodAdd_73a1" : implements(Addable_73a1) {
    ---@param other GoodAdd_73a1
    ---@return GoodAdd_73a1
    __add = function(self, other)
        return self
    end;
}

interface "MultiplyAddable_73a1" : extends(Addable_73a1) {"__mul"}

-- The inherited __add requirement comes from MultiplyAddable_73a1.meta.
class "MissingInheritedMeta_73a1" : implements(MultiplyAddable_73a1) {
    ---@param other MissingInheritedMeta_73a1
    ---@return MissingInheritedMeta_73a1
    __mul = function(self, other)
        return self
    end;
}

-- expect: 21:missing-implements
class "GoodInheritedMeta_73a1" : implements(MultiplyAddable_73a1) {
    ---@param other GoodInheritedMeta_73a1
    ---@return GoodInheritedMeta_73a1
    __add = function(self, other)
        return self
    end;
    ---@param other GoodInheritedMeta_73a1
    ---@return GoodInheritedMeta_73a1
    __mul = function(self, other)
        return self
    end;
}

---@type Addable_73a1
local left = GoodAdd_73a1:new()
---@type Addable_73a1
local right = GoodAdd_73a1:new()
---@type Addable_73a1
local result = left + right
