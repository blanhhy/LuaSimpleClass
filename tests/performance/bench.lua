-- simpleclass 实例运行期性能基准（对比原生 table 基线）
-- 运行：lua tests/performance/bench.lua 或 luajit tests/performance/bench.lua
--
-- 测量约定（三条都是为了不让 JIT 把要测的东西优化掉）：
--   1) 每个被测函数都接受一个变化的实参 x 并把 x 返回/汇入 acc，
--      否则循环体退化成常量累加，JIT 会把它强度削减成 acc = acc + n，测到折叠残渣；
--   2) 接收者保持固定：固定接收者才是常态调用形状，交替接收者会把调用点变成多态，
--      测出的是多态惩罚而不是派发成本；
--   3) 属性写读采用「写 A 读 B 再交换」：写后立刻读同一张表会被 store→load 转发抹掉，
--      那样根本测不到写入。写读不同表则两者都必须真执行，与 simpleclass 路径可比。

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

local index = require "simpleclass"["index"]

local JIT = rawget(_G, 'jit')
print('interpreter:', _VERSION, JIT and ('LuaJIT ' .. JIT.version) or 'PUC Lua')

-- ===== 类定义 =====

class "BenchBase_7b01" {
    rootMethod = function(self, x) return x end;
}

class "BenchL1_7b01" : extends "BenchBase_7b01" {
    l1 = function(self, x) return x end;
}

class "BenchL2_7b01" : extends "BenchL1_7b01" {
    l2 = function(self, x) return x end;
}

class "BenchL3_7b01" : extends "BenchL2_7b01" {
    l3 = function(self, x) return x end;
}

class "BenchLeaf_7b01" : extends "BenchL3_7b01" {
    leafMethod = function(self, x) return x end;
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
    propMethod = function(self, x) return x end;
}

-- 有构造器的类
class "BenchCtorSelf_7b01" {
    __init = function(self, x)
        self.x = x
    end;
}

class "BenchCtorChild_7b01" : extends "BenchCtorSelf_7b01" {
    -- 不写构造器：沿链继承基类构造器
}

class "BenchSuperBase_7b01" {
    __init = function(self, x) return x end;
    visit = function(self, x) return x end;
}

class "BenchSuperSub_7b01" : extends "BenchSuperBase_7b01" {
    via_super_x = function(self, x)
        return super(BenchSuperSub_7b01, self):visit(x)
    end;
    via_super0 = function(self, x)
        return super():visit(x)
    end;
    super_ctor = function(self, x)
        return super(BenchSuperSub_7b01, self)(x) -- 构造器专线
    end;
    via_direct = function(self, x)
        return BenchSuperBase_7b01["visit"](self, x)
    end;
    via_base = function(self, x)
        return BenchSuperSub_7b01["__base"].visit(self, x)
    end;
    via_index = function(self, x)
        return index(BenchSuperSub_7b01, "visit", true)(self, x)
    end;
}

-- ===== 原生基线 =====

local function plainGetV(self, x) return self.v + x end
local plainA = { v = 1, getV = plainGetV }
local plainB = { v = 2, getV = plainGetV }

local PM = { m = function(self, x) return x end }
local mUP = PM.m

local plainClass = {}
local plainMeta = {}

-- Keep allocation/metatable setup separate from constructor field writes.
local function plainNew()
    return setmetatable({ __class = plainClass }, plainMeta)
end

local function plainInitFields(t, x)
    t.x = x
    return t
end

local function plainMake(x)
    return plainInitFields(plainNew(), x)
end

local function rawNew(cls)
    return setmetatable({ __class = cls }, cls)
end

-- ===== 健全性检查 =====

local leaf = BenchLeaf_7b01()
assert(leaf:leafMethod(1) == 1)
assert(leaf:rootMethod(2) == 2)
assert(BenchCtorSelf_7b01(1).x == 1, 'ctor direct')
assert(BenchCtorChild_7b01(2).x == 2, 'ctor inherited')
local p = BenchProp_7b01()
assert(p.value == 1, 'prop getter')
p.value = 3
assert(p.value == 3, 'prop setter')
assert(rawget(p, 'value') == nil)
assert(issubclass(BenchLeaf_7b01, BenchBase_7b01))
assert(not issubclass(BenchLeaf_7b01, BenchSuperBase_7b01))
local sub = BenchSuperSub_7b01()
assert(sub:via_super_x(7) == 7, 'explicit super')
assert(sub:via_base(8) == 8, 'manual super')
assert(sub:via_super0(9) == 9, '0-arg super')
assert(sub:super_ctor(5) == 5, 'super ctor')
assert(BenchBase_7b01():clone():getClass() == BenchBase_7b01, 'clone')
print('sanity: ok')

