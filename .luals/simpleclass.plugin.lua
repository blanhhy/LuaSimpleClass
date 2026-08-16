---@class diff
---@field start  integer
---@field finish integer
---@field text   string

local function findBraceEnd(text, startPos)
    local depth = 0
    local n = #text
    local i = startPos
    while i <= n do
        local c = text:sub(i, i)
        if c == '"' or c == "'" then
            local q = c
            i = i + 1
            while i <= n and text:sub(i, i) ~= q do
                i = i + 1
            end
        elseif c == '-' and i < n and text:sub(i + 1, i + 1) == '-' then
            while i <= n and text:sub(i, i) ~= '\n' do
                i = i + 1
            end
        elseif c == '{' then
            depth = depth + 1
        elseif c == '}' then
            depth = depth - 1
            if depth == 0 then
                return i
            end
        end
        i = i + 1
    end
    return nil
end

local function skipCommentsAndWhitespace(body, i)
    local n = #body
    while i <= n do
        local c = body:sub(i, i)
        if c:match('%s') or c == ';' or c == ',' then
            i = i + 1
        elseif c == '-' and i < n and body:sub(i + 1, i + 1) == '-' then
            while i <= n and body:sub(i, i) ~= '\n' do
                i = i + 1
            end
        else
            break
        end
    end
    return i
end

