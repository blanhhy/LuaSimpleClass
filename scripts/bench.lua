-- <lua> run bench

local source = debug.getinfo(1, 'S').source:match('^@?(.*)[/\\]') or 'scripts/'
local sep = package.config:sub(1, 1)
local root = source:gsub('[/\\]+$', '')
if root == 'scripts' then
    root = '.'
else
    root = root:gsub('[/\\]scripts$', '')
end

local function ujoin(...) return table.concat({...}, sep) end
local ok, err = pcall(dofile, ujoin(root, "tests", "performance", "bench.lua"))

if not ok then
    io.stderr:write(err)
    os.exit(1)
end
