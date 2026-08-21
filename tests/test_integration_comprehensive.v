import meiseayoung.vono
import time
import net.http
import os

fn main() {
	println('=== vono 综合集成测试 ===')
	
	//Test 1: FastRouter integration test
	test_fast_router_integration()
	
	//Test 2: Configuration management integration test
	test_config_integration()
	
	//Test 3: Log system integration test
	test_logger_integration()
	
	//Test 4: Error handling integration test
	test_error_handling_integration()
	
	//Test 5: Security verification integration test
	test_security_integration()
	
	//Test 6: Performance benchmark integration test
	test_performance_integration()
	
	//Test 7: Memory management integration test
	test_memory_management_integration()
	
	println('✅ vono 综合集成测试完成')
}

fn test_fast_router_integration() {
	println('\n📊 FastRouter集成测试...')
	
	//Create application instance
	mut app := vono.Vono.new()
	
	// Verify that FastRouter is enabled by default
	if !app.use_fast_router {
		println('  ❌ FastRouter未默认启用')
		return
	}
	println('  ✅ FastRouter默认启用')
	
	//Add various types of routes
	test_routes := [
		'/static/path',                                    // static routing
		'/users/:id',                                      //Single parameter dynamic routing
		'/users/:id/posts/:post_id',                      //Multi-parameter dynamic routing
		'/api/:version/users/:user_id/posts/:post_id',    //Complex dynamic routing
		'/files/:year/:month/:day/:filename'              //Deep dynamic routing
	]
	
	for route in test_routes {
		app.get(route, fn (mut c vono.Context) http.Response {
			return c.text('response')
		})
	}
	
	//Verify routing statistics
	static_count, dynamic_count, cache_count, _ := app.get_router_stats()
	println('  路由统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
	
	//Test route matching
	test_paths := [
		'/static/path',
		'/users/123',
		'/users/123/posts/456',
		'/api/v1/users/789/posts/101',
		'/files/2023/12/26/document.pdf'
	]
	
	mut match_count := 0
	for path in test_paths {
		if _ := app.fast_router.match_route('GET', path) {
			match_count++
		}
	}
	
	if match_count == test_paths.len {
		println('  ✅ 所有路由匹配成功 (${match_count}/${test_paths.len})')
	} else {
		println('  ❌ 路由匹配失败 (${match_count}/${test_paths.len})')
	}
	
	//Test FastRouter switch
	app.set_fast_router_enabled(false)
	if app.use_fast_router {
		println('  ❌ FastRouter开关失效')
	} else {
		println('  ✅ FastRouter开关正常')
	}
	
	app.set_fast_router_enabled(true)
	if !app.use_fast_router {
		println('  ❌ FastRouter重新启用失败')
	} else {
		println('  ✅ FastRouter重新启用成功')
	}
	
	//Performance analysis
	println('  性能分析:')
	app.analyze_router_performance()
}

fn test_config_integration() {
	println('\n📊 配置管理集成测试...')
	
	//Test default configuration
	config := vono.default_config()
	if config.server.host == '0.0.0.0' && config.server.port == 8080 {
		println('  ✅ 默认配置正确')
	} else {
		println('  ❌ 默认配置错误')
	}
	
	//Test configuration verification
	vono.validate_config(config) or {
		println('  ❌ 配置验证失败: ${err}')
		return
	}
	println('  ✅ 配置验证通过')
	
	//Test configuration save and load
	test_config_file := 'test_config.json'
	
	vono.save_config(config, test_config_file) or {
		println('  ❌ 配置保存失败: ${err}')
		return
	}
	println('  ✅ 配置保存成功')
	
	loaded_config := vono.load_config(test_config_file) or {
		println('  ❌ 配置加载失败: ${err}')
		return
	}
	println('  ✅ 配置加载成功')
	
	// Clean test files
	os.rm(test_config_file) or {}
	
	//Verify configuration content
	if loaded_config.server.host == config.server.host {
		println('  ✅ 配置内容一致')
	} else {
		println('  ❌ 配置内容不一致')
	}
}

fn test_logger_integration() {
	println('\n📊 日志系统集成测试...')
	
	//Create logger configuration
	config := vono.LoggerConfig{
		level: .info
		output: .console
	}
	mut logger := vono.new_logger(config)
	
	//Test logs at each level
	logger.debug('Debug message')
	logger.info('Info message')
	logger.warn('Warning message')
	logger.error('Error message')
	
	println('  ✅ 日志级别测试完成')
	
	//Test the log with module
	logger.info_with_module('Module message', 'test_module')
	println('  ✅ 模块日志测试完成')
	
	//Test logs with fields
	fields := {
		'user_id': '123'
		'action': 'login'
	}
	logger.info_with_fields('User login', fields)
	println('  ✅ 结构化日志测试完成')
	
	//Test the log with request ID
	logger.info_with_request('Request processed', 'req-12345')
	println('  ✅ 请求日志测试完成')
}

fn test_error_handling_integration() {
	println('\n📊 错误处理集成测试...')
	
	//Test error response
	error_response_400 := vono.Response.error(400, 'Bad request test')
	if error_response_400.status_code == 400 {
		println('  ✅ 400 Bad Request 错误响应正确')
	} else {
		println('  ❌ 400 Bad Request 错误响应失败')
	}
	
	error_response_404 := vono.Response.error(404, 'Not found test')
	if error_response_404.status_code == 404 {
		println('  ✅ 404 Not Found 错误响应正确')
	} else {
		println('  ❌ 404 Not Found 错误响应失败')
	}
	
	error_response_500 := vono.Response.error(500, 'Internal error test')
	if error_response_500.status_code == 500 {
		println('  ✅ 500 Internal Error 错误响应正确')
	} else {
		println('  ❌ 500 Internal Error 错误响应失败')
	}
	
	println('  ✅ 错误处理方法测试通过')
}

fn test_security_integration() {
	println('\n📊 安全验证集成测试...')
	
	//Test path verification
	dangerous_paths := [
		'../../../etc/passwd',
		'..\\..\\windows\\system32',
		'/etc/passwd',
		'C:\\Windows\\System32',
		'file:///etc/passwd',
		'path/with/../../traversal',
		'path\\with\\..\\..\\traversal',
		'normal/path/with<script>alert(1)</script>'
	]
	
	mut blocked_count := 0
	for path in dangerous_paths {
		// validate_file_path returns !string, so error means blocked
		_ := vono.validate_file_path(path, vono.PathValidationOptions{}) or {
			blocked_count++
			continue
		}
	}
	
	if blocked_count == dangerous_paths.len {
		println('  ✅ 危险路径全部被阻止 (${blocked_count}/${dangerous_paths.len})')
	} else {
		println('  ⚠️  部分危险路径未被阻止 (${blocked_count}/${dangerous_paths.len})')
	}
	
	//Test safe path
	safe_paths := [
		'documents/report.pdf',
		'images/photo.jpg',
		'data/config.json'
	]
	
	mut safe_count := 0
	for path in safe_paths {
		if _ := vono.validate_file_path(path, vono.PathValidationOptions{}) {
			safe_count++
		}
	}
	
	if safe_count == safe_paths.len {
		println('  ✅ 安全路径全部通过 (${safe_count}/${safe_paths.len})')
	} else {
		println('  ❌ 部分安全路径被阻止 (${safe_count}/${safe_paths.len})')
	}
}

fn test_performance_integration() {
	println('\n📊 性能基准集成测试...')
	
	//Create test application
	mut app := vono.Vono.new()
	
	//Add multiple routes
	performance_routes := [
		'/api/v1/users/:id',
		'/api/v1/users/:id/posts',
		'/api/v1/users/:id/posts/:post_id',
		'/api/v2/products/:category/:id',
		'/files/:year/:month/:day/:filename'
	]
	
	for route in performance_routes {
		app.get(route, fn (mut c vono.Context) http.Response {
			return c.text('response')
		})
	}
	
	//Performance test path
	test_paths := [
		'/api/v1/users/123',
		'/api/v1/users/123/posts',
		'/api/v1/users/123/posts/456',
		'/api/v2/products/electronics/999',
		'/files/2023/12/26/document.pdf'
	]
	
	iterations := 1000
	
	//Test FastRouter performance
	start_time := time.now()
	mut match_count := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := app.fast_router.match_route('GET', path) {
				match_count++
			}
		}
	}
	total_time := time.since(start_time)
	
	avg_time := f64(total_time.microseconds()) / f64(match_count)
	println('  FastRouter性能: ${total_time} (${match_count}次匹配, 平均${avg_time:.3f}μs)')
	
	if avg_time < 20.0 {  // Expect average time to be less than 20μs
		println('  ✅ 性能测试通过 (平均${avg_time:.3f}μs < 20μs)')
	} else {
		println('  ❌ 性能测试未达标 (平均${avg_time:.3f}μs >= 20μs)')
	}
}

