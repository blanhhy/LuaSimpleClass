require "simpleclass"

local function expect(actual, expected, message)
    assert(actual == expected, ('%s: expected %s, got %s')
        :format(message, tostring(expected), tostring(actual)))
end

local CanRun = interface "RuntimeCanRun_8b31" {"run"}
local Runner = class "RuntimeRunner_8b31" : impl(CanRun) {
    run = function(self)
        return self
    end;
}

expect(Runner:isImplements(CanRun), true,
    'impl must be an alias of implements')
expect(Runner():isInstance(CanRun), true,
    'instances created through impl must implement the interface')

return true
