-- Runtime module test runner.
local source = debug.getinfo(1, 'S').source:match('^@?(.*)[/\\]') or 'tests/runtime/'
local sep = package.config:sub(1, 1)
source = source:gsub('[/\\]+$', '')
local root = source:gsub('[/\\]tests[/\\]runtime$', '')
if root == source then
    local f = io.popen(package.config:sub(1, 1) == '\\' and 'cd' or 'pwd')
    root = f and f:read('*l') or '.'
    if f then f:close() end
end

package.path = table.concat({
    root .. sep .. '?.lua',
    root .. sep .. '?/init.lua',
    package.path,
}, ';')

local function listDir(dir)
    local isWin = package.config:sub(1, 1) == '\\'
    local command = isWin and ('dir /b "%s"'):format(dir)
        or ('ls "%s"'):format(dir)
    local handle = io.popen(command)
    if not handle then return {} end

    local files = {}
    for name in (handle:read('*a') or ''):gmatch('[^\r\n]+') do
        if name:match('%.lua$') and name ~= 'run.lua' then
            files[#files + 1] = name
        end
    end
    handle:close()
    table.sort(files)
    return files
end

local passed, failed = 0, 0
for _, name in ipairs(listDir(source)) do
    local ok, err = pcall(dofile, source .. sep .. name)
    if ok then
        passed = passed + 1
        print(('PASS  %s'):format(name))
    else
        failed = failed + 1
        print(('FAIL  %s'):format(name))
        print(err)
    end
end

print(('----  %d passed, %d failed'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