fn test_memory_management_integration() {
	println('\n📊 内存管理集成测试...')
	
	//Test LRU cache
	mut cache := vono.ContextLRUCache.new(100)
	
	//Add test data
	test_data := vono.ContextRouteMatch{
		handler: vono.ContextHandler{
			path: '/test'
			handler: fn (mut c vono.Context) http.Response {
				return c.text('test')
			}
		}
		params: {'id': '123'}
		path: '/test'
		base_path: ''
	}
	
	//Test caching operation
	cache.put('test_key', test_data)
	
	if _ := cache.get('test_key') {
		println('  ✅ 缓存存储和获取正常')
	} else {
		println('  ❌ 缓存存储或获取失败')
	}
	
	//Test cache health check
	if cache.is_healthy() {
		println('  ✅ 缓存健康检查通过')
	} else {
		println('  ❌ 缓存健康检查失败')
	}
	
	//Test cache statistics
	size, capacity := cache.get_stats()
	println('  缓存统计: 大小=${size}, 容量=${capacity}')
	
	//Test cache cleanup
	cache.clear()
	size_after_clear, _ := cache.get_stats()
	
	if size_after_clear == 0 {
		println('  ✅ 缓存清理成功')
	} else {
		println('  ❌ 缓存清理失败')
	}
}

//Create a mock Context for testing
fn create_mock_context() vono.Context {
	req := http.Request{
		method: http.Method.get
		url: '/test'
		data: ''
	}
	
	return vono.Context.new(req, map[string]string{}, map[string]string{}, '')
}