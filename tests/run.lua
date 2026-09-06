-- 预期诊断回归 runner
--
-- 对 tests/ 下全部 *.lua（跳过 run.lua）：
--   1) 一次性复制到隔离的临时工作区，并复制唯一的 simpleclass.d.lua
--      （运行时 simpleclass 模块不需要复制，d.lua 提供完整模块语义）
--   2) 写 .luarc.json（插件绝对路径），只跑一次 lua-language-server --check
--   3) 解析诊断 (行:列 [级别] 消息 (code))，与测试顶部 `-- expect:` 声明比对
--   4) 全过返回 0，否则返回 1
--
-- 测试文件格式：顶部若干行 `-- expect: <行>:<code>` 声明预期诊断；
-- 不写任何 expect 表示该文件应为 0 诊断。

local SRC   = debug.getinfo(1, 'S').source:match('^@?(.*)[/\\]') or 'tests/'
local sep   = package.config:sub(1, 1)
local isWin = sep == '\\'

-- 用绝对路径（相对路径写进临时 .luarc.json 时，LuaLS 相对临时目录解析会找不到）
local function trim(s) return (s or ''):gsub('^%s+', ''):gsub('%s+$', '') end
local function ujoin(...) return table.concat({...}, sep) end

local function getcwd()
    local f = io.popen(isWin and 'cd' or 'pwd')
    if not f then return '.' end
    local r = trim(f:read('*a')); f:close()
    return (r ~= '' and r) or '.'
end

local CWD = getcwd():gsub('[/\\]+$', '')
local PROJECT_DIR = CWD
local TEST_DIR    = ujoin(CWD, 'tests')
local PLUGIN_PATH = ujoin(CWD, '.luals', 'simpleclass.plugin.lua')

-- ---------- 工具 ----------
local function which(exe)
    local cmd = isWin and ('where.exe "%s" 2>nul'):format(exe)
        or ('command -v "%s" 2>/dev/null'):format(exe)
    local f = io.popen(cmd)
    if not f then return nil end
    local r = trim(f:read('*a')); f:close()
    return (r ~= '' and r) or nil
end

