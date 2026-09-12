require "simpleclass"

class "DeclaredProperty_7c8a" {
    property.value;
    ['get.value'] = function(self)
        return 1
    end;
}

local declared = DeclaredProperty_7c8a:new()
local value = declared.value
local number = value + 1

class "UndeclaredProperty_7c8a" {
    ['get.value'] = function(self)
        return 1
    end;
}

local undeclared = UndeclaredProperty_7c8a:new()
-- expect: 22:undefined-field
local missing = undeclared.value

class "SetterOnlyProperty_7c8a" {
    ---@field _value number
    property.value;
    ['set.value'] = function(self, value)
        self._value = value
    end;
}

local setterOnly = SetterOnlyProperty_7c8a:new()
setterOnly.value = 1

class "ManualProperty_7c8a" {
    ---@field value string
    property.value;
    ['get.value'] = function(self)
        return 1
    end;
}

local manual = ManualProperty_7c8a:new()
local upper = manual.value:upper()
print(number, missing, upper)
