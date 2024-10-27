do
    ---@param str string
    ---@param pattern string
    ---@param plain boolean | nil
    ---@return string | nil, integer
    local function find_next(str, pattern, plain)
        local found = str:find(pattern, 0, plain or true)
        if found == nil then
            return nil, 0
        end
        return str:sub(0, found - 1), found - 1
    end

    ---@param str string | nil
    ---@param sep string | nil
    ---@param plain boolean | nil
    ---@return string[]
    function string.split(str, sep, plain)
        if str == nil then
            return {}
        end

        local strLen = str:len()
        local sepLen

        if sep == nil then
            sep = "%s"
            sepLen = 2
        else
            sepLen = sep:len()
        end

        local tbl = {}
        local i = 0
        while true do
            i = i + 1
            local foundStr, foundPos = find_next(str, sep, plain)

            if foundStr == nil then
                tbl[i] = str
                return tbl
            end

            tbl[i] = foundStr
            str = str:sub(foundPos + sepLen + 1, strLen)
        end
    end

    ---@generic T
    ---@generic R
    ---@param t T[]
    ---@param func fun(key: any, value: T) : R
    ---@return R[]
    function table.map(t, func)
        local copy = {}
        for key, value in pairs(t) do
            copy[key] = func(key, value)
        end
        return copy
    end
end

-- caching globals for performance
local type = type
local pairs = pairs
local ipairs = ipairs
local string_split = string.split
local table_insert = table.insert
local table_concat = table.concat
local table_map = table.map
local tostring = tostring

---@class lua-valid.validators
local validators = {}

---@class lua-valid : lua-valid.validators
---@field validator_base lua-valid.validator
---@field validators lua-valid.validators
---@field optional lua-valid.validators
local v = {
    validators = validators,

    -- we add functions in validator base section
    ---@diagnostic disable-next-line: missing-fields
    validator_base = {}
}

setmetatable(v, {
    __index = function(_, key)
        local validator_func = validators[key]
        if not validator_func then
            error("no validator found '" .. tostring(key) .. "'")
        end

        return function(...)
            return validator_func(...)
        end
    end
})

-------------
--- error ---
-------------

---@class lua-valid.error.to_string.options
---@field only_msg boolean | nil

---@alias lua-valid.error.to_string fun(err: lua-valid.error, options: lua-valid.error.to_string.options) : string

---@class lua-valid.error.config
---@field value any
---@field msg string
---@field expected boolean | nil
---@field childs lua-valid.error[] | nil
---@field to_string lua-valid.error.to_string | nil
---@field fatal boolean | nil

---@class lua-valid.error
---@field value any
---@field found type
---@field msg string
---@field missing boolean
---@field expected boolean
---@field childs lua-valid.error[]
---@field to_string fun(options: lua-valid.error.to_string.options | nil) : string
---@field fatal boolean

---@param config lua-valid.error.config
---@return lua-valid.error
function v.generate_error(config)
    ---@type lua-valid.error
    local err = {
        value = config.value,
        found = type(config.value),
        missing = type(config.value) == "nil",
        expected = config.expected or false,
        msg = config.msg,
        childs = config.childs or {},
        fatal = config.fatal or false,

        ---@diagnostic disable-next-line: assign-type-mismatch
        to_string = nil
    }

    if config.to_string then
        local to_string = config.to_string
        ---@cast to_string -nil
        function err.to_string(options)
            return to_string(err, options or {})
        end
    else
        function err.to_string()
            return config.msg
        end
    end

    setmetatable(err, {
        __tostring = err.to_string
    })

    return err
end

---@param err lua-valid.error
---@type lua-valid.error.to_string
v.value_error_to_string = function(err, options)
    if options.only_msg then
        return err.msg
    end

    if err.missing then
        return "missing " .. err.msg
    end

    local msg = ""
    if err.expected then
        msg = msg .. "expected "
    end
    msg = msg .. err.msg .. " found '" .. err.found .. "'"
    return msg
end

----------------------
--- validator base ---
----------------------

