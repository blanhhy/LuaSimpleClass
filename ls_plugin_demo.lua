require "simpleclass"

class "Test_Person" {
    ---@param name string
    ---@param age integer
    __init = function(self, name, age)
        self.name = name
        self.age = age
    end;

    sayHello = function(self)
        print("hello, my name is ".. self.name.. " and I am ".. self.age.. " year old.")
    end;

    isAdult = function(self)
        return self.age >= 18
    end;
}

local p1 = Test_Person:new("John", 25)

-- 试试像这样创建一个实例（用new方法），键入时观察参数提示
-- local p2 = Test_Person:new("Alice", 10)
-- 你会看到Test_Person:new(name:string, age:integer)
----------
local p2
----------



class "Test_Student" : extends "Test_Person" {
    ---@param name string
    ---@param age integer
    ---@param grade integer
    __init = function(self, name, age, grade)
        super(self):__init(name, age)
        self.grade = grade
    end;

    ---@override
    sayHello = function(self)
        print("Hello, my name is ".. self.name.. " and I am a ".. self.grade.. " year old student.")
    end;

    -- @override检查父类是否有sayHello方法
    -- 试试把sayHello方法名改一个字母，观察工作区报错
    -- 你会看到一个undefined-field错误
}


local s1 = Test_Student("Alice", 10, 12)

-- 试试像这样调用isAdult方法，键入时观察补全提示
-- print(s1:isAdult())
-- 你会看到isAdult显示在s1的可用方法列表中
----------
print()
----------

---@param student Test_Student
local function make_student_say_hello(student)
    student:sayHello()
end

-- 试试把s1改成p1，观察工作区报错
-- 你会看到类型不匹配错误
----------
make_student_say_hello(s1)
----------

---@param person Test_Person
local function make_person_say_hello(person)
    person:sayHello()
end


make_person_say_hello(s1)
make_person_say_hello(p1)

-- 试试分别向make_person_say_hello函数传递s1和p1，键入时观察类型提示
-- 你会发现一切正常，因为它们都是Test_Person

interface "Test_CanFly" {"fly"}

class "Test_Bird" : implements(Test_CanFly) {
    fly = function(self)
        print(self:getClass():toString().." is flying")
    end;
}

class "Test_Plane" : implements(Test_CanFly) {
    fly = function(self)
        print(self:getClass():toString().." is flying")
    end;
}

local bird = Test_Bird()
local plane = Test_Plane()

---@param flyable Test_CanFly
local function make_fly(flyable)
    flyable:fly()
end

make_fly(bird)
make_fly(plane)

-- 试试分别向 make_fly 函数传递bird和plane，键入时观察类型提示
-- 你会发现一切正常，因为它们都是Test_CanFly