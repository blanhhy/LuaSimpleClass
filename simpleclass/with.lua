local searchpath = package.searchpath or function(name, path)
    local module = name:gsub("%.", package.config:sub(1, 1))
    for template in path:gmatch("[^;]+") do
        local filename = template:gsub("%?", module)
        local f = io.open(filename, "r")
        if f then f:close() return filename end
    end
    return nil, "module '" .. name .. "' not found"
end

-- 带参数的导入器在 Lua 中可能应用不广泛  
-- 作为 Fallback 方案，携带一个简单的导入器
local function import_with(name, ...)
    local path2m = assert(searchpath(name, package.path))
    local loader = assert(loadfile(path2m, "bt"))
    local export = loader(name, path2m, ...)
    package.loaded[name] = export == nil and true or export
    return export
end

---@param options M.INIT_OPTIONS
---@return simpleclass
return function(options)
    return import_with(
        "simpleclass"
        , options
    )
end
