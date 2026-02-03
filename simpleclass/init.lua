local class = require "simpleclass.class"
local super = require "simpleclass.super"

_G.class = class
_G.super = super
_G.Object = class.base
_G.isinstance = class.base.isInstance
_G.issubclass = class.base.isExtends