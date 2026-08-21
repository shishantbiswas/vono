import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== 增强版 FastRouter 功能测试 ===')
	
	//Test 1: Basic function test
	test_basic_functionality()
	
	//Test 2: LRU cache function test
	test_lru_cache_functionality()
	
	//Test 3: Routing complexity sorting test
	test_route_complexity_sorting()
	
	//Test 4: Advanced cache management test
	test_advanced_cache_management()
	
	//Test 5: Performance comparison test
	test_performance_comparison()
	
	//Test 6: Health check test
	test_health_check()
	
	//Test 7: Intelligent preheating test
	test_smart_warmup()
	
	println('\n🎯 增强版 FastRouter 测试完成')
}

fn test_basic_functionality() {
	println('\n📊 基本功能测试...')
	
	mut router := hono.FastRouter.new()
	
	//Add static route
	static_handler := hono.ContextHandler{
		path: '/static'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('static')
		}
	}
	router.add_route('GET', static_handler, '') or {
		println('  ❌ 添加静态路由失败: ${err}')
		return
	}
	
	//Add dynamic route
	dynamic_handler := hono.ContextHandler{
		path: '/users/:id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('dynamic')
		}
	}
	router.add_route('GET', dynamic_handler, '') or {
		println('  ❌ 添加动态路由失败: ${err}')
		return
	}
	
	//Test static route matching
	if _ := router.match_route('GET', '/static') {
		println('  ✅ 静态路由匹配成功')
	} else {
		println('  ❌ 静态路由匹配失败')
	}
	
	//Test dynamic route matching
	if match_result := router.match_route('GET', '/users/123') {
		println('  ✅ 动态路由匹配成功')
		if match_result.params['id'] == '123' {
			println('  ✅ 参数提取正确: id=${match_result.params['id']}')
		} else {
			println('  ❌ 参数提取错误')
		}
	} else {
		println('  ❌ 动态路由匹配失败')
	}
	
	// Show basic statistics
	static_count, dynamic_count, cache_count := router.get_stats()
	println('  📈 统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
}

fn test_lru_cache_functionality() {
	println('\n📊 LRU 缓存功能测试...')
	
	//Create a router with small cache capacity
	mut router := hono.FastRouter.new_with_cache_size(3)
	
	//Add test route
	for i in 0 .. 5 {
		handler := hono.ContextHandler{
			path: '/test${i}/:id'
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '') or {
			continue
		}
	}
	
	//Test cache filling
	test_paths := ['/test0/123', '/test1/456', '/test2/789', '/test3/101', '/test4/202']
	
	for path in test_paths {
		router.match_route('GET', path)
	}
	
	cache_size, cache_capacity := router.get_cache_stats()
	println('  📈 缓存状态: ${cache_size}/${cache_capacity}')
	
	if cache_size <= 3 {
		println('  ✅ LRU 缓存容量限制正常工作')
	} else {
		println('  ❌ LRU 缓存容量限制失效')
	}
	
	//Test cache hit
	start_time := time.now()
	for _ in 0 .. 1000 {
		router.match_route('GET', '/test4/202')  // Should hit cache
	}
	cache_hit_time := time.since(start_time)
	
	//Test after clearing cache
	router.clear_cache()
	start_time2 := time.now()
	for _ in 0 .. 1000 {
		router.match_route('GET', '/test4/202')  // Will not hit cache
	}
	no_cache_time := time.since(start_time2)
	
	println('  ⏱️  缓存命中时间: ${cache_hit_time}')
	println('  ⏱️  无缓存时间: ${no_cache_time}')
	
	if cache_hit_time < no_cache_time {
		improvement := f64(no_cache_time.microseconds()) / f64(cache_hit_time.microseconds())
		println('  🚀 缓存性能提升: ${improvement:.2f}x')
	}
}

fn test_route_complexity_sorting() {
	println('\n📊 路由复杂度排序测试...')
	
	mut router := hono.FastRouter.new()
	
	//Add routes of different complexity
	routes := [
		'/simple/:id',                                    // Simple routing
		'/complex/:category/:subcategory/:id',           //Complex routing
		'/very/complex/:a/:b/:c/:d/:e',                  // very complex
		'/static/path',                                   // static routing
		'/medium/:type/:id'                              // medium complexity
	]
	
	for route in routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '') or {
			continue
		}
	}
	
	// Get routes grouped by complexity
	simple_routes, complex_routes := router.get_routes_by_complexity()
	
	println('  📊 路由复杂度分布:')
	println('    简单路由 (≤30): ${simple_routes.len}')
	for route in simple_routes {
		println('      ${route.pattern} (复杂度: ${route.complexity})')
	}
	
	println('    复杂路由 (>30): ${complex_routes.len}')
	for route in complex_routes {
		println('      ${route.pattern} (复杂度: ${route.complexity})')
	}
	
	// Verify that the sorting is correct
	mut is_sorted := true
	for i in 1 .. router.precompiled_routes.len {
		if router.precompiled_routes[i-1].complexity > router.precompiled_routes[i].complexity {
			is_sorted = false
			break
		}
	}
	
	if is_sorted {
		println('  ✅ 路由按复杂度正确排序')
	} else {
		println('  ❌ 路由排序有误')
	}
}

