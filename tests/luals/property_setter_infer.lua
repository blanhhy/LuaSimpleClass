class "PropertySetterInfer_8f31" {
    ---@field _value PropertySetterInfer_8f31?
    property.value;
    ['get.value'] = function(self)
        return self._value
    end;

    ['set.value'] = function(self, value)
        self._value = value
        if value then
            print(value.missingField)
        end
    end;
}

-- The field type must be propagated to the unannotated setter parameter.
-- expect: 11:undefined-field
