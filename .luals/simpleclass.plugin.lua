---@class diff
---@field start  integer
---@field finish integer
---@field text   string

-- ===== 词法助手：统一处理 Lua 字符串 / 长字符串 / 注释，避免手写扫描被转义和长括号干扰 =====

-- 跳过一段短字符串（含 \ 转义）。i 指向开引号 " 或 '，返回闭引号后的位置
local function skipShortString(text, i)
    local n = #text
    local q = text:sub(i, i)
    i = i + 1
    while i <= n do
        local c = text:sub(i, i)
        if c == '\\' then
            i = i + 2
        elseif c == q then
            return i + 1
        else
            i = i + 1
        end
    end
    return n + 1
end

-- 若 text 从 pos 起是长括号 `[[` 或 `[=[`，跳到其闭合 `]]`/`]=]` 之后；否则返回 nil
local function skipLongBracket(text, pos)
    local n = #text
    if text:sub(pos, pos) ~= '[' then return nil end
    local eq = 0
    local j = pos + 1
    while j <= n and text:sub(j, j) == '=' do eq = eq + 1; j = j + 1 end
    if j > n or text:sub(j, j) ~= '[' then return nil end
    local close = ']' .. string.rep('=', eq) .. ']'
    local idx = text:find(close, j + 1, true)
    if idx then return idx + #close end
    return n + 1
end

-- 跳过注释：`--[[...]]` 块注释或 `--...` 行注释。i 指向 '-'，返回注释结束后的位置
local function skipComment(text, i)
    local n = #text
    local after = i + 2
    if after <= n and text:sub(after, after) == '[' then
        local e = skipLongBracket(text, after)
        if e then return e end
    end
    local j = i
    while j <= n and text:sub(j, j) ~= '\n' do
        j = j + 1
    end
    return j
end

local function findBraceEnd(text, startPos)
    local depth = 0
    local n = #text
    local i = startPos
    while i <= n do
        local c = text:sub(i, i)
        if c == '"' or c == "'" then
            i = skipShortString(text, i)
        elseif c == '[' and (text:sub(i + 1, i + 1) == '[' or text:sub(i + 1, i + 1) == '=') then
            local e = skipLongBracket(text, i)
            i = e or (i + 1)
        elseif c == '-' and text:sub(i + 1, i + 1) == '-' then
            i = skipComment(text, i)
        elseif c == '{' then
            depth = depth + 1
            i = i + 1
        elseif c == '}' then
            depth = depth - 1
            if depth == 0 then
                return i
            end
            i = i + 1
        else
            i = i + 1
        end
    end
    return nil
end

