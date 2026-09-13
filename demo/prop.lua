require "simpleclass"

class "Account" {
    ---@field private _balance number

    constructor = function(self, balance)
        self._balance = balance or 0
    end;

    property.balance;
    ['get.balance'] = function(self)
        return self._balance
    end;

    ['set.balance'] = function(self, value)
        if value < 0 then
            error("Balance cannot be negative!", 2)
        end
        self._balance = value
    end;
}

local account = Account(100)

account.balance = account.balance + 100
print("Balance:", account.balance) --> 200

account.balance = account.balance - 50
print("Balance:", account.balance) --> 150

xpcall(function()
    account.balance = -100
end, print)

-- Output: Balance cannot be negative!
