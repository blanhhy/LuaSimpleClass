class "SuperInferBase_7c8a" {
    ---@param name string
    setName = function(self, name)
        self.name = name
    end;
}

class "SuperInferChild_7c8a" : extends "SuperInferBase_7c8a" {
    ---@override
    setName = function(self, name) -- 应该能通过 super 从基类得到 name 的类型
        super(SuperInferChild_7c8a, self):setName(name)
        self.tag = name
    end;
}

local c = SuperInferChild_7c8a()
-- expect: 18:param-type-mismatch
c:setName(123)