local function parseClassBlock(text, startPos)
    local n = #text
    local pos = startPos
    local classKwEnd = pos + 4
    local restStart = classKwEnd + 1
    while restStart <= n and text:sub(restStart, restStart):match('%s') do
        restStart = restStart + 1
    end
    if restStart > n or text:sub(restStart, restStart) ~= '"' then
        return nil
    end
    local nameStart = restStart + 1
    local nameEnd = text:find('"', nameStart, true)
    if not nameEnd then return nil end
    local className = text:sub(nameStart, nameEnd - 1)
    pos = nameEnd + 1
    local parentName = nil
    local implementsList = {}
    local extStart, extEnd = text:find('^%s*:?%s*extends?%s*"', pos)
    if extStart then
        local pnameStart = extEnd + 1
        local pnameEnd = text:find('"', pnameStart, true)
        if pnameEnd then
            parentName = text:sub(pnameStart, pnameEnd - 1)
            pos = pnameEnd + 1
        end
    end
    pos = skipCommentsAndWhitespace(text, pos) or pos
    local impStart, impEnd = text:find('^:%s*implements%s*%(', pos)
    if impStart then
        pos = impEnd + 1
        while pos <= n do
            local c = text:sub(pos, pos)
            if c == ')' then
                break
            elseif c:match('[%w_]') then
                local iend = text:find('[%s,)]', pos)
                if iend then
                    local iname = text:sub(pos, iend - 1)
                    implementsList[#implementsList + 1] = iname
                    pos = iend
                else
                    break
                end
            else
                pos = pos + 1
            end
        end
    end
    local braceStart = text:find('{', pos)
    if not braceStart then return nil end
    local braceEnd = findBraceEnd(text, braceStart)
    if not braceEnd then return nil end
    return className, parentName, implementsList, startPos, braceEnd, text:sub(braceStart + 1, braceEnd - 1)
end

local function isWordBoundary(body, pos, n)
    if pos <= 1 or pos > n then return true end
    local c = body:sub(pos, pos)
    return not c:match('[%w_]')
end

local function parseMethods(body)
    local methods = {}
    local fields = {}
    local n = #body
    local i = 1
    while i <= n do
        i = skipCommentsAndWhitespace(body, i)
        if i > n then break end

        local name, afterFieldStart
        do
            local n1, p1 = body:match('^([%w_]+)%s*=%s*()', i)
            local n2, p2 = body:match("^%['([^']+)'%]%s*=%s*()", i)
            local n3, p3 = body:match('^%"([^"]+)"%]%s*=%s*()', i)
            if n1 then
                name = n1; afterFieldStart = p1
            elseif n2 then
                name = n2; afterFieldStart = p2
            elseif n3 then
                name = n3; afterFieldStart = p3
            end
        end
        if not name then
            break
        end

        local isGetter = false
        local isSetter = false
        if name:match('^get%.(.+)$') then
            isGetter = true
            name = name:match('^get%.(.+)$')
        elseif name:match('^set%.(.+)$') then
            isSetter = true
            name = name:match('^set%.(.+)$')
        end

        local commentLines = {}
        local ci = i - 1
        while ci >= 1 do
            while ci >= 1 and (body:sub(ci, ci) == ' ' or body:sub(ci, ci) == '\t') do
                ci = ci - 1
            end
            if ci >= 1 and body:sub(ci, ci) == '\n' then
                ci = ci - 1
                local lineEnd = ci
                while ci >= 1 and body:sub(ci, ci) ~= '\n' do
                    ci = ci - 1
                end
                local lineStart = ci + 1
                local line = body:sub(lineStart, lineEnd)
                if line:match('^%s*---') then
                    table.insert(commentLines, 1, (line:gsub('^%s+', '')))
                else
                    break
                end
            else
                break
            end
        end

        local rest = body:sub(afterFieldStart, math.min(afterFieldStart + 30, n))
        local funcMatchStart, funcMatchEnd = rest:find('^function%s*%(')

        if funcMatchStart then
            local parenStart = afterFieldStart + funcMatchEnd - 1
            local parenDepth = 1
            local j = parenStart + 1
            while j <= n and parenDepth > 0 do
                local c = body:sub(j, j)
                if c == '(' then
                    parenDepth = parenDepth + 1
                    j = j + 1
                elseif c == ')' then
                    parenDepth = parenDepth - 1
                    if parenDepth == 0 then break end
                    j = j + 1
                elseif c == '"' or c == "'" then
                    local q = c; j = j + 1
                    while j <= n and body:sub(j, j) ~= q do j = j + 1 end
                    j = j + 1
                else
                    j = j + 1
                end
            end
            local params = body:sub(parenStart + 1, j - 1)
            local funcBodyStart = j + 1

            local depth = 1
            local k = funcBodyStart
            while k <= n and depth > 0 do
                local c = body:sub(k, k)
                if c == '"' or c == "'" then
                    local q = c; k = k + 1
                    while k <= n and body:sub(k, k) ~= q do k = k + 1 end
                    k = k + 1
                elseif c == '-' and k < n and body:sub(k + 1, k + 1) == '-' then
                    while k <= n and body:sub(k, k) ~= '\n' do k = k + 1 end
                elseif c == '[' and k < n and body:sub(k + 1, k + 1) == '[' then
                    k = k + 2
                    while k <= n and body:sub(k, k + 1) ~= ']]' do k = k + 1 end
                    k = k + 2
                else
                    if isWordBoundary(body, k - 1, n) then
                        if body:sub(k, k + 7) == 'function' and isWordBoundary(body, k + 8, n) then
                            depth = depth + 1; k = k + 8
                        elseif body:sub(k, k + 1) == 'if' and isWordBoundary(body, k + 2, n) then
                            depth = depth + 1; k = k + 2
                        elseif body:sub(k, k + 2) == 'for' and isWordBoundary(body, k + 3, n) then
                            depth = depth + 1; k = k + 3
                        elseif body:sub(k, k + 4) == 'while' and isWordBoundary(body, k + 5, n) then
                            depth = depth + 1; k = k + 5
                        elseif body:sub(k, k + 5) == 'repeat' and isWordBoundary(body, k + 6, n) then
                            depth = depth + 1; k = k + 6
                        elseif body:sub(k, k + 4) == 'until' and isWordBoundary(body, k + 5, n) then
                            depth = depth - 1; if depth == 0 then k = k + 5; break end; k = k + 5
                        elseif body:sub(k, k + 2) == 'end' and isWordBoundary(body, k + 3, n) then
                            depth = depth - 1
                            if depth == 0 then
                                k = k + 3
                                break
                            end
                            k = k + 3
                        else
                            k = k + 1
                        end
                    else
                        k = k + 1
                    end
                end
            end

            local isOverride = false
            for _, doc in ipairs(commentLines) do
                if doc:match('^%-%-%-@[Oo]verride') then
                    isOverride = true
                    break
                end
            end

            local funcBody = body:sub(funcBodyStart, k - 4)
            methods[#methods + 1] = {
                name = name,
                params = params,
                body = funcBody,
                docs = commentLines,
                isGetter = isGetter,
                isSetter = isSetter,
                isOverride = isOverride,
            }
            i = k
        else
            fields[#fields + 1] = {
                name = name,
                docs = commentLines,
                isGetter = isGetter,
                isSetter = isSetter,
            }
            local lineEnd = body:find('[\n;]', afterFieldStart)
            if lineEnd then
                i = lineEnd + 1
            else
                i = n + 1
            end
        end
    end
    return methods, fields
end

local function getFirstParamName(params)
    local first = params:match('^%s*([%w_]+)')
    return first
end

local function stripFirstParam(params)
    local firstComma = params:find(',')
    if firstComma then
        local rest = params:sub(firstComma + 1)
        rest = rest:gsub('^%s+', '')
        return rest
    else
        return ''
    end
end

local function trimBody(body)
    local lines = {}
    for line in body:gmatch('([^\n]*)\n?') do
        if not line:match('^%s*$') then
            lines[#lines + 1] = line
        end
    end
    if #lines == 0 then return '' end
    return table.concat(lines, '\n')
end

local function findClassKeyword(text, from)
    local n = #text
    local pos = from
    while pos <= n do
        local cstart = text:find('class', pos, true)
        if not cstart then return nil end
        local before = cstart > 1 and text:sub(cstart - 1, cstart - 1) or '\n'
        if not before:match('[%w_.]') then
            local afterStart = cstart + 5
            local restStart = afterStart
            while restStart <= n and text:sub(restStart, restStart):match('%s') do
                restStart = restStart + 1
            end
            if restStart <= n and text:sub(restStart, restStart) == '"' then
                return cstart
            end
        end
        pos = cstart + 1
    end
    return nil
end

local function findInterfaceKeyword(text, from)
    local n = #text
    local pos = from
    while pos <= n do
        local cstart = text:find('interface', pos, true)
        if not cstart then return nil end
        local before = cstart > 1 and text:sub(cstart - 1, cstart - 1) or '\n'
        if not before:match('[%w_.]') then
            local afterStart = cstart + 9
            local restStart = afterStart
            while restStart <= n and text:sub(restStart, restStart):match('%s') do
                restStart = restStart + 1
            end
            if restStart <= n and text:sub(restStart, restStart) == '"' then
                return cstart
            end
        end
        pos = cstart + 1
    end
    return nil
end

local function parseInterfaceBlock(text, startPos)
    local n = #text
    local pos = startPos
    local kwEnd = pos + 8
    local restStart = kwEnd + 1
    while restStart <= n and text:sub(restStart, restStart):match('%s') do
        restStart = restStart + 1
    end
    if restStart > n or text:sub(restStart, restStart) ~= '"' then
        return nil
    end
    local nameStart = restStart + 1
    local nameEnd = text:find('"', nameStart, true)
    if not nameEnd then return nil end
    local iname = text:sub(nameStart, nameEnd - 1)
    pos = nameEnd + 1
    local extendsList = {}
    local fields = {}

    pos = skipCommentsAndWhitespace(text, pos) or pos
    local extStart, extEnd = text:find('^:%s*extends%s*%(', pos)
    if extStart then
        pos = extEnd + 1
        while pos <= n do
            local c = text:sub(pos, pos)
            if c == ')' then
                break
            elseif c:match('[%w_]') then
                local eend = text:find('[%s,)]', pos)
                if eend then
                    local ename = text:sub(pos, eend - 1)
                    extendsList[#extendsList + 1] = ename
                    pos = eend
                else
                    break
                end
            else
                pos = pos + 1
            end
        end
        pos = skipCommentsAndWhitespace(text, pos) or pos
    end

    while pos <= n do
        local c = text:sub(pos, pos)
        if c == '{' then
            local braceEnd = findBraceEnd(text, pos)
            if not braceEnd then return nil end
            local body = text:sub(pos + 1, braceEnd - 1)
            for field in body:gmatch('"([^"]+)"') do
                fields[#fields + 1] = field
            end
            return iname, extendsList, fields, startPos, braceEnd
        elseif c == '\n' or c == ';' then
            return iname, extendsList, fields, startPos, pos - 1
        elseif c == '-' and pos < n and text:sub(pos + 1, pos + 1) == '-' then
            while pos <= n and text:sub(pos, pos) ~= '\n' do
                pos = pos + 1
            end
            return iname, extendsList, fields, startPos, pos - 1
        else
            pos = pos + 1
        end
    end

    return iname, extendsList, fields, startPos, n
end

function OnSetText(uri, text)
    local hasClass = findClassKeyword(text, 1)
    local hasInterface = findInterfaceKeyword(text, 1)
    if not hasClass and not hasInterface then
        return
    end
    local diffs = {}

    local pos = 1
    local n = #text
    while pos <= n do
        local nextClass = findClassKeyword(text, pos)
        local nextInterface = findInterfaceKeyword(text, pos)
        local nextPos, isInterface
        if nextClass and nextInterface then
            if nextClass < nextInterface then
                nextPos, isInterface = nextClass, false
            else
                nextPos, isInterface = nextInterface, true
            end
        elseif nextClass then
            nextPos, isInterface = nextClass, false
        elseif nextInterface then
            nextPos, isInterface = nextInterface, true
        else
            break
        end

        if isInterface then
            local iname, extendsList, fields, iStart, iEnd = parseInterfaceBlock(text, nextPos)
            if not iname then
                pos = nextPos + 9
            else
                local out = {}
                -- 第一部分：接口变量标注为 interface 的子类
                out[#out + 1] = iname .. ' = {__iname="' .. iname .. '"} ---@class interface.' .. iname .. ' : interface'
                -- 第二部分：虚拟类型，给类多态用，不继承 interface
                local classLine = '---@class ' .. iname
                if #extendsList > 0 then
                    classLine = classLine .. ' : ' .. table.concat(extendsList, ', ')
                else
                    classLine = classLine .. ' : object'
                end
                out[#out + 1] = classLine
                for _, f in ipairs(fields) do
                    out[#out + 1] = '---@field ' .. f .. ' function'
                end
                diffs[#diffs + 1] = {
                    start  = iEnd + 1,
                    finish = iEnd,
                    text   = '\n' .. table.concat(out, '\n'),
                }
                pos = iEnd + 1
            end
        else
            local className, parentName, implementsList, classStart, classEnd, body = parseClassBlock(text, nextPos)
            if not className then
                pos = nextPos + 5
            else
                local methods, fields = parseMethods(body)
                local parent = parentName or 'object'
                local out = {}
                local classLine = '---@class ' .. className .. ' : ' .. parent
                if #implementsList > 0 then
                    classLine = classLine .. ', ' .. table.concat(implementsList, ', ')
                end
                out[#out + 1] = classLine
                out[#out + 1] = '---@field __class ' .. className
                out[#out + 1] = '---@field __base ' .. parent
                out[#out + 1] = '---@operator call:' .. className
                out[#out + 1] = className .. ' = {}'

                local newMethod = nil
                local initMethod = nil
                for _, m in ipairs(methods) do
                    if m.name == 'new' then newMethod = m end
                    if m.name == '__init' then initMethod = m end
                end

                if newMethod then
                    local paramStr = stripFirstParam(newMethod.params)
                    for _, docLine in ipairs(newMethod.docs) do
                        out[#out + 1] = docLine
                    end
                    out[#out + 1] = '---@diagnostic disable-next-line: unused-local'
                    out[#out + 1] = 'function ' .. className .. ':new(' .. paramStr .. ')return self end'
                elseif initMethod then
                    local paramStr = stripFirstParam(initMethod.params)
                    for _, docLine in ipairs(initMethod.docs) do
                        out[#out + 1] = docLine
                    end
                    out[#out + 1] = '---@diagnostic disable-next-line: unused-local'
                    out[#out + 1] = 'function ' .. className .. ':new(' .. paramStr .. ')return self end'
                else
                    out[#out + 1] = 'function ' .. className .. ':new()return self end'
                end

                for _, f in ipairs(fields) do
                    for _, docLine in ipairs(f.docs) do
                        out[#out + 1] = docLine
                    end
                    out[#out + 1] = className .. '.' .. f.name .. ' = nil'
                end

                for _, m in ipairs(methods) do
                    if m.isGetter then
                        local attrName = m.name
                        out[#out + 1] = className .. '.' .. attrName .. ' = ('
                        out[#out + 1] = '    ---@param self ' .. className
                        out[#out + 1] = '    function(' .. m.params .. ')'
                        if m.body and #m.body > 0 then
                            local trimmed = trimBody(m.body)
                            if #trimmed > 0 then
                                for line in trimmed:gmatch('([^\n]+)') do
                                    out[#out + 1] = '    ' .. line
                                end
                            end
                        end
                        out[#out + 1] = '    end'
                        out[#out + 1] = ')(' .. className .. ')'
                    end
                end

                for _, m in ipairs(methods) do
                    if m.name == 'new' then
                    elseif m.isGetter or m.isSetter then
                    else
                        local firstParam = getFirstParamName(m.params)
                        for _, docLine in ipairs(m.docs) do
                            out[#out + 1] = docLine
                        end
                        if firstParam == 'self' then
                            local cleanParams = stripFirstParam(m.params)
                            out[#out + 1] = 'function ' .. className .. ':' .. m.name .. '(' .. cleanParams .. ')'
                        else
                            out[#out + 1] = 'function ' .. className .. '.' .. m.name .. '(' .. m.params .. ')'
                        end
                        if m.body and #m.body > 0 then
                            local trimmed = trimBody(m.body)
                            if #trimmed > 0 then
                                out[#out + 1] = trimmed
                            end
                        end
                        out[#out + 1] = 'end'
                    end
                end

                local overrideMethods = {}
                for _, m in ipairs(methods) do
                    if m.isOverride and m.name ~= 'new' then
                        overrideMethods[#overrideMethods + 1] = m
                    end
                end
                if #overrideMethods > 0 and parentName then
                    out[#out + 1] = '---@diagnostic disable-next-line: unused-function, unused-local, redefined-local'
                    out[#out + 1] = 'local function __ls_check__()'
                    out[#out + 1] = '    ---@class ' .. parentName
                    out[#out + 1] = '    local _ = {}'
                    out[#out + 1] = '    local override_method'
                    for _, m in ipairs(overrideMethods) do
                        out[#out + 1] = '    override_method = _.' .. m.name
                    end
                    out[#out + 1] = '    return override_method'
                    out[#out + 1] = 'end'
                end

                diffs[#diffs + 1] = {
                    start  = classEnd + 1,
                    finish = classEnd,
                    text   = '\n' .. table.concat(out, '\n'),
                }
                pos = classEnd + 1
            end
        end
    end

    if #diffs == 0 then return nil end
    return diffs
end