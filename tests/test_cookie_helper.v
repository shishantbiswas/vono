import meiseayoung.vono
import net.http

// Cookie Helper function test
//Test the get/set/delete and signature functions of Cookie

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
	println('\n=== Cookie Helper 测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

//Create a test Context with Cookie header
fn create_test_context_with_cookies(cookie_header string) vono.Context {
	mut headers := http.new_header()
	if cookie_header.len > 0 {
		headers.add_custom('Cookie', cookie_header) or {}
	}
	
	req := http.Request{
		method: .get
		url: '/test'
		header: headers
	}
	return vono.Context.new(req, map[string]string{}, map[string]string{}, '')
}

//Create an empty test Context
fn create_empty_context() vono.Context {
	req := http.Request{
		method: .get
		url: '/test'
	}
	return vono.Context.new(req, map[string]string{}, map[string]string{}, '')
}


//Test 1: Get a single cookie
fn test_get_single_cookie() bool {
	ctx := create_test_context_with_cookies('session_id=abc123')
	
	if value := vono.get_cookie(ctx, 'session_id') {
		return value == 'abc123'
	}
	return false
}

//Test 2: Get a cookie that does not exist and return none
fn test_get_nonexistent_cookie() bool {
	ctx := create_test_context_with_cookies('session_id=abc123')
	
	if _ := vono.get_cookie(ctx, 'nonexistent') {
		return false // should return none
	}
	return true
}

//Test 3: Get multiple cookies
fn test_get_multiple_cookies() bool {
	ctx := create_test_context_with_cookies('session_id=abc123; user_id=456; theme=dark')
	
	session := vono.get_cookie(ctx, 'session_id') or { return false }
	user := vono.get_cookie(ctx, 'user_id') or { return false }
	theme := vono.get_cookie(ctx, 'theme') or { return false }
	
	return session == 'abc123' && user == '456' && theme == 'dark'
}

//Test 4: Get all cookies
fn test_get_all_cookies() bool {
	ctx := create_test_context_with_cookies('a=1; b=2; c=3')
	
	cookies := vono.get_all_cookies(ctx)
	
	return cookies.len == 3 && 
		cookies['a'] == '1' && 
		cookies['b'] == '2' && 
		cookies['c'] == '3'
}

// Test 5: Empty Cookie header returns empty map
fn test_get_all_cookies_empty() bool {
	ctx := create_empty_context()
	
	cookies := vono.get_all_cookies(ctx)
	
	return cookies.len == 0
}

//Test 6: Set Cookie
fn test_set_cookie_basic() bool {
	mut ctx := create_empty_context()
	
	vono.set_cookie(mut ctx, 'session', 'xyz789')
	
	// Check if the Set-Cookie header is set
	if set_cookie := ctx.headers['Set-Cookie'] {
		return set_cookie.contains('session=xyz789')
	}
	return false
}

// Test 7: Set Cookie with options
fn test_set_cookie_with_options() bool {
	mut ctx := create_empty_context()
	
	vono.set_cookie(mut ctx, 'token', 'secret123', vono.CookieOptions{
		path: '/api'
		http_only: true
		secure: true
		max_age: 3600
		same_site: .strict
	})
	
	if set_cookie := ctx.headers['Set-Cookie'] {
		return set_cookie.contains('token=secret123') &&
			set_cookie.contains('Path=/api') &&
			set_cookie.contains('HttpOnly') &&
			set_cookie.contains('Secure') &&
			set_cookie.contains('Max-Age=3600') &&
			set_cookie.contains('SameSite=Strict')
	}
	return false
}


//Test 8: Delete Cookie
fn test_delete_cookie() bool {
	mut ctx := create_empty_context()
	
	vono.delete_cookie(mut ctx, 'session')
	
	if set_cookie := ctx.headers['Set-Cookie'] {
		// To delete cookies, Max-Age=0 or expiration time should be set
		return set_cookie.contains('session=') &&
			(set_cookie.contains('Max-Age=0') || set_cookie.contains('Expires='))
	}
	return false
}

//Test 9: Cookie value with spaces
fn test_cookie_with_spaces() bool {
	ctx := create_test_context_with_cookies('name=John Doe')
	
	if value := vono.get_cookie(ctx, 'name') {
		return value == 'John Doe'
	}
	return false
}

// Test 10: Cookie value with quotes
fn test_cookie_with_quotes() bool {
	ctx := create_test_context_with_cookies('data="hello world"')
	
	if value := vono.get_cookie(ctx, 'data') {
		return value == 'hello world'
	}
	return false
}

// Test 11: Signed Cookie setting and retrieval
fn test_signed_cookie_roundtrip() bool {
	mut ctx := create_empty_context()
	secret := 'my-secret-key-12345'
	
	// Set signed cookie
	vono.set_signed_cookie(mut ctx, 'auth', 'user123', secret) or {
		println('Failed to set signed cookie: ${err}')
		return false
	}
	
	// Get the value in the Set-Cookie header
	set_cookie_header := ctx.headers['Set-Cookie'] or { return false }
	
	// Extract Cookie value (format: auth=value.signature; ...)
	mut cookie_value := ''
	parts := set_cookie_header.split(';')
	if parts.len > 0 {
		name_value := parts[0].trim_space()
		eq_pos := name_value.index('=') or { return false }
		cookie_value = name_value[eq_pos + 1..]
	}
	
	//Create a new Context with this Cookie to verify
	verify_ctx := create_test_context_with_cookies('auth=${cookie_value}')
	
	//Verify signature cookie
	if value := vono.get_signed_cookie(verify_ctx, 'auth', secret) {
		return value == 'user123'
	} else {
		println('Failed to get signed cookie: ${err}')
		return false
	}
}

//Test 12: Signed Cookie Tamper Detection
fn test_signed_cookie_tamper_detection() bool {
	mut ctx := create_empty_context()
	secret := 'my-secret-key-12345'
	
	// Set signed cookie
	vono.set_signed_cookie(mut ctx, 'auth', 'user123', secret) or { return false }
	
	// Get the value in the Set-Cookie header
	set_cookie_header := ctx.headers['Set-Cookie'] or { return false }
	
	//Extract cookie value
	mut cookie_value := ''
	parts := set_cookie_header.split(';')
	if parts.len > 0 {
		name_value := parts[0].trim_space()
		eq_pos := name_value.index('=') or { return false }
		cookie_value = name_value[eq_pos + 1..]
	}
	
	// Tamper with Cookie value
	tampered_value := 'tampered' + cookie_value[8..] //Modify value part
	
	//Create a Context with tampered cookies
	verify_ctx := create_test_context_with_cookies('auth=${tampered_value}')
	
	// validation should fail
	if _ := vono.get_signed_cookie(verify_ctx, 'auth', secret) {
		return false // should not succeed
	}
	return true // Validation failures are expected
}

// Test 13: Signing Cookie Wrong Key
fn test_signed_cookie_wrong_secret() bool {
	mut ctx := create_empty_context()
	
	// Set using a key
	vono.set_signed_cookie(mut ctx, 'auth', 'user123', 'secret1') or { return false }
	
	// Get the value in the Set-Cookie header
	set_cookie_header := ctx.headers['Set-Cookie'] or { return false }
	
	//Extract cookie value
	mut cookie_value := ''
	parts := set_cookie_header.split(';')
	if parts.len > 0 {
		name_value := parts[0].trim_space()
		eq_pos := name_value.index('=') or { return false }
		cookie_value = name_value[eq_pos + 1..]
	}
	
	//Create a Context with Cookie
	verify_ctx := create_test_context_with_cookies('auth=${cookie_value}')
	
	// Authentication with a different key should fail
	if _ := vono.get_signed_cookie(verify_ctx, 'auth', 'secret2') {
		return false // should not succeed
	}
	return true // Validation failures are expected
}


// Test 14: Empty keys should return an error
fn test_signed_cookie_empty_secret() bool {
	mut ctx := create_empty_context()
	
	// Empty keys should return an error
	if _ := vono.set_signed_cookie(mut ctx, 'auth', 'value', '') {
		return false // should not succeed
	}
	return true
}

fn main() {
	println('🚀 开始 Cookie Helper 功能测试...\n')

	mut stats := TestStats{}

	//Run all tests
	stats.run_test('获取单个 Cookie', test_get_single_cookie)
	stats.run_test('获取不存在的 Cookie', test_get_nonexistent_cookie)
	stats.run_test('获取多个 Cookie', test_get_multiple_cookies)
	stats.run_test('获取所有 Cookie', test_get_all_cookies)
	stats.run_test('空 Cookie 头返回空 map', test_get_all_cookies_empty)
	stats.run_test('设置 Cookie 基本功能', test_set_cookie_basic)
	stats.run_test('设置 Cookie 带选项', test_set_cookie_with_options)
	stats.run_test('删除 Cookie', test_delete_cookie)
	stats.run_test('Cookie 值带空格', test_cookie_with_spaces)
	stats.run_test('Cookie 值带引号', test_cookie_with_quotes)
	stats.run_test('签名 Cookie 往返一致性', test_signed_cookie_roundtrip)
	stats.run_test('签名 Cookie 篡改检测', test_signed_cookie_tamper_detection)
	stats.run_test('签名 Cookie 错误密钥', test_signed_cookie_wrong_secret)
	stats.run_test('签名 Cookie 空密钥错误', test_signed_cookie_empty_secret)

	//Print test summary
	stats.print_summary()
}