-- 若 collect 提供，则把类体表层出现的单行 `---@field ...` 注释收集为类字段声明（透传至 ---@class 块）
local function skipCommentsAndWhitespace(body, i, collect)
    local n = #body
    while i <= n do
        local c = body:sub(i, i)
        if c:match('%s') or c == ';' or c == ',' then
            i = i + 1
        elseif c == '-' and body:sub(i + 1, i + 1) == '-' then
            if collect then
                local cl = body:sub(i)
                local ce = cl:find('\n', 1, true) or (#cl + 1)
                local lineTxt = (cl:sub(1, ce - 1)):gsub('^%s+', '')
                if lineTxt:match('^%-%-%-@field') then
                    collect[#collect + 1] = lineTxt
                end
            end
            i = skipComment(body, i)
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
    return className, parentName, implementsList, startPos, braceEnd, text:sub(braceStart + 1, braceEnd - 1), braceStart
end

local function isWordBoundary(body, pos, n)
    if pos <= 1 or pos > n then return true end
    local c = body:sub(pos, pos)
    return not c:match('[%w_]')
end

-- 找字段值的结束位置：跳过字符串/注释/嵌套括号，返回顶层 `;` 或换行（depth==0）处的下标。
-- 用于支持跨行 table/表达式作为字段值（否则单行截断会切错类体）。
local function findFieldEnd(body, start)
    local n = #body
    local i = start
    local depth = 0
    while i <= n do
        local c = body:sub(i, i)
        if c == '"' or c == "'" then
            i = skipShortString(body, i)
        elseif c == '[' and (body:sub(i + 1, i + 1) == '[' or body:sub(i + 1, i + 1) == '=') then
            local e = skipLongBracket(body, i)
            i = e or (i + 1)
        elseif c == '-' and body:sub(i + 1, i + 1) == '-' then
            i = skipComment(body, i)
        elseif c == '{' or c == '(' or c == '[' then
            depth = depth + 1; i = i + 1
        elseif c == '}' or c == ')' or c == ']' then
            if depth > 0 then depth = depth - 1 end; i = i + 1
        elseif (c == '\n' or c == ';') and depth == 0 then
            return i
        else
            i = i + 1
        end
    end
    return n + 1
end

local function parseMethods(body)
    local methods = {}
    local fields = {}
    local declareFields = {}
    local n = #body
    local i = 1
    while i <= n do
        i = skipCommentsAndWhitespace(body, i, declareFields)
        if i > n then break end

        local name, afterFieldStart
        do
            local n1, p1 = body:match('^([%w_]+)%s*=%s*()', i)
            local n2, p2 = body:match("^%['([^']+)'%]%s*=%s*()", i)
            local n3, p3 = body:match('^%["([^"]+)"%]%s*=%s*()', i)
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
                local tline = line:gsub('^%s+', '')
                if tline:match('^%-%-%-@field') then
                    -- ---@field 已被前进扫描收集为类字段声明，不再挂到方法/字段的 docs 上
                elseif line:match('^%s*---') then
                    table.insert(commentLines, 1, tline)
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
                    j = skipShortString(body, j)
                elseif c == '[' and (body:sub(j + 1, j + 1) == '[' or body:sub(j + 1, j + 1) == '=') then
                    local e = skipLongBracket(body, j)
                    j = e or (j + 1)
                elseif c == '-' and body:sub(j + 1, j + 1) == '-' then
                    j = skipComment(body, j)
                else
                    j = j + 1
                end
            end
            local params = body:sub(parenStart + 1, j - 1)
            local funcBodyStart = j + 1

            -- 方法体深度匹配：`function/if/for/while/repeat/do` 开块，`end` 关块，`repeat...until` 特判
            -- 独立 `do`（非 while/for 尾部）也会开块，避免 `do return end` 提前截断方法体
            local depth = 1
            local lastKw = ''
            local k = funcBodyStart
            while k <= n and depth > 0 do
                local c = body:sub(k, k)
                if c == '"' or c == "'" then
                    k = skipShortString(body, k)
                elseif c == '[' and (body:sub(k + 1, k + 1) == '[' or body:sub(k + 1, k + 1) == '=') then
                    local e = skipLongBracket(body, k)
                    k = e or (k + 1)
                elseif c == '-' and body:sub(k + 1, k + 1) == '-' then
                    k = skipComment(body, k)
                else
                    if isWordBoundary(body, k - 1, n) then
                        if body:sub(k, k + 7) == 'function' and isWordBoundary(body, k + 8, n) then
                            depth = depth + 1; lastKw = 'function'; k = k + 8
                        elseif body:sub(k, k + 1) == 'if' and isWordBoundary(body, k + 2, n) then
                            depth = depth + 1; lastKw = 'if'; k = k + 2
                        elseif body:sub(k, k + 2) == 'for' and isWordBoundary(body, k + 3, n) then
                            depth = depth + 1; lastKw = 'for'; k = k + 3
                        elseif body:sub(k, k + 4) == 'while' and isWordBoundary(body, k + 5, n) then
                            depth = depth + 1; lastKw = 'while'; k = k + 5
                        elseif body:sub(k, k + 5) == 'repeat' and isWordBoundary(body, k + 6, n) then
                            depth = depth + 1; lastKw = 'repeat'; k = k + 6
                        elseif body:sub(k, k + 1) == 'do' and isWordBoundary(body, k + 2, n) then
                            -- while/for 尾部的 do 已由 while/for 计了一次，这里不能再加
                            if lastKw ~= 'while' and lastKw ~= 'for' then depth = depth + 1 end
                            lastKw = 'do'; k = k + 2
                        elseif body:sub(k, k + 3) == 'then' and isWordBoundary(body, k + 4, n) then
                            lastKw = 'then'; k = k + 4
                        elseif body:sub(k, k + 4) == 'until' and isWordBoundary(body, k + 5, n) then
                            depth = depth - 1; lastKw = 'until'
                            if depth == 0 then k = k + 5; break end
                            k = k + 5
                        elseif body:sub(k, k + 2) == 'end' and isWordBoundary(body, k + 3, n) then
                            depth = depth - 1; lastKw = 'end'
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
                -- body 内"方法签名右括号之后"的位置（相对 body），用于插入 super 遮蔽
                sigEnd = j + 1,
            }
            i = k
        else
            fields[#fields + 1] = {
                name = name,
                docs = commentLines,
                isGetter = isGetter,
                isSetter = isSetter,
            }
            i = findFieldEnd(body, afterFieldStart)
        end
    end
    return methods, fields, declareFields
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
            local isInStringOrComment = false
            local scanPos = pos
            while scanPos < cstart do
                local sc = text:sub(scanPos, scanPos)
                if sc == '"' or sc == "'" then
                    local q = sc
                    scanPos = scanPos + 1
                    while scanPos <= n and text:sub(scanPos, scanPos) ~= q do
                        if text:sub(scanPos, scanPos) == '\n' then
                            break
                        end
                        scanPos = scanPos + 1
                    end
                    if scanPos >= cstart then
                        isInStringOrComment = true
                        break
                    end
                    scanPos = scanPos + 1
                elseif sc == '-' and scanPos < n and text:sub(scanPos + 1, scanPos + 1) == '-' then
                    while scanPos <= n and text:sub(scanPos, scanPos) ~= '\n' do
                        scanPos = scanPos + 1
                    end
                    if scanPos >= cstart then
                        isInStringOrComment = true
                        break
                    end
                elseif sc == '[' and scanPos < n and text:sub(scanPos + 1, scanPos + 1) == '[' then
                    scanPos = scanPos + 2
                    while scanPos <= n and text:sub(scanPos, scanPos + 1) ~= ']]' do
                        scanPos = scanPos + 1
                    end
                    if scanPos >= cstart then
                        isInStringOrComment = true
                        break
                    end
                    scanPos = scanPos + 2
                else
                    scanPos = scanPos + 1
                end
            end
            if not isInStringOrComment then
                local afterStart = cstart + 5
                local restStart = afterStart
                while restStart <= n and text:sub(restStart, restStart):match('%s') do
                    restStart = restStart + 1
                end
                if restStart <= n and text:sub(restStart, restStart) == '"' then
                    return cstart
                end
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
            local isInStringOrComment = false
            local scanPos = pos
            while scanPos < cstart do
                local sc = text:sub(scanPos, scanPos)
                if sc == '"' or sc == "'" then
                    local q = sc
                    scanPos = scanPos + 1
                    while scanPos <= n and text:sub(scanPos, scanPos) ~= q do
                        if text:sub(scanPos, scanPos) == '\n' then
                            break
                        end
                        scanPos = scanPos + 1
                    end
                    if scanPos >= cstart then
                        isInStringOrComment = true
                        break
                    end
                    scanPos = scanPos + 1
                elseif sc == '-' and scanPos < n and text:sub(scanPos + 1, scanPos + 1) == '-' then
                    while scanPos <= n and text:sub(scanPos, scanPos) ~= '\n' do
                        scanPos = scanPos + 1
                    end
                    if scanPos >= cstart then
                        isInStringOrComment = true
                        break
                    end
                elseif sc == '[' and scanPos < n and text:sub(scanPos + 1, scanPos + 1) == '[' then
                    scanPos = scanPos + 2
                    while scanPos <= n and text:sub(scanPos, scanPos + 1) ~= ']]' do
                        scanPos = scanPos + 1
                    end
                    if scanPos >= cstart then
                        isInStringOrComment = true
                        break
                    end
                    scanPos = scanPos + 2
                else
                    scanPos = scanPos + 1
                end
            end
            if not isInStringOrComment then
                local afterStart = cstart + 9
                local restStart = afterStart
                while restStart <= n and text:sub(restStart, restStart):match('%s') do
                    restStart = restStart + 1
                end
                if restStart <= n and text:sub(restStart, restStart) == '"' then
                    return cstart
                end
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

-- 类体元方法键 → LuaLS 支持的 @operator 操作符名（仅算术 / .. / len / unm / call 支持）
-- eq/lt/le/tostring 无对应操作符；__call 与构造器 call 冲突故跳过
local PL_OP_FROM_META = {
    __add = 'add', __sub = 'sub', __mul = 'mul', __div = 'div', __mod = 'mod',
    __pow = 'pow', __idiv = 'idiv', __band = 'band', __bor = 'bor', __bxor = 'bxor',
    __shl = 'shl', __shr = 'shr', __concat = 'concat', __unm = 'unm',
    __bnot = 'bnot', __len = 'len',
}

-- 从参数列表字符串提取参数名（含 self）
local function pl_paramNames(params)
    local names = {}
    for p in (params or ''):gmatch('[%w_]+') do
        names[#names + 1] = p
    end
    return names
end

-- 从某方法的 docs 注解中返回 `@return <type>`，无则 nil
local function pl_methodReturn(docs)
    for _, dl in ipairs(docs or {}) do
        local ret = dl:match('^%-%-%-@return%s+([%S]+)')
        if ret then return ret end
    end
    return nil
end

-- 若除首参外所有参数都已标注 `@param <名> <类型>`，返回第 2 参数类型（二元操作符操作数）
local function pl_operatorOperand(docs, params)
    local names = pl_paramNames(params)
    if #names < 2 then return nil end
    local typeOf = {}
    for _, dl in ipairs(docs or {}) do
        local pn, pt = dl:match('^%-%-%-@param%s+([%w_]+)%s+([%S]+)')
        if pn and pt then typeOf[pn] = pt end
    end
    for i = 2, #names do
        if not typeOf[names[i]] then return nil end
    end
    return typeOf[names[2]]
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
                out[#out + 1] = iname .. ' = {__iname="' .. iname .. '"} ---@class I.' .. iname .. ' : interface'
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
            local className, parentName, implementsList, classStart, classEnd, body, braceStart = parseClassBlock(text, nextPos)
            if not className then
                pos = nextPos + 5
            else
                local methods, fields, declareFields = parseMethods(body)
                local parent = parentName or 'object'
                local out = {}
                local classLine = '---@class ' .. className .. ' : ' .. parent
                if #implementsList > 0 then
                    classLine = classLine .. ', ' .. table.concat(implementsList, ', ')
                end
                out[#out + 1] = classLine
                -- 表表层手写的 ---@field 透传到 ---@class 下的连续注释行，声明未在 __init 赋值的字段
                for _, df in ipairs(declareFields) do
                    out[#out + 1] = df
                end
                out[#out + 1] = '---@field __class ' .. className
                out[#out + 1] = '---@field __base ' .. parent
                out[#out + 1] = '---@operator call:' .. className
                -- 元方法 → @operator 标注（元方法带 @return 才生成；参数全标注则附操作数类型）
                for _, m in ipairs(methods) do
                    local opName = PL_OP_FROM_META[m.name]
                    if opName then
                        -- 用户已在元方法上方手写 ---@operator → 原样透传，跳过自动重构
                        local hadUserOp = false
                        for _, dl in ipairs(m.docs or {}) do
                            local userOp = dl:match('^%-%-%-@operator%s+(.+)')
                            if userOp then
                                out[#out + 1] = '---@operator ' .. userOp
                                hadUserOp = true
                            end
                        end
                        if not hadUserOp then
                            local ret = pl_methodReturn(m.docs)
                            if ret then
                                if m.name == '__len' or #pl_paramNames(m.params) < 2 then
                                    out[#out + 1] = '---@operator ' .. opName .. ': ' .. ret
                                else
                                    local operand = pl_operatorOperand(m.docs, m.params)
                                    if operand then
                                        out[#out + 1] = ('---@operator %s(%s): %s'):format(opName, operand, ret)
                                    else
                                        out[#out + 1] = '---@operator ' .. opName .. ': ' .. ret
                                    end
                                end
                            end
                        end
                    end
                end
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

                -- 方法体已由 OnTransformAst 自注入在原始代码处完成了字段/类型检查，
                -- 重发的副本仅用于登记方法签名与返回类型，其 body 诊断会与原始重复，
                -- 故在此作用域内关闭 body 级诊断，避免重复报警（enable 在重发区末尾恢复）。
                out[#out + 1] = '---@diagnostic disable: undefined-field'

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
                out[#out + 1] = '---@diagnostic enable: undefined-field'

                if #declareFields > 0 then
                    -- 原始类体里的 ---@field（其前无 ---@class）会触发 doc-field-no-class。
                    -- 在此（表体开始处）禁用，到生成的类注解块前再启用，仅覆盖这一小段。
                    diffs[#diffs + 1] = {
                        start  = braceStart + 1,
                        finish = braceStart,
                        text   = '---@diagnostic disable: doc-field-no-class\n',
                    }
                    out[#out + 1] = '---@diagnostic enable: doc-field-no-class'
                end

                -- @override 检查：标注 ---@override 的方法（new 除外）须在基类上确有同名方法。
                -- 用父类类型访问这些名字，基类无同名方法则触发 undefined-field。
                local overrideNames = {}
                local seenOv = {}
                for _, m in ipairs(methods) do
                    if m.isOverride and m.name ~= 'new' and not seenOv[m.name] then
                        seenOv[m.name] = true
                        overrideNames[#overrideNames + 1] = m.name
                    end
                end
                table.sort(overrideNames)
                if #overrideNames > 0 and parentName then
                    out[#out + 1] = '---@diagnostic disable-next-line: unused-function, unused-local, redefined-local'
                    out[#out + 1] = 'local function __ls_override_check__()'
                    out[#out + 1] = '    ---@class ' .. parentName
                    out[#out + 1] = '    local _ = {}'
                    out[#out + 1] = '    local override_method'
                    for _, nm in ipairs(overrideNames) do
                        out[#out + 1] = '    override_method = _.' .. nm
                    end
                    out[#out + 1] = '    return override_method'
                    out[#out + 1] = 'end'
                end

                diffs[#diffs + 1] = {
                    start  = classEnd + 1,
                    finish = classEnd,
                    text   = '\n' .. table.concat(out, '\n'),
                }

                -- 直接在用到 super 的方法内注入局部 `super`（返回基类类型），把 `super(Child, self)` 的
                -- 接收者锚定为基类。位置取方法签名右括号之后、同行末尾，零宽度插入不改变行号。
                local baseName = parentName or 'object'
                for _, m in ipairs(methods) do
                    if m.sigEnd and m.body and m.body:find('super%s*%(') then
                        -- body[i] 对应 text[braceStart+i]；右括号在 body[sigEnd-1]，越过即 braceStart+sigEnd
                        local at = braceStart + m.sigEnd
                        diffs[#diffs + 1] = {
                            start  = at,
                            finish = at - 1,
                            text   = ' local function super(_, _)return ' .. baseName .. ' end',
                        }
                    end
                end
                pos = classEnd + 1
            end
        end
    end

    if #diffs == 0 then return nil end
    return diffs
end

-- ==================================== OnTransformAst 自注入 ====================================
-- 通过 luadoc.buildAndBindDoc 把原始 DSL 方法体里的 self 参数绑定为类类型。
-- 目的：让编辑器对原始 `foo = function(self)` 中的 self 悬停出类型，并参与 field 检查。
-- 这与 OnSetText 的"方法体重发"互补（后者只类型化重发副本，不作用于原始 self）。
-- markVirtual 标记保证不污染高亮。
-- 注：parser.luadoc / parser.guide 是 LuaLS 内部模块，用 pcall + ok_ 兜底，缺省时静默降级。

local ok_luadoc, luadoc = pcall(require, 'parser.luadoc')
local ok_guide,  guide  = pcall(require, 'parser.guide')

---构造一个虚拟的短注释节点
---@param t string   注释标签，如 "param"
---@param value string 注释内容
---@param pos integer
---@return table
local function pl_buildComment(t, value, pos)
    return {
        type    = 'comment.short',
        start   = pos,
        finish  = pos,
        text    = '-@' .. t .. ' ' .. value,
        virtual = true,
    }
end

---沿 callee 链向上解析 class 调用，取回类名（即 `class "Name"` 中的 Name）
---@param outerCall table 外层 call 节点
---@return string?
local function pl_getClassName(outerCall)
    local callee = outerCall and outerCall.node
    while callee do
        if callee.type == 'call' then
            -- class 既可以是全局（全局导入），也可能是手动 `local class = ...` 的局部变量（非全局导入）。
            -- README 约定非全局导入须使函数名与全局导入一致，故这里对 getglobal/getlocal 名 'class' 一并识别。
            if callee.node
            and (callee.node.type == 'getglobal' or callee.node.type == 'getlocal')
            and guide.getKeyName(callee.node) == 'class' then
                local nameNode = callee.args and callee.args[1]
                if nameNode and nameNode.type == 'string' then
                    return guide.getLiteral(nameNode)
                end
                return nil
            end
            callee = callee.node
        elseif callee.type == 'getmethod' then
            callee = callee.node
        else
            callee = nil
        end
    end
    return nil
end

---遍历类体 table，给每个方法的 self 参数绑定 `@param self <类名>`
---@param ast table  AST 根
---@param classname string
---@param tableNode table 类体 table 节点
local function pl_injectSelf(ast, classname, tableNode)
    if not tableNode or tableNode.type ~= 'table' then
        return
    end
    for i = 1, #tableNode do
        local field = tableNode[i]
        local value = field and field.value
        if value and value.type == 'function' and value.args then
            for j = 1, #value.args do
                local p = value.args[j]
                if guide.getKeyName(p) == 'self' then
                    luadoc.buildAndBindDoc(
                        ast, value,
                        pl_buildComment('param', ('self %s'):format(classname), p.start - 1))
                    break
                end
            end
        end
    end
end

---LS 插件回调：在 luadoc 解析前改写 AST，注入自绑定
---@param uri string
---@param ast table
---@return table
function OnTransformAst(uri, ast)
    if ok_luadoc and ok_guide and type(ast) == 'table' and ast.type == 'main' then
        guide.eachSource(ast, function(node)
            if node.type == 'call' and node.args then
                local classname = pl_getClassName(node)
                if classname then
                    for _, a in ipairs(node.args) do
                        if a.type == 'table' then
                            pl_injectSelf(ast, classname, a)
                        end
                    end
                end
            end
        end)
    end
    return ast
end
