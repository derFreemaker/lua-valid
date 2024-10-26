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

-- function TestIsString()
--     test_validator(v.is_string(), "should work", true)
-- end

-- function TestIsInteger()
--     test_validator(v.is_integer(), 123, true)
--     test_validator(v.is_integer(), 123.123, false)
-- end

-- function TestIsNumber()
--     test_validator(v.is_number(), 123, true)
--     test_validator(v.is_number(), 123.123, true)
-- end

-- function TestIsBoolean()
--     test_validator(v.is_boolean(), true, true)
--     test_validator(v.is_boolean(), false, true)
-- end

-- function TestInList()
--     local list = {
--         "test",
--         123
--     }

--     test_validator(v.in_list(list), "test", true)
--     test_validator(v.in_list(list), 123, true)
-- end

-- function TestIsTable()
--     test_validator(v.is_table(), {}, true)

--     local schema = {
--         test = v.is_string()
--     }
--     test_validator(v.is_table(schema), { test = "test" }, true)
--     test_validator(v.is_table(schema), {}, false)

--     test_validator(v.is_table(schema), { test = "asd", ignore = "test" }, false)
--     test_validator(v.is_table(schema, true), { test = "asd", ignore = "test" }, true)
-- end

-- function TestIsArray()
--     test_validator(v.is_array(v.is_integer()), { 123, 123123 }, true)
--     test_validator(v.is_array(v.is_integer()), { 123, 123.123 }, false)

--     test_validator(v.is_array(v.is_integer()), { 123, test = "aasd" }, false)
--     test_validator(v.is_array(v.is_integer(), true), { 123, test = "aasd" }, true)
-- end

-- function TestIsNil()
--     test_validator(v.is_nil(), nil, true)
--     test_validator(v.is_nil(), "not nil", false)
-- end

-- function TestIsFunction()
--     test_validator(v.is_function(), function() end, true)
--     test_validator(v.is_function(), "not a function", false)
-- end

-- function TestIsUserdata()
--     test_validator(v.is_userdata(), { }, false)
--     test_validator(v.is_userdata(), "not userdata", false)
-- end

-- function TestIsThread()
--     local thread = coroutine.create(function() end)
--     test_validator(v.is_thread(), thread, true)
--     test_validator(v.is_thread(), "not a thread", false)
-- end

os.exit(lu.LuaUnit.run())
