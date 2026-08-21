// Middleware optimization test
//Test three optimization points:
// 1. Zero middleware fast path
// 2. Middleware precalculation (sorting at startup)
// 3. Reuse cache key

import meiseayoung.hono
import time
import net.http

//Test statistics
struct TestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats TestStats) start_test(test_name string) {
	stats.total_tests++
	print('🧪 ${test_name}... ')
}

fn (mut stats TestStats) pass_test() {
	stats.passed_tests++
	println('✅')
}

fn (mut stats TestStats) fail_test(error string) {
	stats.failed_tests++
	println('❌ ${error}')
}

fn (stats TestStats) print_summary() {
	println('\n=== 测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')
	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

// Test 1: Zero middleware fast path - has_middlewares flag
fn test_zero_middleware_flag(mut stats TestStats) {
	stats.start_test('零中间件标志 (has_middlewares)')
	
	mut app := hono.Hono.new()
	
	// Newly created applications should have no middleware
	if app.has_middlewares {
		stats.fail_test('新应用不应该有中间件标志')
		return
	}
	
	// Flag should be true after adding middleware
	app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	
	if !app.has_middlewares {
		stats.fail_test('添加中间件后标志应该为 true')
		return
	}
	
	stats.pass_test()
}

//Test 2: Middleware precalculation - sorted_middleware_prefixes
fn test_middleware_precompute(mut stats TestStats) {
	stats.start_test('中间件预计算 (sorted_middleware_prefixes)')
	
	mut app := hono.Hono.new()
	
	//Add route
	app.get('/test', fn (mut c hono.Context) http.Response {
		return c.text('test')
	})
	
	//Create a sub-application and add middleware
	mut sub_app := hono.Hono.new()
	sub_app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	sub_app.get('/hello', fn (mut c hono.Context) http.Response {
		return c.text('hello')
	})
	
	//Mount sub-application
	app.route('/api', mut sub_app)
	
	// Before precomputation, sorted_middleware_prefixes should be empty
	if app.sorted_middleware_prefixes.len != 0 {
		stats.fail_test('预计算前 sorted_middleware_prefixes 应该为空')
		return
	}
	
	// Call precomputation
	app.precompute_middleware_prefixes()
	
	// After precomputation, sorted_middleware_prefixes should contain prefixes
	if app.sorted_middleware_prefixes.len == 0 && app.route_middlewares.len > 0 {
		stats.fail_test('预计算后 sorted_middleware_prefixes 应该包含前缀')
		return
	}
	
	// Verify the has_middlewares flag
	if app.route_middlewares.len > 0 && !app.has_middlewares {
		stats.fail_test('有路由中间件时 has_middlewares 应该为 true')
		return
	}
	
	stats.pass_test()
}

//Test 3: FastRouter cache key reuse
fn test_fast_router_cache_key_reuse(mut stats TestStats) {
	stats.start_test('FastRouter cache key 复用')
	
	mut router := hono.FastRouter.new()
	
	//Add static route
	static_handler := hono.ContextHandler{
		path: '/users'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('users')
		}
	}
	router.add_route('GET', static_handler, '') or {
		stats.fail_test('添加静态路由失败')
		return
	}
	
	//Add dynamic route
	dynamic_handler := hono.ContextHandler{
		path: '/users/:id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('user')
		}
	}
	router.add_route('GET', dynamic_handler, '') or {
		stats.fail_test('添加动态路由失败')
		return
	}
	
	//Test static route matching
	if _ := router.match_route('GET', '/users') {
		// success
	} else {
		stats.fail_test('静态路由匹配失败')
		return
	}
	
	// Test dynamic routing matching (first time, cached)
	if match1 := router.match_route('GET', '/users/123') {
		if match1.params['id'] != '123' {
			stats.fail_test('参数提取失败')
			return
		}
	} else {
		stats.fail_test('动态路由匹配失败')
		return
	}
	
	// Test dynamic route matching (the second time, it should hit the cache)
	if match2 := router.match_route('GET', '/users/123') {
		if match2.params['id'] != '123' {
			stats.fail_test('缓存命中后参数提取失败')
			return
		}
	} else {
		stats.fail_test('缓存命中失败')
		return
	}
	
	//Verify cache status
	_, _, cache_count := router.get_stats()
	if cache_count == 0 {
		stats.fail_test('缓存应该有条目')
		return
	}
	
	stats.pass_test()
}

