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

-- 仅在有属性声明时启用属性访问逻辑，避免影响无关类的性能  
-- 永远自定义 index&newindex 访问器优先，未定义时框架自动实现 getter&setter
return function(this_c, base_c, isTrivial)
    local base_p = base_c["__property"]
    local this_p = this_c["__property"] or (base_p and {})
    this_c["__property"] = this_p
    if not this_p then return end
    if base_p then for k in next, base_p do
        this_p[k] = this_p[k] or base_p[k]
        this_c[k] = this_c[k] or base_c[k]
    end end
    this_c.__newindex = this_c.__newindex or setitem
    this_c.__index = isTrivial and getitem or this_c.__index
end
