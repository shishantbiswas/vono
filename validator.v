module hono

import net.http
import x.json2
import regex

// ValidationTarget enumeration - validation target type
pub enum ValidationTarget {
	json    // JSON body
	query   // Query parameters
	param   // Path parameters
	header  // Request headers
	form    // Form data
}

// Schema union type - supports multiple Schema types
pub type Schema = StringSchema | IntSchema | FloatSchema | BoolSchema | ArraySchema | ObjectSchema

// StringSchema structure - string validation rules
pub struct StringSchema {
pub:
	required    bool
	min_length  int
	max_length  int
	pattern     string
	enum_values []string
	default_val string
}

// IntSchema structure - integer validation rules
pub struct IntSchema {
pub:
	required    bool
	min         ?int
	max         ?int
	enum_values []int
	default_val int
}

// FloatSchema structure - floating point number validation rules
pub struct FloatSchema {
pub:
	required    bool
	min         ?f64
	max         ?f64
	default_val f64
}

// BoolSchema structure - Boolean validation rules
pub struct BoolSchema {
pub:
	required    bool
	default_val bool
}


// ArraySchema structure - array validation rules
pub struct ArraySchema {
pub:
	required  bool
	min_items int
	max_items int
	items     &Schema = unsafe { nil }
}

// ObjectSchema structure - object validation rules
pub struct ObjectSchema {
pub:
	required   bool
	properties map[string]Schema
}

// ValidationResult structure - validation result
pub struct ValidationResult {
pub:
	success bool
	errors  []ValidationError
	data    map[string]json2.Any
}

// ValidationError structure - validation error
pub struct ValidationError {
pub:
	field   string
	message string
	code    string
}

// ValidatorOptions structure - validator configuration options
pub struct ValidatorOptions {
pub:
	on_error ?fn ([]ValidationError, mut Context) http.Response
}


// ============================================================================
// Schema Builder API - factory function
// ============================================================================

// v_string - Create string Schema
pub fn v_string() StringSchema {
	return StringSchema{}
}

// v_int - Create an integer Schema
pub fn v_int() IntSchema {
	return IntSchema{}
}

// v_float - Create a floating point number Schema
pub fn v_float() FloatSchema {
	return FloatSchema{}
}

// v_bool - Create a Boolean Schema
pub fn v_bool() BoolSchema {
	return BoolSchema{}
}

// v_array - Create array Schema
pub fn v_array(items Schema) ArraySchema {
	// Directly store a copy of the Schema
	return ArraySchema{
		items: &items
	}
}

// v_object - Create object Schema
pub fn v_object(properties map[string]Schema) ObjectSchema {
	return ObjectSchema{
		properties: properties
	}
}

// ============================================================================
// StringSchema chain method
// ============================================================================

// required - set as a required field
pub fn (s StringSchema) required() StringSchema {
	return StringSchema{
		...s
		required: true
	}
}

// min - set the minimum length
pub fn (s StringSchema) min(len int) StringSchema {
	return StringSchema{
		...s
		min_length: len
	}
}

// max - sets the maximum length
pub fn (s StringSchema) max(len int) StringSchema {
	return StringSchema{
		...s
		max_length: len
	}
}

// pattern - Set the regular expression pattern
pub fn (s StringSchema) pattern(regex_pattern string) StringSchema {
	return StringSchema{
		...s
		pattern: regex_pattern
	}
}

// enum_of - set enumeration value
pub fn (s StringSchema) enum_of(values []string) StringSchema {
	return StringSchema{
		...s
		enum_values: values
	}
}

// default_value - set default value
pub fn (s StringSchema) default_value(val string) StringSchema {
	return StringSchema{
		...s
		default_val: val
	}
}


// ============================================================================
//IntSchema chain method
// ============================================================================

// required - set as a required field
pub fn (s IntSchema) required() IntSchema {
	return IntSchema{
		...s
		required: true
	}
}

// min - set the minimum value
pub fn (s IntSchema) min(val int) IntSchema {
	return IntSchema{
		...s
		min: val
	}
}