---@class lua-valid.validator
---@field validate fun(self: lua-valid.validator, value: any, return_by_first_fail: boolean | nil) : boolean, lua-valid.error | nil
---@field validators lua-valid.validate_func<any>[]
local validator_base = v.validator_base

---@generic T : lua-valid.validator
---@param validator T
---@return T
function v.new_validator(validator)
    return setmetatable({
        validators = {},
        validate = validator_base.validate,
        add_step = validator_base.add_step
    }, {
        __index = validator
    })
end

---@alias lua-valid.validate_func<T> fun(value: T) : boolean, lua-valid.error | nil

---@param func lua-valid.validate_func<any>
---@return lua-valid.validator
function validator_base:add_step(func)
    table_insert(self.validators, func)
    return self
end

---@param value any
---@param return_by_first_fail boolean | nil
---@return boolean
---@return lua-valid.error | nil
function validator_base:validate(value, return_by_first_fail)
    local errors = {}
    local validator_error = v.generate_error({
        value = value,
        msg = "validator has errors",
        childs = errors,
        to_string = function(err, options)
            local child_err_strs = table_map(err.childs, function(_, child_err)
                return child_err.to_string(options)
            end)
            return table_concat(child_err_strs, " && ")
        end
    })

    for _, validate in ipairs(self.validators) do
        local valid, err = validate(value)
        if not valid then
            ---@cast err -nil
            table_insert(errors, err)
            if err.fatal or return_by_first_fail then
                return false, validator_error
            end
        end
    end

    if #errors == 0 then
        return true
    end

    return false, validator_error
end

---------------------
--- nil validator ---
---------------------

---@class lua-valid.nil_validator : lua-valid.validator
---@field add_step fun(self: lua-valid.nil_validator, func: lua-valid.validate_func<nil>) : lua-valid.nil_validator
local nil_validator = {}

---@return lua-valid.nil_validator
function validators.is_nil()
    ---@type lua-valid.nil_validator
    local nil_v = v.new_validator(nil_validator)
    nil_v:add_step(function(value)
        if type(value) == "nil" then
            return true
        end

        return false, v.generate_error({
            value = value,
            expected = true,
            msg = "a nil",
            to_string = v.value_error_to_string,
            fatal = true
        })
    end)
    return nil_v
end

------------------------
--- string validator ---
------------------------

---@class lua-valid.string_validator : lua-valid.validator
---@field add_step fun(self: lua-valid.string_validator, func: lua-valid.validate_func<string>) : lua-valid.string_validator
local string_validator = {}

---@return lua-valid.string_validator
function validators.is_string()
    local string_v = v.new_validator(string_validator)

    string_v:add_step(function(value)
        if type(value) == "string" then
            return true
        end

        return false, v.generate_error({
            value = value,
            msg = "a string",
            expected = true,
            to_string = v.value_error_to_string,
            fatal = true,
        })
    end)
    return string_v
end

---@param str string
---@return lua-valid.string_validator
function string_validator:equals(str)
    self:add_step(function(value)
        if value == str then
            return true
        end
        return false, v.generate_error({
            value = value,
            msg = "does not equal '" .. str .. "'",
        })
    end)
    return self
end

---@param list string[]
---@return lua-valid.string_validator
function string_validator:in_list(list)
    self:add_step(function(value)
        for _, item in ipairs(list) do
            if item == value then
                return true
            end
        end

        return false, v.generate_error({
            value = value,
            msg = "not in list '{ " .. table_concat(list, ", ") .. " }'"
        })
    end)
    return self
end

-------------------------
--- number validator ---
-------------------------

---@class lua-valid.number_validator : lua-valid.validator
---@field add_step fun(self: lua-valid.number_validator, func: lua-valid.validate_func<number>) : lua-valid.number_validator
local number_validator = {}

---@return lua-valid.number_validator
function validators.is_number()
    local number_v = v.new_validator(number_validator)

    number_v:add_step(function(value)
        if type(value) == "number" then
            return true
        end

        return false, v.generate_error({
            value = value,
            msg = "a number",
            expected = true,
            to_string = v.value_error_to_string,
            fatal = true,
        })
    end)

    return number_v
