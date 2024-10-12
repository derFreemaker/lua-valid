-- caching globals for performance
local type = type
local insert = table.insert
local next = next

---@class lua-valid.error
---@field found string
---@field expected string
---@field missing boolean

---@class lua-valid.validators
local validators = {}

---@alias lua-valid.value.validator fun(value: any) : boolean, lua-valid.error | nil
---@alias lua-valid.table.validator fun(value: any) : boolean, table<any, lua-valid.error> | nil
---@alias lua-valid.validator lua-valid.value.validator | lua-valid.table.validator

---@alias lua-valid.schema table<any, lua-valid.validator>

---@param value any
---@param expected string
---@return lua-valid.error
local function generate_error(value, expected)
    return {
        found = type(value),
        expected = expected,
        missing = value == nil
    }
end

---@return lua-valid.value.validator
function validators.is_string()
    return function(value)
        if type(value) ~= "string" then
            return false, generate_error(value, "a string")
        end

        return true
    end
end

---@return lua-valid.value.validator
function validators.is_integer()
    return function(value)
        if type(value) ~= "number" or value % 1 ~= 0 then
            return false, generate_error(value, "an integer")
        end
        return true
    end
end

---@return lua-valid.value.validator
function validators.is_number()
    return function(value)
        if type(value) ~= "number" then
            return false, generate_error(value, "a number")
        end
        return true
    end
end

---@return lua-valid.value.validator
function validators.is_boolean()
    return function(value)
        if type(value) ~= "boolean" then
            return false, generate_error(value, "a boolean")
        end
        return true
    end
end

---@param child_validator lua-valid.validator
---@param is_object any
---@return lua-valid.table.validator
function validators.is_array(child_validator, is_object)
    return function(value)
        local errs = {}

        if type(value) == "table" then
            for index, child in next, value do
                if not is_object and type(index) ~= "number" then
                    insert(errs, generate_error(value, "an array"))
                else
                    local valid, err = child_validator(child)
                    if not valid then
                        errs[index] = err
                    end
                end
            end
        else
            insert(errs, generate_error(value, "an array"))
        end

        if next(errs) == nil then
            return true
        else
            return false, errs
        end
    end
end

---@return lua-valid.value.validator
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
        return false, generate_error(value, "in list '" .. printed_list)
    end
end

---@param t table
---@param schema lua-valid.schema
---@param ignore_not_specified boolean
---@return boolean, table<any, lua-valid.error>
local function validate_table(t, schema, ignore_not_specified)
    ---@type table<any, lua-valid.error>
    local errs = {}

    for key, value in pairs(t) do
        local validator = schema[key]
        if not validator and not ignore_not_specified then
            errs[key] = { found = type(value), expected = "is not allowed", missing = false }
            goto continue
        end

        local valid, err = validator(value)
        if not valid then
            errs[key] = err
        end

        ::continue::
    end

    return next(errs) == nil, errs
end

---@param schema lua-valid.schema | nil
---@param ignore_not_specified boolean | nil
---@return lua-valid.table.validator
function validators.is_table(schema, ignore_not_specified)
    ignore_not_specified = ignore_not_specified or false

    return function(value)
        if type(value) ~= "table" then
            return false, generate_error(value, "a table")
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
    validation.optional[key] = function(value)
        if value then
            return validator(value)
        end
        return true
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
        return false, errs
    end
end

return validation
