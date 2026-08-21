import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== vono 简化集成测试 ===')
	
	//Test 1: Basic application creation and FastRouter
	test_basic_app_creation()
	
	//Test 2: Route addition and matching
	test_route_management()
	
	//Test 3: Performance verification
	test_performance_validation()
	
	//Test 4: Configure the system
	test_config_system()
	
	println('✅ vono 简化集成测试完成')
}

fn test_basic_app_creation() {
	println('\n📊 基本应用创建测试...')
	
	// Create application
	mut app := hono.Hono.new()
	
	// Verify that FastRouter is enabled by default
	if app.use_fast_router {
		println('  ✅ FastRouter默认启用')
	} else {
		println('  ❌ FastRouter未默认启用')
	}
	
	//Test FastRouter switch
	app.set_fast_router_enabled(false)
	if !app.use_fast_router {
		println('  ✅ FastRouter禁用成功')
	} else {
		println('  ❌ FastRouter禁用失败')
	}
	
	app.set_fast_router_enabled(true)
	if app.use_fast_router {
		println('  ✅ FastRouter重新启用成功')
	} else {
		println('  ❌ FastRouter重新启用失败')
	}
}

fn test_route_management() {
	println('\n📊 路由管理测试...')
	
	mut app := hono.Hono.new()
	
	//Add different types of routes
	app.get('/static', fn (mut c hono.Context) http.Response {
		return c.text('static response')
	})
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user response')
	})
	
	app.post('/api/:version/users', fn (mut c hono.Context) http.Response {
		return c.text('api response')
	})
	
	//Verify routing statistics
	static_count, dynamic_count, cache_count, _ := app.get_router_stats()
	println('  路由统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
	
	//Test route matching
	test_paths := ['/static', '/users/123', '/nonexistent']
	expected_results := [true, true, false]
	
	mut success_count := 0
	for i, path in test_paths {
		expected := expected_results[i]
		
		match_result := app.fast_router.match_route('GET', path)
		actual := match_result != none
		
		if actual == expected {
			success_count++
		}
	}
	
	if success_count == test_paths.len {
		println('  ✅ 路由匹配测试通过 (${success_count}/${test_paths.len})')
	} else {
		println('  ❌ 路由匹配测试失败 (${success_count}/${test_paths.len})')
	}
}

fn test_performance_validation() {
	println('\n📊 性能验证测试...')
	
	//Create FastRouter and HybridRouter for comparison
	mut fast_router := hono.FastRouter.new()
	mut hybrid_router := hono.ContextHybridRouter.new()
	
	//Add the same route
	route_path := '/api/:version/users/:user_id'
	test_path := '/api/v1/users/123'
	
	fast_handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('fast')
		}
	}
	
	hybrid_handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('hybrid')
		}
	}
	
	fast_router.add_route('GET', fast_handler, '') or {
		println('  ❌ FastRouter添加路由失败')
		return
	}
	
	hybrid_router.add_route('GET', hybrid_handler, '')
	
	iterations := 1000
	
	//Test FastRouter performance
	fast_router.clear_cache()
	start_time1 := time.now()
	mut fast_matches := 0
	for _ in 0 .. iterations {
		if _ := fast_router.match_route('GET', test_path) {
			fast_matches++
		}
	}
	fast_time := time.since(start_time1)
	
	//Test HybridRouter performance
	hybrid_router.clear_cache()
	start_time2 := time.now()
	mut hybrid_matches := 0
	for _ in 0 .. iterations {
		if _ := hybrid_router.match_route('GET', test_path) {
			hybrid_matches++
		}
	}
	hybrid_time := time.since(start_time2)
	
	if fast_matches > 0 && hybrid_matches > 0 {
		fast_avg := f64(fast_time.microseconds()) / f64(fast_matches)
		hybrid_avg := f64(hybrid_time.microseconds()) / f64(hybrid_matches)
		
		println('  FastRouter平均: ${fast_avg:.3f}μs')
		println('  HybridRouter平均: ${hybrid_avg:.3f}μs')
		
		if fast_avg < hybrid_avg {
			improvement := hybrid_avg / fast_avg
			println('  ✅ FastRouter性能提升: ${improvement:.2f}x')
		} else {
			println('  ❌ FastRouter性能未提升')
		}
	}
}

fn test_config_system() {
	println('\n📊 配置系统测试...')
	
	// Test default configuration creation
	config := hono.default_config()
	
	//Verify default value
	if config.server.host == '127.0.0.1' && config.server.port == 8080 {
		println('  ✅ 配置创建正确')
	} else {
		println('  ❌ 配置创建错误')
	}
	
	//Test configuration fields
	if config.server.read_timeout == 30 && config.static.root_dir == './static' {
		println('  ✅ 配置字段正确')
	} else {
		println('  ❌ 配置字段错误')
	}
	
	//Test configuration environment
	if config.env == 'development' {
		println('  ✅ 默认环境正确')
	} else {
		println('  ❌ 默认环境错误')
	}
}