-- LuaJIT trace 可追踪性探针
--
-- 运行：luajit tests/performance/jit_trace.lua
--
-- 目的：观测「给定调用形状会不会打断 JIT 的 trace」，而不是从耗时反推。
-- 耗时在 JIT 下会把这类调用整体内联折叠、落进测量地板，看不出任何差别
-- （见 bench.lua 里成片的 ~FOLDED 与 ~CANT FOLD）；
-- 而 trace 的 start / abort 事件是直接可数的事实。
--
-- 读数约定：
--   · aborts = 0 为健康；偶发 1 次属正常运行波动，只看「0 / 个位数 / 大量」这个量级，
--     不要按精确值读。
--   · 脚本末尾带对照组：循环内创建闭包必然命中 NYI，若该组 aborts 为 0，
--     说明 trace 事件根本没被观测到，探针失效，此时上面所有计数都不可信，
--     脚本会以非 0 退出码报出。
--

local source = debug.getinfo(1, 'S').source:match('^@?(.*)[/\\]') or 'tests/'
local sep = package.config:sub(1, 1)
source = source:gsub('[/\\]+$', '')
local root = source:gsub('[/\\]tests[/\\]performance$', '')
if root == source then root = '.' end
package.path = table.concat({
    root .. sep .. '?.lua',
    root .. sep .. '?/init.lua',
    package.path,
}, ';')

local JIT = rawget(_G, 'jit')
print('interpreter:', _VERSION, JIT and ('LuaJIT ' .. JIT.version) or 'PUC Lua')

if not (JIT and JIT.attach) then
    print('无 JIT，本探针不适用。')
    os.exit(0)
end

-- ===== 终端显示宽度：CJK 占 2 列，直接 %-Ns 按字节补齐会把数字顶偏 =====

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

local NAME_W = 42

local function pad(s, w)
    local d = w - dwidth(s)
    return d > 0 and (s .. (' '):rep(d)) or s
end

-- ===== 计数框架 =====

local starts, aborts, counting = 0, 0, false

JIT.attach(function(what)
    if not counting then return end
    if what == 'abort' then
        aborts = aborts + 1
    elseif what == 'start' then
        starts = starts + 1
    end
end, 'trace')

---@param label string
---@param body fun() 热循环写在 body 内，避免包装调用混进被测路径
---@return integer aborts
local function probe(label, body)
    starts, aborts = 0, 0
    counting = true
    body()
    counting = false
    print(pad(label, NAME_W) .. ('starts %4d  aborts %4d'):format(starts, aborts))
    return aborts
end

-- ===== 被测形状 =====

require 'simpleclass'

class "JitTraceBase_9c31" {
    __init = function(self, v)
        self._v = v or 18
    end;
    visit = function(self, x) return x end;
}

class "JitTraceSub_9c31" : extends "JitTraceBase_9c31" {
    via_super_x = function(self, x)
        return super(JitTraceSub_9c31, self):visit(x)
    end;
    via_super0 = function(self, x)
        return super():visit(x)
    end;
}

-- 属性单独一类：getter / setter 是类静态字段，不随继承传递，
-- 放在基类上再拿子类实例访问会取到 nil。
class "JitTraceProp_9c31" {
    __init = function(self, v)
        self._v = v or 18
    end;
    property.value;
    ['get.value'] = function(self)
        return self._v
    end;
    ['set.value'] = function(self, v)
        self._v = v
    end;
}

local sub = JitTraceSub_9c31()
local prop = JitTraceProp_9c31()
local N = 20000
local k = 0
local acc = 0        -- 结果汇入，避免循环被整体消除
local holder = {}    -- 逃逸槽：阻止 JIT 消除分配

local libAborts = 0

libAborts = libAborts + probe('实例方法调用', function()
    for _ = 1, N do k = k + 1; acc = (acc + sub:visit(k)) % 1000003 end
end)

libAborts = libAborts + probe('super(C, self):m(x) [显式]', function()
    for _ = 1, N do k = k + 1; acc = (acc + sub:via_super_x(k)) % 1000003 end
end)

libAborts = libAborts + probe('super():m(x) [零参]', function()
    for _ = 1, N do k = k + 1; acc = (acc + sub:via_super0(k)) % 1000003 end
end)

libAborts = libAborts + probe('属性 getter / setter 读写', function()
    for _ = 1, N do
        k = k + 1
        prop.value = k
        acc = (acc + prop.value) % 1000003
    end
end)

libAborts = libAborts + probe('object.clone [deep]', function()
    for _ = 1, N do k = k + 1; holder[1] = object.clone(sub) end
end)

-- 对照组：已知会打断 trace 的形状，用于校验探针本身是否有效
local maker = function(v) return function() return v end end
local ctlAborts = probe('对照组：循环内创建闭包（应中止）', function()
    for _ = 1, N do
        local f = maker(k)
        k = k + 1
        acc = (acc + f()) % 1000003
    end
end)

-- ===== 自检 =====

print()
print(('库形状中止次数合计: %d（0 为健康，偶发 1 属正常波动）'):format(libAborts))

if ctlAborts == 0 then
    print('探针失效：对照组没有产生任何 abort，说明 trace 事件未被观测到，')
    print('上面所有 aborts 计数均不可信。')
    os.exit(1)
end

if acc == 0 or holder[1] == nil then
    print('异常：被测结果未被观察到，循环可能被整体消除。')
    os.exit(1)
end

print('done: 探针自检通过（对照组产生 abort，观测链路有效）')
os.exit(0)
