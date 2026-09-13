-- simpleclass 实例运行期性能基准（对比原生 table 基线）
-- 运行：lua tests/bench.lua 或 luajit tests/bench.lua

local source = debug.getinfo(1, 'S').source:match('^@?(.*)[/\\]') or 'tests/'
local sep = package.config:sub(1, 1)
source = source:gsub('[/\\]+$', '')
local root = source:gsub('[/\\]tests$', '')
if root == source then root = '.' end
package.path = table.concat({
    root .. sep .. '?.lua',
    root .. sep .. '?/init.lua',
    package.path,
}, ';')

require "simpleclass"

local JIT = rawget(_G, 'jit')
print('interpreter:', _VERSION, JIT and ('LuaJIT ' .. JIT.version) or 'PUC Lua')

-- ===== 类定义 =====

class "BenchBase_7b01" {
    rootMethod = function(self) return 1 end;
}

class "BenchL1_7b01" : extends "BenchBase_7b01" {
    l1 = function(self) return 1 end;
}

class "BenchL2_7b01" : extends "BenchL1_7b01" {
    l2 = function(self) return 1 end;
}

class "BenchL3_7b01" : extends "BenchL2_7b01" {
    l3 = function(self) return 1 end;
}

class "BenchLeaf_7b01" : extends "BenchL3_7b01" {
    leafMethod = function(self) return 1 end;
}

class "BenchProp_7b01" {
    __init = function(self)
        self._v = 1
    end;
    property.value;
    ["get.value"] = function(self)
        return self._v
    end;
    ["set.value"] = function(self, v)
        self._v = v
    end;
    propMethod = function(self) return 1 end;
}

-- 有构造器的类（主流场景）
class "BenchCtorSelf_7b01" {
    __init = function(self, x)
        self.x = x
    end;
}

class "BenchCtorChild_7b01" : extends "BenchCtorSelf_7b01" {
    -- 不写构造器：沿链继承基类构造器
}

class "BenchSuperBase_7b01" {
    visit = function(self) return self end;
}

class "BenchSuperSub_7b01" : extends "BenchSuperBase_7b01" {
    via_super_x = function(self)
        return super(BenchSuperSub_7b01, self):visit()
    end;
    via_super0 = function(self)
        return super():visit()
    end;
    via_direct = function(self)
        return BenchSuperBase_7b01.visit(self)
    end;
}

-- ===== 原生基线 =====

local plain = { v = 1, getV = function(self) return self.v end }
local PM = { m = function(self) return 1 end }
local mUP = PM.m
local function plainInit()
    local t = {}
    t.v = 1
    return t
end

-- ===== 健全性检查 =====

local leaf = BenchLeaf_7b01()
assert(leaf:leafMethod() == 1)
assert(leaf:rootMethod() == 1)
assert(BenchCtorSelf_7b01(1).x == 1, 'ctor direct')
assert(BenchCtorChild_7b01(2).x == 2, 'ctor inherited')
local p = BenchProp_7b01()
assert(p.value == 1, 'prop getter')
p.value = 3
assert(p.value == 3, 'prop setter')
assert(rawget(p, 'value') == nil)
assert(BenchLeaf_7b01:isExtends(BenchBase_7b01))
assert(not BenchLeaf_7b01:isExtends(BenchSuperBase_7b01))
local sub = BenchSuperSub_7b01()
assert(sub:via_super_x() == sub, 'explicit super')
assert(sub:via_direct() == sub)
assert(BenchBase_7b01():clone().__classname == 'BenchBase_7b01', 'clone')
print('sanity: ok')

-- ===== 基准框架 =====

local acc = 0          -- 结果汇入以阻止死代码消除
local holder = {}      -- 逃逸槽：阻止 JIT 消除分配

