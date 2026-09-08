local M, state = ... ---@cast M LLSPatch
local vm, guide = M.vm, M.guide

local t_ok = M.t_require {
    vm.getExactMatchedFunctions, 'function',
    vm.canCastType, 'function',
    vm.isSubType, 'function',
}

if not t_ok then
    return false,
    "type mismatch in required functions"
end

-- 保存原始函数
state.original = vm.getExactMatchedFunctions

local function isBroadNode(node)
    if not node then
        return false
    end
    for item in node:eachObject() do
        local name = vm.getNodeName(item)
        if name == 'any' or name == 'unknown' then
            return true
        end
    end
    return false
end

local function getGenericBounds(func)
    local bounds = {}
    for _, doc in ipairs(func.bindDocs or {}) do
        if doc.type == 'doc.generic' then
            for _, generic in ipairs(doc.generics or {}) do
                local name = generic.generic and generic.generic[1]
                if name then
                    bounds[name] = generic.extends and vm.compileNode(generic.extends)
                end
            end
        end
    end
    return bounds
end

local function getEffectiveParameter(func, param)
    local node = vm.compileNode(param)
    local bounds = getGenericBounds(func)
    for item in node:eachObject() do
        if item.type == 'doc.generic.name' or item.type == 'generic' then
            local bound = bounds[item[1]]
            if bound then
                return bound, false
            end
            -- An unconstrained generic is equivalent to any for matching.
            return nil, true
        end
    end
    return node, false
end

local function isUnresolvedGenericNode(node)
    for item in node:eachObject() do
        if item.type == 'doc.generic.name'
            or item.type == 'generic'
        then
            return true
        end
    end
    return false
end

local function isFunctionMatched(uri, func, args)
    for i, arg in ipairs(args or {}) do
        local parameter = func.args and func.args[i]
        if not parameter then
            return false
        end
        local paramNode, genericBroad = getEffectiveParameter(func, parameter)
        if not genericBroad and not vm.canCastType(uri, paramNode, vm.compileNode(arg))
        then
            return false
        end
    end
    return true
end

local function getParameterInfo(func, index)
    local parameter = func.args and func.args[index]
    if not parameter then
        return nil
    end

    local node, genericBroad = getEffectiveParameter(func, parameter)
    local literals, literalCount = vm.getLiterals(node)
    return {
        node = node,
        broad = genericBroad or isBroadNode(node),
        literals = literals,
        literalCount = literalCount,
    }
end

local function getArgumentInfo(arg)
    local node = vm.compileNode(arg)
    local literals, literalCount = vm.getLiterals(node)
    return {
        node = node,
        broad = isBroadNode(node),
        literals = literals,
        literalCount = literalCount,
    }
end

local function hasLiteralMatch(arg, parameter)
    if not arg.literals or not parameter.literals then
        return false
    end
    for literal in pairs(arg.literals) do
        if parameter.literals[literal] then
            return true
        end
    end
    return false
end

-- Compare two parameter types for one actual argument.
-- Returns 1 when first is more precise, -1 when second is more precise,
-- and 0 when the relationship is unknown or equivalent.
local function compareParameter(uri, arg, first, second)
    if first.broad ~= second.broad then
        return first.broad and -1 or 1
    end
    if first.broad then
        return 0
    end

    local firstLiteral = hasLiteralMatch(arg, first)
    local secondLiteral = hasLiteralMatch(arg, second)
    if firstLiteral ~= secondLiteral then
        return firstLiteral and 1 or -1
    end
    if firstLiteral and secondLiteral
        and first.literalCount ~= second.literalCount
    then
        return first.literalCount < second.literalCount and 1 or -1
    end

    local firstExact = vm.isSubType(uri, arg.node, first.node) == true
        and vm.isSubType(uri, first.node, arg.node) == true
    local secondExact = vm.isSubType(uri, arg.node, second.node) == true
        and vm.isSubType(uri, second.node, arg.node) == true
    if firstExact ~= secondExact then
        return firstExact and 1 or -1
    end

    local firstToSecond = vm.isSubType(uri, first.node, second.node)
    local secondToFirst = vm.isSubType(uri, second.node, first.node)
    if firstToSecond == true and secondToFirst ~= true then
        return 1
    end
    if secondToFirst == true and firstToSecond ~= true then
        return -1
    end
    return 0
end

local function isMoreSpecific(uri, first, second, args)
    local better = false
    for i, arg in ipairs(args) do
        local firstParameter = getParameterInfo(first, i)
        local secondParameter = getParameterInfo(second, i)
        if not firstParameter or not secondParameter then
            return false
        end

        local relation = compareParameter(uri, arg, firstParameter, secondParameter)
        if relation < 0 then
            return false
        elseif relation > 0 then
            better = true
        end
    end
    return better
end

vm.getExactMatchedFunctions = function(func, args)
    local matches = state.original(func, args)
    if not matches or #matches < 2 then
        return matches
    end

    local uri = guide.getUri(func)

    -- An unresolved generic argument is not specific enough to choose a signature.
    for _, arg in ipairs(args or {}) do
        if isUnresolvedGenericNode(vm.compileNode(arg)) then
            return matches
        end
    end

    local argumentInfo = {}
    for i, arg in ipairs(args or {}) do
        argumentInfo[i] = getArgumentInfo(arg)
        -- A broad actual value cannot select one overload safely.
        if argumentInfo[i].broad then
            return matches
        end
    end

    local matched = {}
    for _, candidate in ipairs(matches) do
        if isFunctionMatched(uri, candidate, args) then
            matched[#matched + 1] = candidate
        end
    end
    if #matched < 2 then
        return #matched > 0 and matched or matches
    end

    local dominated = {}
    for i, candidate in ipairs(matched) do
        for j, other in ipairs(matched) do
            if i ~= j and isMoreSpecific(uri, other, candidate, argumentInfo) then
                dominated[i] = true
                break
            end
        end
    end

    local selected = {}
    for i, candidate in ipairs(matched) do
        if not dominated[i] then
            selected[#selected + 1] = candidate
        end
    end
    return #selected > 0 and selected or matched
end

return true
