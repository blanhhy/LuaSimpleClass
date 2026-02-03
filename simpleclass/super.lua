local type, setmetatable
    = type, setmetatable

local Super = {
    __index = function(proxy, key)
        local field = proxy.__super[key]
        if "function" ~= type(field) then return field end
        return function(self, ...)
            self = self == proxy and proxy.self or self
            return field(self, ...)
        end
    end
}

local function super(obj)
    return setmetatable({
        self = obj,
        __class = obj.__class,
        __super = obj.__base,
    }, Super)
end

return super