end

---@param num number
---@return lua-valid.number_validator
function number_validator:equals(num)
    self:add_step(function(value)
        if value == num then
            return true
        end

        return false, v.generate_error({
            value = value,
            msg = "does not equal '" .. tostring(num) .. "'",
        })
    end)
    return self
end

---@param min number
---@return lua-valid.number_validator
function number_validator:min(min)
    self:add_step(function(value)
        if value >= min then
            return true
        end

        return false, v.generate_error({
            value = value,
            msg = "cannot be smaller than min '" .. tostring(min) .. "'"
        })
    end)
    return self
end

---@param max number
---@return lua-valid.number_validator
function number_validator:max(max)
    self:add_step(function(value)
        if value <= max then
            return true
        end

        return false, v.generate_error({
            value = value,
            msg = "cannot be bigger than max '" .. tostring(max) .. "'"
        })
    end)
    return self
end

---@param min number
---@param max number
---@return lua-valid.number_validator
function number_validator:between(min, max)
    if min > max then
        error("min '" .. tostring(min) .. "' cannot be bigger than max '" .. tostring(max) .. "'")
    end

    self:add_step(function(value)
        if min > value or value > max then
            return false, v.generate_error({
                value = value,
                msg = "needs to be between '" .. tostring(min) .. "' and '" .. tostring(max) .. "'",
            })
        end

        return true
    end)
    return self
end

-------------------------
--- integer validator ---
-------------------------

---@class lua-valid.integer_validator : lua-valid.validator
---@field add_step fun(self: lua-valid.integer_validator, func: lua-valid.validate_func<integer>) : lua-valid.integer_validator
local integer_validator = {}

---@return lua-valid.integer_validator
function validators.is_integer()
    ---@type lua-valid.integer_validator
    local integer_v = v.new_validator(integer_validator)

    integer_v:add_step(function(value)
        if type(value) == "number" and value % 1 == 0 then
            return true
        end

        return false, v.generate_error({
            value = value,
            msg = "an integer",
            expected = true,
            to_string = v.value_error_to_string,
            fatal = true,
        })
    end)

    return integer_v
end

---@param int integer
---@return lua-valid.integer_validator
function integer_validator:equals(int)
    self:add_step(function(value)
        if value == int then
            return true
        end

        return false, v.generate_error({
            value = value,
            msg = "does not equal '" .. tostring(int) .. "'",
        })
    end)
    return self
end

---@param min integer
---@return lua-valid.integer_validator
function integer_validator:min(min)
    self:add_step(function(value)
        if value >= min then
            return true
        end

        return false, v.generate_error({
            value = value,
            msg = "cannot be smaller than min '" .. tostring(min) .. "'"
        })
    end)
    return self
end

---@param max integer
---@return lua-valid.integer_validator
function integer_validator:max(max)
    self:add_step(function(value)
        if value <= max then
            return true
        end

        return false, v.generate_error({
            value = value,
            msg = "cannot be bigger than max '" .. tostring(max) .. "'"
        })
    end)
    return self
end

---@param min integer
---@param max integer
---@return lua-valid.integer_validator
function integer_validator:between(min, max)
    if min > max then
        error("min '" .. tostring(min) .. "' cannot be bigger than max '" .. tostring(max) .. "'")
    end

    self:add_step(function(value)
        if min > value or value > max then
            return false, v.generate_error({
                value = value,
                msg = "needs to be between '" .. tostring(min) .. "' and '" .. tostring(max) .. "'",
            })
        end

        return true
    end)
    return self
end

-------------------------
--- boolean validator ---
-------------------------

---@class lua-valid.boolean_validator : lua-valid.validator
---@field add_step fun(self: lua-valid.boolean_validator, func: lua-valid.validate_func<boolean>) : lua-valid.boolean_validator
local boolean_validator = {}

---@param func lua-valid.validate_func<boolean>
---@return lua-valid.boolean_validator
function boolean_validator:add_step(func)
    validator_base.add_step(self, func)
    return self
end