-- ===== 基准框架 =====

local acc = 0          -- 结果汇入以阻止死代码消除
local holder = {}      -- 逃逸槽：阻止 JIT 消除分配

local function measure(f)
    for _ = 1, 6000 do f() end                    -- 预热 / JIT
    acc = 0                                       -- 每个测项都从 0 重新累加，不跨测项继承
    local n, dt, ran = 100000, 0, 0
    repeat
        ran = n                                   -- 记录本次实际执行的次数
        local t0 = os.clock()
        for _ = 1, n do f() end
        dt = os.clock() - t0
        if dt < 0.1 then n = n * 4 end
    until dt >= 0.1 or ran >= 200000000           -- 跑够 0.1s 才计时，避免时钟精度吞噬结果
    return dt * 1e6 / ran, ran, dt
end

-- 测量地板：低于此值的行说明 JIT 已把该行的工作（含派发）整体折叠掉
local FLOOR = 0.001 -- us/op

-- 终端显示宽度：CJK 等 3 字节以上的 UTF-8 序列占 2 列。
-- 直接用 %-Ns 是按字节补齐，中文行的数字会被顶偏，所以必须按显示宽度自己补。
local function dwidth(s)
    local w, i, n = 0, 1, #s
    while i <= n do
        local b = s:byte(i)
        if b < 0x80 then i = i + 1; w = w + 1
        elseif b < 0xE0 then i = i + 2; w = w + 1
        elseif b < 0xF0 then i = i + 3; w = w + 2
        else i = i + 4; w = w + 2 end
    end
    return w
end

local NAME_W = 40 -- 最长的测项名

local function pad(s, w)
    local d = w - dwidth(s)
    return d > 0 and (s .. (' '):rep(d)) or s
end

-- 每项跑两次取小值。FOLDED 表示已到地板，FAST 表示计时段太短，UNSTABLE 表示两次偏差 >30%。
local function bench(name, f, ref)
    local us1, n1, dt1 = measure(f)
    local us2, n2, dt2 = measure(f)
    local us, nn, dt = us1, n1, dt1
    if us2 < us1 then us, nn, dt = us2, n2, dt2 end

    local flag = ''
    if us < FLOOR then
        flag = '  [√]FOLDED'
    elseif dt < 0.05 then
        flag = '  [!]FAST'
    elseif us > 0 and math.abs(us1 - us2) / us > 0.3 then
        flag = '  [!]UNSTABLE'
    end
    local ratio = ''
    if ref then
        if ref < FLOOR and us >= FLOOR then
            -- 参照行已被折叠而本行没有，无法相比
            ratio = '  [!]CANT FOLD'
        elseif ref < FLOOR then
            -- 都被折叠，比值总在1左右，打印意义不大
            ratio = ''
        elseif ref > 0 then
            ratio = ('  %6.2fx'):format(us / ref)
        else
            ratio = '  [?]REF=0'
        end
    end
    print(pad(name, NAME_W) .. ('%7.6f us/op  %7.1fM ops%s%s'):format(
        us, nn / 1e6, ratio, flag))
    return us
end

-- 运行环境漂移探测：同一段纯整数依赖链在各节开头各测一次。
-- 值变大说明 CPU 降频/系统负载上来了，该节的绝对耗时（us/op）随之膨胀；
-- 比值只在该节内部（同一时段）才可信。纯依赖链不分配、不访问内存，只反映机器状态。
local cal_sink = 0
local SPIN_N = JIT and 30000000 or 3000000   -- 两种解释器下都让单轮 ≈15ms，避免被时钟精度量化

local function spin(n)
    -- 累加值在 1e6 内回卷：一旦越过 2^31，LuaJIT 的整数加法守卫会持续失守，
    -- 这条 trace 就再也代表不了机器速度（它反映的是 trace 反复退出）
    local s = 0
    for _ = 1, n do
        s = s + 1
        if s == 1000000 then s = 0 end
    end
    return s
