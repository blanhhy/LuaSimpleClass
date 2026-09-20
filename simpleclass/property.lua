local next, rawset, error
    = next, rawset, error

local function getitem(self, key)
    local claz = self.__class
    local getr = claz.__property[key]
    if not getr then return claz[key] end
    if getr ~= true then return getr(self) end
end

local function setitem(self, k, v)
    local claz = self.__class
    local prop = claz["__property"]
    if not prop[k] then return rawset(self, k, v) end
    local setr = claz[k]
    if setr then return setr(self, v) end
    error("cannot set property."..k..", no setter defined.")
end

return function(this_c, base_c, isTrivial)
    local base_p = base_c["__property"]
    local this_p = this_c["__property"] or (base_p and {})
    this_c["__property"] = this_p
    if not this_p then return end
    if base_p then for k in next, base_p do if not this_p[k] then
        this_p[k] = base_p[k]
        this_c[k] = base_c[k]
    end end end
    this_c.__newindex = this_c.__newindex or setitem
    this_c.__index = isTrivial and getitem or this_c.__index
end
