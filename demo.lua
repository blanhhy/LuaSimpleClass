local sc = require "simpleclass"

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
        super():__init(name, age)
        self.grade = grade
    end;
    ---@override
    sayHello = function(self)
        print("Hello, my name is ".. self.name.. " and I am a ".. self.grade.. " year old student.")
    end;
}

local p1 = Person("John", 25)
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

print(sc.type(s1)) --> Student

--#==========================================
--# 深层继承
--#==========================================
class "CollageStudent" : Student {
    __init = function(self, name, age, grade)
        -- 在实例方法里，可以省略 super 的参数
        super():__init(name, age, grade)
    end;
}

local c1 = CollageStudent("Alice", 22, "junior")
c1:sayHello()
-- Output: Hello, my name is Alice and I am a junior year old student.

--#==========================================
--# 接口使用
--#==========================================
interface "CanEat" {"eat"}
interface "CanFly" {"fly"}

-- 错误的定义
xpcall(function()
    -- 如果在用配套 LS 插件的话，静态就会报错。这里错误示范，临时禁用诊断
    ---@diagnostic disable-next-line: unknown-diag-code
    ---@diagnostic disable-next-line: missing-implements
    class "Bird_wrong" : implements(CanEat, CanFly) {
        eat = function()
            print("I can eat but not fly.")
        end;
    }
    -- Output: class Bird_wrong implements <interface 'CanFly'> but does not implement method 'fly'.
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

print(Eagle:isImplements(BirdLike)) --> true
print(eagle:isInstance(BirdLike))   --> true

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

--#==========================================
--# Getter / Setter
--#==========================================
class "Account" {
    ---@field private _balance number
    __init = function(self, balance)
        self._balance = balance or 0
    end;
    ['get.balance'] = function(self)
        return self._balance
    end;
    ['set.balance'] = function(self, value)
        self._balance = value
    end;
}

local account = Account(100)
print(account.balance) --> 100

account.balance = 200
print(account.balance) --> 200
