require "simpleclass"

class "FactoryAccount_7c8a" {
    ---@field private bank table
    ---@field private owner string

    ---@param owner string
    __init = function(self, owner)
        self.owner = owner
    end;

    ---@static
    ---@param owner string
    ---@param bank table
    create = function(cls, owner, bank)
        local account = cls:new(owner)  -- account 被应被声明为 @class，以表达在类内部
        account.bank = bank             -- 类自己注入自己实例的字段是合法的，不应有可见性或禁止注入诊断
        account.extra = "some"
        return account
    end;
}

local account = FactoryAccount_7c8a:create("owner", {})
-- The factory may initialize its own private fields.
-- expect: 26:invisible
print(account.owner)
-- expect: 28:invisible
print(account.bank)
-- expect: 30:inject-field
account.extra_2 = "some_2"

class "FactoryView_7c8a" {
    ---@static
    ---@param acnt FactoryAccount_7c8a
    create = function(cls, acnt)
        local view = cls:new()
        view.account = acnt     -- 合法
        acnt.extra_3 = "some_3" -- 给无关的类注入字段仍是非法的
        return view
    end;
}

-- expect: 38:inject-field
