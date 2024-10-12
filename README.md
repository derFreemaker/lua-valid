# lua-valid
Lua basic validation library.

## Validators

### Normal Validators
- `is_string()` : verify that value is of type `string`
- `is_integer()` : verify that value is of type `integer`
- `is_number()` : verify that value is of type `number`
- `is_boolean()` : verify that value is of type `boolean`
- `in_list(list)` : verify that value is from the given list
- `is_table(schema, ignore_not_specified)` : verify that value is of type `table` and when given validate the schema.
- `is_array(validator, is_object)` : verify that value is of type `table`

### Meta Validators
- `optional.<validator>` : if value is there run validator
- `OR(<validators>...)` : check given validators until valid is found

## Validation error
- `found` : the found type
- `expected` : what was expected
- `missing` : true if value was `nil`
