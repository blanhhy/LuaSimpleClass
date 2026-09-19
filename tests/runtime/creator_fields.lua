-- A class-only import must not treat interface-only creator fields as bases.
local modules = {
    'simpleclass.class',
    'simpleclass.m',
    'simpleclass.object',
    'simpleclass.declare',
}
local saved = {}
for _, name in ipairs(modules) do
    saved[name] = package.loaded[name]
    package.loaded[name] = nil
end

local ok, err = pcall(function()
    local class = require 'simpleclass.class'
    local M = require 'simpleclass.m'
    local creator = class 'RuntimeCreatorFieldsBase_7c8a'

    assert(rawget(M.creator, 'impl') == false)
    assert(rawget(M.creator, 'iCheck') == false)
    assert(rawget(M.creator, 'ifaces') == false)
    assert(rawget(M.creator, 'implements') == false)

    local base = creator {}
    local child = class 'RuntimeCreatorFieldsChild_7c8a'
        :extends 'RuntimeCreatorFieldsBase_7c8a' {}
    assert(base.__classname == 'RuntimeCreatorFieldsBase_7c8a')
    assert(child.__base == base)
end)

for _, name in ipairs(modules) do
    package.loaded[name] = saved[name]
end

assert(ok, err)
return true