// max - set the maximum value
pub fn (s IntSchema) max(val int) IntSchema {
	return IntSchema{
		...s
		max: val
	}
}

// enum_of - set enumeration value
pub fn (s IntSchema) enum_of(values []int) IntSchema {
	return IntSchema{
		...s
		enum_values: values
	}
}

// default_value - set default value
pub fn (s IntSchema) default_value(val int) IntSchema {
	return IntSchema{
		...s
		default_val: val
	}
}

// ============================================================================
// FloatSchema chain method
// ============================================================================

// required - set as a required field
pub fn (s FloatSchema) required() FloatSchema {
	return FloatSchema{
		...s
		required: true
	}
}

// min - set the minimum value
pub fn (s FloatSchema) min(val f64) FloatSchema {
	return FloatSchema{
		...s
		min: val
	}
}

// max - set the maximum value
pub fn (s FloatSchema) max(val f64) FloatSchema {
	return FloatSchema{
		...s
		max: val
	}
}

// default_value - set default value
pub fn (s FloatSchema) default_value(val f64) FloatSchema {
	return FloatSchema{
		...s
		default_val: val
	}
}

// ============================================================================
// BoolSchema chain method
// ============================================================================

// required - set as a required field
pub fn (s BoolSchema) required() BoolSchema {
	return BoolSchema{
		...s
		required: true
	}
}

// default_value - set default value
pub fn (s BoolSchema) default_value(val bool) BoolSchema {
	return BoolSchema{
		...s
		default_val: val
	}
}


// ============================================================================
//ArraySchema chain method
// ============================================================================

// required - set as a required field
pub fn (s ArraySchema) required() ArraySchema {
	return ArraySchema{
		...s
		required: true
	}
}

// min_items_count - sets the minimum number of elements
pub fn (s ArraySchema) min_items_count(count int) ArraySchema {
	return ArraySchema{
		...s
		min_items: count
	}
}

// max_items_count - sets the maximum number of elements
pub fn (s ArraySchema) max_items_count(count int) ArraySchema {
	return ArraySchema{
		...s
		max_items: count
	}
}

// ============================================================================
// ObjectSchema chain method
// ============================================================================

// required - set as a required field
pub fn (s ObjectSchema) required() ObjectSchema {
	return ObjectSchema{
		...s
		required: true
	}
}


// ============================================================================
//Verify logic implementation
// ============================================================================

// validate_value - validate a single value
fn validate_value(field_name string, value json2.Any, schema Schema) []ValidationError {
	mut errors := []ValidationError{}
	
	match schema {
		StringSchema {
			errors << validate_string(field_name, value, schema)
		}
		IntSchema {
			errors << validate_int(field_name, value, schema)
		}
		FloatSchema {
			errors << validate_float(field_name, value, schema)
		}
		BoolSchema {
			errors << validate_bool(field_name, value, schema)
		}
		ArraySchema {
			errors << validate_array(field_name, value, schema)
		}
		ObjectSchema {
			errors << validate_object(field_name, value, schema)
		}
	}
	
	return errors
}

// validate_string - validate string value
fn validate_string(field_name string, value json2.Any, schema StringSchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// Check if the value is null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	// Get string value
	str_val := value.str()
	
	// Check for empty string
	if str_val.len == 0 && schema.required {
		errors << ValidationError{
			field: field_name
			message: 'Field is required'
			code: 'required'
		}
		return errors
	}
	
	// Check the minimum length
	if schema.min_length > 0 && str_val.len < schema.min_length {
		errors << ValidationError{
			field: field_name
			message: 'String length must be at least ${schema.min_length}'
			code: 'min_length'
		}
	}
	
	// Check the maximum length
	if schema.max_length > 0 && str_val.len > schema.max_length {
		errors << ValidationError{
			field: field_name
			message: 'String length must be at most ${schema.max_length}'
			code: 'max_length'
		}
	}
	
	// Check regular expression pattern
	if schema.pattern.len > 0 {
		mut re := regex.regex_opt(schema.pattern) or {
			errors << ValidationError{
				field: field_name
				message: 'Invalid pattern: ${schema.pattern}'
				code: 'invalid_pattern'
			}
			return errors
		}
		
		if !re.matches_string(str_val) {
			errors << ValidationError{
				field: field_name
				message: 'Value does not match pattern: ${schema.pattern}'
				code: 'pattern'
			}
		}
	}
	
	// Check enumeration value
	if schema.enum_values.len > 0 {
		if str_val !in schema.enum_values {
			errors << ValidationError{
				field: field_name
				message: 'Value must be one of: ${schema.enum_values.join(", ")}'
				code: 'enum'
			}
		}
	}
	
	return errors
}


