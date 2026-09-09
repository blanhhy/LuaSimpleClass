local function prequire(m)
    local ok, ret = pcall(require, m)
    ok = ok and ret ~= nil
    return ok, ret
end

local ok_vm,     vm     = prequire 'vm'
local ok_files,  files  = prequire 'files'
local ok_guide,  guide  = prequire 'parser.guide'
local ok_luadoc, luadoc = prequire 'parser.luadoc'
local ok_define, define = prequire 'proto.define'
local ok_diag,   diag   = prequire 'proto.diagnostic'

-- 需要应用的补丁
local ENABLE_PATCHES = {
    'overload_dispatch';
}

-- 插件级状态，跨阶段、跨文件记录工作区信息
local __sc_implpos = {}
local __sc_overridepos = {}
local __sc_classmeta = {}

-- These names are exported by the simpleclass module.  A file opting into
-- local-import checking must bind them locally before using them bare.
local SC_IMPORT_APIS = {
    class = true,
    super = true,
    interface = true,
    object = true,
    isinstance = true,
    issubclass = true,
    type = true,
    env_import = true,
    AUTO_GLOBAL = true,
    I_FEATURE = true,
}

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
    local impKwStart, impFin
    if impStart then
        -- implements 关键字起点（跳过冒号与空白），供诊断定位到原始 implements(...) 块
        local k = impStart + 1
        while text:sub(k, k):match('%s') do k = k + 1 end
        impKwStart = k
        pos = impEnd + 1
        while pos <= n do
            local c = text:sub(pos, pos)
            if c == ')' then
                impFin = pos
                break
            elseif c == '-' and text:sub(pos + 1, pos + 1) == '-' then
                pos = skipComment(text, pos)
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
    return className, parentName, implementsList, startPos, braceEnd, text:sub(braceStart + 1, braceEnd - 1), braceStart, impKwStart, impFin
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

-- Find the closing parenthesis of a call while ignoring strings and comments.
local function findMatchingParen(text, open)
    local depth = 1
    local i = open + 1
    while i <= #text do
        local c = text:sub(i, i)
        if c == '"' or c == "'" then
            i = skipShortString(text, i)
        elseif c == '[' then
            local e = skipLongBracket(text, i)
            i = e or (i + 1)
        elseif c == '-' and text:sub(i + 1, i + 1) == '-' then
            i = skipComment(text, i)
        elseif c == '(' then
            depth = depth + 1
            i = i + 1
        elseif c == ')' then
            depth = depth - 1
            if depth == 0 then return i end
            i = i + 1
        else
            i = i + 1
        end
    end
    return nil
end

local function getFirstParamName(params)
    return params:match('^%s*([%w_]+)')
end