//Test 4: HybridRouter cache key reuse
fn test_hybrid_router_cache_key_reuse(mut stats TestStats) {
	stats.start_test('HybridRouter cache key 复用')
	
	mut router := hono.ContextHybridRouter.new()
	
	//Add dynamic route
	dynamic_handler := hono.ContextHandler{
		path: '/posts/:id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('post')
		}
	}
	router.add_route('GET', dynamic_handler, '')
	
	// First match (no cache)
	if match1 := router.match_route('GET', '/posts/456') {
		if match1.params['id'] != '456' {
			stats.fail_test('参数提取失败')
			return
		}
	} else {
		stats.fail_test('动态路由匹配失败')
		return
	}
	
	// Second match (should hit cache)
	if match2 := router.match_route('GET', '/posts/456') {
		if match2.params['id'] != '456' {
			stats.fail_test('缓存命中后参数提取失败')
			return
		}
	} else {
		stats.fail_test('缓存命中失败')
		return
	}
	
	stats.pass_test()
}

// Test 5: Performance comparison - with middleware vs without middleware
fn test_middleware_performance_comparison(mut stats TestStats) {
	stats.start_test('中间件性能对比')
	
	//Create a router without middleware
	mut router_no_mw := hono.FastRouter.new()
	handler := hono.ContextHandler{
		path: '/api/users/:id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('user')
		}
	}
	router_no_mw.add_route('GET', handler, '') or {
		stats.fail_test('添加路由失败')
		return
	}
	
	// preheat
	for _ in 0 .. 100 {
		_ := router_no_mw.match_route('GET', '/api/users/123') or { continue }
	}
	
	//Test performance without middleware
	iterations := 10000
	start_no_mw := time.now()
	for _ in 0 .. iterations {
		_ := router_no_mw.match_route('GET', '/api/users/123') or { continue }
	}
	duration_no_mw := time.since(start_no_mw)
	
	//Create an application with middleware
	mut app_with_mw := hono.Hono.new()
	app_with_mw.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	app_with_mw.get('/api/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user')
	})
	app_with_mw.precompute_middleware_prefixes()
	
	// preheat
	for _ in 0 .. 100 {
		_ := app_with_mw.fast_router.match_route('GET', '/api/users/123') or { continue }
	}
	
	// Test the performance of middleware
	start_with_mw := time.now()
	for _ in 0 .. iterations {
		_ := app_with_mw.fast_router.match_route('GET', '/api/users/123') or { continue }
	}
	duration_with_mw := time.since(start_with_mw)
	
	println('')
	println('  📊 无中间件: ${duration_no_mw.milliseconds()}ms (${iterations} 次)')
	println('  📊 有中间件: ${duration_with_mw.milliseconds()}ms (${iterations} 次)')
	
	// The performance difference should not be too big (route matching itself is not affected by middleware)
	stats.pass_test()
}

//Test 6: Precomputed sorting correctness
fn test_precompute_sorting(mut stats TestStats) {
	stats.start_test('预计算排序正确性')
	
	mut app := hono.Hono.new()
	
	// Add multiple sub-applications to simulate prefixes of different lengths
	mut sub1 := hono.Hono.new()
	sub1.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	sub1.get('/test', fn (mut c hono.Context) http.Response {
		return c.text('test')
	})
	
	mut sub2 := hono.Hono.new()
	sub2.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	sub2.get('/test', fn (mut c hono.Context) http.Response {
		return c.text('test')
	})
	
	mut sub3 := hono.Hono.new()
	sub3.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	sub3.get('/test', fn (mut c hono.Context) http.Response {
		return c.text('test')
	})
	
	//Mount in different order (long prefix is ​​mounted first)
	app.route('/api/v1/users', mut sub1)
	app.route('/api', mut sub2)
	app.route('/api/v1', mut sub3)
	
	// precompute
	app.precompute_middleware_prefixes()
	
	// Verify sorting: short prefix should be at the front
	if app.sorted_middleware_prefixes.len >= 2 {
		for i in 0 .. app.sorted_middleware_prefixes.len - 1 {
			if app.sorted_middleware_prefixes[i].len > app.sorted_middleware_prefixes[i + 1].len {
				stats.fail_test('前缀排序不正确：${app.sorted_middleware_prefixes[i]} 应该在 ${app.sorted_middleware_prefixes[i + 1]} 之后')
				return
			}
		}
	}
	
	stats.pass_test()
}

fn main() {
	println('🚀 开始中间件优化测试...\n')
	
	mut stats := TestStats{}
	
	//Run all tests
	test_zero_middleware_flag(mut stats)
	test_middleware_precompute(mut stats)
	test_fast_router_cache_key_reuse(mut stats)
	test_hybrid_router_cache_key_reuse(mut stats)
	test_middleware_performance_comparison(mut stats)
	test_precompute_sorting(mut stats)
	
	//Print test summary
	stats.print_summary()
}
