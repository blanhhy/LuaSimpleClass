class "ParamInfer_7c8a" {
    ---@field name string
    ---@field _count number

    __init = function(self, name)
        print(name.noSuchField) -- 已经写了 @field 无需再写 @param，参数 name 自动推导为 string
        self.name = name
    end;

    ['get.count'] = function(self)
        self._count = self._count or 0
        return self._count
    end;

    ['set.count'] = function(self, value)
        print(value.noSuchField)
        self._count = value
    end;

    initarg = function(self, arg)
        print(arg.noSuchField) -- 只应对直接赋值推断，arg 仍保持 any
        self.arg = arg or {}
    end;
}

local o = ParamInfer_7c8a:new("o")
print(o.count + 1)

-- 如果字段类型已知，可以推导出赋给该字段的参数类型
-- expect: 6:undefined-field
-- expect: 16:undefined-field
