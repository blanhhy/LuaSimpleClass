require "simpleclass"

local function expect(actual, expected, message)
    assert(actual == expected, ('%s: expected %s, got %s')
        :format(message, tostring(expected), tostring(actual)))
end

class "RuntimeProperty_4a82" {
    __init = function(self)
        self._value = 1
    end;
    property.value;
    ["get.value"] = function(self)
        return self._value
    end;
    ["set.value"] = function(self, value)
        self._value = value * 2
    end;
}

local obj = RuntimeProperty_4a82:new()
expect(obj.value, 1, 'getter initial value')

obj.value = 3
expect(obj.value, 6, 'setter must preserve getter semantics')
assert(rawget(obj, 'value') == nil,
    'setter must not create a raw field that bypasses the getter')

obj._value = 9
expect(obj.value, 9, 'getter must read the backing field')

class "RuntimeDeclaredProperty_4a82" {
    __init = function(self)
        self._value = 4
    end;
    property.value;
    ["get.value"] = function(self)
        return self._value
    end;
}

local noSetter = RuntimeDeclaredProperty_4a82:new()
expect(noSetter.value, 4, 'declared property getter without setter')
local ok, err = pcall(function()
    noSetter.value = 8
end)
assert(not ok and tostring(err):match('cannot set property%.value, no setter defined'))
assert(rawget(noSetter, 'value') == nil,
    'declared property without setter must not create an instance field')
expect(noSetter.value, 4,
    'failed assignment without setter must not change the property value')

class "RuntimeStaticProperty_4a82" {
    property.value;
    value = 42;
    ["get.value"] = function()
        return "inst"
    end;
}

local staticField = RuntimeStaticProperty_4a82:new()
expect(staticField.value, "inst",
    'a same-name static field must not take priority over the instance property')

class "RuntimeSetterOnlyProperty_4a82" {
    property.value;
    ["set.value"] = function(self, value)
        self._value = value * 2
    end;
}

local setterOnly = RuntimeSetterOnlyProperty_4a82:new()
setterOnly.value = 5
expect(setterOnly._value, 10,
    'a setter-only property must route assignment through the setter')
assert(rawget(setterOnly, 'value') == nil,
    'a setter-only property must not create a raw field')

class "RuntimeInheritedPropertyBase_4a82" {
    __init = function(self)
        self._value = 2
    end;
    property.value;
    ["get.value"] = function(self)
        return self._value
    end;
    ["set.value"] = function(self, value)
        self._value = value * 2
    end;
}

class "RuntimeInheritedPropertyChild_4a82" : extends "RuntimeInheritedPropertyBase_4a82" {
    property.extra;
    ["get.extra"] = function()
        return "child"
    end;
}

local inherited = RuntimeInheritedPropertyChild_4a82:new()
expect(inherited.value, 2,
    'a child must find an inherited getter through the class index')
inherited.value = 5
expect(inherited._value, 10,
    'a child must find an inherited setter through the class index')
expect(inherited.extra, "child",
    'a child must retain its own declared property')

return true
