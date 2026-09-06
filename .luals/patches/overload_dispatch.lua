---@param M llspatcher
---@param state table
---@return boolean
return function(M, state)
    local vm, guide = M.vm, M.guide

    local t_ok = M.t_require {
        vm.getExactMatchedFunctions, 'function',
        vm.canCastType, 'function',
        vm.isSubType, 'function',
    }

    if not t_ok then
        return false
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

    local function isBroadParameter(func)
        local param = func.args and func.args[1]
        if not param then
            return false
        end
        local node, genericBroad = getEffectiveParameter(func, param)
        return genericBroad or isBroadNode(node)
    end

    local function isGenericFunction(func)
        for _, doc in ipairs(func.bindDocs or {}) do
            if doc.type == 'doc.generic' then
                return true
            end
        end
        return false
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
        local params = func.args or {}
        for i, arg in ipairs(args or {}) do
            local param = params[i]
            if not param then
                return false
            end
            local paramNode, genericBroad = getEffectiveParameter(func, param)
            if not genericBroad
            and not vm.canCastType(uri, paramNode, vm.compileNode(arg))
            then
                return false
            end
        end
        return true
    end

    local function isMoreSpecific(uri, first, second)
        local firstArgs = first.args or {}
        local secondArgs = second.args or {}
        if #firstArgs ~= #secondArgs then
            return false
        end

        -- A useful generic is more specific than any/unknown, but a concrete
        -- non-generic declaration is preferred over a generic declaration.
        local firstGeneric = isGenericFunction(first)
        local secondGeneric = isGenericFunction(second)
        if firstGeneric ~= secondGeneric then
            if firstGeneric then
                return isBroadParameter(second)
            end
            return not isBroadParameter(first)
        end

        local strict = false
        for i = 1, #firstArgs do
            local firstNode = vm.compileNode(firstArgs[i])
            local secondNode = vm.compileNode(secondArgs[i])
            if isBroadNode(firstNode) or isBroadNode(secondNode) then
                return false
            end
            if vm.isSubType(uri, firstNode, secondNode) ~= true then
                return false
            end
            if vm.isSubType(uri, secondNode, firstNode) ~= true then
                strict = true
            end
        end
        return strict
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

        -- Prefer every matched non-broad candidate, including a useful generic
        -- candidate, over an any/unknown fallback.
        local matchedConcrete = {}
        local matchedFallback = {}
        for _, candidate in ipairs(matches) do
            if isFunctionMatched(uri, candidate, args) then
                if isBroadParameter(candidate) then
                    matchedFallback[#matchedFallback + 1] = candidate
                else
                    matchedConcrete[#matchedConcrete + 1] = candidate
                end
            end
        end
        if #matchedConcrete > 0 then
            matches = matchedConcrete
        elseif #matchedFallback > 0 then
            return matchedFallback
        end
        if #matches < 2 then
            return matches
        end

        -- Static uncertainty must remain a union; do not guess when the argument is broad.
        for _, arg in ipairs(args or {}) do
            if isBroadNode(vm.compileNode(arg)) then
                return matches
            end
        end

        -- any/unknown is a fallback only when a concrete candidate also matches.
        local concrete = {}
        for _, candidate in ipairs(matches) do
            if not isBroadParameter(candidate) then
                concrete[#concrete + 1] = candidate
            end
        end
        if #concrete == 0 then
            return matches
        end

        -- Keep only candidates that are not strictly dominated by a more specific one.
        local dominated = {}
        for i, candidate in ipairs(concrete) do
            for j, other in ipairs(concrete) do
                if i ~= j and isMoreSpecific(uri, other, candidate) then
                    dominated[i] = true
                    break
                end
            end
        end

        local selected = {}
        for i, candidate in ipairs(concrete) do
            if not dominated[i] then
                selected[#selected + 1] = candidate
            end
        end
        return #selected > 0 and selected or concrete
    end

    return true
end
