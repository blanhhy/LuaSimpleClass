local sc = require "simpleclass"

local function expect(actual, expected, message)
    assert(actual == expected, ('%s: expected %s, got %s')
        :format(message, tostring(expected), tostring(actual)))
end

local className = 'RuntimeNameClass_4a82'
local classValue = {}
_G[className] = classValue

local class = sc.class(className) {}
expect(_G[className], classValue,
    'class definition must not replace an external global')
expect(sc._ENV[className], class,
    'class definition must still update the runtime registry')

local classAgain = sc.class(className) {}
expect(_G[className], classValue,
    'redefinition must keep an unrelated external global')
expect(sc._ENV[className], classAgain,
    'class redefinition must update the runtime registry')

local registeredClassName = 'RuntimeRegisteredClass_4a82'
_G[registeredClassName] = nil
local registeredClass = sc.class(registeredClassName) {}
expect(_G[registeredClassName], registeredClass,
    'first class definition must register globally')

local registeredClassAgain = sc.class(registeredClassName) {}
expect(_G[registeredClassName], registeredClassAgain,
    'same-name class redefinition must update the global registration')

local interfaceName = 'RuntimeNameInterface_4a82'
local interfaceValue = {}
_G[interfaceName] = interfaceValue

local iface = sc.interface(interfaceName)
expect(_G[interfaceName], interfaceValue,
    'interface definition must not replace an external global')
expect(sc._ENV[interfaceName], iface,
    'interface definition must update the runtime registry')

local registeredInterfaceName = 'RuntimeRegisteredInterface_4a82'
_G[registeredInterfaceName] = nil
local registeredInterface = sc.interface(registeredInterfaceName)
expect(_G[registeredInterfaceName], registeredInterface,
    'first interface definition must register globally')

local registeredInterfaceAgain = sc.interface(registeredInterfaceName)
expect(_G[registeredInterfaceName], registeredInterfaceAgain,
    'same-name interface redefinition must update the global registration')

return true