local function measure(f)
    for _ = 1, 6000 do f() end                    -- 预热 / JIT
    local n, dt, ran = 100000, 0, 0
    repeat
        ran = n                                   -- 记录本次实际执行的次数
        local t0 = os.clock()
        for _ = 1, n do f() end
        dt = os.clock() - t0
        if dt < 0.12 then n = n * 4 end
    until dt >= 0.12 or n >= 50000000
    return dt * 1e6 / ran, ran
end

local function bench(name, f, ref)
    local us, n = measure(f)
    print(("%-32s %9.6f us/op  %7.1fM ops%s"):format(
        name, us, n / 1e6,
        ref and ('  %6.2fx'):format(us / ref) or ''))
    return us
end

print('\n== 实例创建 ==')
local ref_new = bench('{}', function() holder[1] = {} end)
bench('plainInit()', function() holder[1] = plainInit() end, ref_new)

local function rawNew(cls)
    return setmetatable({ __class = cls }, cls)
end
bench('rawNew(cls) [no ctor]', function() holder[1] = rawNew(BenchLeaf_7b01) end, ref_new)
bench('BenchBase()', function() holder[1] = BenchBase_7b01() end, ref_new)
bench('BenchLeaf() [depth5]', function() holder[1] = BenchLeaf_7b01() end, ref_new)
-- 有构造器的类（主流场景）
bench('BenchCtorSelf(1) [own ctor]', function() holder[1] = BenchCtorSelf_7b01(1) end, ref_new)
bench('BenchCtorChild(2) [inh ctor]', function() holder[1] = BenchCtorChild_7b01(2) end, ref_new)

print('\n== 实例方法调用 ==')
local ref_call = bench('PM.m(plain)', function() acc = acc + PM.m(plain) end)
bench('mUP(plain) [upvalue]', function() acc = acc + mUP(plain) end, ref_call)
bench('plain:getV()', function() acc = acc + plain:getV() end, ref_call)
bench('leaf:leafMethod()', function() acc = acc + leaf:leafMethod() end, ref_call)
bench('Leaf.leafMethod(leaf) [dot]', function() acc = acc + BenchLeaf_7b01.leafMethod(leaf) end, ref_call)
bench('leaf:rootMethod() [inherited]', function() acc = acc + leaf:rootMethod() end, ref_call)
bench('p:propMethod() [prop class]', function() acc = acc + p:propMethod() end, ref_call)

print('\n== 属性读写（p 为带属性类实例）==')
local ref_read = bench('plain.v', function() acc = acc + plain.v end)
bench('p._v [raw field]', function() acc = acc + p._v end, ref_read)
bench('p.value [getter]', function() acc = acc + p.value end, ref_read)
bench('plain:getV() [method getter]', function() acc = acc + plain:getV() end, ref_read)

local ref_write = bench('plain.v = k', function() plain.v = acc; acc = acc + 1 end)
bench('p._v = k [raw field]', function() p._v = acc; acc = acc + 1 end, ref_write)
bench('p.value = k [setter]', function() p.value = acc; acc = acc + 1 end, ref_write)

print('\n== super 调用 ==')
local ref_super = bench('Base.visit(sub) [direct]',
    function() acc = acc + (BenchSuperBase_7b01.visit(sub) == sub and 1 or 0) end)
bench('sub:via_super_x() [explicit]',
    function() acc = acc + (sub:via_super_x() == sub and 1 or 0) end, ref_super)
bench('sub:via_super0() [0-arg]',
    function() acc = acc + (sub:via_super0() == sub and 1 or 0) end, ref_super)

print('\n== 偶发 API（绝对值）==')
bench('Leaf:isExtends(Base) [true]',
    function() acc = acc + (BenchLeaf_7b01:isExtends(BenchBase_7b01) and 1 or 0) end)
bench('Leaf:isExtends(Other) [false]',
    function() acc = acc + (BenchLeaf_7b01:isExtends(BenchSuperBase_7b01) and 1 or 0) end)
bench('obj:clone()', function() holder[1] = leaf:clone() end)

print('\nsanity acc =', acc)
