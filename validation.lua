-- caching globals for performance
local type = type
local insert = table.insert
local next = next
local concat = table.concat

---@class lua-valid.error
---@field kind "value" | "table" | "array" | "or"
---@field to_string fun(indent: integer | nil) : string

---@class lua-valid.value.error : lua-valid.error
---@field kind "value"
---@field found string
---@field err_msg string
---@field expected boolean
---@field missing boolean

---@class lua-valid.table.error : lua-valid.error
---@field kind "table"
---@field errors table<any, lua-valid.error>

---@class lua-valid.array.error : lua-valid.error
---@field kind "array"
---@field errors table<any, lua-valid.error>

---@class lua-valid.or.error : lua-valid.error
---@field kind "or"
---@field errors lua-valid.error[]

---@alias lua-valid.validator fun(value: any) : boolean, lua-valid.error | nil

---@alias lua-valid.schema table<any, lua-valid.validator>

---@class lua-valid.validators
local validators = {}

---@param indent integer
---@return string
local function generate_indent(indent)
    if indent == 0 then
        return ""
    end
    local indents = {}
    for _ = 1, indent do
        insert(indents, "    ")
    end
    return concat(indents)
end

---@param value any
---@param expected boolean
---@param err_msg string
---@return lua-valid.value.error
local function generate_value_error(value, expected, err_msg)
    local err = {
        kind = "value",
        found = type(value),
        err_msg = err_msg,
        expected = expected,
        missing = value == nil,
    }

    function err.to_string()
        local str = ""
        if err.missing then
            str = "is missing and "
        end
        if err.expected then
            str = str .. "expected "
        end
        str = str .. err.err_msg
        if not err.missing then
            str = str .. " - found: " .. err.found
        end
        return str
    end

    return err
end

---@param errors table<any, lua-valid.error>
---@return lua-valid.table.error
local function generate_table_error(errors)
    local err = {
        kind = "table",
        errors = errors,
    }

    ---@param indent integer | nil
    function err.to_string(indent)
        indent = indent or 0

        local str = "{\n"
        local indent_str = generate_indent(indent)
        for key, value in pairs(err.errors) do
            str = str .. indent_str .. generate_indent(1) .. tostring(key) .. ": " .. value.to_string(indent + 1) .. "\n"
        end

        return str .. indent_str .. "}"
    end

    return err
end

---@param errors table<any, lua-valid.error>
---@return lua-valid.array.error
local function generate_array_error(errors)
    local err = {
        kind = "array",
        errors = errors,
    }

    ---@param indent integer | nil
    function err.to_string(indent)
        indent = indent or 0

        local str = "{\n"
        local indent_str = generate_indent(indent)
        for key, value in pairs(err.errors) do
            str = str .. indent_str .. generate_indent(1) .. tostring(key) .. ": " .. value.to_string(indent + 1) .. "\n"
        end

        return str .. indent_str .. "}"
    end

    return err
end

---@param err lua-valid.or.error
---@param indent integer
---@return string
local function or_error_to_string(err, indent)
    local expected = {}
    for _, value in ipairs(err.errors) do
        if value.kind == "value" then
            ---@cast value lua-valid.value.error
            insert(expected, value.err_msg)
        elseif value.kind == "table" then
            ---@cast value lua-valid.table.error
            insert(expected, "a table: " .. value.to_string(indent + 1))
        elseif value.kind == "array" then
            ---@cast value lua-valid.table.error
            insert(expected, "an array: " .. value.to_string(indent + 1))
        elseif value.kind == "or" then
            ---@cast value lua-valid.or.error
            insert(expected, or_error_to_string(value, indent))
        else
            -- we ignore
        end
    end
    return concat(expected, "\nOR ")
end

---@param errors lua-valid.error[]
---@return lua-valid.or.error
local function generate_or_error(errors)
    local err = {
        kind = "or",
        errors = errors
    }

    ---@param indent integer | nil
    function err.to_string(indent)
        indent = indent or 0

        return "expected " .. or_error_to_string(err, indent)
    end

    return err
