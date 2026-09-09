-- getter 单引号与双引号都应被识别，读取属性类型正确（number）。
-- 本文件为正向用例：直接按 number 使用 getter（算术运算），期望 0 诊断。
-- 若双引号 getter 未被识别，acc2.balance 本身会报 undefined-field，导致本用例 FAIL。
require "simpleclass"

class "Acct1_pos" {
    __init = function(self)
        self._balance = 0
    end;
    ['get.balance'] = function(self)
        return self._balance
    end;
}

local acc1 = Acct1_pos()
local b1 = acc1.balance          -- 单引号 getter：读取类型为 number

class "Acct2_pos" {
    __init = function(self)
        self._balance = 0
    end;
    ["get.balance"] = function(self)
        return self._balance
    end;
}

local acc2 = Acct2_pos()
local b2 = acc2.balance          -- 双引号 getter：读取类型为 number

-- number 与 number 相加，类型正确时不报警；getter 未被识别则会在上方报 undefined-field
local total = b1 + b2 + acc1.balance + acc2.balance
print(total)
