---@diagnostic disable: deprecated, lowercase-global
local sc = require "simpleclass"
local ctype = sc.type

local type, tostring, setmetatable, tonumber
    = type, tostring, setmetatable, tonumber
local insert, concat, remove = table.insert, table.concat, table.remove
local unpack = table.unpack or unpack
local int = math.floor

local table_new, table_clr

if pcall(require, "jit") then
    local ok_new, new = pcall(require, "table.new")
    local ok_clr, clr = pcall(require, "table.clear")
    table_new = ok_new and new or nil
    table_clr = ok_clr and clr or nil
elseif _VERSION >= "Lua 5.5" then
    table_new = table.create
end

---仿 Python 的 list 类
class "list" {
    -- 静态属性

    ---@static
    -- 索引检查开关, 默认开启
    chkidxEnabled = true;

    -- 静态方法

    ---@static
    ---@param lim number
    ---@param length? integer 如果提供了 length, 返回值会被规范为正向索引
    ---@return integer index 索引是一个在 [1, lim] 范围内的整数
    chkidx = function(index, lim, length)
        if not list.chkidxEnabled then return index end
        local err = (
            (type(index) ~= "number" or int(index) ~= index) and
            ("<integer> expected, got <%s>."):format(ctype(index))
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
    ---@param value? any 默认为 0
    -- 创建一个指定长度的数组, 并填充默认值
    create = function(length, value)
        if nil == value then value = 0 end
        length = list.chkidx(length, math.huge)
        local arr = list:_newContainter(length)
        for i = 1, length do arr[i] = value end
        return arr
    end;

    -- 构造方法

    -- 可以从参数列表或已有的数组来创建数组, 也可以创建空数组  
    -- （由于 jit 和 5.5 情况下有预分配空间的需求，所以用了 new 而不是 __init）
    ---@param ... any
    ---@overload fun(cls:list.class, array:any[]):list
    new = function(cls, ...)
        local nargs = select('#', ...)

        if nargs == 0 then
            return setmetatable({__class = cls, length = 0}, cls)
        end

        local array = nargs == 1 and type(...) == "table" and (...) or {...}
        local newArr

        if table_new then
            newArr = table_new(#array, 2)
            newArr.__class = cls
            setmetatable(newArr, cls)
        else
            newArr = setmetatable({__class = cls}, cls)
        end

        local count = 0

        for i, v in ipairs(array) do
            newArr[i] = v
            count = i
        end

        newArr.length = count
        return newArr
    end;

    ---@static
    -- 产生一个空容器，内部使用，必须立即填充值
    _newContainter = function(cls, length)
        local newArr
        if table_new then
            newArr = table_new(length, 2)
            newArr.__class = cls
            setmetatable(newArr, cls)
        else
            newArr = setmetatable({__class = cls}, cls)
        end
        newArr.length = length
        return newArr
    end;

    -- 基本操作方法

    -- 在尾部追加元素
    append = function(self, value)
        if nil == value then
            error("cannot add nil into a list", 2)
        end
        self.length = self.length + 1
        self[self.length] = value
        return self
    end;

    -- 向指定索引处插入元素
    ---@param index? integer 默认在数组末尾
    ---@overload fun(self:list, value:any):list
    insert = function(self, index, value)
        if value == nil then
            if index == nil then error("cannot add nil into a list", 2) end
            value = index
            index = self.length + 1
        else
            index = list.chkidx(index, self.length + 1, self.length)
        end
        insert(self, index, value)
        self.length = self.length + 1
        return self
    end;

    -- 弹出指定索引的元素, 返回其值
    ---@param index? integer 默认在数组末尾
    pop = function(self, index)
        if self.length == 0 then error("pop from empty list", 2) end
        index = index and list.chkidx(index, self.length, self.length) or self.length
        self.length = self.length - 1
        return remove(self, index)
    end;

    -- 移除指定值, 只移除第一个, 返回其原来的索引
    remove = function(self, value)
        if nil == value then error("non-nil value expected.", 2) end
        for i = 1, self.length do
            if value == self[i] then
                remove(self, i)
                self.length = self.length - 1
                return i
            end
        end
    end;

    -- 移除指定值, 只移除最后一个, 返回其原来的索引
    removeLast = function(self, value)
        if nil == value then error("non-nil value expected.", 2) end
        for i = self.length, 1, -1 do
            if value == self[i] then
                remove(self, i)
                self.length = self.length - 1
                return i
            end
        end
    end;

    -- 移除指定值, 移除所有, 返回被移除的个数
    removeAll = function(self, value)
        if value == nil then error("non-nil value expected.", 2) end
        local n, k = self.length, 0
        for i = 1, n do
            local v = self[i]
            if v ~= value then k = k + 1; self[k] = v end
        end
        for i = k + 1, n do self[i] = nil end
        self.length = k
        return n - k
    end;

    -- 清空数组, 长度归零
    clear = function(self)
        local cls = self.__class
        if table_clr then
            table_clr(self) -- 保留元表
            self.__class = cls -- 重绑class
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
            error(("<table?> expected, got <%s>."):format(ctype(array)), 2)
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
    ---@param i? integer
    ---@param j? integer
    fill = function(self, value, i, j)
        if nil == value then
            error("cannot add nil into a list", 2)
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
    ---@return integer?
    index = function(self, value)
        if nil == value then return nil end
        for i = 1, self.length do
            if value == self[i] then return i end
        end
        return nil
    end;

    -- 找到最后一个匹配的索引, 返回 nil 则表示没有找到
    ---@return integer?
    lastIndex = function(self, value)
        if nil == value then return nil end
        for i = self.length, 1, -1 do
            if value == self[i] then return i end
        end
        return nil
    end;

    -- 找到所有匹配的索引, 返回值是包含所有索引的 list 对象
    ---@return list
    indices = function(self, value)
        if nil == value then return list() end
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
        return list:new(self)
    end;

    -- 数组切片, 得到一个新的数组
    ---@param i? integer 起始索引
    ---@param j? integer 结束索引
    ---@param step? integer 切片的步长
    ---@return list
    sub = function(self, i, j, step)
        step = step and list.chkidx(step, math.huge) or 1
        i = i and list.chkidx(i, self.length, self.length) or (step > 0 and 1 or self.length)
        j = j and list.chkidx(j, self.length, self.length) or (step > 0 and self.length or 1)

        local slice = setmetatable({__class = list}, list)
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
    ---@return list
    rep = function(self, n)
        if type(n) ~= "number" or int(n) ~= n then
            error(("<integer> expected, got <%s>."):format(ctype(n)), 2)
        end
        if n <= 0 then return list() end
        local rep = list:_newContainter(self.length * n)
        for i = 1, self.length do
            for j = 0, n - 1 do
                rep[i + j * self.length] = self[i]
            end
        end
        return rep
    end;

    -- 获取去重数组
    ---@return list
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
    ---@return table<any, integer>
    values = function(self)
        local values = {}
        for i = self.length, 1, -1 do
            values[self[i]] = i
        end
        return values
    end;

    -- 统计方法

    -- 获取数组中的最大值, 要求值可以互相比较
    ---@return any
    max = function(self)
        local max = self[1]
        if self.length < 2 then return max end
        for i = 2, self.length do
            max = max < self[i] and self[i] or max
        end
        return max
    end;

    -- 获取数组中的最小值, 要求值可以互相比较
    ---@return any
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
            strList[i] = type(self[i]) == "string"
                and ("%q"):format(self[i])
                or  tostring(self[i])
        end
        return '{'..concat(strList, ", ")..'}'
    end;

    -- 元方法

    -- 连接两个数组, 得到一个新的数组
    ---@param arr1 list
    ---@param arr2 list
    ---@return list
    __concat = function(arr1, arr2)
        if not isinstance(arr1, list) or not isinstance(arr2, list) then
            error(("attempt to concat list with a %s value")
                :format(isinstance(arr1, list) and ctype(arr2) or ctype(arr1)), 2)
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
    ---@operator mul(integer): list
    __mul = function(left, right)
        if not isinstance(left, list) then
            return right:rep(left)
        end
        return left:rep(right)
    end;

    -- 让切片语法更简洁
    -- eg: slice = arr[[1:3:1]]
    ---@param str string
    ---@return list
    __call = function(self, str)
        if type(str) ~= "string" then error("attempt to call a list value", 2) end
        local i, j, k = str:match "^([^:]*):?([^:]*):?([^:]*)$"
        local b = i and i ~= '' and (tonumber(i) or error("slice syntax error: "..str, 2)) or nil
        local e = j and j ~= '' and (tonumber(j) or error("slice syntax error: "..str, 2)) or nil
        local s = k and k ~= '' and (tonumber(k) or error("slice syntax error: "..str, 2)) or nil
        return self:sub(b, e, s)
    end;

    -- 重载 < 和 > 符号, 基于数组长度和第一个不等元素
    __lt = function(left, right)
        if type(left) ~= "table" or type(right) ~= "table" then -- 允许list和普通的数组比较
            error(("attempt to compare list with a %s value")
                :format(type(left) == "table" and ctype(right) or ctype(left)), 2)
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
                :format(type(left) == "table" and ctype(right) or ctype(left)), 2)
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

list = list ---@type list.constructor|list.class

-- 不在当前文件运行，只返回类
if ... then return list end

-- 下面是演示

-- 创建一个list实例
local originalNumbers = list(34, 6577, 8, 1, 85, 5635, 3)
print("创建数组: originalNumbers = " .. tostring(originalNumbers))
print()

-- list 可以从参数列表或已有的数组来创建, 或创建空数组
-- list(3, 4, 5)
-- list{1, 2, 3, 4, 5}
-- list()

-- 排序数组
local sortedNumbers = originalNumbers:copy()
sortedNumbers:sort()
print("排序操作:")
print("   before: " .. tostring(originalNumbers))
print("   after:  " .. tostring(sortedNumbers))
print()

-- 排序方法就是 table.sort 函数

-- 反转数组
local reversedNumbers = sortedNumbers:copy()
reversedNumbers:reverse()
print("反转操作:")
print("   before: " .. tostring(sortedNumbers))
print("   after:  " .. tostring(reversedNumbers))
print()

-- 反转方法是原地操作, 同时会返回 self

-- 截取子数组
local subArray = reversedNumbers:sub(3, 5)
print("截取子数组:")
print("   source:  " .. tostring(reversedNumbers))
print("   slice(3,5): " .. tostring(subArray))
print("   获取了索引3到5的元素：[索引3]" .. reversedNumbers[3] .. ", [索引4]" .. reversedNumbers[4] .. ", [索引5]" .. reversedNumbers[5])
print()

-- sub 的索引规则和 lua 的 string.sub 一致

-- 扩充新元素
local extendedArray = reversedNumbers:copy()
local newElements = {1, 3, 6, 3, 9}
extendedArray:extend(newElements)
print("扩展操作:")
print("   original: " .. tostring(reversedNumbers))
print("   newElements: " .. "{1, 3, 6, 3, 9}")
print("   extended: " .. tostring(extendedArray))
print()

-- extend 可以批量扩充元素, 也可以用来连接数组
-- 是原地操作, 同时会返回 self

-- 查找所有匹配值的索引
local indicesOf3 = extendedArray:indices(3)
print("查找值3的所有索引:")
print("   array: " .. tostring(extendedArray))
print("   indicesOf3: " .. tostring(indicesOf3))
print("   unpack: " .. table.concat({indicesOf3:unpack()}, ", "))
print()

-- 查找索引有 index, lastIndex, indices 三个方法
-- 顾名思义, index 返回第一个匹配的索引, lastIndex 返回最后一个匹配的索引, indices 返回所有匹配的索引
-- indiecs 返回的也是 list 对象

-- 删除第一个匹配值
local withoutFirst3 = extendedArray:copy()
withoutFirst3:remove(3)
print("删除第一个3:")
print("   before: " .. tostring(extendedArray))
print("   after:  " .. tostring(withoutFirst3))
print()

-- 删除最后一个匹配值
local withoutLast3 = withoutFirst3:copy()
withoutLast3:removeLast(3)
print("删除最后一个3:")
print("   before: " .. tostring(withoutFirst3))
print("   after:  " .. tostring(withoutLast3))
print()

-- 移除值也有 remove, removeLast, removeAll 三个方法
-- 和 index 那三个类似, 分别是移除第一个, 移除最后一个, 和移除所有匹配的元素
-- 其中 remove 和 removeLast 返回原来那个值的索引, 而 removeAll 返回被移除的个数

-- 获取唯一值数组
local uniqueValues = withoutLast3:unique()
print("去重操作:")
print("   before: " .. tostring(withoutLast3))
print("   unique: " .. tostring(uniqueValues))
print()

-- unique 用于去重, 得到一个新的数组, 原数组不变
-- 还有一个去重相关的方法 values, 用于得到值的集合, 自然是不重复的
-- values 方法返回的是键为数组值, 值为它们第一次出现的索引的 table

-- 创建和填充数组
print("创建和操作:")
local defaultArray = list.create(5)
print("   list.create(5) = " .. tostring(defaultArray))

-- create 不指定填充值的话, 默认是 0
-- 在 jit 环境下有优化, 会调用 table.new 来预分配空间

defaultArray:fill(7)
print("   fill(7) -> " .. tostring(defaultArray))

-- fill 可以指定填充区间, 默认是整个数组

defaultArray:clear()
print("   clear() -> " .. tostring(defaultArray) .. ", length = " .. defaultArray.length)
print()

-- clear 在 jit 环境下会调用 table.clear

-- 切片操作
print("切片操作:")
print("   source: " .. tostring(uniqueValues))
local sliceStep2 = uniqueValues[[2:-2:2]] -- 从第二个到倒数第二个, 间隔为2的切片
print("   slice[2:-2:2]: " .. tostring(sliceStep2))
print()

-- 数组切片用小括号和调用 sub 方法是一样的, 同一个函数
-- 数组切片与 python 类似, 也有切片步长 step 参数
-- 但是要注意索引的原则, 应该参考 string.sub 的规则

-- 重复和连接操作
print("重复和连接操作:")
local smallArray1 = list(1, 2, 3)
local repeatedArray = smallArray1 * 2
print("   {1,2,3} * 2 = " .. tostring(repeatedArray))

-- 重复可以用 * 符号, 也可以用 rep 方法
-- 为了模仿 python 风格, * 会调用 rep 方法

local smallArray2 = list(4, 5, 6)
local concatenatedArray = smallArray1 .. smallArray2
print("   {1,2,3} .. {4,5,6} = " .. tostring(concatenatedArray))
print()

-- 注意:
-- 连接操作符和 extend 方法不一样, .. 会返回新的数组, 而 extend 就地修改原数组
-- 和 concat 也不一样, concat 是 table 库的 concat, 是用来把数组拼接成字符串的

-- 最大值和最小值
print("统计操作:")
local randomArray = list()
for _ = 1, 20 do
    randomArray:append(math.random(1, 16))
end
print("   randomArray: " .. tostring(randomArray))
print("   max: " .. randomArray:max() .. ", min: " .. randomArray:min())

local targetValue = randomArray[10]
local countResult = randomArray:count(targetValue)
print("   count(" .. targetValue .. "): 出现 " .. countResult .. " 次")
print()

-- 最值方法使用 lua 的大于小于符号, 以保证运算符重载的对象能参与比较
-- 使用最值方法需要确保数组内的元素都互相可比

-- 数组比较
print("数组比较:")
local arrA = list(1, 2, 3, 4, 5)
local arrB = list(1, 2, 3, 4, 5)
print("   arrA = " .. tostring(arrA))
print("   arrB = " .. tostring(arrB))
print("   arrA == arrB? " .. tostring(arrA == arrB)) -- 是否相等, 比较的是内容
print("   arrA is arrB? " .. tostring(arrA:is(arrB))) -- 是否为同一个对象, 比较的是地址

-- == 比较的是内容, is 比较的是地址
-- is 方法来自 object, 和 rawequal 是同一个函数

arrA:insert(2, 6)
print("   arrA插入6后: " .. tostring(arrA))
print("   arrA > arrB? " .. tostring(arrA > arrB)) -- 比较的是第一个不等元素
print()

-- 不等号会先比较长度, 长度相同则比较第一个不等元素

xpcall(function()

-- 可以和普通 table 对象比较
print("和普通 table 对象比较:")
local arrC = {1, 2, 3, 4, 5}
print("   arrC = table: " .. table.concat(arrC, ", "))
print("   arrA > arrC? " .. tostring(arrA > arrC))
print("   arrB == arrC? " .. tostring(arrB == arrC))

-- 比较数组的时候至少有一个是 list 对象即可, 普通的 table 数组也可以参与
-- 其他的类型不行 (除非它们也有元方法且处于优先地位), lua5.2 以下版本另说

end, function()
    print("lua5.2以下版本比较运算符须操作数拥有相同元方法")
end)

-- 还有其他的方法比如 pop弹出, copy 复制, 等等, 都比较简单
-- 复制数组也可以直接用构造函数实现
-- arr2 = list(arr1)
-- 也可以用 object 通用的 clone
-- arr2 = arr1:clone()

-- 以及 ipairs 和 unpack 方法, 就是 lua 原来的 ipairs 和 unpack 函数
-- for i, v in arr:ipairs() do
--     print(i, v)
-- end
-- v1, v2, v3, ... = arr:unpack()