---@return lua-valid.boolean_validator
function validators.is_boolean()
    ---@type lua-valid.boolean_validator
    local boolean_v = v.new_validator(boolean_validator)

    boolean_v:add_step(function(value)
        if type(value) == "boolean" then
            return true
        end

        return false, v.generate_error({
            value = value,
            msg = "a boolean",
            expected = true,
            to_string = v.value_error_to_string,
            fatal = true,
        })
    end)

    return boolean_v
end

-----------------------
--- table validator ---
-----------------------

---@class lua-valid.table_validator : lua-valid.validator
---@field add_step fun(self: lua-valid.table_validator, func: lua-valid.validate_func<table>) : lua-valid.table_validator
local table_validator = {}

---@param func lua-valid.validate_func<table>
---@return lua-valid.table_validator
function table_validator:add_step(func)
    validator_base.add_step(self, func)
    return self
end

---@param schema table<any, lua-valid.validator> | nil
---@param ignore_not_specified boolean | nil
---@return lua-valid.table_validator
function validators.is_table(schema, ignore_not_specified)
    ---@type lua-valid.table_validator
    local table_v = v.new_validator(table_validator)

    table_v:add_step(function(table)
        if type(table) ~= "table" then
            return false, v.generate_error({
                value = table,
                msg = "a table",
                expected = true,
                to_string = v.value_error_to_string,
                fatal = true,
            })
        end

        if not schema then
            return true
        end

        local child_errors = {}
        for key, value in pairs(table) do
            local child_validator = schema[key]

            if not child_validator and not ignore_not_specified then
                table_insert(child_errors, v.generate_error({
                    value = value,
                    msg = tostring(key) .. ": not allowed"
                }))
            end
        end

        for key, child_validator in pairs(schema) do
            local value = table[key]

            local child_valid, child_err = child_validator:validate(value, false)
            if not child_valid then
                ---@cast child_err -nil
                table_insert(child_errors, v.generate_error({
                    value = value,
                    msg = tostring(key) .. ": " .. child_err.to_string(),
                }))
            end
        end

        if #child_errors == 0 then
            return true
        end

        return false, v.generate_error({
            value = table,
            msg = "table has validation errors",
            childs = child_errors,
            to_string = function(err)
                local msg = "{\n"
                for _, child_err in ipairs(err.childs) do
                    local child_err_str = child_err.to_string()
                    for _, line in ipairs(string_split(child_err_str, "\n")) do
                        msg = msg .. "    " .. line .. "\n"
                    end
                end
                return msg .. "}"
            end
        })
    end)

    return table_v
end

-----------------------
--- array validator ---
-----------------------

---@class lua-valid.array_validator : lua-valid.validator
---@field add_step fun(self: lua-valid.array_validator, func: lua-valid.validate_func<any[]>) : lua-valid.array_validator
local array_validator = {}

---@param child_validator lua-valid.validator
---@param is_object boolean | nil
---@return lua-valid.array_validator
function validators.is_array(child_validator, is_object)
    ---@type lua-valid.array_validator
    local array_v = v.new_validator(array_validator)

    array_v:add_step(function(array)
        if type(array) ~= "table" then
            return false, v.generate_error({
                value = array,
                msg = "an array",
                expected = true,
                to_string = v.value_error_to_string,
                fatal = true,
            })
        end

        ---@type lua-valid.error[]
        local child_errors = {}
        if not is_object then
            for key, value in pairs(array) do
                if type(key) ~= "number" or key % 1 ~= 0 then
                    table_insert(child_errors, v.generate_error({
                        value = value,
                        msg = tostring(key) .. ": not allowed"
                    }))
                end
            end
        end

        for index, value in ipairs(array) do
            local child_valid, child_err = child_validator:validate(value)
            if not child_valid then
                ---@cast child_err -nil
                table_insert(child_errors, v.generate_error({
                    value = value,
                    msg = tostring(index) .. ": " .. child_err.to_string()
                }))
            end
        end

        if #child_errors == 0 then
            return true
        end

        return false, v.generate_error({
            value = array,
            msg = "array has validation errors",
            childs = child_errors,
            to_string = function(err)
                local msg = "{\n"
                for _, child_err in ipairs(err.childs) do
                    for _, line in ipairs(string_split(child_err.to_string(), "\n")) do
                        msg = msg .. "    " .. line .. "\n"
                    end
                end
                return msg .. "}"
            end
        })
    end)

    return array_v