local function readFile(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local c = f:read('*a'); f:close()
    return c
end

local function writeFile(path, s)
    local f = io.open(path, 'w')
    if not f then return false end
    f:write(s); f:close()
    return true
end

local function copyFile(src, dst)
    local c = readFile(src)
    if c == nil then return false end
    return writeFile(dst, c)
end

local function listDir(dir)
    local cmd = isWin and ('dir /b "%s"'):format(dir) or ('ls "%s"'):format(dir)
    local f = io.popen(cmd)
    if not f then return nil end
    local out = f:read('*a'); f:close()
    local r = {}
    for line in (out or ''):gmatch('[^\r\n]+') do r[#r + 1] = line end
    return r
end

local function json(v)
    if type(v) == 'string' then
        local e = v:gsub('\\', '\\\\'):gsub('"', '\\"')
        return '"' .. e .. '"'
    end
    if type(v) == 'boolean' then return tostring(v) end
    if type(v) == 'number' then return tostring(v) end
    if type(v) == 'table' then
        local p = {}
        for k, vv in pairs(v) do p[#p + 1] = json(k) .. ':' .. json(vv) end
        return '{' .. table.concat(p, ',') .. '}'
    end
    return 'null'
end

-- ---------- 解析测试文件期望 ----------
local function parseExpects(text)
    local expects = {}
    for line in text:gmatch('[^\n]*') do
        local ln, code = line:match('%-%-%s*expect:%s*(%d+)%s*:%s*([%w%-]+)')
        if ln then expects[#expects + 1] = { line = tonumber(ln), code = code } end
    end
    return expects
end

-- ---------- 运行 luals 并解析实际诊断 ----------
local function runCheck(workspaceDir)
    local cfgPath = ujoin(workspaceDir, '.luarc.json')
    writeFile(cfgPath, json({
        ['runtime.plugin']  = PLUGIN_PATH,
        workspace           = { useGitIgnore = false },
    }))

    local luals = os.getenv('LUA_LS') or which('lua-language-server')
        or which('lua-language-server.exe') or which('lua_ls')
    if not luals then io.stderr:write('lua-language-server not found.\n'); return nil end

    local q = function(s) return '"' .. s .. '"' end
    -- Windows 下：cmd 直接带 2>&1 启动 LuaLS 时，其 worker 子进程句柄继承会失败
    -- （"The filename, directory name, or volume label syntax is incorrect"），
    -- 前缀 call 让 cmd 正确设置控制台 stdio 继承。
    local prefix = isWin and 'call ' or ''
    local cmd = ('%s%s --configpath %s --check %s 2>&1')
        :format(prefix, q(luals), q(cfgPath), q(workspaceDir))
    local f = io.popen(cmd)
    if not f then return nil end
    local out = f:read('*a'); f:close()

    if os.getenv('LSREG_DEBUG') then io.stderr:write('=== RAW OUT ===\n' .. (out or '') .. '\n=== END ===\n') end

    local diags = {}
    -- 剥掉 LuaLS 输出的 ANSI 颜色码（如 \x1b[34m \x1b[0m）与 \r，否则正则锚点对不上
    local clean = (out or ''):gsub('\27%[[;%-%d]+m', ''):gsub('\r', '')
    -- 诊断可能跨多行（如 param-type-mismatch 附带 - detail 行），
    -- (code) 与 :line:col 不在同一行。逐行扫描：先记下最近一次 :line:col，
    -- 当某行以 (code) 结尾时，把该 code 归属到该 line。
    local pendingFile, pendingLine = nil, nil
    for raw in clean:gmatch('[^\n]*') do
        -- <tmp>/xxx.lua:31:32 [Warning] ... 定位文件和行
        local file, ln = raw:match('([^/\\]+%.lua):(%d+):%d+')
        if file then
            pendingFile = file
            pendingLine = tonumber(ln)
        end
        if pendingFile and pendingLine then
            local code = raw:match('%(([%w%-]+)%)$')
            if code then
                diags[#diags + 1] = {
                    file = pendingFile,
                    line = pendingLine,
                    code = code,
                }
                pendingFile, pendingLine = nil, nil
            end
        end
    end
    -- LuaLS 可能对同一位置同一 code 输出多行，去重后计数才稳定
    local seen, uniq = {}, {}
    for _, d in ipairs(diags) do
        local k = d.file .. ':' .. d.line .. ':' .. d.code
        if not seen[k] then seen[k] = true; uniq[#uniq + 1] = d end
    end
    return uniq
end

-- ---------- 主流程 ----------
local files = {}
for _, name in ipairs(listDir(TEST_DIR) or {}) do
    if name:match('%.lua$') and name ~= 'run.lua' then
        files[#files + 1] = TEST_DIR .. sep .. name
    end
end
table.sort(files)
if #files == 0 then io.stderr:write('no test files in ' .. TEST_DIR .. '\n'); return 1 end

-- 建立临时工作区
local ws = os.tmpname()
os.remove(ws)
os.execute(isWin and ('rmdir /s /q "%s" 2>nul'):format(ws) or ('rm -rf "%s"'):format(ws))
os.execute(isWin and ('if not exist "%s" mkdir "%s"'):format(ws, ws) or ('mkdir -p "%s"'):format(ws))

local expectedByFile = {}
for _, path in ipairs(files) do
    local testFile = path:match('([^/\\]+%.lua)$')
    expectedByFile[testFile] = parseExpects(readFile(path))
    copyFile(path, ws .. sep .. testFile)
end

-- 复制 simpleclass.d.lua 提供类型与模块定义
copyFile(
	ujoin(PROJECT_DIR, 'simpleclass.d.lua'),
	ujoin(ws, 'simpleclass.d.lua')
)

local diags = runCheck(ws)
if not diags then
    os.execute(isWin and ('rmdir /s /q "%s" 2>nul'):format(ws) or ('rm -rf "%s"'):format(ws))
    return 1
end

local actualByFile = {}
for _, d in ipairs(diags) do
    local list = actualByFile[d.file]
    if not list then list = {}; actualByFile[d.file] = list end
    list[#list + 1] = d
end

local pass, fail = 0, 0
local function checkFile(testFile, expects, actual)
    local expectSet, actualSet = {}, {}
    for _, e in ipairs(expects) do expectSet[e.line .. ':' .. e.code] = true end
    for _, d in ipairs(actual) do actualSet[d.line .. ':' .. d.code] = true end

    local missing, extra = {}, {}
    for _, e in ipairs(expects) do
        if not actualSet[e.line .. ':' .. e.code] then missing[#missing + 1] = e.line .. ':' .. e.code end
    end
    for k in pairs(actualSet) do
        if not expectSet[k] then extra[#extra + 1] = k end
    end
    table.sort(extra)

    if #missing == 0 and #extra == 0 then
        pass = pass + 1
        print(('PASS  %-28s (%d diag)'):format(testFile, #actual))
    else
        fail = fail + 1
        print(('FAIL  %-28s (expected %d, got %d)'):format(testFile, #expects, #actual))
        if #missing > 0 then print('  missing(expected but absent):\n    ' .. table.concat(missing, '\n    ')) end
        if #extra > 0 then print('  extra(reported but unexpected):\n    ' .. table.concat(extra, '\n    ')) end
    end
end

for _, path in ipairs(files) do
    local testFile = path:match('([^/\\]+%.lua)$')
    checkFile(testFile, expectedByFile[testFile], actualByFile[testFile] or {})
end

for testFile, actual in pairs(actualByFile) do
    if not expectedByFile[testFile] then
        checkFile(testFile, {}, actual)
    end
end

os.execute(isWin and ('rmdir /s /q "%s" 2>nul'):format(ws) or ('rm -rf "%s"'):format(ws))

print(('---- %d passed, %d failed'):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