end

local function calibrate()
    local best = math.huge
    for _ = 1, 3 do                              -- 首轮兼任预热（JIT trace 编译）
        local t = os.clock()
        local r = spin(SPIN_N)
        local dt = os.clock() - t
        cal_sink = cal_sink + r % 1024
        if dt < best then best = dt end
    end
    return best * 1e6 / SPIN_N
end

local cals = {}

local function section(title)
    local c = calibrate()
    cals[#cals + 1] = c
    print(('\n== %s ==  [cal %.6f us/op]'):format(title, c))
end

section('空实例创建：new（表<-元表）')
local ref_new = bench('{} [no mt]', function() holder[1] = {} end)
bench('plainNew() [tbl<-mt]', function() holder[1] = plainNew() end, ref_new)
bench('rawNew(cls) [inst<-cls]', function() holder[1] = rawNew(BenchLeaf_7b01) end, ref_new)
bench('BenchBase:new() [depth1]', function() holder[1] = BenchBase_7b01:new() end, ref_new)
bench('BenchLeaf:new() [depth5]', function() holder[1] = BenchLeaf_7b01:new() end, ref_new)

section('仅初始化：init/ctor [1field]')
local initPool = {}
for i = 1, 16 do initPool[i] = {} end
local initPos = 0
local initK = 0
local ctorSelf = BenchCtorSelf_7b01.__init
local function nextInitTarget()
    initPos = initPos % #initPool + 1
    return initPool[initPos]
end
local ref_init = bench('plainInitFields(t, x)', function()
    initK = initK + 1
    local t = nextInitTarget()
    plainInitFields(t, initK)
    acc = acc + t.x
end)
bench('BenchCtorSelf.__init(t, x)', function()
    initK = initK + 1
    local t = nextInitTarget()
    ctorSelf(t, initK)
    acc = acc + t.x
end, ref_init)

section('完整实例创建（new + init）')
local createK = 0
local ref_full = bench('plainMake(x) [factory func]', function()
    createK = createK + 1
    holder[1] = plainMake(createK)
end)
bench('BenchCtorSelf:new(x) [own init]', function()
    createK = createK + 1
    holder[1] = BenchCtorSelf_7b01:new(createK)
end, ref_full)
bench('BenchCtorChild:new(x) [inh init]', function()
    createK = createK + 1
    holder[1] = BenchCtorChild_7b01:new(createK)
end, ref_full)
bench('BenchProp:new() [set raw prop]', function()
    holder[1] = BenchProp_7b01:new()
end, ref_full)

section('实例方法调用')
local baseI, l1I = BenchBase_7b01(), BenchL1_7b01()
local kc = 0
local ref_call = bench('Leaf.leafMethod(t, x) [raw func]', function()
    kc = kc + 1
    acc = acc + BenchLeaf_7b01["leafMethod"](leaf, kc)
end)
bench('PM.m(t, x) [plain tbl]', function()
    kc = kc + 1
    acc = acc + PM.m(plainA, kc)
end, ref_call)
bench('mUP(t, x) [upvalue]', function()
    kc = kc + 1
    acc = acc + mUP(plainA, kc)
end, ref_call)
bench('t:getV(x) [tbl meth]', function()
    kc = kc + 1
    acc = acc + plainA:getV(kc)
end, ref_call)
bench('base:rootMethod(x) [depth1]', function()
    kc = kc + 1
    acc = acc + baseI:rootMethod(kc)
end, ref_call)
bench('l1:l1(x) [depth2]', function()
    kc = kc + 1
    acc = acc + l1I:l1(kc)
end, ref_call)
bench('leaf:leafMethod(x) [depth5 own]', function()
    kc = kc + 1
    acc = acc + leaf:leafMethod(kc)
end, ref_call)
bench('leaf:rootMethod(x) [depth5 inh]', function()
    kc = kc + 1
    acc = acc + leaf:rootMethod(kc)
end, ref_call)
bench('p:propMethod(x) [cls with prop]', function()
    kc = kc + 1
    acc = acc + p:propMethod(kc)
end, ref_call)

section('属性读写')
local kf = 0
local rwA, rwB = plainA, plainB
local ref_rw = bench('plain.v [tbl field] <rw>', function()
    kf = kf + 1
    rwA.v = kf
    acc = acc + rwB.v
    rwA, rwB = rwB, rwA
end)
local gA, gB = plainA, plainB
bench('plain:getV(0) [classic] <r>', function()
    kf = kf + 1
    gA.v = kf
    acc = acc + gB:getV(0)
    gA, gB = gB, gA
end, ref_rw)
local fA, fB = BenchProp_7b01(), BenchProp_7b01()
bench('p._v [raw field] <rw>', function()
    kf = kf + 1
    fA._v = kf
    acc = acc + fB._v
    fA, fB = fB, fA
end, ref_rw)
local hA, hB = BenchProp_7b01(), BenchProp_7b01()
bench('p.value [getter+setter] <rw>', function()
    kf = kf + 1
    hA.value = kf
    acc = acc + hB.value
    hA, hB = hB, hA
end, ref_rw)
local iA, iB = BenchProp_7b01(), BenchProp_7b01()
bench('p.value [getter] <r>', function()
    kf = kf + 1
    iA._v = kf
    acc = acc + iB.value
    iA, iB = iB, iA
end, ref_rw)

section('super 调用')
local subA = BenchSuperSub_7b01()
-- 避免混入查找实例方法本身的开销干扰测试关注点
local via_direct  = BenchSuperSub_7b01["via_direct"]
local via_base    = BenchSuperSub_7b01["via_base"]
local via_index   = BenchSuperSub_7b01["via_index"]
local via_super_x = BenchSuperSub_7b01["via_super_x"]
local via_super0  = BenchSuperSub_7b01["via_super0"]
local super_ctor  = BenchSuperSub_7b01["super_ctor"]
local ks = 0
local ref_super = bench('sub:via_direct(x) [hardcode Base]', function()
    ks = ks + 1
    acc = acc + via_direct(subA, ks)
end)
if not index then
bench('sub:via_base(x) [relative __base]', function()
    ks = ks + 1
    acc = acc + via_base(subA, ks)
end, ref_super)
else
bench('sub:via_index(x) [call index()]', function()
    ks = ks + 1
    acc = acc + via_index(subA, ks)
end, ref_super)
end
bench('sub:via_super_x(x) [explicit]', function()
    ks = ks + 1
    acc = acc + via_super_x(subA, ks)
end, ref_super)
bench('sub:super_ctor(x) [init dedicated]', function()
    ks = ks + 1
    acc = acc + super_ctor(subA, ks)
end, ref_super)
bench('sub:via_super0(x) [0-arg] [debug lib]', function()
    ks = ks + 1
    acc = acc + via_super0(subA, ks)
end, ref_super)

section('偶发 API（绝对值）')
local clsPool = { BenchLeaf_7b01, BenchL3_7b01 }
local kp = 0
bench('issubclass(cls, Base) [true]', function()
    kp = kp + 1
    local c = (kp % 2 == 0) and clsPool[1] or clsPool[2]
    acc = acc + (issubclass(c, BenchBase_7b01) and kp or 0)
end)
bench('issubclass(cls, Other) [false]', function()
    kp = kp + 1
    local c = (kp % 2 == 0) and clsPool[1] or clsPool[2]
    acc = acc + (issubclass(c, BenchSuperBase_7b01) and 0 or kp)
end)
bench('object.clone [shallow]', function() holder[1] = object.clone(leaf, false) end)
bench('object.clone [deep]', function() holder[1] = object.clone(leaf, true) end)

-- 收尾复核：确认被反复读写的对象语义仍然正确（基准不该改变被测对象的行为）
assert(leaf:leafMethod(1) == 1 and leaf:rootMethod(2) == 2)
assert(p.value == 3 and issubclass(BenchLeaf_7b01, BenchBase_7b01))

acc = acc + cal_sink                              -- 让校准链的汇总值可观测，避免被消除
local c_first, c_last = cals[1], cals[#cals]
local drift = c_last / c_first
print(('\n校准 %.6f -> %.6f us/op（漂移 %+.0f%%）%s'):format(
    c_first, c_last, (drift - 1) * 100,
    math.abs(drift - 1) > 0.2
        and '  << 环境漂移明显，请只比较同一节内部的比值'
        or  '  （环境稳定，绝对值可用）'))
print('done: 全部测项完成，语义复核通过')