end

--------------------------
--- function validator ---
--------------------------

---@class lua-valid.function_validator : lua-valid.validator
---@field add_step fun(self: lua-valid.function_validator, func: lua-valid.validate_func<function>) : lua-valid.function_validator
local function_validator = {}

---@return lua-valid.function_validator
function validators.is_function()
    ---@type lua-valid.function_validator
    local function_v = v.new_validator(function_validator)

    function_v:add_step(function(value)
        if type(value) == "function" then
            return true
        end

        return false, v.generate_error({
            value = value,
            expected = true,
            msg = "a function",
            to_string = v.value_error_to_string,
            fatal = true,
        })
    end)

    return function_v
end

--------------------------
--- userdata validator ---
--------------------------

---@class lua-valid.userdata_validator : lua-valid.validator
---@field add_step fun(self: lua-valid.userdata_validator, func: lua-valid.validate_func<userdata>) : lua-valid.userdata_validator
local userdata_validator = {}

---@return lua-valid.userdata_validator
function validators.is_userdata()
    ---@type lua-valid.userdata_validator
    local userdata_v = v.new_validator(userdata_validator)

    userdata_v:add_step(function(value)
        if type(value) == "userdata" then
            return true
        end

        return false, v.generate_error({
            value = value,
            expected = true,
            msg = "userdata",
            to_string = v.value_error_to_string,
            fatal = true,
        })
    end)

    return userdata_v
end

--------------------------
--- thread validator ---
--------------------------

---@class lua-valid.thread_validator : lua-valid.validator
---@field add_step fun(self: lua-valid.thread_validator, func: lua-valid.validate_func<thread>) : lua-valid.thread_validator
local thread_validator = {}

---@return lua-valid.thread_validator
function validators.is_thread()
    ---@type lua-valid.thread_validator
    local thread_v = v.new_validator(thread_validator)

    thread_v:add_step(function(value)
        if type(value) == "thread" then
            return true
        end

        return false, v.generate_error({
            value = value,
            expected = true,
            msg = "a thread",
            to_string = v.value_error_to_string,
            fatal = true,
        })
    end)

    return thread_v
end

-----------------------
--- Meta validators ---
-----------------------

---@param validator lua-valid.validator
local function make_optional(validator)
    local validate = validator.validate
    function validator:validate(value, return_by_first_fail)
        if value == nil then
            return true
        end
        return validate(self, value, return_by_first_fail)
    end
end
v.optional = setmetatable({}, {
    __index = function(_, key)
        local validator_func = validators[key]
        if not validator_func then
            error("no validator found '" .. tostring(key) .. "'")
        end

        return function(...)
            local validator = validator_func(...)
            make_optional(validator)
            return validator
        end
    end
})

---@class lua-valid.or_validator : lua-valid.validator
---@field add_step fun(self: lua-valid.or_validator, func: lua-valid.validate_func<any>) : lua-valid.or_validator
local or_validator = {}

---@param ... lua-valid.validator
---@return lua-valid.validator
function v.OR(...)
    local or_v = v.new_validator(or_validator)

    local or_validators = { ... }
    or_v:add_step(function(value)
        ---@type lua-valid.error[]
        local errors = {}
        for _, validator in ipairs(or_validators) do
            local valid, err = validator:validate(value)
            if valid then
                return true
            end

            table_insert(errors, err)
        end

        return false, v.generate_error({
            value = value,
            msg = "error in or validation",
            childs = errors,
            to_string = function(err)
                return "expected " .. table_concat(table_map(err.childs, function(_, child_err)
                    return child_err.to_string({ pure = true })
                end), " OR ")
            end,
            falal = true,
        })
    end)

    return or_v
end

return v
