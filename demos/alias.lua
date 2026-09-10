local alias = require "simpleclass".alias

-- 演示 alias 的使用：
-- 在定义类时使用别名可以轻松委派方法，避免重复代码。

interface "Movable" {"move"}
interface "Flyable" {"fly"}

class "Human" : implements(Movable) {
    walk = function(self)
        print("Human walk")
    end;
    ---@override
    alias.move :walk(); -- 等价于在类定义完毕后直接令 Human.move = Human.walk
}

print(Human().move == Human().walk) --> true

class "Plane" : implements(Movable, Flyable) {
    ---@override
    fly = function(self)
        print("Plane fly")
    end;
    ---@override
    alias.move :fly();
}

---@param obj Movable
local function makeMove(obj)
    obj:move()
end

for _, obj in ipairs{Human(), Plane()} do
    makeMove(obj)
end

-- Outputs:
-- Human walk
-- Plane fly

-- 除此之外，alias 还可以用于创建偏函数（Partial Function）。

class "Calculator" {
    ---@static
    ---@param a number
    ---@param b number
    add = function(a, b)
        return a + b
    end;
    alias.add5 .add(5);
}

print(Calculator.add(3, 4)) --> 7
print(Calculator.add5(3))   --> 8
