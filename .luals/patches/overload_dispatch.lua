---@param M llspatcher
---@param state table
---@return boolean
return function(M, state)
    local vm, guide = M.vm, M.guide

    local t_ok = M.t_require {
        vm.getExactMatchedFunctions, 'function',
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

    local function isBroadParameter(func)
        local param = func.args and func.args[1]
        return param ~= nil and isBroadNode(vm.compileNode(param))
    end

    local function isMoreSpecific(uri, first, second)
        local firstArgs = first.args or {}
        local secondArgs = second.args or {}
        if #firstArgs ~= #secondArgs then
            return false
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

        -- local name = guide.getKeyName(func)
        -- if not name or not state.targets[name] then
        --     return matches
        -- end

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
        local uri = guide.getUri(func)
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