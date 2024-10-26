lu = require("tests.luaunit")

-- local v = require("validation")

-- ---@param validator lua-valid.validator
-- ---@param value any
-- ---@param expected_valid boolean
-- local function test_validator(validator, value, expected_valid)
--     local valid, err = validator(value)

--     if valid ~= expected_valid then
--         if expected_valid then
--             ---@cast err -nil

--             lu.fail(err.to_string())
--         else
--             lu.fail("should have been not valid")
--         end
--     end
-- end

-- function TestOptional()
--     test_validator(v.optional.is_string(), nil, true)
--     test_validator(v.optional.is_string(), "asd", true)
--     test_validator(v.optional.is_string(), 123, false)
-- end

-- function TestOR()
--     test_validator(v.OR(v.is_string(), v.is_integer()), "123", true)
--     test_validator(v.OR(v.is_string(), v.is_integer()), 123, true)
--     test_validator(v.OR(v.is_string(), v.is_integer()), 123.123, false)
-- end

os.exit(lu.LuaUnit.run())
