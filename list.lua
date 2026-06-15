---@diagnostic disable: deprecated
if not class then
    require "simpleclass"
end

-- 仿 Python 的 list 类

local isJIT = pcall(require, "jit")
local is5_5 = _VERSION >= "Lua 5.5"
local table_new, table_clear

if isJIT then
    table_new = require "table.new"
    table_clear = require "table.clear"
end

if is5_5 then
    table_new = table.create
end

local Int = math.floor
local type, tostring, setmetatable = type, tostring, setmetatable
local insert, concat, remove = table.insert, table.concat, table.remove
local unpack = table.unpack or unpack

local isinstance, cls_type = isinstance, cls_type

class "list" {
    -- 静态属性
    ---@static
    chkidxEnabled = true; -- 索引检查开关, 默认开启

    -- 静态方法
    ---@static
    ---@param lim number
    ---@param length? integer 如果提供了 length, 返回值会被规范为正向索引
    ---@return integer index 索引是一个在 [1, lim] 范围内的整数
    chkidx = function(index, lim, length)
        if not list.chkidxEnabled then return index end
        local err = (
            (type(index) ~= "number" or Int(index) ~= index) and
            ("<integer> expected, got <%s>."):format(cls_type(index))
        ) or (
            (index == 0 or index > lim or -index > lim) and
            "list index out of range"
        )
        if err then error(err, 3) end
        if length and index < 0 then return index + 1 + length end
        return index
    end;

    ---@static
    ---@param length integer
    ---@param value? any
    -- 创建一个指定长度的数组, 并填充默认值
    create = function(length, value)
        if nil == value then value = 0 end
        length = list.chkidx(length, math.huge)

        local arr = list:_newContainter(length)

        for i = 1, length do
            arr[i] = value
        end

        return arr
    end;

    -- 构造方法
    -- 由于 jit 和 5.5 情况下有预分配空间的需求, 所以直接重写了 new, 没有用 __init
    -- 可以从参数列表或已有的数组来创建数组, 也可以创建空数组
    ---@Override
    ---@Classmethod
    new = function(self, ...)
        local nargs = select('#', ...)

        if nargs == 0 then
            return setmetatable({__class = self, length = 0}, self)
        end

        local array = nargs == 1 and type(...) == "table" and (...) or {...}
        local newArr