end

---@return lua-valid.validator
function validators.is_string()
    return function(value)
        if type(value) ~= "string" then
            return false, generate_value_error(value, true, "a string")
        end

        return true
    end
end

---@return lua-valid.validator
function validators.is_integer()
    return function(value)
        if type(value) ~= "number" or value % 1 ~= 0 then
            return false, generate_value_error(value, true, "an integer")
        end
        return true
    end
end

---@return lua-valid.validator
function validators.is_number()
    return function(value)
        if type(value) ~= "number" then
            return false, generate_value_error(value, true, "a number")
        end
        return true
    end
end

---@return lua-valid.validator
function validators.is_boolean()
    return function(value)
        if type(value) ~= "boolean" then
            return false, generate_value_error(value, true, "a boolean")
        end
        return true
    end
end

---@param child_validator lua-valid.validator
---@param is_object boolean | nil
---@return lua-valid.validator
function validators.is_array(child_validator, is_object)
    return function(value)
        local errs = {}

        if type(value) == "table" then
            for index, child in next, value do
                if not validators.is_integer()(index) then
                    if not is_object then
                        errs[index] = generate_value_error(child, false, "is not allowed")
                    end
                    goto continue
                end

                local valid, err = child_validator(child)
                if not valid then
                    errs[index] = err
                end

                ::continue::
            end
        else
            return false, generate_value_error(value, true, "an array")
        end

        if next(errs) == nil then
            return true
        else
            return false, generate_array_error(errs)
        end
    end
end

---@return lua-valid.validator
function validators.in_list(list)
    return function(value)
        local printed_list = "["
        for _, value_in_list in next, list do
            if value_in_list == value then
                return true
            end

            printed_list = printed_list .. " '" .. value_in_list .. "'"
        end

        printed_list = printed_list .. " ]"
        return false, generate_value_error(value, true, "in list " .. printed_list)
    end
end

---@param t table
---@param schema lua-valid.schema
---@param ignore_not_specified boolean
---@return boolean
---@return lua-valid.table.error | nil
local function validate_table(t, schema, ignore_not_specified)
    ---@type table<any, lua-valid.error>
    local errs = {}

    for key, validator in next, schema do
        if not t[key] then
            local _, err = validator(nil)
            errs[key] = err
        end
    end

    for key, value in next, t do
        local validator = schema[key]
        if not validator then
            if not ignore_not_specified then
                errs[key] = generate_value_error(value, false, "is not allowed")
            end
            goto continue
        end

        local valid, err = validator(value)
        if not valid then
            errs[key] = err
        end

        ::continue::
    end

    if next(errs) == nil then
        return true
    end

    return false, generate_table_error(errs)
end

---@param schema lua-valid.schema | nil
---@param ignore_not_specified boolean | nil
---@return lua-valid.validator
function validators.is_table(schema, ignore_not_specified)
    ignore_not_specified = ignore_not_specified or false

    return function(value)
        if type(value) ~= "table" then
            return false, generate_value_error(value, true, "a table")
        end

        if not schema then
            return true
        end

        return validate_table(value, schema, ignore_not_specified)
    end
end

---@class lua-valid : lua-valid.validators
---@field optional lua-valid.validators
local validation = {
    optional = {}
}
for key, validator in pairs(validators) do
    validation[key] = validator
end
for key, validator in pairs(validators) do
    validation.optional[key] = function(...)
        local validator_func = validator(...)
        return function(value)
            if value then
                return validator_func(value)
            end
            return true
        end
    end
end

---@param ... lua-valid.validator
---@return lua-valid.validator
function validation.OR(...)
    local or_validators = { ... }
    return function(value)
        local errs = {}
        for _, validator in ipairs(or_validators) do
            local valid, err = validator(value)
            if valid then
                return true
            end
            ---@cast err -nil

            insert(errs, err)
        end
        return false, generate_or_error(errs)
    end
end

return validation
