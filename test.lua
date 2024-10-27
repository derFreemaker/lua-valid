local v = require("validation")

---@class lua-valid.validators
local validators = v.validators

---@class my_validator : lua-valid.validator
---@field add_step fun(self: my_validator, func: lua-valid.validate_func<any>) : my_validator
local my_validator = {}

---@return my_validator
function my_validator:test()
    return self
end

---@return my_validator
function validators.my_validator()
    local my_v = v.new_validator(my_validator)

    my_v:add_step(function(value)
        return false, v.generate_error({
            value = value,
            msg = "custom validator",
            to_string = function(err, options)
                if options.only_msg then
                    return "pure"
                end
                return err.msg
            end
        })
    end)
    return my_v
end

local test = v.is_table({
    test = v.OR(v.my_validator(), v.is_integer(), v.is_string()),
    test2 = v.is_number():between(200, 300),
    test_table = v.optional.is_table({
        test = v.is_boolean(),
        test2 = v.my_validator(),
    })
})
local valid, err = test:validate({ testtest = "", test_table = {} })
print(valid)
print(err)
