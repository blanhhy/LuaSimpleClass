-- @operator 自动生成：元方法带 @return 才生成操作符标注。
-- __add 返回 Vec → `v + v` 结果为 Vec，故 (v+v).noSuchField 触发 undefined-field（line 15）。
-- 反之 __mul 无 @return → 不生成 operator，(n*n) 保持 unknown，(n*n).alsoNoSuch 不应报警。
-- expect: 15:undefined-field
require "simpleclass"

class "Vec_nwnwsiiu2" {
    ---@return Vec_nwnwsiiu2
    __add = function(self, other)
        return self
    end;
}

local v = Vec_nwnwsiiu2()
print((v + v).noSuchField)

class "Num_nwnwsiiu2" {
    __mul = function(self, n)
        return self
    end;
}

local n = Num_nwnwsiiu2()
print((n * n).alsoNoSuch)

-- 双操作数不对称（如 __mul(left,right)，左右可互换）只能靠用户手写 @operator 。
-- 用户写在元方法上方，插件原样透传到类块，故 (p*3).noSuchPair 触发 undefined-field。
class "Pair_nwnwsiiu2" {
    ---@operator mul(integer): Pair_nwnwsiiu2
    __mul = function(self, n)
        return self
    end;
}

local p = Pair_nwnwsiiu2()
-- expect: 37:undefined-field
print((p * 3).noSuchPair)
