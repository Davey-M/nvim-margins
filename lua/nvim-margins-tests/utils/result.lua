require("nvim-margins.utils.result")

local function test_wrap_catches_errors()
    local ERROR_MSG = "Throwing test error"
    local test = Wrap(function() error(ERROR_MSG) end)

    assert(test.is_error, "test is error")
    assert(test.message ~= nil, "message exists")
    assert(string.find(test.message,ERROR_MSG) ~= nil, "message is correct")
end
test_wrap_catches_errors()

local function test_wrap_returns_values()
    local VALUE = "Test was a success"
    local test = Wrap(function(value) return value end, VALUE)

    assert(not test.is_error, "not an error")
    assert(test.value ~= nil, "has a value")
    assert(test.value == VALUE, "value matches")
end
test_wrap_returns_values()

local function test_wrap_returns_all_values()
    local function func_to_wrap(arg1, arg2)
        if arg2 == nil then
            return arg1
        else
            return arg1, arg2
        end
    end

    local test_2_args = Wrap(func_to_wrap, "foo", 1234)
    assert(type(test_2_args.value) == "table", "test is a table")
    assert(#test_2_args.value == 2, "test has all args")

    local ARG = "bar"
    local test_1_arg = Wrap(func_to_wrap, ARG)
    assert(type(test_1_arg.value) == "string", "test is a string")
    assert(test_1_arg.value == ARG, "test is correct string")
end
test_wrap_returns_all_values()

