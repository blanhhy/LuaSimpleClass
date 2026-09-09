local src = debug.getinfo(1, 'S').source:match('^@?(.*)[/\\]') or 'tests/'
local sep = package.config:sub(1, 1)
src = src:gsub('[/\\]+$', '')

local exit = os.exit
local exitCodes = {}

---@diagnostic disable-next-line: duplicate-set-field
function os.exit(code)
    table.insert(exitCodes, code)
end

print "Running SimpleClass runtime test..."
dofile(src .. sep .. 'runtime' .. sep .. 'run.lua')
print "Running LuaLS plugin test..."
dofile(src .. sep .. 'luals' .. sep .. 'run.lua')

for _, code in ipairs(exitCodes) do
    if code ~= 0 then
        exit(code)
    end
end

exit(0)
