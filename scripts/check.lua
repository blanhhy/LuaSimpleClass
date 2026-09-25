-- <lua> run check
-- 获取 lua-language-server 在实际工作区的检查结果

local function trim(s)
    if s == nil then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local is_win = package.config:sub(1, 1) == "\\"
local sep = is_win and "\\" or "/"

local function quote_arg(s)
    s = tostring(s)
    if is_win then
        return '"' .. s:gsub('"', '""') .. '"'
    end
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function which(exe)
    local command
    if package.config:sub(1, 1) == "\\" then
        command = "where.exe " .. quote_arg(exe) .. " 2>nul"
    else
        command = "command -v " .. quote_arg(exe) .. " 2>/dev/null"
    end
    local handle = io.popen(command)
    if not handle then return nil end
    local result = trim(handle:read("*a"))
    handle:close()
    if result == "" then return nil end
    return result
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

local function dir_exists(path)
    if is_win then
        local handle = io.popen('if exist ' .. quote_arg(path) .. ' (echo yes) else (echo no)')
        if handle then
            local result = trim(handle:read("*a"))
            handle:close()
            return result == "yes"
        end
        return false
    else
        local handle = io.popen('test -d ' .. quote_arg(path) .. ' && echo yes || echo no')
        if handle then
            local result = trim(handle:read("*a"))
            handle:close()
            return result == "yes"
        end
        return false
    end
end

local function remove_dir(path)
    if not path then return end
    local command
    if is_win then
        command = 'rmdir /s /q ' .. quote_arg(path) .. ' >nul 2>nul'
    else
        command = 'rm -rf -- ' .. quote_arg(path) .. ' >/dev/null 2>&1'
    end
    os.execute(command)
end

local function find_vscode_extension_luals()
    local is_win = package.config:sub(1, 1) == "\\"
    local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
    local sep = is_win and "\\" or "/"
    local vscode_ext = home .. sep .. ".vscode" .. sep .. "extensions"
    if not dir_exists(vscode_ext) then return nil end
    local luals_exe = is_win and "lua-language-server.exe" or "lua-language-server"
    local pattern = vscode_ext .. sep .. "sumneko.lua-*"
    local ls_cmd = is_win and ('dir /b /ad "' .. pattern .. '" 2>nul') or ('ls -d "' .. pattern .. '" 2>/dev/null')
    local handle = io.popen(ls_cmd)
    if not handle then return nil end
    local luals_path = nil
    for raw_dir_name in handle:lines() do
        local dir_name = trim(raw_dir_name)
        if dir_name ~= "" then
            local candidate = vscode_ext .. sep .. dir_name .. sep .. "server" .. sep .. "bin" .. sep .. luals_exe
            if file_exists(candidate) then luals_path = candidate end
        end
    end
    handle:close()
    return luals_path
end

local function find_workspace_config(root_dir)
    for _, name in ipairs({".luarc.json", ".luarc.lua"}) do
        local path = root_dir .. sep .. name
        if file_exists(path) then return path end
    end
    return nil
end

local function find_vscode_user_settings()
    local appdata = os.getenv("APPDATA") or ""
    if appdata ~= "" then
        local path = appdata .. "\\Code\\User\\settings.json"
        if file_exists(path) then return path end
    end
    local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
    local is_win = package.config:sub(1, 1) == "\\"
    if is_win then
        local path = home .. "\\.vscode\\User\\settings.json"
        if file_exists(path) then return path end
    else
        local path = home .. "/.config/Code/User/settings.json"
        if file_exists(path) then return path end
    end
    return nil
end

local function find_vscode_workspace_settings(root_dir)
    local p = root_dir .. "/.vscode/settings.json"
    if file_exists(p) then return p end
    return nil
end

