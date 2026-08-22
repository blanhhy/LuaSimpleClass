-- 解析器健壮性 + 方法边界负向测试。
-- 每个方法都种一个未定义字段探针（self.probe_XXX），应恰好在【原始行】被报一次，
-- 且不得出现副本重复报警（由 OnTransformAst 自注入 + 副本区 disable 保证）。
--
-- expect: 42:undefined-field   (guardDo 的 do return 守卫)
-- expect: 53:undefined-field   (deep 的 for>if>while>do 深嵌套)
-- expect: 65:undefined-field   (lon 的 [==[ ]==] 长字符串内含 ]] 与 function/end)
-- expect: 72:undefined-field   (esc 的 \' / \" 转义字符串)
-- expect: 78:undefined-field   (bcom 的 --[[ ]] 块注释内含 end/function)
-- expect: 88:undefined-field   (rep 的 repeat/until 与 do break)

require "simpleclass"

class "Edge_qwiojediuew" {
    __init = function(self, name)
        self.name = name
        self.ok = 0
        self.cleanData = {}
    end;

    -- 跨行 table 字段：花括号与字符串含 } 不能干扰类体扫描
    tfield = {
        x = 1,
        y = { z = "brace } here" },
        list = { 1, 2, 3 },
    };

    -- 字段字符串含转义引号与 }
    msg = "closing } and \" and \' fine";

    -- 干净方法：仅访问已声明字段，应零警告
    clean = function(self)
        local a = self.ok + 1
        self.cleanData[1] = a
        return "no warning"
    end;

    -- 探针1 do return 守卫
    guardDo = function(self)
        for i = 1, 10 do
            if i == 5 then
                do return self.probe_do end
            end
        end
        return self.ok
    end;

    -- 探针2 深嵌套 for>if>while>do
    deep = function(self)
        for a = 1, 3 do
            if a > 0 then
                while a < 9 do
                    do return self.probe_deep end
                end
            end
        end
        return self.ok
    end;

    -- 探针3 高级长字符串
    lon = function(self)
        local s = [==[ cannot end ]] here
            function fake() { return 1 } end
        ]==]
        return self.probe_lon
    end;

    -- 探针4 转义引号 + 花括号
    esc = function(self)
        local a = 'it\'s } and \' fine'
        local b = "has \" brace } and \\"
        return self.probe_esc
    end;

    -- 探针5 块注释
    bcom = function(self)
        --[[ block }} with end }{{ and function ]]
        return self.probe_bcom
    end;

    -- 探针6 repeat/until 与 do break
    rep = function(self)
        local i = 0
        repeat
            i = i + 1
            if i > 3 then do break end end
        until i >= 5
        return self.probe_rep
    end;

    -- 干净方法2：方法内一行式匿名函数
    nested = function(self)
        local fn = function() return self.ok end
        return fn()
    end;
}

local o = Edge_qwiojediuew("x")
print(o:guardDo())