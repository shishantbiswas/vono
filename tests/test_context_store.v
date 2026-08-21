import meiseayoung.vono
import net.http

// Context Store function test
//Test the store field and get/set/get_client_ip method of Context

struct TestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats TestStats) run_test(test_name string, test_func fn () bool) {
	stats.total_tests++
	print('🧪 ${test_name}... ')

	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats TestStats) print_summary() {
	println('\n=== Context Store 测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

//Create a Context for testing
fn create_test_context() vono.Context {
	req := http.Request{
		method: .get
		url: '/test'
	}
	return vono.Context.new(req, map[string]string{}, map[string]string{}, '')
}

//Test 1: Basic set and get operations
fn test_basic_set_get() bool {
	mut ctx := create_test_context()
	
	// set value
	ctx.set('user_id', '12345')
	ctx.set('role', 'admin')
	
	// get value
	if user_id := ctx.get('user_id') {
		if user_id != '12345' {
			return false
		}
	} else {
		return false
	}
	
	if role := ctx.get('role') {
		if role != 'admin' {
			return false
		}
	} else {
		return false
	}
	
	return true
}

//Test 2: Get non-existing key and return none
fn test_get_nonexistent_key() bool {
	ctx := create_test_context()
	
	// Get the non-existing key
	if _ := ctx.get('nonexistent') {
		return false // should return none
	}
	
	return true
}

// Test 3: Overwrite existing value
fn test_overwrite_value() bool {
	mut ctx := create_test_context()
	
	//Set initial value
	ctx.set('key', 'value1')
	
	// override value
	ctx.set('key', 'value2')
	
	//Verify new value
	if val := ctx.get('key') {
		return val == 'value2'
	}
	
	return false
}

// Test 4: Empty string value
fn test_empty_string_value() bool {
	mut ctx := create_test_context()
	
	//Set empty string
	ctx.set('empty', '')
	
	// Get empty string
	if val := ctx.get('empty') {
		return val == ''
	}
	
	return false
}

// Test 5: Multiple key-value pairs
fn test_multiple_keys() bool {
	mut ctx := create_test_context()
	
	//Set multiple values
	for i in 0 .. 10 {
		ctx.set('key${i}', 'value${i}')
	}
	
	// Validate all values
	for i in 0 .. 10 {
		if val := ctx.get('key${i}') {
			if val != 'value${i}' {
				return false
			}
		} else {
			return false
		}
	}
	
	return true
}

//Test 6: get_client_ip default return value
fn test_get_client_ip_default() bool {
	ctx := create_test_context()
	
	// When no IP related header is set, the default value should be returned
	ip := ctx.get_client_ip()
	return ip == '127.0.0.1'
}

//Test 7: get_client_ip is obtained from X-Forwarded-For
fn test_get_client_ip_forwarded_for() bool {
	mut headers := http.new_header()
	headers.add_custom('X-Forwarded-For', '192.168.1.100, 10.0.0.1') or { return false }
	
	req := http.Request{
		method: .get
		url: '/test'
		header: headers
	}
	ctx := vono.Context.new(req, map[string]string{}, map[string]string{}, '')
	
	// should return the first IP
	ip := ctx.get_client_ip()
	return ip == '192.168.1.100'
}

//Test 8: get_client_ip gets from X-Real-IP
fn test_get_client_ip_real_ip() bool {
	mut headers := http.new_header()
	headers.add_custom('X-Real-IP', '10.20.30.40') or { return false }
	
	req := http.Request{
		method: .get
		url: '/test'
		header: headers
	}
	ctx := vono.Context.new(req, map[string]string{}, map[string]string{}, '')
	
	ip := ctx.get_client_ip()
	return ip == '10.20.30.40'
}

// Test 9: X-Forwarded-For takes precedence over X-Real-IP
fn test_get_client_ip_priority() bool {
	mut headers := http.new_header()
	headers.add_custom('X-Forwarded-For', '1.2.3.4') or { return false }
	headers.add_custom('X-Real-IP', '5.6.7.8') or { return false }
	
	req := http.Request{
		method: .get
		url: '/test'
		header: headers
	}
	ctx := vono.Context.new(req, map[string]string{}, map[string]string{}, '')
	
	// X-Forwarded-For should take precedence
	ip := ctx.get_client_ip()
	return ip == '1.2.3.4'
}

//Test 10: store initialized to empty
fn test_store_initialized_empty() bool {
	ctx := create_test_context()
	
	// The store of the newly created Context should be empty
	// Attempts to get any key should return none
	if _ := ctx.get('any_key') {
		return false
	}
	
	return true
}

fn main() {
	println('🚀 开始 Context Store 功能测试...\n')

	mut stats := TestStats{}

	//Run all tests
	stats.run_test('基本 set/get 操作', test_basic_set_get)
	stats.run_test('获取不存在的 key', test_get_nonexistent_key)
	stats.run_test('覆盖已存在的值', test_overwrite_value)
	stats.run_test('空字符串值', test_empty_string_value)
	stats.run_test('多个键值对', test_multiple_keys)
	stats.run_test('get_client_ip 默认值', test_get_client_ip_default)
	stats.run_test('get_client_ip X-Forwarded-For', test_get_client_ip_forwarded_for)
	stats.run_test('get_client_ip X-Real-IP', test_get_client_ip_real_ip)
	stats.run_test('X-Forwarded-For 优先级', test_get_client_ip_priority)
	stats.run_test('store 初始化为空', test_store_initialized_empty)

	//Print test summary
	stats.print_summary()
}