-- All Lua metamethods are listed here. An empty value means that LuaLS has
-- no matching @operator spelling, but the method is still a meta method.
local PL_OP_FROM_META = {
    __add = 'add', __sub = 'sub', __mul = 'mul', __div = 'div', __mod = 'mod',
    __pow = 'pow', __idiv = 'idiv', __band = 'band', __bor = 'bor', __bxor = 'bxor',
    __shl = 'shl', __shr = 'shr', __concat = 'concat', __unm = 'unm',
    __bnot = 'bnot', __len = 'len', __call = 'call',
    __eq = '', __lt = '', __le = '', __tostring = '', __index = '',
    __newindex = '', __gc = '', __mode = '', __metatable = '', __name = '',
    __pairs = '', __ipairs = '', __close = '',
}

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
        local nameStart, nameFinish
        do
            local n1, p1 = body:match('^([%w_]+)%s*=%s*()', i)
            local n2, p2 = body:match("^%['([^']+)'%]%s*=%s*()", i)
            local n3, p3 = body:match('^%["([^"]+)"%]%s*=%s*()', i)
            if n1 then
                name = n1; afterFieldStart = p1
                nameStart = i; nameFinish = i + #n1 - 1
            elseif n2 then
                name = n2; afterFieldStart = p2
                nameStart = i + 2; nameFinish = nameStart + #n2 - 1
            elseif n3 then
                name = n3; afterFieldStart = p3
                nameStart = i + 2; nameFinish = nameStart + #n3 - 1
            end
        end
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

            local getterName = name:match('^get%.(.+)$')
            local setterName = name:match('^set%.(.+)$')
            local isGetter = getterName ~= nil
            local isSetter = setterName ~= nil
            name = isGetter and getterName
                or isSetter and setterName
                or name

            local operatorName = PL_OP_FROM_META[name]
            local first = getFirstParamName(params)
            local isStatic   = false
            local isOverride = false
            for _, line in ipairs(commentLines) do
                if line:match('^%-%-%-@[Ss]tatic') then
                    isStatic = true
                end
                if line:match('^%-%-%-@[Oo]verride') then
                    isOverride = true
                end
            end

            local kind
            if name == 'new'            then kind = 'new'
            elseif name == '__init'     then kind = 'init'
            elseif operatorName ~= nil  then kind = 'meta'
            elseif isGetter             then kind = 'getter'
            elseif isSetter             then kind = 'setter'
            elseif isStatic and (
                first == 'cls' or
                first == 'self' )       then kind = 'class'
            elseif isStatic             then kind = 'static'
                                        else kind = 'instance'
            end

            local funcBody = body:sub(funcBodyStart, k - 4)
            methods[#methods + 1] = {
                name = name,
                params = params,
                body = funcBody,
                docs = commentLines,
                kind = kind,
                operatorName = operatorName,
                isMeta = kind == 'meta',
                isStatic = isStatic,
                isProperty = kind == 'getter' or kind == 'setter',
                isOverride = isOverride,
                sourceStart = nameStart,
                sourceFinish = nameFinish,
                -- body 内"方法签名右括号之后"的位置（相对 body），用于插入 super 遮蔽
                sigEnd = j + 1,
            }
            i = k
        else
            local fieldEnd = findFieldEnd(body, afterFieldStart)
            local fieldValue = (body:sub(afterFieldStart, fieldEnd - 1)):gsub('^%s+', ''):gsub('%s+$', '')
            fields[#fields + 1] = {
                name = name,
                value = fieldValue,
                docs = commentLines,
            }
            i = fieldEnd
        end
    end
    return methods, fields, declareFields
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
        -- 方法体会被重新拼接到 diff 文本中，不能把原始行尾空白带入生成代码。
        local cleanLine = line:gsub('%s+$', '')
        if not cleanLine:match('^%s*$') then
            lines[#lines + 1] = cleanLine
        end
    end
    if #lines == 0 then return '' end
    return table.concat(lines, '\n')
end

local function findDslKeyword(text, from, keyword)
    local n = #text
    local i = from
    while i <= n do
        local c = text:sub(i, i)
        if c == '"' or c == "'" then
            i = skipShortString(text, i)
        elseif c == '[' then
            local e = skipLongBracket(text, i)
            i = e or (i + 1)
        elseif c == '-' and text:sub(i + 1, i + 1) == '-' then
            i = skipComment(text, i)
        elseif text:sub(i, i + #keyword - 1) == keyword then
            local before = i > 1 and text:sub(i - 1, i - 1) or '\n'
            local afterStart = i + #keyword
            local restStart = afterStart
            while restStart <= n and text:sub(restStart, restStart):match('%s') do
                restStart = restStart + 1
            end
            if not before:match('[%w_.]')
                and restStart <= n
                and text:sub(restStart, restStart) == '"' then
                return i
            end
            i = i + #keyword
        else
            i = i + 1
        end
    end
    return nil
end

local function findClassKeyword(text, from)
    return findDslKeyword(text, from, 'class')
end

local function findInterfaceKeyword(text, from)
    return findDslKeyword(text, from, 'interface')
end

-- Interface bodies are a flat list of string members. Only collect literals at
-- the body root; strings inside comments, long strings, or nested expressions
-- are data and must not become interface requirements.
local function collectInterfaceFields(body)
    local fields = {}
    local round, curly, square = 0, 0, 0
    local i = 1
    while i <= #body do
        local c = body:sub(i, i)
        if c == '"' or c == "'" then
            local e = skipShortString(body, i)
            if round == 0 and curly == 0 and square == 0 and e > i + 1 then
                fields[#fields + 1] = body:sub(i + 1, e - 2)
            end
            i = e
        elseif c == '[' then
            local e = skipLongBracket(body, i)
            if e then
                i = e
            else
                square = square + 1
                i = i + 1
            end
        elseif c == '-' and body:sub(i + 1, i + 1) == '-' then
            i = skipComment(body, i)
        elseif c == '(' then
            round = round + 1
            i = i + 1
        elseif c == ')' then
            if round > 0 then round = round - 1 end
            i = i + 1
        elseif c == '{' then
            curly = curly + 1
            i = i + 1
        elseif c == '}' then
            if curly > 0 then curly = curly - 1 end
            i = i + 1
        elseif c == ']' then
            if square > 0 then square = square - 1 end
            i = i + 1
        else
            i = i + 1
        end
    end
    return fields
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
            elseif c == '-' and text:sub(pos + 1, pos + 1) == '-' then
                pos = skipComment(text, pos)
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
            fields = collectInterfaceFields(body)
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

-- 从类体字段声明和 getter 返回值建立属性类型索引。
local function pl_fieldTypes(declareFields, methods)
    local types = {}
    for _, line in ipairs(declareFields or {}) do
        local spec = line:match('^%-%-%-@field%s+(.+)$')
        local name, typ
        if spec then
            local first, rest = spec:match('^([%w_]+)%s+(.+)$')
            if first == 'public' or first == 'protected'
                or first == 'private' or first == 'package' then
                name, typ = rest:match('^([%w_]+)%s+(.+)$')
            else
                name, typ = first, rest
            end
        end
        if name and typ then
            types[name] = typ:gsub('%s+$', '')
        end
    end
    for _, method in ipairs(methods or {}) do
        if method.kind == 'getter' and not types[method.name] then
            local ret = pl_methodReturn(method.docs)
            if ret then
                types[method.name] = ret
            else
                local backing = method.body:match('return%s+self%s*%.%s*([%w_]+)')
                if backing and types[backing] then
                    types[method.name] = types[backing]
                end
            end
        elseif method.kind == 'setter' and not types[method.name] then
            local backing = method.body:match('self%s*%.%s*([%w_]+)%s*=%s*[%w_]+%f[%W]')
            if backing and types[backing] then
                types[method.name] = types[backing]
            end
        end
    end
    return types
end

local function pl_hasParamDoc(docs, name)
    for _, line in ipairs(docs or {}) do
        local docName = line:match('^%-%-%-@param%s+([%w_]+)%s')
        if docName == name then
            return true
        end
        docName = line:match('^%-%-%-@param%s+([%w_]+)%?%s')
        if docName == name then
            return true
        end
    end
    return false
end

-- 只从单一、直接的字段赋值推导参数，避免把复杂表达式误认为参数类型来源。
local function pl_methodParamTypes(method, fieldTypes)
    local params = pl_paramNames(method.params)
    if #params < 2 then return {} end
    local inferred = method.inferred or {}

    local function add(name, typ)
        if not name or not typ or name == params[1] or pl_hasParamDoc(method.docs, name) then
            return
        end
        if inferred[name] and inferred[name] ~= typ then
            inferred[name] = false
        else
            inferred[name] = typ
        end
    end

    if method.kind == 'setter' then
        -- set.<property> 的属性名已经在 parseMethods 中去掉了 set. 前缀。
        if #params == 2 then
            local typ = fieldTypes[method.name]
            if not typ then
                local backing = method.body:match('self%s*%.%s*([%w_]+)%s*=%s*' .. params[2] .. '%f[%W]')
                typ = backing and fieldTypes[backing]
            end
            add(params[2], typ)
        end
    else
        for field, param in method.body:gmatch('self%s*%.%s*([%w_]+)%s*=%s*([%w_]+)') do
            add(param, fieldTypes[field])
        end
    end

    for name, typ in pairs(inferred) do
        if not typ then inferred[name] = nil end
    end
    return inferred
end

-- 把顶层逗号分隔的参数列表切成字符串表，忽略括号/字符串/长注释/长字符串内的逗号。
-- 起始位置位于 `(` 之后，结束位置在匹配的 `)` 之前。
local function pl_splitCallArgs(body, open, close)
    local args = {}
    local round, curly, square = 0, 0, 0
    local i = open
    local start = open
    while i <= close do
        local c = body:sub(i, i)
        if c == '"' or c == "'" then
            i = skipShortString(body, i)
        elseif c == '[' then
            local e = skipLongBracket(body, i)
            if e then
                i = e
            else
                square = square + 1
                i = i + 1
            end
        elseif c == '-' and body:sub(i + 1, i + 1) == '-' then
            i = skipComment(body, i)
        elseif c == '(' then
            round = round + 1
            i = i + 1
        elseif c == ')' then
            if round > 0 then round = round - 1 end
            i = i + 1
        elseif c == '{' then
            curly = curly + 1
            i = i + 1
        elseif c == '}' then
            if curly > 0 then curly = curly - 1 end
            i = i + 1
        elseif c == ']' then
            if square > 0 then square = square - 1 end
            i = i + 1
        elseif c == ',' and round == 0 and curly == 0 and square == 0 then
            args[#args + 1] = body:sub(start, i - 1)
            start = i + 1
            i = i + 1
        else
            i = i + 1
        end
    end
    if i > start then args[#args + 1] = body:sub(start, close) end
    return args
end

local function pl_isCodePosition(text, target)
    local i = 1
    while i < target do
        local c = text:sub(i, i)
        if c == '"' or c == "'" then
            local e = skipShortString(text, i)
            if e > target then return false end
            i = e
        elseif c == '[' then
            local e = skipLongBracket(text, i)
            if e then
                if e > target then return false end
                i = e
            else
                i = i + 1
            end
        elseif c == '-' and text:sub(i + 1, i + 1) == '-' then
            local e = skipComment(text, i)
            if e > target then return false end
            i = e
        else
            i = i + 1
        end
    end
    return true
end

-- 在 body 中找出对名字 `name` 的调用，并把实参列表表返回，每条以 `parentParamName` 形式追加。
local function pl_collectSuperCalls(body, name)
    local calls = {}
    local i = 1
    while i <= #body do
        -- super(Cls, self):name(args)
        local found, finish = body:find('super%s*%(%s*[%w_]+%s*,%s*self%s*%)%s*:%s*' .. name .. '%s*%(', i)
        if found and pl_isCodePosition(body, found) then
            local close = findMatchingParen(body, finish)
            if close then
                calls[#calls + 1] = pl_splitCallArgs(body, finish + 1, close - 1)
                i = close + 1
            else
                i = finish + 1
            end
        else
            -- Parent.name(self, args...)  或  Parent:name(args)
            found, finish = body:find('[%w_]+%s*%:%s*' .. name .. '%s*%(', i)
            if not found then
                found, finish = body:find('[%w_]+%s*%.%s*' .. name .. '%s*%(%s*self%s*,', i)
            end
            if found and pl_isCodePosition(body, found) then
                local close = findMatchingParen(body, finish)
                if close then
                    local args = pl_splitCallArgs(body, finish + 1, close - 1)
                    -- 对 Parent.name(self, ...) 形式：跳过首个 self 实参
                    local isDotCall = body:sub(finish - 1, finish - 1) == '.'
                    if isDotCall and args[1] and args[1]:match('^%s*self%s*$') then
                        table.remove(args, 1)
                    end
                    calls[#calls + 1] = args
                    i = close + 1
                else
                    i = finish + 1
                end
            else
                i = i + 1
            end
        end
    end
    return calls
end

-- 若子类方法 body 调用了父类同名方法并按位置转发参数，则继承父类参数已知类型。
local function pl_superParamTypes(method, classmeta, allmeta)
    if not classmeta or not classmeta.parent then return {} end
    local params = pl_paramNames(method.params)
    if #params < 2 then return {} end
    local myInferred = method.inferred or {}
    local extra = {}

    local function need(name) return params[1] ~= name and not myInferred[name] and not pl_hasParamDoc(method.docs, name) end

    local function add(name, typ)
        if not name or not typ or not need(name) then return end
        extra[name] = typ
    end

    local calls = pl_collectSuperCalls(method.body or '', method.name)
    if #calls == 0 then return extra end

    local visit, curClass = 0, classmeta
    while curClass and curClass.parent do
        visit = visit + 1
        if visit > 16 then break end
        local parentMeta = allmeta and allmeta[curClass.parent]
        local parentMethod = parentMeta and parentMeta.methods[method.name]
        local parentParamTypes = {}
        if parentMethod then
            for i, pname in ipairs(pl_paramNames(parentMethod.params)) do
                local typ = parentMethod.inferred and parentMethod.inferred[pname]
                if not typ then
                    for _, line in ipairs(parentMethod.docs or {}) do
                        local docName, docType = line:match('^%-%-%-@param%s+([%w_]+)%s+(.+)$')
                        if docName == pname and docType then typ = docType:gsub('%s+$', '') end
                    end
                end
                if typ and i >= 2 then
                    parentParamTypes[i - 1] = typ
                end
            end
        end

        for _, argList in ipairs(calls) do
            for pi, pname in pairs(parentParamTypes) do
                local argText = argList[pi]
                if argText then
                    local argName = argText:match('^%s*([%w_]+)%s*$')
                    if argName then
                        add(argName, pname)
                    end
                end
            end
        end

        curClass = parentMeta
    end

    return extra
end

-- Find the @static annotation in the comment lines
local function pl_isStaticMember(docs)
    for _, line in ipairs(docs or {}) do
        if line:match('^%-%-%-@static') then
            return true
        end
    end
    return false
end

-- Derive class-dependent placement from the classification produced by
-- parseMethods. This function must not reclassify the method.
local function pl_methodInfo(method, classname)
    local kind = method.kind
    local first = getFirstParamName(method.params)
    local isClassOwner = kind == 'new'
        or kind == 'meta'
        or kind == 'class'
        or kind == 'static'
    local ownerType = isClassOwner and (classname .. '.class') or classname
    local receiverType
    if kind == 'new' then
        receiverType = first and (classname .. '.class') or nil
    elseif kind == 'static' then
        receiverType = nil
    elseif kind == 'class' then
        receiverType = classname .. '.class'
    else
        receiverType = first and classname or nil
    end

    return {
        ownerType = ownerType,
        receiverType = receiverType,
        receiverName = first,
        target = isClassOwner and classname or (classname .. '.__proto'),
        usesColon = receiverType == ownerType and first == 'self',
    }
end

local function pl_inferredParamTypes(method, fieldTypes, classmeta, allmeta)
    local inferred = pl_methodParamTypes(method, fieldTypes)
    method.inferred = inferred
    if classmeta and allmeta then
        for name, typ in pairs(pl_superParamTypes(method, classmeta, allmeta)) do
            inferred[name] = typ
        end
    end
    return inferred
end

local function pl_inferredParamDocs(method, fieldTypes, classmeta, allmeta)
    local inferred = pl_inferredParamTypes(method, fieldTypes, classmeta, allmeta)
    local docs = {}
    for _, name in ipairs(pl_paramNames(method.params)) do
        if inferred[name] and not pl_hasParamDoc(method.docs, name) then
            docs[#docs + 1] = ('---@param %s %s'):format(name, inferred[name])
        end
    end
    return docs
end

---@class diff
---@field start  integer
---@field finish integer
---@field text   string

---@param uri  string
---@param text string
---@return diff[]?
function OnSetText(uri, text)
    -- A file may lose its last DSL declaration during reload. Clear the
    -- per-file caches before the early return so old diagnostics cannot leak.
    __sc_implpos[uri] = {}
    __sc_overridepos[uri] = {}
    __sc_classmeta[uri] = {}
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
                if extendsList and #extendsList > 0 then
                    classLine = classLine .. ' : ' .. table.concat(extendsList, ', ')
                else
                    classLine = classLine .. ' : object'
                end
                out[#out + 1] = classLine
                for _, f in ipairs(fields or {}) do
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
            local className, parentName, implementsList, classStart, classEnd, body, braceStart, impKwStart, impFin = parseClassBlock(text, nextPos)
            if not className then
                pos = nextPos + 5
            else
                local methods, fields, declareFields = parseMethods(body)
                local methodMeta = {}
                for _, method in ipairs(methods) do
                    methodMeta[method.name] = method
                end
                __sc_classmeta[uri][className] = {
                    methods = methodMeta,
                    fieldTypes = pl_fieldTypes(declareFields, methods),
                    parent = parentName,
                }
                local classmeta = __sc_classmeta[uri][className]
                local parent = parentName or 'object'
                local out = {}

                if parentName then
                    local overrideMethods = {}
                    local seenOverride = {}
                    for _, m in ipairs(methods) do
                        if m.isOverride and m.name ~= 'new' and not seenOverride[m.name] then
                            seenOverride[m.name] = true
                            overrideMethods[#overrideMethods + 1] = {
                                name = m.name,
                                start = braceStart + m.sourceStart,
                                finish = braceStart + m.sourceFinish,
                            }
                        end
                    end
                    if #overrideMethods > 0 then
                        __sc_overridepos[uri][className] = {
                            parent = parentName,
                            methods = overrideMethods,
                        }
                    end
                end
                -- 类对象：X.class 继承 class，call 运算符返回实例 X
                out[#out + 1] = '---@class ' .. className .. '.class : class'
                out[#out + 1] = '---@operator call:' .. className
                out[#out + 1] = className .. ' = {}'
                -- 实例：X 继承父类实例 parent
                local classLine = '---@class ' .. className .. ' : ' .. parent
                if implementsList and #implementsList > 0 then
                    classLine = classLine .. ', ' .. table.concat(implementsList, ', ')
                end
                out[#out + 1] = classLine
                out[#out + 1] = '---@field __class ' .. className .. '.class'
                -- 表表层手写的 ---@field 透传到 ---@class 下的连续注释行，声明未在 __init 赋值的字段
                for _, df in ipairs(declareFields) do
                    out[#out + 1] = df
                end
                -- 元方法 → @operator 标注（元方法带 @return 才生成；参数全标注则附操作数类型）
                for _, m in ipairs(methods) do
                    local opName = m.operatorName
                    if opName and opName ~= '' then
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
                                if opName == 'len' or #pl_paramNames(m.params) < 2 then
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
                out[#out + 1] = className .. '.__proto = {}'

                -- 若实现了接口，额外生成 "未继承接口" 的 X.__own 类型，
                -- 仅列出本类自身声明的实例方法，供接口约束（missing-implements）检查。
                -- X.__own 的 extends 只含父类、不含接口，故 vm.getFields 展开时
                -- 不会把接口方法当作继承可达，从而能判定"该类缺哪些接口方法"。
                if #implementsList > 0 then
                    local ownMembers = {}
                    for _, m in ipairs(methods) do
                        if m.kind ~= 'new' and m.kind ~= 'init' then
                            if not m.isMeta and not m.isStatic and not m.isProperty then
                                ownMembers[#ownMembers + 1] = m.name
                            end
                        end
                    end
                    -- 空类体也要生成（空类型），否则"一个方法都没实现"的场景会被诊断器跳过而漏报
                    out[#out + 1] = '---@class ' .. className .. '.__own : ' .. parent
                    for _, mn in ipairs(ownMembers) do
                        out[#out + 1] = '---@field ' .. mn .. ' function'
                    end
                end

                local newMethod = nil
                local initMethod = nil
                for _, m in ipairs(methods) do
                    if m.kind == 'new' then newMethod = m end
                    if m.kind == 'init' then initMethod = m end
                end

                if newMethod then
                    local paramStr = stripFirstParam(newMethod.params)
                    for _, docLine in ipairs(newMethod.docs) do
                        out[#out + 1] = docLine
                    end
                    for _, docLine in ipairs(pl_inferredParamDocs(newMethod, classmeta.fieldTypes, classmeta, __sc_classmeta[uri])) do
                        out[#out + 1] = docLine
                    end
                    if not pl_methodReturn(newMethod.docs) then
                        out[#out + 1] = '---@return ' .. className
                    end
                    out[#out + 1] = 'function ' .. className .. ':new(' .. paramStr .. ')return self.__proto end'
                elseif initMethod then
                    local paramStr = stripFirstParam(initMethod.params)
                    for _, docLine in ipairs(initMethod.docs) do
                        out[#out + 1] = docLine
                    end
                    for _, docLine in ipairs(pl_inferredParamDocs(initMethod, classmeta.fieldTypes, classmeta, __sc_classmeta[uri])) do
                        out[#out + 1] = docLine
                    end
                    if not pl_methodReturn(initMethod.docs) then
                        out[#out + 1] = '---@return ' .. className
                    end
                    out[#out + 1] = 'function ' .. className .. ':new(' .. paramStr .. ')return self.__proto end'
                else
                    out[#out + 1] = '---@return ' .. className
                    out[#out + 1] = 'function ' .. className .. ':new()return self.__proto end'
                end

                for _, f in ipairs(fields) do
                    local isStatic = pl_isStaticMember(f.docs)
                    for _, docLine in ipairs(f.docs) do
                        out[#out + 1] = docLine
                    end
                    if isStatic then
                        out[#out + 1] = className .. '.' .. f.name .. ' = ' .. (f.value or 'nil')
                    else
                        out[#out + 1] = className .. '.__proto.' .. f.name .. ' = ' .. (f.value or 'nil')
                    end
                end

                for _, m in ipairs(methods) do
                    if m.kind == 'getter' then
                        local info = pl_methodInfo(m, className)
                        local attrName = m.name
                        out[#out + 1] = className .. '.__proto.' .. attrName .. ' = ('
                        out[#out + 1] = '    ---@param self ' .. info.receiverType
                        out[#out + 1] = '    function(' .. m.params .. ')'
                        out[#out + 1] = '        self = self ---@class ' .. info.receiverType
                        if m.body and #m.body > 0 then
                            local trimmed = trimBody(m.body)
                            if #trimmed > 0 then
                                out[#out + 1] = '        ---@diagnostic disable'
                                for line in trimmed:gmatch('([^\n]+)') do
                                    out[#out + 1] = '    ' .. line
                                end
                                out[#out + 1] = '        ---@diagnostic enable'
                            end
                        end
                        out[#out + 1] = '    end'
                        out[#out + 1] = ')(' .. className .. '.__proto)'
                    end
                end

                for _, m in ipairs(methods) do
                    local info = pl_methodInfo(m, className)
                    if m.kind == 'new' then
                    elseif m.isProperty then
                    else
                        local receiverType = info.receiverType
                        for _, docLine in ipairs(m.docs) do
                            out[#out + 1] = docLine
                        end
                        for _, docLine in ipairs(pl_inferredParamDocs(m, classmeta.fieldTypes, classmeta, __sc_classmeta[uri])) do
                            out[#out + 1] = docLine
                        end
                        -- 挂载目标：元方法/静态方法挂类对象，其余挂实例
                        if receiverType and info.receiverName and not info.usesColon
                        and not pl_hasParamDoc(m.docs, info.receiverName) then
                            out[#out + 1] = '---@param ' .. info.receiverName .. ' ' .. receiverType
                        end
                        if info.usesColon then
                            local cleanParams = stripFirstParam(m.params)
                            out[#out + 1] = 'function ' .. info.target .. ':' .. m.name .. '(' .. cleanParams .. ')'
                        else
                            out[#out + 1] = 'function ' .. info.target .. '.' .. m.name .. '(' .. m.params .. ')'
                        end
                        if receiverType and info.receiverName then
                            out[#out + 1] = '    ' .. info.receiverName .. ' = ' .. info.receiverName .. ' ---@class ' .. receiverType
                        end
                        if m.body and #m.body > 0 then
                            local trimmed = trimBody(m.body)
                            if #trimmed > 0 then
                                out[#out + 1] = '    ---@diagnostic disable'
                                out[#out + 1] = trimmed
                                out[#out + 1] = '    ---@diagnostic enable'
                            end
                        end
                        out[#out + 1] = 'end'
                    end
                end
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

                -- 旧的 @override 检查实现：通过访问伪造的父类字段间接触发
                -- undefined-field。现在由下方的 invalid-override 诊断器直接检查，
                -- 保留这段注释作为旧实现的对照，避免与新诊断重复报警。
                --[[
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
                ]]--

                diffs[#diffs + 1] = {
                    start  = classEnd + 1,
                    finish = classEnd,
                    text   = '\n' .. table.concat(out, '\n'),
                }

                -- 直接在用到 super 的方法内注入局部 `super`（返回基类实例类型），把 `super(Child, self)` 的
                -- 接收者锚定为基类实例。位置取方法签名右括号之后、同行末尾，零宽度插入不改变行号。
                local baseExpr = parentName and (parentName .. '.__proto') or 'object'
                for _, m in ipairs(methods) do
                    if m.sigEnd and m.body and m.body:find('super%s*%(') then
                        -- body[i] 对应 text[braceStart+i]；右括号在 body[sigEnd-1]，越过即 braceStart+sigEnd
                        local at = braceStart + m.sigEnd
                        diffs[#diffs + 1] = {
                            start  = at,
                            finish = at - 1,
                            text   = ' local function super(_, _)return ' .. baseExpr .. ' end',
                        }
                    end
                end
                if #implementsList > 0 and impKwStart and impFin then
                    __sc_implpos[uri][className] = { start = impKwStart, finish = impFin }
                end
                pos = classEnd + 1
            end
        end
    end

    local allmeta = __sc_classmeta[uri]
    local classCount = 0
    for _ in pairs(allmeta) do classCount = classCount + 1 end
    for _ = 1, classCount do
        for _, classmeta in pairs(allmeta) do
            local parent = classmeta.parent and allmeta[classmeta.parent]
            if parent then
                for name, typ in pairs(parent.fieldTypes) do
                    if not classmeta.fieldTypes[name] then
                        classmeta.fieldTypes[name] = typ
                    end
                end
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

-- LuaLS treats `---@param self Class` as a type reference only.  Bind a
-- virtual class doc to the receiver as well, so visibility checks can see
-- that the original DSL method body executes in Class's context.
local function pl_bindClassToParam(ast, param, classname)
    if not param or not classname then
        return
    end
    local doc = luadoc.buildAndBindDoc(
        ast,
        param,
        pl_buildComment('class', classname, param.start - 1)
    )
    if not doc then
        return
    end
    param.bindDocs = param.bindDocs or {}
    param.bindDocs[#param.bindDocs + 1] = doc
    doc.bindSource = param
end

-- A class-owned method may create an instance through its class receiver:
-- `local value = cls:new(...)`. The return type has no @class annotation
-- which causes visibility and inject-field checks to fail.
-- So bind the local reference to the concrete class as well.
local function pl_unwrapAssignedValue(value)
    while value and value.type == 'select' do
        value = value.vararg
    end
    return value
end

local function pl_bindCreatedInstance(ast, source, classname)
    if not source or source.type ~= 'local' or not classname
    or guide.isParam(source) then
        return
    end
    local value = pl_unwrapAssignedValue(source.value)
    if not value or value.type ~= 'call' then
        return
    end
    local callee = value.node
    if not callee or callee.type ~= 'getmethod'
    or guide.getKeyName(callee) ~= 'new' then
        return
    end
    luadoc.buildAndBindDoc(
        ast,
        source,
        pl_buildComment('class', classname, source.start - 1)
    )
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

---遍历类体 table，给每个方法的接收者参数绑定类型：
---  实例方法首参数 → `<类名>`；@static 且首参数为 cls/self → `<类名>.class`
---  首参类型与归属类型一致且名字为 self 时，重发副本使用冒号语法
---  赋值给已知字段的参数 → `@param <参数名> <字段类型>`
---@param ast table  AST 根
---@param classname string
---@param tableNode table 类体 table 节点
local function pl_injectParams(ast, uri, classname, tableNode, classmeta)
    if not tableNode or tableNode.type ~= 'table' then
        return
    end
    for i = 1, #tableNode do
        local field = tableNode[i]
        local value = field and field.value
        if value and value.type == 'function' and value.args then
            local tableKey = guide.getKeyName(field)
            local methodName = type(tableKey) == 'string' -- 键名不一定是 string
                and tableKey:gsub('^get%.', ''):gsub('^set%.', '')
            local method = classmeta and methodName and classmeta.methods[methodName]
            if method then
                local methodInfo = pl_methodInfo(method, classname)
                local receiverType = methodInfo.receiverType
                if receiverType then
                    local receiverName = getFirstParamName(method.params)
                    for j = 1, #value.args do
                        local p = value.args[j]
                        if guide.getKeyName(p) == receiverName then
                            luadoc.buildAndBindDoc(
                                ast, value,
                                pl_buildComment('param', ('%s %s'):format(receiverName, receiverType), p.start - 1))
                            pl_bindClassToParam(ast, p, receiverType)
                            break
                        end
                    end
                end
                if methodInfo.ownerType == classname .. '.class'
                and methodInfo.receiverName then
                    guide.eachSource(value, function(source)
                        if source.type ~= 'local' then
                            return
                        end
                        local object = pl_unwrapAssignedValue(source.value)
                        local callee = object and object.type == 'call' and object.node
                        local receiver = callee and callee.type == 'getmethod' and callee.node
                        if receiver and guide.getKeyName(receiver) == methodInfo.receiverName then
                            pl_bindCreatedInstance(ast, source, classname)
                        end
                    end)
                end
                if classmeta.fieldTypes then
                    local inferred = pl_inferredParamTypes(
                        method,
                        classmeta.fieldTypes,
                        classmeta,
                        __sc_classmeta[uri]
                    )
                    for j = 1, #value.args do
                        local p = value.args[j]
                        local key = guide.getKeyName(p)
                        local typ = key and inferred[key]
                        if typ then
                            luadoc.buildAndBindDoc(
                                ast, value,
                                pl_buildComment('param', ('%s %s'):format(key, typ), p.start - 1))
                        end
                    end
                end
            end
        end
    end
end

local function pl_docClassSets(global, uri)
    local sets = {}
    if not global then return sets end
    for _, set in ipairs(global:getSets(uri)) do
        if set.type == 'doc.class' then
            sets[#sets + 1] = set
        end
    end
    return sets
end

local function pl_vmFieldNames(set)
    local names = {}
    for _, field in ipairs(vm.getFields(set)) do
        local name = vm.getKeyName(field)
        if name and type(name) == 'string' then
            names[name] = true
        end
    end
    return names
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
                    local classmeta = __sc_classmeta[uri] and __sc_classmeta[uri][classname]
                    if classmeta and classmeta.parent and ok_vm then
                        local parent = vm.getGlobal('type', classmeta.parent)
                        if parent then
                            for _, set in ipairs(pl_docClassSets(parent, uri)) do
                                for _, field in ipairs(vm.getFields(set)) do
                                    local name = vm.getKeyName(field)
                                    if name and not classmeta.fieldTypes[name] then
                                        local okInfer, infer = pcall(vm.getInfer, field)
                                        if okInfer and infer then
                                            local okView, typ = pcall(infer.view, infer, uri)
                                            if okView and typ and typ ~= 'unknown' then
                                                classmeta.fieldTypes[name] = typ
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    for _, a in ipairs(node.args) do
                        if a.type == 'table' then
                            pl_injectParams(
                                ast,
                                uri,
                                classname,
                                a,
                                classmeta
                            )
                        end
                    end
                end
            end
        end)
    end
    return ast
end

-- ==================================== 自定义诊断器 ====================================
-- 机制：core.diagnostics.<name> 由 LS 按名动态 require，此处通过 package.loaded 预置

---@alias diagnostic.severity 'Hint' | 'Information' | 'Warning' | 'Error'      诊断级别
---@alias diagnostic.fstatus  'Any' | 'Opened' | 'None'                         文件状态要求
---@alias diagnostic.callback fun(diag: diagnostic)                             诊断回调
---@alias diagnostic.handler  fun(uri: string, callback: diagnostic.callback)   诊断器实现
---@class diagnostic
---@field start integer
---@field finish integer
---@field message string

if ok_files and ok_define and ok_diag and ok_vm and ok_guide then
    -- 注册自定义的 LuaLS 诊断器
    ---@param name     string
    ---@param severity diagnostic.severity
    ---@param status   diagnostic.fstatus
    ---@param handler? diagnostic.handler
    local function registerDiagnostic(name, severity, status, handler)
        diag.register { name } {
            group    = 'simpleclass',
            severity = severity,
            status   = status,
        }
        -- getDiagAndErrNameMap() 可能在插件加载前已经建立。
        diag._diagAndErrNames = nil
        define.DiagnosticDefaultSeverity[name] = severity
        define.DiagnosticDefaultNeededFileStatus[name] = status
        package.loaded['core.diagnostics.' .. name] = handler or nil
    end

    -- The marker may share the leading comment preamble with LuaLS file-level
    -- annotations such as @meta and @diagnostic.  Stop at the first code line
    -- so strings and later comments cannot turn into directives.
    local function hasLocalImportMarker(text)
        if type(text) ~= 'string' then
            return false
        end
        local n = #text
        local i = 1
        if text:sub(1, 3) == '\239\187\191' then
            i = 4
        end
        while i <= n do
            while i <= n and text:sub(i, i):match('%s') do
                i = i + 1
            end
            if i > n then
                return false
            end

            if text:sub(i, i) == '-' and text:sub(i + 1, i + 1) == '-' then
                local after = i + 2
                local longEnd = after <= n and skipLongBracket(text, after)
                if longEnd then
                    i = longEnd
                else
                    local finish = text:find('\n', i, true) or (n + 1)
                    local line = text:sub(i, finish - 1)
                    if line:match('^%-%-%-%s*@simpleclass%s+local%-import%s*$') then
                        return true
                    end
                    i = finish
                end
            else
                return false
            end
        end
        return false
    end

    -- 把原始源码字节偏移转换为诊断器需要的 diff 后 packed 位置。
    ---@param startOffset  integer 原始源码字节偏移
    ---@param finishOffset integer 原始源码字节偏移
    local function diagRangeFromOriginal(state, startOffset, finishOffset)
        if state.diffInfo then
            -- diffedPackPosition 的列重测包含目标字节，起点需后退一个字节；
            -- finish 保持在目标字符上，使范围包含方法名最后一个字符。
            local okStart,  diffedStart  = pcall(files.diffedOffset, state, startOffset - 1)
            local okFinish, diffedFinish = pcall(files.diffedOffset, state, finishOffset)
            if okStart and okFinish and diffedStart and diffedFinish then
                return guide.offsetToPosition(state, diffedStart)
                    ,  guide.offsetToPosition(state, diffedFinish)
            end
        else
            return guide.offsetToPosition(state, startOffset)
                ,  guide.offsetToPosition(state, finishOffset)
        end
    end

    -- 由 OnSetText 生成 X.__own 类（extends 只含父类、不含接口），
    -- 在类型解析后的周期诊断中检查每个 implements 接口的类是否实现了接口要求的全部成员。
    registerDiagnostic('missing-implements', 'Error', 'Any', function (uri, callback)
        local state = files.getState(uri)
        if not state then return end

        -- 与内置诊断器一致：枚举 vm 已编译的全局类型，而非遍历 state.ast 的 doc 注释节点。
        local seen = {}
        for _, gv in ipairs(vm.getGlobals('type')) do
            for _, set in ipairs(gv:getSets(uri)) do
                if      set.type == 'doc.class'
                    and set.extends and #set.extends >= 2
                    and set.class   and set.class[1]
                    and guide.getUri(set) == uri
                then
                    local selfName = set.class[1]
                    if not seen[selfName] then
                        seen[selfName] = true

                        -- 仅检查插件生成的类：需存在 X.__own 类型
                        local ownG = vm.getGlobal('type', selfName .. '.__own')
                        local ownDef = ownG and pl_docClassSets(ownG, uri)[1]
                        if ownDef then
                            -- 类实现成员集合（X.__own 不含接口，展开即类自己写的）
                            local clsFields = pl_vmFieldNames(ownDef)

                            -- 接口要求成员：extends[2..] 都是接口，读其 ---@field
                            local missing = {}
                            for idx = 2, #set.extends do
                                local ifname = set.extends[idx][1]
                                local ig = ifname and vm.getGlobal('type', ifname)
                                if ig then
                                    for _, s2 in ipairs(ig:getSets(uri)) do
                                        if s2.type == 'doc.class' and s2.fields then
                                            for _, fld in ipairs(s2.fields) do
                                                local k = vm.getKeyName(fld)
                                                if k and type(k) == 'string' and not clsFields[k] then
                                                    missing[#missing + 1] = ('%s.%s'):format(ifname, k)
                                                end
                                            end
                                        end
                                    end
                                end
                            end

                            if #missing == 0 then break end

                            -- posRange 记录原始源码中 implements(...) 的字节偏移；
                            -- 诊断 start/finish 须为 diff 后文本的 packed 位置（row*10000+col），
                            -- packPosition 会再经 diffedOffsetBack 映射回原始行/列。
                            local posRange = __sc_implpos[uri] and __sc_implpos[uri][selfName]
                            local start, finish = set.start, set.finish
                            if posRange then
                                local rangeStart, rangeFinish = diagRangeFromOriginal(
                                    state, posRange.start, posRange.finish)
                                if rangeStart and rangeFinish then
                                    start, finish = rangeStart, rangeFinish
                                end
                            end
                            callback {
                                start   = start,
                                finish  = finish,
                                message = ('%s implements interfaces but does not implement method: %s')
                                    :format(selfName, table.concat(missing, ', ')),
                            }
                        end
                    end
                end
            end
        end
    end)

    registerDiagnostic('invalid-override', 'Warning', 'Any', function (uri, callback)
        local state = files.getState(uri)
        local classes = __sc_overridepos[uri]
        if not state or not classes then return end

        for className, info in pairs(classes) do
            local parentGlobal = vm.getGlobal('type', info.parent)
            local parentFields = {}
            if parentGlobal then
                for _, parentSet in ipairs(pl_docClassSets(parentGlobal, uri)) do
                    for name in pairs(pl_vmFieldNames(parentSet)) do
                        parentFields[name] = true
                    end
                end
            end

            for _, method in ipairs(info.methods) do
                if not parentFields[method.name] then
                    local start, finish = diagRangeFromOriginal(
                        state, method.start, method.finish)
                    if start and finish then
                        callback {
                            start = start,
                            finish = finish,
                            message = ("%s marks '%s' with @override, but %s has no such method")
                                :format(className, method.name, info.parent),
                        }
                    end
                end
            end
        end
    end)

    -- LuaLS global declarations are workspace-wide.  This diagnostic is
    -- intentionally file-local and therefore does not use vm.isUndefinedGlobal.
    registerDiagnostic('simpleclass-missing-import', 'Warning', 'Any', function (uri, callback)
        local state = files.getState(uri)
        if not state then return end

        local text = state.originText or state.text or state.lua
        if not hasLocalImportMarker(text) then
            return
        end

        guide.eachSourceType(state.ast, 'getglobal', function (source)
            local name = source[1]
            if SC_IMPORT_APIS[name] then
                callback {
                    start = source.start,
                    finish = source.finish,
                    message = ('simpleclass API `%s` is not locally imported')
                        :format(name),
                }
            end
        end)
    end)
end



-- ==================================== VM 补丁 ====================================
-- Optional patcher for LuaLS.
-- This relies on LuaLS VM internals and is intentionally opt-in per function.

local _pl_src = debug and debug.getinfo(1, 'S').source
local _pl_dir = _pl_src and _pl_src:match('^@?(.*)[/\\][^/\\]+$')
local _pt_dir = _pl_dir and _pl_dir .. '/patches/'
local apply_patch = nil

if _pt_dir and ok_vm and ok_guide then
    local M = {} ---@class LLSPatch
    M.vm = vm
    M.guide = guide

    ---Declare the type requirement for a patch.
    ---@param vt_list [any, type, any, type, any, type]
    function M.t_require(vt_list)
        if not vt_list or #vt_list == 0 then
            return true
        end
        for i = 1, #vt_list, 2 do
            local v = vt_list[i]
            local t = vt_list[i+1]
            if type(v) ~= t then
                return false
            end
        end
        return true
    end

    ---Apply a patch. This is a no-op if the patch is already applied.  
    -- Patch must exist in `patches` directory.
    ---@param name string
    ---@return boolean ok
    ---@return string? err if failed.
    function apply_patch(name)
        if type(name) ~= 'string' or name == '' then
            return false
            , ("Invalid patch name '%s'")
            : format(name)
        end

        local state = vm.__simpleclass_patcher_state
        if not state then
            state = {}
            vm.__simpleclass_patcher_state = state
        end

        if state[name] then
            return true
        end

        local patch, err1 = loadfile(_pt_dir .. name .. '.lua', "bt", _ENV)
        if not patch then
            state[name] = false
            return false
            , ("Failed to load patch '%s': %s")
            : format(name, err1)
        end

        state[name] = {}
        local do_ok, pt_ok, err2 = pcall(patch, M, state[name])

        if not do_ok or not pt_ok then
            state[name] = false
            return false
            , ("Failed to apply patch '%s': %s")
            : format(name, pt_ok or err2)
        end
        return true
    end

    for _, name in ipairs(ENABLE_PATCHES) do
        apply_patch(name)
    end
end
