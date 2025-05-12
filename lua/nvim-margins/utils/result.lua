--- @class Result
--- @field __type string A type to verify that this is a result.
--- @field is_error boolean Whether the Result is in an error state.
--- @field message any?
--- @field  value any?
local Result = {
    __type = "Result",
}

function Result:new(is_error, value, message)
    local result
    if value == nil then
        result = {
            is_error = is_error,
            message = message,
        }
    else
        result = {
            is_error = is_error,
            value = value,
        }
    end

    setmetatable(result, self)

    return result
end

function Result:match(ok_callback, err_callback)
    if self.is_error() then
        return err_callback(self)
    else
        return ok_callback(self)
    end
end

function Result:match_ok(callback)
    if not self.is_error then
        return callback(self.value)
    end

    return nil
end

function Result:match_err(callback)
    if self.is_error then
        return callback(self.message)
    end

    return nil
end

--- Create a Result in an ok state.
---
--- @param value any The value of the ok.
--- @return Result
function Ok(value)
    return Result:new(false, value, nil)
end

--- Create a Result in an error state.
---
--- @param message any A message for an error. Can be nil.
--- @return Result
function Err(message)
    return Result:new(true, nil, message)
end

--- Wrap a function and return a Result that catches any errors thrown within the function.
---
--- If the function returns multiple arguments they are packed into a table and all returned.
---
--- @param func function A func to be called in protected mode.
--- @param ... any Arguments passed to func.
--- @return Result
function Wrap(func, ...)
    local args = {...} -- has to be done this way because the inner function doesn't have access to ...
    local output_value
    local success, value = pcall(function()
        output_value = table.pack(func(table.unpack(args)))
    end)

    if success then
        if #output_value > 1 then
            return Ok(output_value)
        else
            return Ok(output_value[1])
        end
    else
        return Err(value)
    end
end