// validate_int - validates integer values
fn validate_int(field_name string, value json2.Any, schema IntSchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// Check if the value is null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	//Try to convert to integer
	int_val := value.int()
	
	// Check the minimum value
	if min := schema.min {
		if int_val < min {
			errors << ValidationError{
				field: field_name
				message: 'Value must be at least ${min}'
				code: 'min'
			}
		}
	}
	
	// Check the maximum value
	if max := schema.max {
		if int_val > max {
			errors << ValidationError{
				field: field_name
				message: 'Value must be at most ${max}'
				code: 'max'
			}
		}
	}
	
	// Check enumeration value
	if schema.enum_values.len > 0 {
		if int_val !in schema.enum_values {
			errors << ValidationError{
				field: field_name
				message: 'Value must be one of: ${schema.enum_values}'
				code: 'enum'
			}
		}
	}
	
	return errors
}

// validate_float - validate floating point values
fn validate_float(field_name string, value json2.Any, schema FloatSchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// Check if the value is null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	//Try to convert to float
	float_val := value.f64()
	
	// Check the minimum value
	if min := schema.min {
		if float_val < min {
			errors << ValidationError{
				field: field_name
				message: 'Value must be at least ${min}'
				code: 'min'
			}
		}
	}
	
	// Check the maximum value
	if max := schema.max {
		if float_val > max {
			errors << ValidationError{
				field: field_name
				message: 'Value must be at most ${max}'
				code: 'max'
			}
		}
	}
	
	return errors
}

// validate_bool - validate boolean value
fn validate_bool(field_name string, value json2.Any, schema BoolSchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// Check if the value is null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	// Verify if it is a boolean type
	match value {
		bool {
			// Valid boolean value
		}
		else {
			// Attempt to convert from string
			str_val := value.str().to_lower()
			if str_val !in ['true', 'false', '1', '0'] {
				errors << ValidationError{
					field: field_name
					message: 'Value must be a boolean'
					code: 'type'
				}
			}
		}
	}
	
	return errors
}


// validate_array - validate array values
fn validate_array(field_name string, value json2.Any, schema ArraySchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// Check if the value is null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	// Get array
	arr := value.as_array()
	
	// Check the minimum number of elements
	if schema.min_items > 0 && arr.len < schema.min_items {
		errors << ValidationError{
			field: field_name
			message: 'Array must have at least ${schema.min_items} items'
			code: 'min_items'
		}
	}
	
	// Check the maximum number of elements
	if schema.max_items > 0 && arr.len > schema.max_items {
		errors << ValidationError{
			field: field_name
			message: 'Array must have at most ${schema.max_items} items'
			code: 'max_items'
		}
	}
	
	//Verify array elements
	if schema.items != unsafe { nil } {
		for i, item in arr {
			item_errors := validate_value('${field_name}[${i}]', item, *schema.items)
			errors << item_errors
		}
	}
	
	return errors
}

