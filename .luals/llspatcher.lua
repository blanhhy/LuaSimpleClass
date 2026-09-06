-- Optional patcher for LuaLS.
-- This relies on LuaLS VM internals and is intentionally opt-in per function.

local ok_vm, vm    = pcall(require, 'vm')
local ok_gd, guide = pcall(require, 'parser.guide')

---@class llspatcher
local M = {}

if not ok_vm or not ok_gd then
    function M.apply() end
    return M
end

M.vm = vm
M.guide = guide

---Declare the type requirement for a patch.
---@param vt_list [any, type, any, type, any, type]
function M.t_require(vt_list)
    if not vt_list or #vt_list == 0 then
        return true
    end
    for i = 1, #vt_list, 2 do
        local v = vt_list[i]
        local t = vt_list[i+1]
        if type(v) ~= t then
            return false
        end
    end
    return true
end

---Apply a patch. This is a no-op if the patch is already applied.  
-- Patch must exist in `patches` directory.
---@param name string
---@return boolean ok
---@return string? err if failed.
function M.apply(name)
    if type(name) ~= 'string' or name == '' then
        return false
        , ("Invalid patch name '%s'")
        : format(name)
    end

    local state = vm.__simpleclass_patcher_state

    if not state then
        state = {}
        vm.__simpleclass_patcher_state = state
    end

    if state[name] then
        return true
    end

    local rq_ok, patch = pcall(require, "patches."..name)
    state[name] = {}

    if not rq_ok then
        state[name] = false
        return false
        , ("Failed to require patch '%s'")
        : format(name)
    end

    local do_ok, pt_ok, err = pcall(patch, M, state[name])

    if not do_ok then
        state[name] = false
        return false
        , ("Error applying patch '%s': %s")
        : format(name, pt_ok)
    end

    if not pt_ok then
        state[name] = false
        return false
        , ("Failed to apply patch '%s': %s")
        : format(name, err)
    end

    if not state[name] or next(state[name]) == nil then
        state[name] = true
    end

    return true
end

return M
