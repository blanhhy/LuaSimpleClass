local type = type
_ENV = nil

-- 类静态不继承：不仅没有这样的必要，还会使实例继承在查找时被迫触发 __index 递归
-- 尤其是 object 及其直接派生类的 __index 是毫无意义的，因为几乎总是 missing
local class_MT = {
    __tostring = function(self) return self.__classname end;
    __call = function(self, ...) return self:new(...) end;
    __metatable = "class";
}

local mm_names = {
    "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__idiv", "__unm",
    "__band", "__bor", "__bxor", "__bnot", "__shl", "__shr", "__eq", "__lt",
    "__le", "__concat", "__len", "__tostring", "__pairs", "__gc", "__close",
    "__newindex", "__call", -- index 特殊处理
}

---@class M : simpleclass
local M = {
    _ENV = {}; ---@type table<string, class>
    _MMS = mm_names;
    _CMT = class_MT;
}

-- 深继承实例迭代 __base 链表
-- 优点：迭代在深继承下比 __index 递归更快，开销可控；有机会针对JIT优化
-- 缺点：原平凡 __index 在访问自有字段时更快（查表），迭代有固定调用开销

---@param this object|class
---@param super? boolean 跳过一层
---@return any
function M.index(this, key, super)
    if not this or key == nil then return end
    local clazz = this.__class or this
    if super then clazz = clazz["__base"] end
    local field
    -- 预判实际 OOP 工程中可能出现的最大继承长度（一般 8 层，这里 12 层）
    -- 使 LuaJIT 现在**可以编译**继承方法查找，大幅提升 LuaJIT 下的运行时性能
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    if not clazz then return end field = clazz[key] if field ~= nil then return field end clazz = clazz["__base"]
    -- 更深的链回落成迭代：只是慢，语义完全一致
    while clazz do
        field = clazz[key]
        if field ~= nil then return field end
        clazz = clazz["__base"]
    end
end

---Get the type of a value, considering classes as special types  
---eg: 
---```lua
---simpleclass.type(Eagle()) => Eagle
---simpleclass.type("Hello") => "string"
---```
---@param val any
---@return class|type
function M.type(val)
    local typ = type(val)
    if typ == "table" and val.__class then
        return val.__class
    end
    return typ
end

---Check if the class extends the base class
---@param this class
---@param base class
---@return boolean
function M.issubclass(this, base)
    while type(this) == "table" do
        if this == base then return true end
        this = this["__base"]
    end
    return false
end

return M