local sc = require "simpleclass"
local alias = sc.alias

local function catch(err, ...)
    if type(err) ~= "string" then return false end
    for _, keyword in ipairs{...} do
        if not err:find(keyword, 1, true) then return false end
    end
    return true
end

class "RuntimeAlias_5a21" {
    fly = function(self)
        return self
    end;
    alias.move:fly(),
}

local instance = RuntimeAlias_5a21:new()
assert(RuntimeAlias_5a21.move == RuntimeAlias_5a21.fly)
assert(instance:move() == instance)

local ok, err = pcall(function()
    class "RuntimeAliasMissing_5a21" {
        alias.missing:doesNotExist(),
    }
end)
assert(not ok and catch(err, 'bad alias', 'doesNotExist', 'not found'))

ok, err = pcall(function()
    class "RuntimeAliasChain_5a21" {
        target = function(self) return self end;
        alias.first:target():second(),
    }
end)
assert(not ok and catch(err, 'bad alias', 'first', 'target', 'cannot chain', 'second'))

local aliasRef
do
    local creator = class "RuntimeAliasCleanup_5a21"
    local body = {
        target = function(self) return self end;
        alias.move:target(),
    }
    aliasRef = setmetatable({body[1]}, {__mode = "v"})
    creator(body)
    assert(body[1] == nil)
end
collectgarbage("collect")
collectgarbage("collect")
assert(aliasRef[1] == nil)

return true
