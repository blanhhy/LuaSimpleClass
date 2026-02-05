require "simpleclass"

class "Person" {
    __init = function(self, name, age)
        self.name = name
        self.age = age
    end;
    sayHello = function(self)
        print("Hello, my name is ".. self.name.. " and I am ".. self.age.. " years old.")
    end;
}

class "Student" : extends "Person" {
    __init = function(self, name, age, grade)
        super(self):__init(name, age)
        self.grade = grade
    end;
    sayHello = function(self)
        print("Hello, my name is ".. self.name.. " and I am a ".. self.grade.. " year old student.")
    end;
}

local p1 = Person:new("John", 25)
p1:sayHello()

-- Output: Hello, my name is John and I am 25 years old.

local s1 = Student:new("Jane", 20, "senior")
s1:sayHello()

-- Output: Hello, my name is Jane and I am a senior year old student.

print(s1:isInstance(Student)) --> true
print(s1:isInstance(Person))  --> true
print(s1:isInstance(Object))  --> true

print(class.type(s1)) --> Student


interface "CanEat" {"eat"}
interface "CanFly" {"fly"}

-- 错误的定义
xpcall(function()
class "Bird" : implements(CanEat, CanFly) {
    eat = function()
        print("Bird eats bugs")
    end;
}
end, print)

-- Output: class Bird implements <interface 'CanFly'> but dose not implement method fly().

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

-- 接口继承
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

print(eagle:isInstance(BirdLike))  --> true