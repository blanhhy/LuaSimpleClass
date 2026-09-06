-- Regression cases for lexer boundaries and super argument parsing.

require "simpleclass"

-- These DSL-looking tokens are data, not declarations.
local fixture = [=[
class "FakeClass_parser_7c8a" { fake = function() end; }
interface "FakeInterface_parser_7c8a" { "fake" }
]=]

interface "RobustInterface_parser_7c8a" {
    "run";
    -- "ghost_from_comment_parser_7c8a"
    [=[ "ghost_from_long_string_parser_7c8a" ]=]
}

class "RobustBase_parser_7c8a" {
    ---@field name string
    ---@field opts table
    ---@field suffix string

    run = function(self, name, opts, suffix)
        self.name = name
        self.opts = opts
        self.suffix = suffix
        local nested = { first = { 1, 2 }, second = "end )" }
        local quoted = "function fake() end )"
        return self.name, nested, quoted
    end;
}

class "RobustChild_parser_7c8a" : extends "RobustBase_parser_7c8a" : implements(RobustInterface_parser_7c8a) {
    run = function(self, name, opts, suffix)
        -- The table comma and the string parenthesis must not end the call.
        super(RobustChild_parser_7c8a, self):run(name, {first = 1, second = 2}, suffix)
        return self.name
    end;
}

local child = RobustChild_parser_7c8a()

-- The child parameters are inferred from the parent method.
-- expect: 44:param-type-mismatch
child:run(123, {}, "ok")
-- expect: 46:param-type-mismatch
child:run("ok", {}, 456)