// validate_object - validate object values ​​(recursively validate nested properties)
fn validate_object(field_name string, value json2.Any, schema ObjectSchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// Check if the value is null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	// get object
	obj := value.as_map()
	
	// Validate each attribute
	for prop_name, prop_schema in schema.properties {
		full_field_name := if field_name.len > 0 { '${field_name}.${prop_name}' } else { prop_name }
		
		if prop_name in obj {
			prop_value := obj[prop_name] or { json2.Null{} }
			prop_errors := validate_value(full_field_name, prop_value, prop_schema)
			errors << prop_errors
		} else {
			// Field does not exist, check if it is required
			is_required := match prop_schema {
				StringSchema { prop_schema.required }
				IntSchema { prop_schema.required }
				FloatSchema { prop_schema.required }
				BoolSchema { prop_schema.required }
				ArraySchema { prop_schema.required }
				ObjectSchema { prop_schema.required }
			}
			
			if is_required {
				errors << ValidationError{
					field: full_field_name
					message: 'Field is required'
					code: 'required'
				}
			}
		}
	}
	
	return errors
}

// validate_schema - Verify that the data conforms to the ObjectSchema
pub fn validate_schema(data map[string]json2.Any, schema ObjectSchema) ValidationResult {
	mut errors := []ValidationError{}
	
	// Validate each attribute
	for prop_name, prop_schema in schema.properties {
		if prop_name in data {
			prop_value := data[prop_name] or { json2.Null{} }
			prop_errors := validate_value(prop_name, prop_value, prop_schema)
			errors << prop_errors
		} else {
			// Field does not exist, check if it is required
			is_required := match prop_schema {
				StringSchema { prop_schema.required }
				IntSchema { prop_schema.required }
				FloatSchema { prop_schema.required }
				BoolSchema { prop_schema.required }
				ArraySchema { prop_schema.required }
				ObjectSchema { prop_schema.required }
			}
			
			if is_required {
				errors << ValidationError{
					field: prop_name
					message: 'Field is required'
					code: 'required'
				}
			}
		}
	}
	
	return ValidationResult{
		success: errors.len == 0
		errors: errors
		data: data
	}
}


// ============================================================================
//Verify middleware implementation
// ============================================================================

// validator - validation middleware factory function
// Return a ContextMiddleware for validating request data
pub fn validator(target ValidationTarget, schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	opts := if options.len > 0 { options[0] } else { ValidatorOptions{} }
	
	return fn [target, schema, opts] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// Get data based on target type
		data := get_validation_data(c, target) or {
			// Parsing error
			errors := [ValidationError{
				field: ''
				message: err.msg()
				code: 'parse_error'
			}]
			
			// Use custom error handler or default response
			if on_error := opts.on_error {
				return on_error(errors, mut c)
			}
			
			c.status(400)
			return c.json(build_error_response(errors))
		}
		
		//Verify data
		result := validate_schema(data, schema)
		
		if !result.success {
			// Use custom error handler or default response
			if on_error := opts.on_error {
				return on_error(result.errors, mut c)
			}
			
			c.status(400)
			return c.json(build_error_response(result.errors))
		}
		
		// Store the verified data in Context
		store_validated_data(mut c, result.data)
		
		// Continue processing the request
		return next(mut c)
	}
}

// get_validation_data - Get the data to be validated based on the target type
fn get_validation_data(c Context, target ValidationTarget) !map[string]json2.Any {
	match target {
		.json {
			return parse_json_body(c)
		}
		.query {
			return parse_query_params(c)
		}
		.param {
			return parse_path_params(c)
		}
		.header {
			return parse_headers(c)
		}
		.form {
			return parse_form_data(c)
		}
	}
}

// parse_json_body - Parse the JSON request body
fn parse_json_body(c Context) !map[string]json2.Any {
	if c.body.len == 0 {
		return map[string]json2.Any{}
	}
	
	raw := json2.decode[json2.Any](c.body) or {
		return error('Invalid JSON: ${err}')
	}
	
	return raw.as_map()
}

// parse_query_params - parse query parameters
fn parse_query_params(c Context) !map[string]json2.Any {
	mut data := map[string]json2.Any{}
	
	for key, value in c.query {
		data[key] = json2.Any(value)
	}
	
	return data
}

// parse_path_params - parse path parameters
fn parse_path_params(c Context) !map[string]json2.Any {
	mut data := map[string]json2.Any{}
	
	for key, value in c.params {
		data[key] = json2.Any(value)
	}
	
	return data
}

