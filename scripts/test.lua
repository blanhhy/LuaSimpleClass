-- <lua> run test [<args>]
-- Run the runtime and LuaLS regression suites.
--
-- Usage:
--   lua scripts/test.lua             Run both suites
--   lua scripts/test.lua runtime     Run the runtime suite
--   lua scripts/test.lua luals       Run the LuaLS suite

local source = debug.getinfo(1, 'S').source:match('^@?(.*)[/\\]') or 'scripts/'
local sep = package.config:sub(1, 1)
local root = source:gsub('[/\\]+$', '')
if root == 'scripts' then
    root = '.'
else
    root = root:gsub('[/\\]scripts$', '')
end

local suites = {
    runtime = root .. sep .. 'tests' .. sep .. 'runtime' .. sep .. 'run.lua',
    luals   = root .. sep .. 'tests' .. sep .. 'luals' .. sep .. 'run.lua',
}

local selected = {}
for i = 1, #arg do
    local name = arg[i]:lower()
    if name == 'all' or name == 'both' then
        selected = {'runtime', 'luals'}
        break
    elseif suites[name] then
        selected[#selected + 1] = name
    else
        io.stderr:write(('unknown test suite: %s\n'):format(arg[i]))
        io.stderr:write('usage: lua scripts/test.lua [runtime|luals|all]\n')
        os.exit(2)
    end
end
if #selected == 0 then selected = {'runtime', 'luals'} end

local realExit = os.exit
local exitCodes = {}
---@diagnostic disable-next-line: duplicate-set-field
function os.exit(code)
    exitCodes[#exitCodes + 1] = code or 0
end

for _, name in ipairs(selected) do
    print(name == 'runtime'
        and 'Running SimpleClass runtime test...'
        or 'Running LuaLS plugin test...')
    local ok, err = pcall(dofile, suites[name])
    if not ok then
        exitCodes[#exitCodes + 1] = 1
        io.stderr:write(tostring(err) .. '\n')
    end
end

os.exit = realExit
for _, code in ipairs(exitCodes) do
    if code ~= 0 then realExit(code); return end
end
realExit(0)
