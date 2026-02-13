---@diagnostic disable: lowercase-global
---@class simpleclass
local M = require "simpleclass.local"

class = M.class
super = M.super
interface = M.interface
cls_type = M.type

local Object = M.object

Object = Object
isinstance = Object.isInstance
issubclass = Object.isExtends

return M