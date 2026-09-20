require "simpleclass"

local function expect(actual, expected, message)
    assert(actual == expected, ('%s: expected %s, got %s')
        :format(message, tostring(expected), tostring(actual)))
end

local function catch(err, ...)
    if type(err) ~= "string" then return false end
    for _, kwd in ipairs{...} do
        if not err:find(kwd, 1, true) then return false end
    end
    return true
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
assert(not ok and catch(err, 'cannot set property', 'no setter defined'))
assert(rawget(noSetter, 'value') == nil,
    'declared property without setter must not create an instance field')
expect(noSetter.value, 4,
    'failed assignment without setter must not change the property value')

local _, err1 = pcall(function()
class "RuntimeStaticProperty_4a82" {
    property.value;
    value = 42;
    ["get.value"] = function()
        return "inst"
    end;
}
end)

expect(catch(err1, "bad class definition", "static field", "property"), true,
    'a field cannot be both static field and a property')

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

local customGetterCalls = 0
local customSetterCalls = 0
class "RuntimeCustomPropertyBase_4a82" {
    __init = function(self)
        rawset(self, '_value', 1)
    end;
    __index = function(self, key)
        if key == 'value' then
            customGetterCalls = customGetterCalls + 1
            return rawget(self, '_value') + 100
        end
        return rawget(self, key)
    end;
    __newindex = function(self, key, value)
        if key == 'value' then
            customSetterCalls = customSetterCalls + 1
            return rawset(self, '_value', value * 2)
        end
        return rawset(self, key, value)
    end;
    property.value;
}

class "RuntimeCustomPropertyChild_4a82" : extends "RuntimeCustomPropertyBase_4a82" {}

local customBase = RuntimeCustomPropertyBase_4a82:new()
expect(customBase.value, 101,
    'a base custom getter must handle its own instance')
customBase.value = 3
expect(customBase.value, 106,
    'a base custom setter must handle its own instance')

local customChild = RuntimeCustomPropertyChild_4a82:new()
expect(customChild.value, 101,
    'a child must inherit the base custom getter')
customChild.value = 4
expect(customChild.value, 108,
    'a child must inherit the base custom setter')
assert(customGetterCalls == 4 and customSetterCalls == 2,
    'custom property dispatch should use the inherited base hooks')

local unusedGetterCalls = 0
local unusedSetterCalls = 0
class "RuntimeUnappliedAccessorBase_4a82" {
    __getter = function(self, key)
        unusedGetterCalls = unusedGetterCalls + 1
        return 'base getter: ' .. key
    end;
    __setter = function(self, key, value)
        unusedSetterCalls = unusedSetterCalls + 1
        rawset(self, key, value)
    end;
}

class "RuntimeUnappliedAccessorChild_4a82" : extends "RuntimeUnappliedAccessorBase_4a82" {
    __getter = function()
        unusedGetterCalls = unusedGetterCalls + 1
        return 'child getter'
    end;
    __setter = function(self, key, value)
        unusedSetterCalls = unusedSetterCalls + 1
        rawset(self, key, value)
    end;
    property.value;
}

local unapplied = RuntimeUnappliedAccessorChild_4a82:new()
assert(unapplied.value == nil,
    'a base __getter must not become a child accessor by name lookup')
local setterOk, setterError = pcall(function()
    unapplied.value = 1
end)
assert(not setterOk and catch(setterError, 'cannot set property', 'no setter defined'))
assert(unusedGetterCalls == 0 and unusedSetterCalls == 0,
    'unbound base __getter/__setter must not enter the property inheritance chain')

return true
