-- Zero-argument super calls should infer forwarded constructor parameters.
-- expect: 33:param-type-mismatch
-- expect: 34:param-type-mismatch
-- expect: 35:param-type-mismatch
-- expect: 36:param-type-mismatch

class "SuperInferZeroBase_7c8a" {
    ---@param name string
    ---@param age integer
    __init = function(self, name, age)
        self.name = name
        self.age = age
    end;
}

class "SuperInferZeroStudent_7c8a" : extends "SuperInferZeroBase_7c8a" {
    ---@param grade string
    __init = function(self, name, age, grade)
        super():__init(name, age)
        self.grade = grade
    end;
}

class "SuperInferZeroCollege_7c8a" : extends "SuperInferZeroStudent_7c8a" {
    ---@param college string
    __init = function(self, name, age, grade, college)
        super()(name, age, grade)
        self.college = college
    end;
}

local valid = SuperInferZeroCollege_7c8a:new("name", 18, "grade", "college")
local badName = SuperInferZeroCollege_7c8a:new(1, 18, "grade", "college")
local badAge = SuperInferZeroCollege_7c8a:new("name", "18", "grade", "college")
local badGrade = SuperInferZeroCollege_7c8a:new("name", 18, 1, "college")
local badCollege = SuperInferZeroCollege_7c8a:new("name", 18, "grade", 1)
print(valid, badName, badAge, badGrade, badCollege)
