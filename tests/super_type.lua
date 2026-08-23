-- super() 锚定基类：方法内注入局部 `function super(_, _) return <父类> end` 遮蔽全局 super，
-- 使 `super(Child, self):name()` 的接收者为父类。父类无该方法则于原调用处(line 24)报 undefined-field。
-- 有效调用 super(...):__init 不应报警。
-- expect: 24:undefined-field
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
    wrongSig = function(self)
        super(Student_q2gihi2j43, self):__init("only-name")
    end;
}
-- expect: 27:missing-parameter
