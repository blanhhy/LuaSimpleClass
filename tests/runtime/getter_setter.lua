require "simpleclass"

local function expect(actual, expected, message)
    assert(actual == expected, ('%s: expected %s, got %s')
        :format(message, tostring(expected), tostring(actual)))
end

class "RuntimeProperty_4a82" {
    __init = function(self)
        self._value = 1
    end;
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

return true