fn test_advanced_cache_management() {
	println('\n📊 高级缓存管理测试...')
	
	mut router := hono.FastRouter.new()
	
	//Add test route
	handler := hono.ContextHandler{
		path: '/test/:id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('test')
		}
	}
	router.add_route('GET', handler, '') or {
		println('  ❌ 添加路由失败')
		return
	}
	
	// Set short TTL for testing
	router.set_cache_ttl(1)  // 1 second TTL
	
	//Fill cache
	router.match_route('GET', '/test/123')
	
	cache_size1, _ := router.get_cache_stats()
	println('  📈 缓存填充后: ${cache_size1} 条目')
	
	// Wait for TTL to expire
	time.sleep(1100 * time.millisecond)
	
	// Force cleanup of expired entries
	router.force_cleanup_expired()
	
	cache_size2, _ := router.get_cache_stats()
	println('  📈 TTL 清理后: ${cache_size2} 条目')
	
	if cache_size2 < cache_size1 {
		println('  ✅ TTL 过期清理正常工作')
	} else {
		println('  ⚠️  TTL 过期清理可能未生效')
	}
	
	//Test cache health check
	if router.is_healthy() {
		println('  ✅ 缓存健康状态正常')
	} else {
		println('  ❌ 缓存健康状态异常')
	}
	
	// Test detailed statistics
	detailed_stats := router.get_detailed_stats()
	println('  📊 详细统计:')
	for key, value in detailed_stats {
		println('    ${key}: ${value}')
	}
}

fn test_performance_comparison() {
	println('\n📊 性能对比测试...')
	
	//Create an enhanced version of FastRouter
	mut enhanced_router := hono.FastRouter.new()
	
	//Create original HybridRouter for comparison
	mut hybrid_router := hono.ContextHybridRouter.new()
	
	//Add the same route
	test_routes := [
		'/users/:id',
		'/posts/:post_id/comments/:comment_id',
		'/api/:version/users/:user_id',
		'/files/:category/:filename',
		'/admin/:module/:action/:id'
	]
	
	for route in test_routes {
		enhanced_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('enhanced')
			}
		}
		enhanced_router.add_route('GET', enhanced_handler, '') or {
			continue
		}
		
		hybrid_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('hybrid')
			}
		}
		hybrid_router.add_route('GET', hybrid_handler, '')
	}
	
	// test path
	test_paths := [
		'/users/123',
		'/posts/456/comments/789',
		'/api/v1/users/101',
		'/files/images/photo.jpg',
		'/admin/users/edit/555'
	]
	
	iterations := 5000
	
	// Test the enhanced version of FastRouter
	start_time1 := time.now()
	mut enhanced_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := enhanced_router.match_route('GET', path) {
				enhanced_matches++
			}
		}
	}
	enhanced_time := time.since(start_time1)
	
	// Test the original HybridRouter
	start_time2 := time.now()
	mut hybrid_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := hybrid_router.match_route('GET', path) {
				hybrid_matches++
			}
		}
	}
	hybrid_time := time.since(start_time2)
	
	println('  ⏱️  增强版 FastRouter: ${enhanced_time} (${enhanced_matches} 匹配)')
	println('  ⏱️  原始 HybridRouter: ${hybrid_time} (${hybrid_matches} 匹配)')
	
	if enhanced_matches > 0 && hybrid_matches > 0 {
		enhanced_avg := f64(enhanced_time.microseconds()) / f64(enhanced_matches)
		hybrid_avg := f64(hybrid_time.microseconds()) / f64(hybrid_matches)
		
		if hybrid_avg > enhanced_avg {
			improvement := hybrid_avg / enhanced_avg
			println('  🚀 增强版性能提升: ${improvement:.2f}x')
		} else {
			println('  ⚠️  性能提升不明显')
		}
	}
}

fn test_health_check() {
	println('\n📊 健康检查测试...')
	
	mut router := hono.FastRouter.new()
	
	//Add some routes
	for i in 0 .. 10 {
		handler := hono.ContextHandler{
			path: '/test${i}/:id'
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '') or {
			continue
		}
	}
	
	//Fill cache
	for i in 0 .. 10 {
		router.match_route('GET', '/test${i}/123')
	}
	
	// Check health status
	if router.is_healthy() {
		println('  ✅ 路由器健康状态正常')
	} else {
		println('  ❌ 路由器健康状态异常')
	}
	
	// Show full performance analysis
	router.analyze_performance()
}

fn test_smart_warmup() {
	println('\n📊 智能预热测试...')
	
	mut router := hono.FastRouter.new()
	
	//Add routes of different complexity
	routes := [
		'/simple/:id',
		'/complex/:a/:b/:c',
		'/very/complex/:w/:x/:y/:z',
		'/medium/:type/:id'
	]
	
	for route in routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '') or {
			continue
		}
	}
	
	// Prepare sample path
	sample_paths := [
		'/simple/123',
		'/complex/a/b/c',
		'/very/complex/w/x/y/z',
		'/medium/type1/456'
	]
	
	//Perform smart preheating
	router.smart_warmup(sample_paths)
	
	// Check the preheating effect
	cache_size, _ := router.get_cache_stats()
	println('  📈 预热后缓存大小: ${cache_size}')
	
	if cache_size > 0 {
		println('  ✅ 智能预热成功')
	} else {
		println('  ⚠️  智能预热效果不明显')
	}
	
	//Test the performance after preheating
	start_time := time.now()
	for _ in 0 .. 1000 {
		for path in sample_paths {
			router.match_route('GET', path)
		}
	}
	warmed_time := time.since(start_time)
	
	println('  ⏱️  预热后性能: ${warmed_time}')
}