-- 表表层手写 ---@field 透传为 ---@class 下的类字段声明，声明未在 __init 赋值的字段。
-- title: string       标量     → n.title.missing 触发 undefined-field（line 24）。
-- meta: {key: string} 结构体表 → meta.nope 触发 undefined-field（line 25）。
-- tags: string[]      数组表   → tags[1].nope 触发 undefined-field（line 26）。
-- 未声明的 n.attr      触发 undefined-field（line 27），证明字段注释确实生效、且未凭空放行。
-- 裸 table 可含任意字段，故不使用它来演示报警。
-- expect: 24:undefined-field
-- expect: 25:undefined-field
-- expect: 26:undefined-field
-- expect: 27:undefined-field
require "simpleclass"

class "Note_fldec" {
    ---@field title string
    ---@field meta  {key: string}
    ---@field tags  string[] 

    __init = function(self)
        self.body = "x"
    end;
}

local n = Note_fldec()
print(n.title.missing)
print(n.meta.nope)
print(n.tags[1].nope)
print(n.attr.notThere)