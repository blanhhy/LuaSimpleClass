---@diagnostic disable: lowercase-global
---@class simpleclass
local M = require "simpleclass.local"

M._GLOBAL = true

class = M.class
super = M.super
interface = M.interface
cls_type = M.type

object = M.object ---@type object
isinstance = object.isInstance
issubclass = object.isExtends

return M