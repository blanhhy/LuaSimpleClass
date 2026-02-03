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