-- super() 父类锚定（注入基类存在性检查）：super(Student, self) 调用的方法若父类无同名方法，
-- 在注入的检查块中触发 undefined-field（line 22 = 注入块 base_method=_.__nonexistent_base）。
-- 有效调用 super(...):__init 不应报警。
-- expect: 22:undefined-field
require "simpleclass"

class "Person_qwceuirgqf" {
    --- @param name string
    --- @param age number
    __init = function(self, name, age)
        self.name = name
        self.age = age
    end;
}



class "Student_q2gihi2j43" : extends "Person_qwceuirgqf" {
    __init = function(self, name, age, grade)
        super(Student_q2gihi2j43, self):__init(name, age)
        self.grade = grade
    end;
    bad = function(self)
        super(Student_q2gihi2j43, self):__nonexistent_base()
    end;
}
