---@class diff
---@field start  integer # The number of bytes at the beginning of the replacement
---@field finish integer # The number of bytes at the end of the replacement
---@field text   string  # What to replace

local function skipTo(text, pos, predicate)
    local n = #text
    local i = pos
    while i <= n do
        local c = text:sub(i, i)
        if c == '"' or c == "'" then
            local q = c
            i = i + 1
            while i <= n do
                local cc = text:sub(i, i)
                if cc == '\\' then
                    i = i + 2
                elseif cc == q then
                    i = i + 1
                    break
                else
                    i = i + 1
                end
            end
        elseif c == '-' and i < n and text:sub(i + 1, i + 1) == '-' then
            while i <= n and text:sub(i, i) ~= '\n' do
                i = i + 1
            end
        elseif c == '[' and i < n and text:sub(i + 1, i + 1) == '[' then
            local endStr = text:find(']]', i + 2, true)
            i = endStr and (endStr + 2) or (n + 1)
        else
            if predicate(c, i) then
                return i
            end
            i = i + 1
        end
    end
    return nil
end

local function findBraceEnd(text, startPos)
    local depth = 0
    local n = #text
    local i = startPos
    while i <= n do
        local c = text:sub(i, i)
        if c == '"' or c == "'" then
            local q = c
            i = i + 1
            while i <= n do
                local cc = text:sub(i, i)
                if cc == '\\' then
                    i = i + 2
                elseif cc == q then
                    break
                else
                    i = i + 1
                end
            end
        elseif c == '-' and i < n and text:sub(i + 1, i + 1) == '-' then
            while i <= n and text:sub(i, i) ~= '\n' do
                i = i + 1
            end
        elseif c == '[' and i < n and text:sub(i + 1, i + 1) == '[' then
            local endStr = text:find(']]', i + 2, true)
            i = endStr and (endStr + 2) or (n + 1)
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

local function findFuncEnd(text, startPos)
    local depth = 0
    local n = #text
    local i = startPos
    while i <= n do
        local c = text:sub(i, i)
        if c == '"' or c == "'" then
            local q = c
            i = i + 1
            while i <= n do
                local cc = text:sub(i, i)
                if cc == '\\' then
                    i = i + 2
                elseif cc == q then
                    break
                else
                    i = i + 1
                end
            end
        elseif c == '-' and i < n and text:sub(i + 1, i + 1) == '-' then
            while i <= n and text:sub(i, i) ~= '\n' do
                i = i + 1
            end
        elseif c == '[' and i < n and text:sub(i + 1, i + 1) == '[' then
            local endStr = text:find(']]', i + 2, true)
            i = endStr and (endStr + 2) or (n + 1)
        elseif c == '{' then
            depth = depth + 1
        elseif c == '}' then
            depth = depth - 1
            if depth == 0 then
                return i
            end
        elseif depth == 0 then
            local kw_end = text:sub(i, i + 2)
            if kw_end == 'end' then
                local before = i > 1 and text:sub(i - 1, i - 1) or ' '
                local after = i + 3 <= n and text:sub(i + 3, i + 3) or ' '
                if (before == ' ' or before == '\n' or before == '\t' or before == ';') and
                   (after == ' ' or after == '\n' or after == '\t' or after == ';' or after == ',' or after == '}' or after == '') then
                    return i + 2
                end
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

