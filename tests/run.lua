-- 预期诊断回归 runner
--
-- 对 tests/ 下每个 *.lua（跳过 run.lua）：
--   1) 复制该文件 + simpleclass 模块 到隔离的临时工作区
--      （临时目录无 .gitignore 且配置 useGitIgnore=false，故一定被分析）
--   2) 写 .luarc.json（插件绝对路径），跑 lua-language-server --check
--   3) 解析诊断 (行:列 [级别] 消息 (code))，与测试顶部 `-- expect:` 声明比对
--   4) 全过返回 0，否则返回 1
--
-- 测试文件格式：顶部若干行 `-- expect: <行>:<code>` 声明预期诊断；
-- 不写任何 expect 表示该文件应为 0 诊断。

local SRC   = debug.getinfo(1, 'S').source:match('^@?(.*)[/\\]') or 'tests/'
local isWin = package.config:sub(1, 1) == '\\'
local sep   = isWin and '\\' or '/'

-- 用绝对路径（相对路径写进临时 .luarc.json 时，LuaLS 相对临时目录解析会找不到）
local function trim(s) return (s or ''):gsub('^%s+', ''):gsub('%s+$', '') end

local function getcwd()
    local f = io.popen(isWin and 'cd' or 'pwd')
    if not f then return '.' end
    local r = trim(f:read('*a')); f:close()
    return (r ~= '' and r) or '.'
end

local CWD = getcwd():gsub('[/\\]+$', '')
local PROJECT_DIR = CWD
local TEST_DIR    = CWD .. sep .. 'tests'
local SIMPLE_DIR  = CWD .. sep .. 'simpleclass'
local PLUGIN_PATH = CWD .. sep .. '.luals' .. sep .. 'simpleclass.plugin.lua'

-- ---------- 工具 ----------
local function which(exe)
    local cmd = isWin and ('where "%s" 2>nul'):format(exe)
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
    local cfgPath = workspaceDir .. sep .. '.luarc.json'
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
    for raw in clean:gmatch('[^\n]*') do
        -- <tmp>/xxx.lua:31:32 [Warning] ... (undefined-field)
        local ln, code = raw:match('%.lua:(%d+):%d+ %[.-%] .- %(([%w%-]+)%)$')
        if ln then diags[#diags + 1] = { line = tonumber(ln), code = code } end
    end
    return diags
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

local pass, fail = 0, 0
for _, path in ipairs(files) do
    local testFile = path:match('([^/\\]+%.lua)$')
    local text = readFile(path)
    local expects = parseExpects(text)

    -- 隔离临时工作区
    local tmpRoot = (os.getenv('TEMP') or os.getenv('TMP') or '/tmp'):gsub('[/\\]+$', '')
    local ws = tmpRoot .. sep .. 'lsreg_' .. tostring(os.time()) .. '_' .. pass .. '_' .. testFile:gsub('%.lua$', '')
    os.execute(isWin and ('rmdir /s /q "%s" 2>nul'):format(ws) or ('rm -rf "%s"'):format(ws))
    os.execute(isWin and ('if not exist "%s" mkdir "%s"'):format(ws, ws) or ('mkdir -p "%s"'):format(ws))

    -- 复制测试文件
    copyFile(path, ws .. sep .. testFile)
    -- 复制 simpleclass 模块
    local scDir = ws .. sep .. 'simpleclass'
    os.execute(isWin and ('if not exist "%s" mkdir "%s"'):format(scDir, scDir) or ('mkdir -p "%s"'):format(scDir))
    for _, sf in ipairs(listDir(SIMPLE_DIR) or {}) do
        copyFile(SIMPLE_DIR .. sep .. sf, scDir .. sep .. sf)
    end

    local diags = runCheck(ws)

    local expectSet, actualSet = {}, {}
    for _, e in ipairs(expects) do expectSet[e.line .. ':' .. e.code] = true end
    for _, d in ipairs(diags or {}) do actualSet[d.line .. ':' .. d.code] = true end

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
        print(('PASS  %-28s (%d diag)'):format(testFile, #(diags or {})))
    else
        fail = fail + 1
        print(('FAIL  %-28s (expected %d, got %d)'):format(testFile, #expects, #(diags or {})))
        if #missing > 0 then print('  missing(expected but absent):\n    ' .. table.concat(missing, '\n    ')) end
        if #extra > 0 then print('  extra(reported but unexpected):\n    ' .. table.concat(extra, '\n    ')) end
    end

    os.execute(isWin and ('rmdir /s /q "%s" 2>nul'):format(ws) or ('rm -rf "%s"'):format(ws))
end

print(('---- %d passed, %d failed'):format(pass, fail))
os.exit(fail == 0 and 0 or 1)