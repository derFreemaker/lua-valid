# lua-valid
Lua basic validation library.

## Recommendations
- [sumneko Lua](https://github.com/LuaLS/lua-language-server) as LSP for type shenanigans

## Validators

### Type Validators
- `is_nil()`: verify that value is of type `nil`
- `is_string()`: verify that value is of type `string`
- `is_number()`: verify that value is of type `number`
- `is_integer()`: verify that value is of type `integer`
- `is_boolean()`: verify that value is of type `boolean`
- `is_table([schema], [ignore_not_specified])`: verify that value is of type `table`
- `is_array(child_validator, [is_object])`: verify that value is of type `array`
- `is_function()`: verify that value is of type `function`
- `is_userdata()`: verify that value is of type `userdata`
- `is_thread()`: verify that value is of type `thread`

### String Validators
extra validators can be called after `is_string()`
- `equals(str)`: verify that value equals the given string.
- `in_list(list)`: verify that value is in the given list.

### Number Validators
extra validators can be called after `is_number()`
- `equals(num)`: verify that value is the same as the given number.
- `min(min)`: verify that value is bigger or equal of min.
- `max(max)`: verify that value is smaller or equal of max.
- `between(min, max)`: verify that value is between min and max.

### Integer Validators
extra validators can be called after `is_integer()`
- `equals(num)`: verify that value is the same as the given number.
- `min(min)`: verify that value is bigger or equal of min.
- `max(max)`: verify that value is smaller or equal of max.
- `between(min, max)`: verify that value is between min and max.

### Meta Validators
- `optional.<validator>`: if value is there run validator
- `OR(<validator>...)`: check given validators until valid is found

## Validation Error
- `value`: the value
- `found`: the found type
- `msg`: custom message from the validator
- `missing`: if validator is missing value
- `expected`: if validator expected something (should be more information in `msg`)
- `childs`: child errors
- `to_string(options)`: custom to_string function
- `fatal`: if error is fatal  

### Validation Error Config
- `value`: the value
- `msg`: custom message
- `expected`: if validator expected something (should be more information in `msg`)
- `childs`: child errors
- `to_string(err, options)`: custom to_string function (gets passed the error itself and options)
- `fatal`: if error was fatal

### Validation Error to_string Options
- `only_msg`: only msg **should** be return by to_string function.

## Examples

### Basic
```lua
local validation = require("validation")

local string_validator = validation.is_string():in_list({ "test", "foo" })
local valid, err = string_validator:validate("asd")
-- false   not in list '{ test, foo }'
print(valid, err)

local valid, err = string_validator:validate("foo")
-- true    nil
print(valid, err)
```

### Table Validator
```lua
local validation = require("validation")

local table_validator = validation.is_table({
    test = validation.is_string():in_list({ "test", "foo" })
})
-- If `validation.is_table([schema], [ignore_not_specified])` is given a schema it will also check if the table follows the schema.

local valid, err = table_validator:validate({ test = 123 })
-- false   {
--    test: expected a string found 'number'
-- }
print(valid, err)
-- Its important to remember that the to_string function is there to make the error state readable for a human not for value extraction

local valid, err = table_validator:validate({ test = "asd" })
-- false   {
--     test: not in list '{ test, foo }'
-- }
print(valid, err)
-- Since `test` is a string we get the error message from the `in_list()` step since `is_string()` returns a fatal error if the given value is not a string.

local valid, err = table_validator:validate({ test = "foo" })
-- true    nil
print(valid, err)
```

### custom Validator Example
```lua
local validation = require("validation")

-- You wanna do this to add your validator to the 'lua-valid.validators' type
---@class lua-valid.validators
local validators = validation.validators

---@class <{validator_type}> : lua-valid.validator
---@field add_step fun(self: <{validator_type}>, func: lua-valid.validate_func<{your_validation_type}>) : <{validator_type}>
-- Its recommended to add to the class for lsp completion and type saftey.
local <{validator}> = {}

---@return <{validator_type}>
function validators.<{validator}>()
    -- Its recommended to use the `validation.new_validator()` function for initialization.
    local v = validation.new_validator(<{validator}>)

    -- You can add validation step like so
    v:add_step(function(value)
        -- validate value

        -- return error like so
        return false, validation.generate_error({
            value = value,
            msg = "<{custom message}>",
            to_string = function(err, options)
                if options.only_msg then
                    return err.msg
                end
                return "some stuff: " .. err.msg
            end,
            fatal = true, -- Setting this true will mean the validation process will stop at this error and return since its not error safe to proceed when you make type assumptions and don't validate the value type in every step.
        })
    end)

    return v
end

-- You can add child validators for you validator like so
function <{validator}>:equals(other)
    self:add_step(function(value)
        if value == other then
            return true
        end

        -- Its recommended to use `validation.generate_error(<config>)`
        return false, validation.generate_error({
            value = value,
            msg = "was not equal",
            to_string = function(err, options)
                -- you don't have to implement this
                -- only if you need it
                if options.only_msg then
                    return err.msg
                end

                return tostring(value) .. " " .. err.msg
            end
        })
    end)
end

-- now you can use it also as optional like so
local optional_<validator> = validation.optional.<validator>()
-- this will make it so the validator is only called if there is a value and return true if there is no value 
```

## Thrid-Party
- [luaunit](https://github.com/bluebird75/luaunit) (for testing)
