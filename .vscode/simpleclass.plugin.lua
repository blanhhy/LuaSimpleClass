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
    local extStart, extEnd = text:find('^%s*:?%s*extends?%s*"', pos)
    if extStart then
        local pnameStart = extEnd + 1
        local pnameEnd = text:find('"', pnameStart, true)
        if pnameEnd then
            parentName = text:sub(pnameStart, pnameEnd - 1)
            pos = pnameEnd + 1
        end
    end
    local braceStart = text:find('{', pos)
    if not braceStart then return nil end
    local braceEnd = findBraceEnd(text, braceStart)
    if not braceEnd then return nil end
    return className, parentName, startPos, braceEnd, text:sub(braceStart + 1, braceEnd - 1)
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

local function parseMethods(body)
    local methods = {}
    local n = #body
    local i = 1
    while i <= n do
        i = skipCommentsAndWhitespace(body, i)
        if i > n then break end
        local nameStart = i
        local name, after = body:match('^([%w_]+)%s*=%s*(.*)', i)
        if not name then
            break
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
        local funcKw = after:match('^function%s*%(')
        if funcKw then
            local eqPos = body:find('=', i, true)
            local funcWordStart = body:find('function', eqPos + 1, true)
            local parenStart = body:find('(', funcWordStart, true)
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
                    local q = c
                    j = j + 1
                    while j <= n and body:sub(j, j) ~= q do
                        j = j + 1
                    end
                    j = j + 1
                else
                    j = j + 1
                end
            end
            local params = body:sub(parenStart + 1, j - 1)
            local funcBodyStart = j + 1
            local braceDepth = 0
            local k = funcBodyStart
            while k <= n do
                local c = body:sub(k, k)
                if c == '"' or c == "'" then
                    local q = c
                    k = k + 1
                    while k <= n and body:sub(k, k) ~= q do
                        k = k + 1
                    end
                    k = k + 1
                elseif c == '-' and k < n and body:sub(k + 1, k + 1) == '-' then
                    while k <= n and body:sub(k, k) ~= '\n' do
                        k = k + 1
                    end
                elseif c == '{' then
                    braceDepth = braceDepth + 1
                    k = k + 1
                elseif c == '}' then
                    braceDepth = braceDepth - 1
                    if braceDepth < 0 then
                        k = k + 1
                        break
                    end
                    k = k + 1
                elseif braceDepth == 0 then
                    local kw_end = body:sub(k, k + 2)
                    if kw_end == 'end' then
                        local before = k > 1 and body:sub(k - 1, k - 1) or ' '
                        local after_ch = k + 3 <= n and body:sub(k + 3, k + 3) or ' '
                        if (before == ' ' or before == '\n' or before == '\t' or before == ';') and
                           (after_ch == ' ' or after_ch == '\n' or after_ch == '\t' or after_ch == ';' or after_ch == ',' or after_ch == '}' or after_ch == '') then
                            break
                        end
                    end
                    k = k + 1
                else
                    k = k + 1
                end
            end
            local funcBody = body:sub(funcBodyStart, k - 1)
            methods[#methods + 1] = {
                name = name,
                params = params,
                body = funcBody,
                docs = commentLines,
            }
            i = k + 3
        else
            i = i + #name + 1 + #after
        end
    end
    return methods
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

    while pos <= n do
        local c = text:sub(pos, pos)
        if c == '{' then
            local braceEnd = findBraceEnd(text, pos)
            if not braceEnd then return nil end
            return iname, startPos, braceEnd
        elseif c == '\n' or c == ';' then
            return iname, startPos, pos - 1
        elseif c == '-' and pos < n and text:sub(pos + 1, pos + 1) == '-' then
            while pos <= n and text:sub(pos, pos) ~= '\n' do
                pos = pos + 1
            end
            return iname, startPos, pos - 1
        else
            pos = pos + 1
        end
    end

    return iname, startPos, n
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
            local iname, iStart, iEnd = parseInterfaceBlock(text, nextPos)
            if not iname then
                pos = nextPos + 9
            else
                local annotation = iname .. ' = {__iname="' .. iname .. '"} ---@class interface.' .. iname .. ' : interface'
                diffs[#diffs + 1] = {
                    start  = iEnd + 1,
                    finish = iEnd,
                    text   = '\n' .. annotation,
                }
                pos = iEnd + 1
            end
        else
            local className, parentName, classStart, classEnd, body = parseClassBlock(text, nextPos)
            if not className then
                pos = nextPos + 5
            else
                local methods = parseMethods(body)
                local parent = parentName or 'object'
                local out = {}
                out[#out + 1] = '---@class ' .. className .. ' : ' .. parent
                out[#out + 1] = '---@operator call:' .. className
                out[#out + 1] = className .. ' = {}'
                local initMethod = nil
                for _, m in ipairs(methods) do
                    if m.name == '__init' then initMethod = m end
                end
                if initMethod then
                    local paramStr = stripFirstParam(initMethod.params)
                    for _, docLine in ipairs(initMethod.docs) do
                        out[#out + 1] = docLine
                    end
                    out[#out + 1] = '---@diagnostic disable-next-line: unused-local'
                    out[#out + 1] = 'function ' .. className .. ':new(' .. paramStr .. ')return self end'
                else
                    out[#out + 1] = 'function ' .. className .. ':new()return self end'
                end
                for _, m in ipairs(methods) do
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

function OnTransformAst(uri, ast)
    local classes = {}
    local function walkClasses(node)
        if not node or type(node) ~= 'table' then return end
        local callNode
        if node.type == 'call' then
            callNode = node.node
            if callNode and callNode[1] == 'class' then
                local args = node.args
                if args and #args >= 2 then
                    local nameNode = args[1]
                    if nameNode and (nameNode.type == 'string' or nameNode.type == 'name') then
                        local className = nameNode[1]
                        local tableNode = args[2]
                        if tableNode and tableNode.type == 'table' then
                            classes[#classes + 1] = {
                                className = className,
                                tableNode = tableNode,
                            }
                        end
                    end
                end
            end
        end
        for idx = 1, #node do
            local child = node[idx]
            if type(child) == 'table' and child ~= node and child ~= callNode then
                walkClasses(child)
            end
        end
    end
    walkClasses(ast)
    if #classes == 0 then return end

    for _, cls in ipairs(classes) do
        local className = cls.className
        local tbl = cls.tableNode
        for idx = 1, #tbl do
            local field = tbl[idx]
            if field and field.type == 'tablefield' then
                local funcNode = field.value
                if funcNode and funcNode.type == 'function' then
                    local paramsNode = funcNode.args
                    if paramsNode and #paramsNode >= 1 then
                        local firstParam = paramsNode[1]
                        if firstParam and firstParam[1] == 'self' then
                            firstParam.type = 'self'

                            local classRefNode = {
                                type = 'getglobal',
                                [1] = className,
                            }
                            field._origType = field.type
                            field.type = 'setfield'
                            field.node = classRefNode

                            local paramPos = firstParam.start or 0
                            local typeNameNode = {
                                type   = 'doc.type.name',
                                [1]    = className,
                                start  = paramPos,
                                finish = paramPos,
                            }
                            local extendsNode = {
                                type   = 'doc.type',
                                start  = paramPos,
                                finish = paramPos,
                                types  = { typeNameNode },
                            }
                            local docParamNameNode = {
                                type   = 'doc.param.name',
                                [1]    = 'self',
                                start  = paramPos,
                                finish = paramPos,
                            }
                            local docParamNode = {
                                type        = 'doc.param',
                                param       = docParamNameNode,
                                extends     = extendsNode,
                                start       = paramPos,
                                finish      = paramPos,
                                firstFinish = paramPos,
                            }
                            if not firstParam.bindDocs then
                                firstParam.bindDocs = {}
                            end
                            firstParam.bindDocs[#firstParam.bindDocs + 1] = docParamNode
                            if not funcNode.bindDocs then
                                funcNode.bindDocs = {}
                            end
                            funcNode.bindDocs[#funcNode.bindDocs + 1] = docParamNode
                        end
                    end
                end
            end
        end
    end
end