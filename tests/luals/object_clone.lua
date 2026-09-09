local sc = require "simpleclass"
local class = sc.class
local object = sc.object

local CloneProbe_8f31 = class "CloneProbe_8f31" {}
local source = CloneProbe_8f31:new()

local staticCopy = object.clone(source)
local instanceCopy = source:clone()
print(staticCopy, instanceCopy)

-- Both overload forms must check their parameter types.
local badStatic = object.clone(1) -- expect: 13:param-type-mismatch
local badInstance = source:clone("deep") -- expect: 14:param-type-mismatch
print(badStatic, badInstance)

---@param obj CloneProbe_8f31
local function takeCloneProbe_8f31(obj) end

---@param obj object
local function takeObject(obj) end

-- Static clone can preserve the source type.
takeCloneProbe_8f31(staticCopy)
takeObject(staticCopy)

-- Instance clone can return an object at least.
takeCloneProbe_8f31(instanceCopy) -- expect: 28:param-type-mismatch
takeObject(instanceCopy)
