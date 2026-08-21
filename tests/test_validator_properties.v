import meiseayoung.vono
import rand
import time
import x.json2

// Verify system property test
// Property-Based Testing for Validator functionality

const test_iterations = 100

struct PropertyTestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats PropertyTestStats) run_property_test(test_name string, test_func fn () bool) {
	stats.total_tests++
	print('🔬 ${test_name}... ')

	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats PropertyTestStats) print_summary() {
	println('\n=== 验证系统属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

// Generate random string
fn generate_random_string(min_len int, max_len int) string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	len := rand.int_in_range(min_len, max_len + 1) or { min_len }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}


// Generate random integers
fn generate_random_int(min int, max int) int {
	return rand.int_in_range(min, max + 1) or { min }
}

// Generate random floating point numbers
fn generate_random_float(min f64, max f64) f64 {
	return min + rand.f64() * (max - min)
}

// Generate random boolean values
fn generate_random_bool() bool {
	return rand.int_in_range(0, 2) or { 0 } == 1
}

// ============================================================================
// Property 14: Validator Required Field Enforcement
// Feature: builtin-middleware, Property 14: Validator Required Field Enforcement
// Validates: Requirements 7.5, 7.7
// 
// *For any* schema with required fields, validation SHALL fail if any required 
// field is missing from the input.
// ============================================================================
fn test_property_14_required_field_enforcement() bool {
	rand.seed([u32(time.now().unix()), u32(14141)])
	
	for i in 0 .. test_iterations {
		// Create a schema with required fields
		field_name := 'required_field_${i}'
		schema := vono.v_object({
			field_name: vono.v_string().required()
		})
		
		// Test 1: Missing required fields should fail
		empty_data := map[string]json2.Any{}
		result1 := vono.validate_schema(empty_data, schema)
		
		if result1.success {
			println('  Iteration ${i}: Validation should fail when required field is missing')
			return false
		}
		
		// Verify that the error message contains the correct field name
		mut found_error := false
		for err in result1.errors {
			if err.field == field_name && err.code == 'required' {
				found_error = true
				break
			}
		}
		
		if !found_error {
			println('  Iteration ${i}: Error should reference the missing required field')
			return false
		}
		
		// Test 2: Providing required fields should succeed
		mut data_with_field := map[string]json2.Any{}
		data_with_field[field_name] = json2.Any(generate_random_string(1, 20))
		result2 := vono.validate_schema(data_with_field, schema)
		
		if !result2.success {
			println('  Iteration ${i}: Validation should pass when required field is provided')
			return false
		}
	}
	
	return true
}


// ============================================================================
// Property 15: Validator Type Coercion Consistency
// Feature: builtin-middleware, Property 15: Validator Type Coercion Consistency
// Validates: Requirements 7.6, 7.8
// 
// *For any* input value and type schema, if the value can be coerced to the 
// target type, the validated output SHALL be of the correct type.
// ============================================================================
fn test_property_15_type_coercion_consistency() bool {
	rand.seed([u32(time.now().unix()), u32(15151)])
	
	for i in 0 .. test_iterations {
		//Test string type
		str_schema := vono.v_object({
			'str_field': vono.v_string()
		})
		
		str_value := generate_random_string(1, 50)
		mut str_data := map[string]json2.Any{}
		str_data['str_field'] = json2.Any(str_value)
		
		str_result := vono.validate_schema(str_data, str_schema)
		if !str_result.success {
			println('  Iteration ${i}: String validation should pass for valid string')
			return false
		}
		
		//Test integer type
		int_schema := vono.v_object({
			'int_field': vono.v_int()
		})
		
		int_value := generate_random_int(-1000, 1000)
		mut int_data := map[string]json2.Any{}
		int_data['int_field'] = json2.Any(int_value)
		
		int_result := vono.validate_schema(int_data, int_schema)
		if !int_result.success {
			println('  Iteration ${i}: Int validation should pass for valid int')
			return false
		}
		
		//Test floating point type
		float_schema := vono.v_object({
			'float_field': vono.v_float()
		})
		
		float_value := generate_random_float(-1000.0, 1000.0)
		mut float_data := map[string]json2.Any{}
		float_data['float_field'] = json2.Any(float_value)
		
		float_result := vono.validate_schema(float_data, float_schema)
		if !float_result.success {
			println('  Iteration ${i}: Float validation should pass for valid float')
			return false
		}
		
		//Test boolean type
		bool_schema := vono.v_object({
			'bool_field': vono.v_bool()
		})
		
		bool_value := generate_random_bool()
		mut bool_data := map[string]json2.Any{}
		bool_data['bool_field'] = json2.Any(bool_value)
		
		bool_result := vono.validate_schema(bool_data, bool_schema)
		if !bool_result.success {
			println('  Iteration ${i}: Bool validation should pass for valid bool')
			return false
		}
	}
	
	return true
}


// ============================================================================
// Property 16: Validator Constraint Enforcement
// Feature: builtin-middleware, Property 16: Validator Constraint Enforcement
// Validates: Requirements 7.9, 7.10, 7.11
// 
// *For any* string/numeric value and constraint schema (min, max, pattern, enum), 
// validation SHALL fail if the value violates any constraint.
// ============================================================================
fn test_property_16_constraint_enforcement() bool {
	rand.seed([u32(time.now().unix()), u32(16161)])
	
	for i in 0 .. test_iterations {
		//Test string minimum length constraint
		min_len := rand.int_in_range(5, 20) or { 10 }
		str_min_schema := vono.v_object({
			'str_field': vono.v_string().min(min_len)
		})
		
		// Generate a string that is too short
		short_str := generate_random_string(1, min_len - 1)
		mut short_data := map[string]json2.Any{}
		short_data['str_field'] = json2.Any(short_str)
		
		short_result := vono.validate_schema(short_data, str_min_schema)
		if short_result.success {
			println('  Iteration ${i}: String shorter than min_length should fail validation')
			return false
		}
		
		// Generate a string long enough
		long_str := generate_random_string(min_len, min_len + 10)
		mut long_data := map[string]json2.Any{}
		long_data['str_field'] = json2.Any(long_str)
		
		long_result := vono.validate_schema(long_data, str_min_schema)
		if !long_result.success {
			println('  Iteration ${i}: String meeting min_length should pass validation')
			return false
		}
		
		//Test the maximum string length constraint
		max_len := rand.int_in_range(5, 20) or { 10 }
		str_max_schema := vono.v_object({
			'str_field': vono.v_string().max(max_len)
		})
		
		// Generate a string that is too long
		too_long_str := generate_random_string(max_len + 1, max_len + 10)
		mut too_long_data := map[string]json2.Any{}
		too_long_data['str_field'] = json2.Any(too_long_str)
		
		too_long_result := vono.validate_schema(too_long_data, str_max_schema)
		if too_long_result.success {
			println('  Iteration ${i}: String longer than max_length should fail validation')
			return false
		}
		
		// Test the integer minimum constraint
		min_val := rand.int_in_range(-100, 100) or { 0 }
		int_min_schema := vono.v_object({
			'int_field': vono.v_int().min(min_val)
		})
		
		// Generate an integer less than the minimum value
		too_small := min_val - rand.int_in_range(1, 50) or { 1 }
		mut too_small_data := map[string]json2.Any{}
		too_small_data['int_field'] = json2.Any(too_small)
		
		too_small_result := vono.validate_schema(too_small_data, int_min_schema)
		if too_small_result.success {
			println('  Iteration ${i}: Int smaller than min should fail validation')
			return false
		}
		
		// Test the integer maximum constraint
		max_val := rand.int_in_range(-100, 100) or { 0 }
		int_max_schema := vono.v_object({
			'int_field': vono.v_int().max(max_val)
		})
		
		// Generate an integer greater than the maximum value
		too_large := max_val + rand.int_in_range(1, 50) or { 1 }
		mut too_large_data := map[string]json2.Any{}
		too_large_data['int_field'] = json2.Any(too_large)
		
		too_large_result := vono.validate_schema(too_large_data, int_max_schema)
		if too_large_result.success {
			println('  Iteration ${i}: Int larger than max should fail validation')
			return false
		}
		
		//Test enumeration constraints
		enum_values := ['apple', 'banana', 'cherry']
		enum_schema := vono.v_object({
			'enum_field': vono.v_string().enum_of(enum_values)
		})
		
		// Test for valid enumeration values
		valid_enum_idx := rand.int_in_range(0, enum_values.len) or { 0 }
		mut valid_enum_data := map[string]json2.Any{}
		valid_enum_data['enum_field'] = json2.Any(enum_values[valid_enum_idx])
		
		valid_enum_result := vono.validate_schema(valid_enum_data, enum_schema)
		if !valid_enum_result.success {
			println('  Iteration ${i}: Valid enum value should pass validation')
			return false
		}
		
		// Test for invalid enumeration values
		mut invalid_enum_data := map[string]json2.Any{}
		invalid_enum_data['enum_field'] = json2.Any('invalid_value')
		
		invalid_enum_result := vono.validate_schema(invalid_enum_data, enum_schema)
		if invalid_enum_result.success {
			println('  Iteration ${i}: Invalid enum value should fail validation')
			return false
		}
	}
	
	return true
}


// ============================================================================
// Property 17: Validator Nested Object Recursion
// Feature: builtin-middleware, Property 17: Validator Nested Object Recursion
// Validates: Requirements 7.12, 7.13
// 
// *For any* nested object schema, validation SHALL recursively validate all 
// nested properties.
// ============================================================================
fn test_property_17_nested_object_recursion() bool {
	rand.seed([u32(time.now().unix()), u32(17171)])
	
	for i in 0 .. test_iterations {
		//Create nested object schema
		nested_schema := vono.v_object({
			'outer': vono.v_object({
				'inner': vono.v_object({
					'value': vono.v_string().required()
				}).required()
			}).required()
		})
		
		// Test 1: The complete nested object should pass validation
		inner_value := generate_random_string(1, 20)
		
		mut inner_obj := map[string]json2.Any{}
		inner_obj['value'] = json2.Any(inner_value)
		
		mut middle_obj := map[string]json2.Any{}
		middle_obj['inner'] = json2.Any(inner_obj)
		
		mut outer_obj := map[string]json2.Any{}
		outer_obj['outer'] = json2.Any(middle_obj)
		
		valid_result := vono.validate_schema(outer_obj, nested_schema)
		if !valid_result.success {
			println('  Iteration ${i}: Valid nested object should pass validation')
			println('  Errors: ${valid_result.errors}')
			return false
		}
		
		// Test 2: Should fail if innermost required field is missing
		mut inner_obj_missing := map[string]json2.Any{}
		// Do not add 'value' field
		
		mut middle_obj_missing := map[string]json2.Any{}
		middle_obj_missing['inner'] = json2.Any(inner_obj_missing)
		
		mut outer_obj_missing := map[string]json2.Any{}
		outer_obj_missing['outer'] = json2.Any(middle_obj_missing)
		
		missing_result := vono.validate_schema(outer_obj_missing, nested_schema)
		if missing_result.success {
			println('  Iteration ${i}: Missing nested required field should fail validation')
			return false
		}
		
		// Validate error path contains nested field names
		mut found_nested_error := false
		for err in missing_result.errors {
			if err.field.contains('outer') && err.field.contains('inner') && err.field.contains('value') {
				found_nested_error = true
				break
			}
		}
		
		if !found_nested_error {
			println('  Iteration ${i}: Error should reference the nested field path')
			return false
		}
		
		// Test 3: Missing middle-tier object should fail
		mut outer_obj_no_middle := map[string]json2.Any{}
		outer_obj_no_middle['outer'] = json2.Any(map[string]json2.Any{})
		
		no_middle_result := vono.validate_schema(outer_obj_no_middle, nested_schema)
		if no_middle_result.success {
			println('  Iteration ${i}: Missing middle nested object should fail validation')
			return false
		}
	}
	
	return true
}

fn main() {
	println('🚀 开始验证系统属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := PropertyTestStats{}

	//Run property tests
	// Feature: builtin-middleware, Property 14: Validator Required Field Enforcement
	// Validates: Requirements 7.5, 7.7
	stats.run_property_test('Property 14: Validator Required Field Enforcement', test_property_14_required_field_enforcement)
	
	// Feature: builtin-middleware, Property 15: Validator Type Coercion Consistency
	// Validates: Requirements 7.6, 7.8
	stats.run_property_test('Property 15: Validator Type Coercion Consistency', test_property_15_type_coercion_consistency)
	
	// Feature: builtin-middleware, Property 16: Validator Constraint Enforcement
	// Validates: Requirements 7.9, 7.10, 7.11
	stats.run_property_test('Property 16: Validator Constraint Enforcement', test_property_16_constraint_enforcement)
	
	// Feature: builtin-middleware, Property 17: Validator Nested Object Recursion
	// Validates: Requirements 7.12, 7.13
	stats.run_property_test('Property 17: Validator Nested Object Recursion', test_property_17_nested_object_recursion)

	//Print test summary
	stats.print_summary()
}