        if isJIT or is5_5 then
            newArr = table_new(#array, 2)
            newArr.__class = self
            setmetatable(newArr, self)
        else
            newArr = setmetatable({__class = self}, self)
        end

        local count = 0

        for i, v in ipairs(array) do
            newArr[i] = v
            count = i
        end

        newArr.length = count
        return newArr
    end;

    -- 内部构造方法
    -- 产生一个空容器, 内部使用, 必须立即填充值
    ---@Classmethod
    _newContainter = function(self, length)
        local newArr

        if isJIT then
            newArr = table_new(length, 2)
            newArr.__class = self
            setmetatable(newArr, self)
        else
            newArr = setmetatable({__class = self}, self)
        end

        newArr.length = length
        return newArr
    end;

    -- 基本操作方法

    -- 在尾部追加元素
    append = function(self, value)
        if nil == value then
            error("Cannot add nil into a list", 2)
        end
        self.length = self.length + 1
        self[self.length] = value
    end;

    -- 向指定索引处插入元素
    ---@param index? integer 默认在数组末尾
    insert = function(self, index, value)
        index = index and list.chkidx(index, self.length + 1, self.length) or self.length + 1
        if nil == value then
            error("Cannot add nil into a list", 2)
        end
        self.length = self.length + 1
        return insert(self, index, value)
    end;

    -- 弹出指定索引的元素, 返回其值
    ---@param index? integer 默认在数组末尾
    pop = function(self, index)
        index = index and list.chkidx(index, self.length, self.length) or self.length
        self.length = self.length - 1
        return remove(self, index)
    end;

    -- 移除指定值, 只移除第一个, 返回其原来的索引
    remove = function(self, value)
        if nil == value then
            error("non-nil value expected.", 2)
        end
        for i = 1, self.length do
            if value == self[i] then
                remove(self, i)
                self.length = self.length - 1
                return i
            end
        end
        return nil
    end;

    -- 移除指定值, 只移除最后一个, 返回其原来的索引
    removeLast = function(self, value)
        if nil == value then
            error("non-nil value expected.", 2)
        end
        for i = self.length, 1, -1 do
            if value == self[i] then
                remove(self, i)
                self.length = self.length - 1
                return i
            end
        end
        return nil
    end;

    -- 移除指定值, 移除所有, 返回被移除的个数
    removeAll = function(self, value)
        if nil == value then
            error("non-nil value expected.", 2)
        end
        local old_length = self.length
        for i = self.length, 1, -1 do
            if value == self[i] then
                remove(self, i)
                self.length = self.length - 1
            end
        end
        return old_length - self.length
    end;

    -- 清空数组, 长度归零
    clear = function(self)
        if isJIT then
            table_clear(self, self.length) -- 保留元表
            self.__class = list -- 重绑class
            self.length = 0 -- 重置length
            return self
        end
        for i = 1, self.length do
            self[i] = nil
        end
        self.length = 0
        return self
    end;

    -- 用另一个数组扩展当前数组
    ---@param array table
    extend = function(self, array)
        if type(array) ~= "table" then
            error(("<table?> expected, got <%s>."):format(cls_type(array)), 2)
        end
        local length = self.length
        local count = 0
        for i, v in ipairs(array) do
            self[length + i] = v
            count = i
        end
        self.length = length + count
        return self
    end;

    -- 填充数组的某块区域为指定值
    fill = function(self, value, i, j)
        if nil == value then
            error("Cannot add nil into a list", 2)
        end
        i = i and list.chkidx(i, self.length, self.length) or 1
        j = j and list.chkidx(j, self.length, self.length) or self.length
        for o = i, j do
            self[o] = value
        end
        return self
    end;

    -- 原地反转数组
    ---@param i? integer
    ---@param j? integer
    reverse = function(self, i, j)
        i = i and list.chkidx(i, self.length, self.length) or 1
        j = j and list.chkidx(j, self.length, self.length) or self.length
        while i < j do
            self[i], self[j] = self[j], self[i]
            i = i + 1
            j = j - 1
        end
        return self
    end;

    -- 查找方法

    -- 找到第一个匹配的索引, 返回 nil 则表示没有找到
    index = function(self, value)
        if nil == value then
            error("non-nil value expected.", 2)
        end
        for i = 1, self.length do
            if value == self[i] then return i end
        end
        return nil
    end;

    -- 找到最后一个匹配的索引, 返回 nil 则表示没有找到
    lastIndex = function(self, value)
        if nil == value then
            error("non-nil value expected.", 2)
        end
        for i = self.length, 1, -1 do
            if value == self[i] then return i end
        end
        return nil
    end;

    -- 找到所有匹配的索引, 返回值是包含所有索引的 list 对象
    indices = function(self, value)
        if nil == value then
            error("non-nil value expected.", 2)
        end
        local indices = setmetatable({__class = list}, list) -- 为了简化调用栈, 直接用原始方式了
        local count = 0
        for i = 1, self.length do
            if value == self[i] then
                count = count + 1
                indices[count] = i
            end
        end
        indices.length = count
        return indices
    end;

    -- 统计一个值出现的次数
    count = function(self, value)
        if self.length == 0 or nil == value then return 0 end
        local count = 0
        for i = 1, self.length do
            if value == self[i] then
                count = count + 1
            end
        end
        return count
    end;

    -- 切片和复制

    -- 复制数组, 是直接以自己为参数 new 一个新的
    copy = function(self)
        return list.new(self)
    end;

    -- 数组切片, 得到一个新的数组
    ---@param i? integer 起始索引
    ---@param j? integer 结束索引
    ---@param step? integer 切片的步长
    sub = function(self, i, j, step)
        i = i and list.chkidx(i, self.length, self.length) or 1
        j = j and list.chkidx(j, self.length, self.length) or self.length
        step = step and list.chkidx(step, math.huge) or 1

        local slice = setmetatable({__class = list}, list) -- 内部构造函数, 为了下面手动初始化
        local count = 0

        for o = i, j, step do
            count = count + 1
            slice[count] = self[o]
        end

        slice.length = count

        return slice
    end;

    -- 复制数组 n 次, 得到一个新的数组
    ---@param n integer
    rep = function(self, n)
        if type(n) ~= "number" or Int(n) ~= n then
            error(("<integer> expected, got <%s>."):format(n))
        end

        if n <= 0 then return list() end

        local newArr = list:_newContainter(self.length * n)

        for i = 1, self.length do
            for j = 0, n - 1 do
                newArr[i + j * self.length] = self[i]
            end
        end

        return newArr
    end;

    -- 获取去重数组
    unique = function(self)
        local unique = setmetatable({__class = list}, list)
        local seen = {}
        local count = 0
        for i = 1, self.length do
            local value = self[i]
            if not seen[value] then
                seen[value] = true
                count = count + 1
                unique[count] = value
            end
        end
        unique.length = count
        return unique
    end;

    -- 获取值的集合, 返回一个 table
    -- 键是所有的值, 值是它们第一次出现的索引
    values = function(self)
        local values = {}
        for i = self.length, 1, -1 do
            values[self[i]] = i
        end
        return values
    end;

    -- 统计方法

    -- 获取数组中的最大值, 要求值可以互相比较
    max = function(self)
        local max = self[1]
        if self.length < 2 then return max end
        for i = 2, self.length do
            max = max < self[i] and self[i] or max
        end
        return max
    end;

    -- 获取数组中的最小值, 要求值可以互相比较
    min = function(self)
        local min = self[1]
        if self.length < 2 then return min end
        for i = 2, self.length do
            min = min > self[i] and self[i] or min
        end
        return min
    end;

    -- 转换和比较方法

    ---@Override
    __tostring = function(self)
        local strList = {}
        for i = 1, self.length do
            strList[i] = tostring(self[i])
        end
        return '{'..concat(strList, ", ")..'}'
    end;

    -- 元方法

    -- 连接两个数组, 得到一个新的数组
    __concat = function(arr1, arr2)
        if not isinstance(arr1, list) or not isinstance(arr2, list) then
            error(("attempt to concat list with a %s value")
                :format(isinstance(arr1, list) and cls_type(arr2) or cls_type(arr1)), 2)
        end

        local newArr = list:_newContainter(arr1.length + arr2.length)

        for i = 1, arr1.length do
            newArr[i] = arr1[i]
        end

        for i = 1, arr2.length do
            newArr[arr1.length + i] = arr2[i]
        end

        return newArr
    end;

    -- 类 Python 的数组重复操作
    -- eg: arr = list(1, 2) * 3
    __mul = function(left, right)
        if not isinstance(left, list) then
            return right:rep(left)
        end
        return left:rep(right)
    end;

    -- 重载 < 和 > 符号, 基于数组长度和第一个不等元素
    __lt = function(left, right)
        if type(left) ~= "table" or type(right) ~= "table" then -- 允许list和普通的数组比较
            error(("attempt to compare list with a %s value")
                :format(type(left) == "table" and cls_type(right) or cls_type(left)), 2)
        end
        local len1, len2 = left.length or #left, right.length or #right
        if len1 ~= len2 then return len1 < len2 end
        for i = 1, len1 do
            if left[i] < right[i] then return true end
            if left[i] > right[i] then return false end
        end
        return false
    end;

    -- 重载 <= 和 >= 符号, 基于数组长度和第一个不等元素
    __le = function(left, right)
        if type(left) ~= "table" or type(right) ~= "table" then -- 允许list和普通的数组比较
            error(("attempt to compare list with a %s value")
                :format(type(left) == "table" and cls_type(right) or cls_type(left)), 2)
        end
        local len1, len2 = left.length or #left, right.length or #right
        if len1 ~= len2 then return len1 <= len2 end
        for i = 1, len1 do
            if left[i] < right[i] then return true end
            if left[i] > right[i] then return false end
        end
        return true
    end;

    -- 重载 == 符号, 比较数组内容是否相同
    __eq = function(left, right)
        local len1, len2 = left.length or #left, right.length or #right
        if len1 ~= len2 then return false end
        for i = 1, len1 do
            if left[i] ~= right[i] then return false end
        end
        return true
    end;

    -- 直接封装的表方法
    concat = concat;
    unpack = unpack;
    ipairs = ipairs;
    sort   = table.sort;
}

-- 让切片语法更简洁
-- eg: slice = arr(1, 3[, 1])
list.__call = list.sub

return list
