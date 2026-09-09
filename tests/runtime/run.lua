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

local tests = {
    'super.lua',
}

local passed, failed = 0, 0
for _, name in ipairs(tests) do
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
