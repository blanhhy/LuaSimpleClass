interface "InterfaceAliasCanRun_8b31" {"run"}

local Runner = class "InterfaceAliasRunner_8b31" : impl(InterfaceAliasCanRun_8b31) {
    run = function(self)
        return self
    end;
}

local runner = Runner:new()
runner:run()
