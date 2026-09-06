class "ParamInferBase_7c8a" {
    ---@field inherited number
}

class "ParamInferChild_7c8a" : extends "ParamInferBase_7c8a" {
    update = function(self, value)
        print(value.noSuchField)
        self.inherited = value
    end;
}

-- expect: 7:undefined-field