// parse_headers - parse request headers
fn parse_headers(c Context) !map[string]json2.Any {
	mut data := map[string]json2.Any{}
	
	// Get common request headers
	common_headers := ['Content-Type', 'Accept', 'Authorization', 'X-Request-ID', 
		'X-Forwarded-For', 'User-Agent', 'Host', 'Origin', 'Referer']
	
	for header_name in common_headers {
		if header_value := c.req.header.get_custom(header_name) {
			data[header_name] = json2.Any(header_value)
		}
	}
	
	return data
}

// parse_form_data - Parse form data
fn parse_form_data(c Context) !map[string]json2.Any {
	mut data := map[string]json2.Any{}
	
	if c.body.len == 0 {
		return data
	}
	
	// Parse application/x-www-form-urlencoded format
	pairs := c.body.split('&')
	for pair in pairs {
		eq_pos := pair.index('=') or { continue }
		if eq_pos == 0 {
			continue
		}
		
		key := pair[..eq_pos]
		value := if eq_pos + 1 < pair.len { pair[eq_pos + 1..] } else { '' }
		
		// URL decoding
		decoded_key := url_decode(key)
		decoded_value := url_decode(value)
		
		data[decoded_key] = json2.Any(decoded_value)
	}
	
	return data
}


// url_decode - URL decoding
fn url_decode(s string) string {
	mut result := []u8{}
	mut i := 0
	
	for i < s.len {
		if s[i] == `%` && i + 2 < s.len {
			//Try to decode hexadecimal
			hex_str := s[i + 1..i + 3]
			if hex_val := hex_to_byte(hex_str) {
				result << hex_val
				i += 3
				continue
			}
		} else if s[i] == `+` {
			result << ` `
			i++
			continue
		}
		
		result << s[i]
		i++
	}
	
	return result.bytestr()
}

// hex_to_byte - Converts a two-digit hexadecimal string to bytes
fn hex_to_byte(hex string) ?u8 {
	if hex.len != 2 {
		return none
	}
	
	high := hex_char_to_val(hex[0]) or { return none }
	low := hex_char_to_val(hex[1]) or { return none }
	
	return u8(high * 16 + low)
}

// hex_char_to_val - Convert hexadecimal characters to numeric values
fn hex_char_to_val(c u8) ?int {
	if c >= `0` && c <= `9` {
		return int(c - `0`)
	}
	if c >= `a` && c <= `f` {
		return int(c - `a` + 10)
	}
	if c >= `A` && c <= `F` {
		return int(c - `A` + 10)
	}
	return none
}

// store_validated_data - stores validated data into Context
fn store_validated_data(mut c Context, data map[string]json2.Any) {
	//Serialize data into JSON string storage
	mut json_parts := []string{}
	for key, value in data {
		json_parts << '"${key}":${value.json_str()}'
	}
	json_str := '{${json_parts.join(",")}}'
	c.set('validated_data', json_str)
	
	// Store the string values ​​of each field at the same time (for quick access)
	for key, value in data {
		c.set('validated_${key}', value.str())
	}
}

// build_error_response - Build error response JSON
fn build_error_response(errors []ValidationError) string {
	mut error_parts := []string{}
	
	for err in errors {
		error_parts << '{"field":"${err.field}","message":"${err.message}","code":"${err.code}"}'
	}
	
	return '{"error":"Bad Request","errors":[${error_parts.join(",")}]}'
}

// get_validated_data - Get validated data from Context
pub fn get_validated_data(c Context) map[string]string {
	mut data := map[string]string{}
	
	// Get all keys starting with validated_ from the store
	for key, value in c.store {
		if key.starts_with('validated_') && key != 'validated_data' {
			field_name := key[10..] // Remove 'validated_' prefix
			data[field_name] = value
		}
	}
	
	return data
}

// get_validated_json - Get the complete validated JSON data from the Context
pub fn get_validated_json(c Context) ?string {
	return c.get('validated_data')
}

// get_validated_field - Get a single validated field value from the Context
pub fn get_validated_field(c Context, field string) ?string {
	return c.get('validated_${field}')
}