local function json_stringify(val, indent)
    if val == nil then return "null" end
    local t = type(val)
    if t == "boolean" then return val and "true" or "false" end
    if t == "number" then return tostring(val) end
    if t == "string" then
        local escaped = val:gsub("\\", "\\\\"):gsub('"', '\\"')
            :gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
        return '"' .. escaped .. '"'
    end
    if t == "table" then
        local is_array = #val > 0
        local parts = {}
        local ni = indent and indent .. "  " or ""
        if is_array then
            for i, v in ipairs(val) do
                parts[i] = (indent and ni or "") .. json_stringify(v, ni)
            end
            if #parts == 0 then return "[]" end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. (indent or "") .. "]"
        else
            for k, v in pairs(val) do
                parts[#parts + 1] = (indent and ni or "") .. '"' .. k .. '": ' .. json_stringify(v, ni)
            end
            if #parts == 0 then return "{}" end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. (indent or "") .. "}"
        end
    end
    return "null"
end

local function strip_json_comments(text)
    local out, i, n = {}, 1, #text
    while i <= n do
        local c = text:sub(i, i)
        local next_c = text:sub(i + 1, i + 1)
        if c == '"' then
            local start = i
            i = i + 1
            while i <= n do
                local ch = text:sub(i, i)
                if ch == '\\' then
                    i = i + 2
                elseif ch == '"' then
                    i = i + 1
                    break
                else
                    i = i + 1
                end
            end
            out[#out + 1] = text:sub(start, i - 1)
        elseif c == '/' and next_c == '/' then
            i = i + 2
            while i <= n and text:sub(i, i) ~= '\n' do i = i + 1 end
            if i <= n then out[#out + 1] = '\n'; i = i + 1 end
        elseif c == '/' and next_c == '*' then
            i = i + 2
            while i <= n - 1 and text:sub(i, i + 1) ~= '*/' do
                if text:sub(i, i) == '\n' then out[#out + 1] = '\n' end
                i = i + 1
            end
            i = math.min(i + 2, n + 1)
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return table.concat(out)
end

local function find_matching_brace(text, open_pos)
    local depth = 0
    local i = open_pos
    local n = #text
    while i <= n do
        local c = text:sub(i, i)
        if c == '{' then depth = depth + 1
        elseif c == '}' then
            depth = depth - 1
            if depth == 0 then return i end
        elseif c == '[' then depth = depth + 1
        elseif c == ']' then
            depth = depth - 1
            if depth == 0 then return i end
        elseif c == '"' then
            i = i + 1
            while i <= n and text:sub(i, i) ~= '"' do
                if text:sub(i, i) == '\\' then i = i + 1 end
                i = i + 1
            end
        elseif c == "'" then
            i = i + 1
            while i <= n and text:sub(i, i) ~= "'" do
                if text:sub(i, i) == '\\' then i = i + 1 end
                i = i + 1
            end
        end
        i = i + 1
    end
    return nil
end

local function parse_simple_value(val_str)
    val_str = trim(val_str)
    if val_str == "null" then return nil end
    if val_str == "true" then return true end
    if val_str == "false" then return false end
    if val_str:match('^-?%d+%.?%d*$') then return tonumber(val_str) end
    if val_str:match('^"') then
        local inner = val_str:gsub('^"', ''):gsub('"$', '')
        inner = inner:gsub('\\"', '"'):gsub("\\\\", "\\")
            :gsub("\\n", "\n"):gsub("\\r", "\r"):gsub("\\t", "\t")
        return inner
    end
    return val_str
end

-- 递归解析 pos 处的一个 JSON 值，返回 value, nextPos（nextPos 指向该值之后）。
-- 支持字符串/数字/布尔/数组/嵌套对象，正确处理字符串转义与注释不在此层处理。
local function parse_value_at(text, pos)
    local n = #text
    local i = pos
    while i <= n and text:sub(i, i):match('%s') do i = i + 1 end
    local c = text:sub(i, i)
    if c == '"' then
        local j = i + 1
        while j <= n do
            local ch = text:sub(j, j)
            if ch == '\\' then
                j = j + 1
            elseif ch == '"' then
                break
            end
            j = j + 1
        end
        return parse_simple_value(text:sub(i, j)), j + 1
    elseif c == '[' then
        local close = find_matching_brace(text, i)
        local arr, p = {}, i + 1
        while p < close do
            while p < close and (text:sub(p, p):match('%s') or text:sub(p, p) == ',') do p = p + 1 end
            if p >= close then break end
            local v, nxt = parse_value_at(text, p)
            arr[#arr + 1] = v
            p = nxt
        end
        return arr, close + 1
    elseif c == '{' then
        local close = find_matching_brace(text, i)
        local obj, p = {}, i + 1
        while p < close do
            while p < close and text:sub(p, p):match('%s') do p = p + 1 end
            if p >= close then break end
            if text:sub(p, p) == '"' then
                local k, kend = parse_value_at(text, p)
                p = kend
                while p < close and text:sub(p, p):match('%s') do p = p + 1 end
                if p < close and text:sub(p, p) == ':' then p = p + 1 end
                local v, nxt = parse_value_at(text, p)
                if v ~= nil then
                    ---@type table|string|number|boolean
                    local val = v
                    obj[tostring(k)] = val
                end
                p = nxt
            else
                p = p + 1
            end
        end
        return obj, close + 1
    elseif c == 't' and text:sub(i, i + 3) == 'true' then
        return true, i + 4
    elseif c == 'f' and text:sub(i, i + 4) == 'false' then
        return false, i + 5
    elseif c == 'n' and text:sub(i, i + 3) == 'null' then
        return nil, i + 4
    else
        local j = i
        while j <= n and not text:sub(j, j):match('[%s,]') do
            if text:sub(j, j) == '}' or text:sub(j, j) == ']' then break end
            j = j + 1
        end
        local tok = trim(text:sub(i, j - 1))
        return (tok ~= '' and (tonumber(tok) or tok)) or nil, j
    end
end

local function extract_settings(settings_path, prefix)
    if not settings_path or not file_exists(settings_path) then return nil end
    local f = io.open(settings_path, "r")
    if not f then return nil end
    local content = strip_json_comments(f:read("*a"))
    f:close()

    local config = {}

    local search_start = 1
    while true do
        local key_start
        if prefix then
            key_start = content:find('"' .. prefix .. "%.", search_start)
        else
            key_start = content:find('"', search_start)
        end
        if not key_start then break end

        local key_end = content:find('"', key_start + 1)
        if not key_end then break end
        local key = content:sub(key_start + 1, key_end - 1)

        if prefix and not key:find("^" .. prefix .. "%.") then
            search_start = key_end + 1
        else
            local colon_pos = content:find(':', key_end)
            local search_end = #content
            if colon_pos then
                local next_comma = content:find(',', key_start)
                local next_brace = content:find('}', key_start)
                local next_newline = content:find('\n', key_start)
                for _, p in ipairs({next_comma, next_brace, next_newline}) do
                    if p and p < search_end and p > key_start then search_end = p end
                end
            end

            if not colon_pos or colon_pos > search_end then
                search_start = key_end + 1
            else
                local val_start = colon_pos + 1
                while val_start <= #content and content:sub(val_start, val_start):match('%s') do
                    val_start = val_start + 1
                end

                local c = content:sub(val_start, val_start)
                local parts = {}
                for part in (prefix and key:gsub(prefix .. "%.", "") or key):gmatch("[^%.]+") do
                    parts[#parts + 1] = part
                end

                local tbl = config
                for i = 1, #parts - 1 do
                    local p = parts[i]
                    if not tbl[p] then tbl[p] = {} end
                    tbl = tbl[p]
                end

                if c == '[' then
                    local v, nxt = parse_value_at(content, val_start)
                    tbl[parts[#parts]] = v
                    search_start = nxt
                elseif c == '{' then
                    local v, nxt = parse_value_at(content, val_start)
                    if type(v) == 'table' then
                        local target = tbl[parts[#parts]]
                        if type(target) == 'table' then
                            -- 浅合并到已存在的成员（同键覆盖）
                            for kk, vv in pairs(v) do target[kk] = vv end
                        else
                            tbl[parts[#parts]] = v
                        end
                    else
                        tbl[parts[#parts]] = v
                    end
                    search_start = nxt
                elseif c == '"' or c == 't' or c == 'f' or c == 'n' or c == '-' or c:match('%d') then
                    local end_pos
                    if c == '"' then
                        -- 字符串值：推进到闭引号之后，避免读到值内部的下一个键
                        end_pos = val_start + 1
                        while end_pos <= #content do
                            local ch = content:sub(end_pos, end_pos)
                            if ch == '\\' then
                                end_pos = end_pos + 1
                            elseif ch == '"' then
                                end_pos = end_pos + 1
                                break
                            end
                            end_pos = end_pos + 1
                        end
                    else
                        end_pos = #content
                        local next_comma = content:find(',', val_start)
                        local next_brace = content:find('}', val_start)
                        local next_newline = content:find('\n', val_start)
                        for _, p in ipairs({next_comma, next_brace, next_newline}) do
                            if p and p < end_pos and p > val_start then end_pos = p end
                        end
                    end
                    local val_str = content:sub(val_start, end_pos - 1)
                    tbl[parts[#parts]] = parse_simple_value(val_str)
                    search_start = end_pos
                else
                    search_start = val_start + 1
                end
            end
        end
    end

    local has_config = false
    for _ in pairs(config) do has_config = true; break end
    if not has_config then return nil end
    return config
end

local function deep_merge(base, override)
    if not override then return base end
    if not base then return override end
    local function is_array(value)
        if type(value) ~= "table" then return false end
        for key in pairs(value) do
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
                return false
            end
        end
        return true
    end
    for k, v in pairs(override) do
        if type(v) == "table" and type(base[k]) == "table"
            and not is_array(v) and not is_array(base[k]) then
            deep_merge(base[k], v)
        else
            base[k] = v
        end
    end
    return base
end

local function is_absolute_path(path)
    if type(path) ~= "string" then return false end
    return is_win
        and (path:match("^%a:[/\\]") or path:match("^[/\\]"))
        or (not is_win and path:sub(1, 1) == "/")
end

local function absolutize_path(path, root_dir)
    if type(path) ~= "string" or path == "" or is_absolute_path(path) then
        return path
    end
    return root_dir .. sep .. path:gsub("^%.[/\\]", "")
end

local function absolutize_path_list(value, root_dir)
    if type(value) == "string" then return absolutize_path(value, root_dir) end
    if type(value) ~= "table" then return value end
    for i, path in ipairs(value) do
        value[i] = absolutize_path(path, root_dir)
    end
    return value
end

local function absolutize_config_paths(config, root_dir)
    if type(config) ~= "table" then return end
    local runtime = config.runtime
    if type(runtime) == "table" then
        runtime.plugin = absolutize_path_list(runtime.plugin, root_dir)
    end
    local workspace = config.workspace
    if type(workspace) == "table" then
        workspace.library = absolutize_path_list(workspace.library, root_dir)
        workspace.ignoreDir = absolutize_path_list(workspace.ignoreDir, root_dir)
    end
end

local function generate_temp_config(project_settings, user_settings, workspace_settings)
    local merged = {}

    if project_settings then
        deep_merge(merged, project_settings)
    end

    if user_settings then
        deep_merge(merged, user_settings)
    end

    if workspace_settings then
        deep_merge(merged, workspace_settings)
    end

    local has_config = false
    for _ in pairs(merged) do has_config = true; break end
    if not has_config then return nil end

    local temp_path = os.tmpname()
    os.remove(temp_path)
    
    if is_win then
        os.execute('if not exist ' .. quote_arg(temp_path) .. ' mkdir ' .. quote_arg(temp_path))
    else
        os.execute('mkdir -p ' .. quote_arg(temp_path))
    end

    if not dir_exists(temp_path) then
        remove_dir(temp_path)
        return nil
    end

    local luarc_path = temp_path .. sep .. ".luarc.json"
    local f = io.open(luarc_path, "w")
    if not f then
        remove_dir(temp_path)
        return nil
    end
    local ok = pcall(function()
        f:write(json_stringify(merged) .. "\n")
    end)
    f:close()
    if not ok then
        remove_dir(temp_path)
        return nil
    end

    return temp_path
end

local source = debug.getinfo(1, "S").source
local script_dir = source and source:match("@?(.*)[/\\]scripts[/\\]") or ""
local root_dir = arg[1] or (script_dir ~= "" and script_dir or ".")
if not is_absolute_path(root_dir) then
    local handle = io.popen(is_win and "cd" or "pwd")
    local cwd = handle and trim(handle:read("*a")) or "."
    if handle then handle:close() end
    root_dir = cwd .. sep .. root_dir
end

local luals = os.getenv("LUA_LS")
    or find_vscode_extension_luals()
    or which("lua-language-server")
    or which("lua-language-server.exe")
    or which("lua_ls")
    or which("lua-language-server.cmd")

if not luals then
    io.stderr:write("lua-language-server not found. Please add it to PATH or set LUA_LS environment variable.\n")
    io.stderr:write("You can also install the sumneko.lua extension for VSCode.\n")
    os.exit(1)
end

print("lua-language-server: " .. luals)

local project_config = find_workspace_config(root_dir)
local user_settings_path = find_vscode_user_settings()
local workspace_settings_path = find_vscode_workspace_settings(root_dir)

local project_settings = nil
local user_settings = nil
local workspace_settings = nil

if project_config then
    print("Project configuration: " .. project_config)
    project_settings = extract_settings(project_config, nil)
    absolutize_config_paths(project_settings, root_dir)
end

if user_settings_path then
    print("VSCode User settings: " .. user_settings_path)
    user_settings = extract_settings(user_settings_path, "Lua")
    absolutize_config_paths(user_settings, root_dir)
end

if workspace_settings_path then
    print("VSCode Workspace settings: " .. workspace_settings_path)
    workspace_settings = extract_settings(workspace_settings_path, "Lua")
    absolutize_config_paths(workspace_settings, root_dir)
end

local temp_config_dir = generate_temp_config(project_settings, user_settings, workspace_settings)

if temp_config_dir then
    print("Generated merged configuration: " .. temp_config_dir .. "/.luarc.json")
end

local cmd_parts = { quote_arg(luals) }

if temp_config_dir then
    local luarc_file = temp_config_dir .. (package.config:sub(1, 1) == "\\" and "\\.luarc.json" or "/.luarc.json")
    cmd_parts[#cmd_parts + 1] = "--configpath"
    cmd_parts[#cmd_parts + 1] = quote_arg(luarc_file)
else
    if project_config then
        cmd_parts[#cmd_parts + 1] = "--configpath"
        cmd_parts[#cmd_parts + 1] = quote_arg(project_config)
    end
end

cmd_parts[#cmd_parts + 1] = "--check"
cmd_parts[#cmd_parts + 1] = quote_arg(root_dir)

local cmd = table.concat(cmd_parts, " ")
if is_win then cmd = "call " .. cmd end
print("Executing command: " .. cmd)
print("---")

local handle = io.popen(cmd .. " 2>&1", "r")
if not handle then
    remove_dir(temp_config_dir)
    io.stderr:write("failed to start lua-language-server.\n")
    os.exit(1)
end
local output = handle:read("*a")
local process_ok, process_reason, process_code = handle:close()
remove_dir(temp_config_dir)

local exited_ok = process_ok == true
    or (type(process_ok) == "number" and process_ok == 0)
    or process_code == 0
local has_diagnostic = output and output:match("%.lua:%d+:%d+%s+%[[^]]+%]")

if output and output ~= "" then
    print(output)
end

if not exited_ok then
    io.stderr:write(("lua-language-server failed (%s, %s).\n"):
        format(tostring(process_reason), tostring(process_code)))
    os.exit(1)
end

if has_diagnostic then os.exit(1) end

print("lua-language-server check passed: no diagnostics found.")
os.exit(0)