local function parseMethods(body)
    local methods = {}
    local n = #body
    local i = 1

    while i <= n do
        local beforeName = body:match('^[%s;,]*', i)
        i = i + #beforeName

        if i > n then break end

        local name, after = body:match('^([%w_]+)%s*=%s*(.*)', i)
        if not name then
            break
        end

        local rest = after
        local funcKw = rest:match('^function%s*%(')
        if funcKw then
            local funcStartInBody = i + #name + 1
            local eqPos = body:find('=', i, true)
            local funcWordStart = body:find('function', eqPos + 1, true)
            local parenStart = body:find('(', funcWordStart, true)

            local parenDepth = 1
            local j = parenStart + 1
            local inString = nil
            while j <= n and parenDepth > 0 do
                local c = body:sub(j, j)
                if inString then
                    if c == '\\' then
                        j = j + 2
                    elseif c == inString then
                        inString = nil
                        j = j + 1
                    else
                        j = j + 1
                    end
                elseif c == '"' or c == "'" then
                    inString = c
                    j = j + 1
                elseif c == '(' then
                    parenDepth = parenDepth + 1
                    j = j + 1
                elseif c == ')' then
                    parenDepth = parenDepth - 1
                    if parenDepth == 0 then
                        break
                    end
                    j = j + 1
                else
                    j = j + 1
                end
            end

            local params = body:sub(parenStart + 1, j - 1)
            local funcBodyStart = j + 1

            local braceDepth = 0
            local endDepth = 0
            local k = funcBodyStart
            local inStr2 = nil
            while k <= n do
                local c = body:sub(k, k)
                if inStr2 then
                    if c == '\\' then
                        k = k + 2
                    elseif c == inStr2 then
                        inStr2 = nil
                        k = k + 1
                    else
                        k = k + 1
                    end
                elseif c == '"' or c == "'" then
                    inStr2 = c
                    k = k + 1
                elseif c == '-' and k < n and body:sub(k + 1, k + 1) == '-' then
                    while k <= n and body:sub(k, k) ~= '\n' do
                        k = k + 1
                    end
                elseif c == '[' and k < n and body:sub(k + 1, k + 1) == '[' then
                    local endStr = body:find(']]', k + 2, true)
                    k = endStr and (endStr + 2) or (n + 1)
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
            }
            i = k + 3
        else
            i = i + #name + 1 + #rest
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
        local isBlank = line:match('^%s*$') ~= nil
        if not isBlank then
            lines[#lines + 1] = line
        end
    end
    if #lines == 0 then return '' end
    return '\n' .. table.concat(lines, '\n')
end

local function findClassKeyword(text, from)
    local n = #text
    local pos = from
    while pos <= n do
        local cstart = text:find('class', pos, true)
        if not cstart then return nil end
        local before = cstart > 1 and text:sub(cstart - 1, cstart - 1) or '\n'
        if not before:match('[%w_]') then
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

---@param  uri  string # The uri of file
---@param  text string # The content of file
---@return diff[]?
function OnSetText(uri, text)
    if not findClassKeyword(text, 1) then
        return
    end

    local diffs = {}
    local pos = 1
    local n = #text

    while pos <= n do
        local nextClass = findClassKeyword(text, pos)
        if not nextClass then break end

        local className, parentName, classStart, classEnd, body = parseClassBlock(text, nextClass)
        if not className then
            pos = nextClass + 5
        else
            local methods = parseMethods(body)
            local parent = parentName or 'object'

            local out = {}
            out[#out + 1] = '---@class ' .. className .. ' : ' .. parent
            out[#out + 1] = className .. ' = {}'

            local initMethod = nil
            for _, m in ipairs(methods) do
                if m.name == '__init' then
                    initMethod = m
                end
            end

            if initMethod then
                local paramStr = stripFirstParam(initMethod.params)
                out[#out + 1] = '---@diagnostic disable-next-line: unused-local'
                out[#out + 1] = 'function ' .. className .. ':new(' .. paramStr .. ')return self end'
            else
                out[#out + 1] = 'function ' .. className .. ':new()return self end'
            end

            for _, m in ipairs(methods) do
                local firstParam = getFirstParamName(m.params)
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

    if #diffs == 0 then return nil end
    return diffs
end


--[[
没有继承时
class "Person" {
    __init = function(self, name, age)
        self.name = name
        self.age = age
    end;
    sayHello = function(self)
        print("Hello, my name is ".. self.name.. " and I am ".. self.age.. " years old.")
    end;
}
解析为：
---@class Person : object
Person = {}
---@diagnostic disable-next-line: unused-local
function Person:new(name, age)return self end
function Person:__init(name, age)
    self.name = name
    self.age = age
end
function Person:sayHello()
    print("Hello, my name is ".. self.name.. " and I am ".. self.age.. " years old.")
end
=======
有继承时
class "Student" : extends "Person" {
    __init = function(self, name, age, grade)
        super(self):__init(name, age)
        self.grade = grade
    end;
    sayHello = function(self)
        print("Hello, my name is ".. self.name.. " and I am a ".. self.grade.. " year old student.")
    end;
}
解析为：
---@class Student : Person
Student = {}
---@diagnostic disable-next-line: unused-local
function Student:new(name, age, grade)return self end
function Student:__init(name, age, grade)
    super(self):__init(name, age)
    self.grade = grade
end
function Student:sayHello()
    print("Hello, my name is ".. self.name.. " and I am a ".. self.grade.. " year old student.")
end
]]

--[[
当然还有很多语法，比如接口，匿名类等等，详见readme
但是先不管那些，一步一步来，首要任务是完成上面两种情况的解析
]]