-- 泛型 for 控制变量的 call 运算符兜底
--
-- LuaLS 的泛型 for 推导（compiler.lua 的 compileForVars）把
-- `for k, v in f, s, c do` 建模为 `local k, v = f(s, c)`，只通过
-- getReturn → call.return 向迭代器索要“函数返回值”，其分派只认
-- function / doc.type.function。
--
-- 普通调用表达式在结果未定型时会回退到 vm.runOperator('call', ...)
-- （compiler.lua 的 case 'call'），泛型 for 却没有这一步。于是当迭代器的
-- “可调用性”来自 __call 元方法（类型对象是 class/table 而非 function，
-- 典型如 SimpleClass 的 range：alias.__call.next() 生成的 @operator call）时，
-- 控制变量会退化为 unknown。
--
-- 本补丁包装 vm.compileNode：若被编译的是泛型 for 的控制变量，且默认推导
-- 未定型，则取 explist 第一个表达式做一次 call 运算符分派来补齐类型，
-- 复刻普通调用的兜底逻辑。
--
-- 另外，取迭代器用的 vm.selectNode 对 call 表达式只问 getReturn，为空就把
-- 内建 unknown 合并进“按被调用者缓存”的 call.return 节点
-- （callee._callReturns[1]）。该节点被后续 case 'call' 复用时，unknown 属于
-- global/type，会使 isTyped() 误判为“已定型”，从而跳过运算符兜底，把调用
-- 整体短路成 unknown（裸类 `class "X" {}` 即如此；带 `---@type X.constructor`
-- 注解的类因 getReturn 非空而幸免）。此处对这种被污染的缓存做一次清理后重编。

local M, state = ... ---@cast M LLSPatch
local vm = M.vm

local t_ok = M.t_require {
    vm.compileNode, 'function',
    vm.runOperator, 'function',
    vm.getNode,     'function',
    vm.setNode,     'function',
    vm.removeNode,  'function',
}

if not t_ok then
    return false,
    "type mismatch in required functions"
end

-- 保存原始函数
state.original = vm.compileNode

---source 是否为泛型 for 的控制变量。是则返回其所在的 `in` 节点。
---用 keys 做同一性判定，把 explist（同为 in 节点的子节点）排除在外，
---避免 runOperator 内部递归回自身。
local function getForInNode(source)
    local parent = source.parent
    if not parent or parent.type ~= 'in' or not parent.keys then
        return nil
    end
    for i = 1, #parent.keys do
        if parent.keys[i] == source then
            return parent
        end
    end
    return nil
end

---节点中是否含有内建的 unknown 类型
---@return boolean
local function hasUnknown(node)
    if not node then
        return false
    end
    for obj in node:eachObject() do
        if obj.type == 'global' and obj.cate == 'type'
        and obj.name == 'unknown' then
            return true
        end
    end
    return false
end

---迭代器若是调用表达式，可能被 vm.selectNode 注入的 unknown 污染了共享的
---call.return 缓存。此处只清掉被污染的那一项，让该调用干净重编，还原迭代器
---值的真实类型。仅在确实含 unknown 时动手，避免无谓改动。
---@return boolean cleaned
local function cleanPollutedCall(iterExp)
    if iterExp.type ~= 'call' then
        return false
    end
    local callee = iterExp.node
    if not callee then
        return false
    end
    local callReturns = callee._callReturns
    local slot = callReturns and callReturns[1]
    if not slot or not hasUnknown(vm.getNode(slot)) then
        return false
    end
    callReturns[1] = nil
    vm.removeNode(iterExp)
    vm.compileNode(iterExp)
    return true
end

---用迭代器的 call 运算符结果补齐控制变量类型
---@return boolean applied
local function applyCallOperator(source)
    local parent = getForInNode(source)
    if not parent then
        return false
    end
    local exps = parent.exps
    local iterExp = exps and exps[1]
    if not iterExp then
        return false
    end

    local opNode = vm.runOperator('call', iterExp)
    if not opNode or not opNode:isTyped() then
        -- 迭代器值被 unknown 短路时，清掉污染后重试
        if cleanPollutedCall(iterExp) then
            opNode = vm.runOperator('call', iterExp)
        end
    end
    if not opNode or not opNode:isTyped() then
        return false
    end
    -- 剥离可空性：泛型 for 里 nil 是循环停止信号，不应出现在循环变量类型上
    -- （与 compileForVars 的 getReturn(...):removeOptional() 行为一致）
    local bound = opNode:copy()
    bound:removeOptional()
    vm.setNode(source, bound)
    return true
end

vm.compileNode = function(source)
    local node = state.original(source)

    -- 仅处理泛型 for 控制变量，且默认推导未定型的情况
    if node and source and source.parent
    and not node:isTyped()
    and source.parent.type == 'in' then
        -- 依赖 LuaLS 未公开的细节，隔离异常以免波及正常诊断
        local ok, applied = pcall(applyCallOperator, source)
        if ok and applied then
            return vm.getNode(source)
        end
    end

    return node
end

return true
