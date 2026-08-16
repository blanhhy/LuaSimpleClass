-- 输出 simpleclass DSL 解析后的结果

local plugin = {
    ".luals/simpleclass.plugin.lua";
    "../.luals/simpleclass.plugin.lua";
}

---@class parse.lua.args
---@field file    string? Path to the input file.
---@field text    string? Text to parse.
---@field output  string? Path to the output file. Default is stdout.
---@field diff    boolean? Whether to show diffs only. Default is false.
---@field lines   integer? Context lines to show in diffs. Default is 3.
local args = {}

local i = 1
while i <= #arg do
    if arg[i] == "--file" or arg[i] == "-f" then
        args.file = arg[i + 1]; i = i + 2
    elseif arg[i] == "--text" or arg[i] == "-t" then
        args.text = arg[i + 1]; i = i + 2
    elseif arg[i] == "--output" or arg[i] == "-o" then
        args.output = arg[i + 1]; i = i + 2
    elseif arg[i] == "--diff" or arg[i] == "-d" then
        args.diff = true; i = i + 1
    elseif arg[i] == "--lines" or arg[i] == "-l" then
        args.lines = tonumber(arg[i + 1]) or 3; i = i + 2
    else
        i = i + 1
    end
end

local i = 1
repeat
    dofile(plugin[i])
    i = i + 1
until OnSetText or i > #plugin

if not OnSetText then
    print("Error: plugin not found.")
    os.exit(1)
end

local text
if args.file then
    local f = io.open(args.file, "r")
    if not f then
        print("Error: Cannot open file: " .. args.file)
        os.exit(1)
    end
    text = f:read("*a")
    f:close()
elseif args.text then
    text = args.text
else
    local f = io.open("demo.lua", "r")
    if f then
        text = f:read("*a")
        f:close()
    else
        print("Error: No input specified and demo.lua not found")
        os.exit(1)
    end
end

local diffs = OnSetText("test", text)

if not diffs or #diffs == 0 then
    print("No diffs generated")
    os.exit(0)
end

if args.diff then
    local lines = args.lines or 3
    table.sort(diffs, function(a, b) return a.start < b.start end)
    for idx, d in ipairs(diffs) do
        print(string.format("=== Diff %d (start=%d, finish=%d) ===", idx, d.start, d.finish))
        local ctxStart = math.max(1, d.start - lines)
        local ctxEnd = math.min(#text, d.finish + lines)
        local before = text:sub(ctxStart, d.start - 1)
        local after = text:sub(d.finish + 1, ctxEnd)
        if before ~= "" then
            print("  [lines] " .. before:gsub("\n", "\\n"))
        end
        print("  [+insert] " .. d.text:gsub("\n", "\\n"))
        if after ~= "" then
            print("  [lines] " .. after:gsub("\n", "\\n"))
        end
        print()
    end
else
    table.sort(diffs, function(a, b) return a.start > b.start end)
    for _, d in ipairs(diffs) do
        text = text:sub(1, d.finish) .. d.text .. text:sub(d.start, #text)
    end
    if args.output then
        local f = io.open(args.output, "w")
        if f then
            f:write(text)
            f:close()
            print("Written to: " .. args.output)
        else
            print("Error: Cannot open output file: " .. args.output)
            os.exit(1)
        end
    else
        print(text)
    end
end