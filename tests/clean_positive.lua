-- 正向测试：此文件应完全干净（零诊断），验证健壮性改动不引入误报。
-- 未在顶部写 `-- expect:` 即表示期望 0 条诊断。

require "simpleclass"

class "CleanT_ebdenjewni" {
    __init = function(self, n)
        self.n = n
        self.seen = {}
    end;

    a = function(self)
        for i = 1, self.n do
            self.seen[i] = i
        end
        return self.seen
    end;

    -- 跨行 table 字段（含转义引号与 }）
    tbl = {
        k = "v asd } quote \" fine",
        nested = { 1, 2 },
    };

    msg = 'plain } string';
}

local c = CleanT_ebdenjewni(3)
print(c:a())