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
noSetter.value = 8
assert(rawget(noSetter, 'value') == nil,
    'declared property without setter must not create an instance field')
expect(noSetter.value, 4,
    'assignment without setter must not change the property value')

class "RuntimeStaticProperty_4a82" {
    property.value;
    value = 42;
    ["get.value"] = function()
        error('the getter must not override a class field')
    end;
}

local staticField = RuntimeStaticProperty_4a82:new()
expect(staticField.value, 42,
    'a same-name class field must take priority over the getter')

return true
