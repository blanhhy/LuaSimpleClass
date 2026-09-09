require "simpleclass"

class "GetClassType_7f31" {
    ---@static
    marker = "class-marker";
}

local object = GetClassType_7f31:new()
-- The default getClass must return GetClassType_7f31.class, not plain class.
print(object:getClass().marker)

class "GetClassChild_7f31" : extends "GetClassType_7f31" {
    ---@static
    childMarker = "child-marker";
}

local child = GetClassChild_7f31:new()
print(child:getClass().childMarker)

class "GetClassOverride_7f31" {
    ---@return string
    getClass = function(self)
        return "custom"
    end;
}

local custom = GetClassOverride_7f31:new()
-- A user override must remain a string-returning method.
print(custom:getClass():sub(1, 1))

class "GetClassOverrideChild_7f31" : extends "GetClassOverride_7f31" {}
local inheritedCustom = GetClassOverrideChild_7f31:new()
print(inheritedCustom:getClass():sub(1, 1))
