local sc = require "simpleclass"
local ctype = sc.type

--#==========================================
--# 基础使用
--#==========================================

class "Person" {
    ---@param name string
    ---@param age integer
    __init = function(self, name, age)
        self.name = name
        self.age = age
    end;
    sayHello = function(self)
        print("Hello, my name is ".. self.name.. " and I am ".. self.age.. " years old.")
    end;
}

class "Student" : extends "Person" {
    ---@param grade string
    __init = function(self, name, age, grade)
        super(Student, self):__init(name, age)
        self.grade = grade
    end;
    ---@override
    sayHello = function(self)
        print("Hello, my name is ".. self.name.. " and I am a ".. self.grade.. " year old student.")
    end;
}

local p1 = Person:new("John", 25)
p1:sayHello()

-- Output: Hello, my name is John and I am 25 years old.

-- 使用 :new 可以获得 LuaLS 的参数提示和类型检查
local s1 = Student:new("Jane", 20, "senior")
s1:sayHello()

-- Output: Hello, my name is Jane and I am a senior year old student.

print(s1:isInstance(Student))  --> true
print(s1:isInstance(Person))   --> true
print(s1:isInstance(object))   --> true
print(isinstance(s1, "table")) --> true

print(ctype(s1)) --> Student

--#==========================================
--# 接口使用
--#==========================================

interface "CanEat" {"eat"}
interface "CanFly" {"fly"}

-- 错误的定义
xpcall(function()
    ---@diagnostic disable-next-line: unknown-diag-code
    ---@diagnostic disable-next-line: missing-implements
    class "Bird_wrong" : implements(CanEat, CanFly) {
        eat = function()
            print("I can eat but not fly.")
        end;
    }
    -- Output: class 'Bird_wrong' implements interface 'CanFly' but does not implement method 'fly'.
end, print)

-- 正确的定义
class "Bird" : implements(CanEat, CanFly) {
    eat = function(self)
        print(self:getClass():toString().." eats bugs")
    end;
    fly = function(self)
        print(self:getClass():toString().." is flying")
    end;
}

local bird = Bird()
bird:eat() --> Bird eats bugs
bird:fly() --> Bird is flying

-- 接口组合
interface "BirdLike" : extends(CanEat, CanFly) {
    "spawn";
    "nest";
}

-- 同时进行继承与实现接口
class "Eagle" : extends "Bird" : implements(BirdLike) {
    spawn = function(self)
        print(self:getClass():toString().." is spawning")
    end;
    nest = function(self)
        print(self:getClass():toString().." is nesting")
    end;
}

local eagle = Eagle()
eagle:eat()   --> Eagle eats bugs
eagle:fly()   --> Eagle is flying
eagle:spawn() --> Eagle is spawning
eagle:nest()  --> Eagle is nesting

print(isimplements(Eagle, BirdLike, CanEat, CanFly)) --> true
print(isinstance(eagle, BirdLike))                   --> true

--#==========================================
--# 多态应用
--#==========================================

-- 接口的多态
---@param flyable CanFly
local function makeFly(flyable)
    assert(isinstance(flyable, CanFly), "flyable must be a CanFly object")
    flyable:fly()
end

-- 继承的多态
---@param bird Bird
local function makeBirdFly(bird)
    assert(isinstance(bird, Bird), "bird must be a Bird object")
    makeFly(bird)
end

-- 合法调用
makeFly(bird)
makeBirdFly(eagle)

-- 错误调用
xpcall(function()
    ---@diagnostic disable-next-line: param-type-mismatch
    makeFly(Person())
    -- Output: flyable must be a CanFly object
end, print)
