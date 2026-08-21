import meiseayoung.vono
import time
import net.http

fn main() {
	println('=== 增强版 FastRouter vs 原始 Router 性能对比 ===')
	
	//Test 1: Small-scale routing performance comparison
	test_small_scale_comparison()
	
	//Test 2: Large-scale routing performance comparison
	test_large_scale_comparison()
	
	//Test 3: Comparison of complex routing modes
	test_complex_patterns_comparison()
	
	//Test 4: Cache efficiency comparison
	test_cache_efficiency_comparison()
	
	//Test 5: Memory usage comparison
	test_memory_usage_comparison()
	
	println('\n🎯 性能对比测试完成')
}

fn test_small_scale_comparison() {
	println('\n📊 小规模路由性能对比 (10个路由)...')
	
	//Create an enhanced version of FastRouter
	mut enhanced_router := vono.FastRouter.new()
	
	//Create original HybridRouter
	mut original_router := vono.ContextHybridRouter.new()
	
	//Add the same route
	test_routes := [
		'/users/:id',
		'/posts/:post_id/comments/:comment_id',
		'/api/v1/users/:user_id/posts/:post_id',
		'/files/:category/:filename',
		'/search/:query',
		'/admin/users/:id/settings',
		'/api/v2/projects/:project_id/tasks/:task_id',
		'/shop/products/:id/reviews/:review_id',
		'/blog/:year/:month/:slug',
		'/docs/:section/:page'
	]
	
	for route in test_routes {
		enhanced_handler := vono.ContextHandler{
			path: route
			handler: fn (mut c vono.Context) http.Response {
				return c.text('enhanced')
			}
		}
		enhanced_router.add_route('GET', enhanced_handler, '') or {
			continue
		}
		
		original_handler := vono.ContextHandler{
			path: route
			handler: fn (mut c vono.Context) http.Response {
				return c.text('original')
			}
		}
		original_router.add_route('GET', original_handler, '')
	}
	
	// test path
	test_paths := [
		'/users/123',
		'/posts/456/comments/789',
		'/api/v1/users/101/posts/202',
		'/files/images/photo.jpg',
		'/search/test-query',
		'/admin/users/555/settings',
		'/api/v2/projects/777/tasks/888',
		'/shop/products/999/reviews/111',
		'/blog/2023/12/hello-world',
		'/docs/api/authentication'
	]
	
	iterations := 5000
	
	// Test the enhanced version of FastRouter (cold start)
	enhanced_router.clear_cache()
	start_time1 := time.now()
	mut enhanced_cold_matches := 0
	for _ in 0 .. iterations {
		enhanced_router.clear_cache()
		for path in test_paths {
			if _ := enhanced_router.match_route('GET', path) {
				enhanced_cold_matches++
			}
		}
	}
	enhanced_cold_time := time.since(start_time1)
	
	// Test original HybridRouter (cold start)
	original_router.clear_cache()
	original_router.clear_regex_cache()
	start_time2 := time.now()
	mut original_cold_matches := 0
	for _ in 0 .. iterations {
		original_router.clear_cache()
		original_router.clear_regex_cache()
		for path in test_paths {
			if _ := original_router.match_route('GET', path) {
				original_cold_matches++
			}
		}
	}
	original_cold_time := time.since(start_time2)
	
	println('  冷启动性能 (${iterations}轮 × ${test_paths.len}路径):')
	if enhanced_cold_matches > 0 {
		enhanced_avg := f64(enhanced_cold_time.microseconds()) / f64(enhanced_cold_matches)
		println('    增强版 FastRouter: ${enhanced_cold_time} (平均 ${enhanced_avg:.3f}μs)')
	}
	
	if original_cold_matches > 0 {
		original_avg := f64(original_cold_time.microseconds()) / f64(original_cold_matches)
		println('    原始 HybridRouter: ${original_cold_time} (平均 ${original_avg:.3f}μs)')
		
		if enhanced_cold_matches > 0 {
			enhanced_avg := f64(enhanced_cold_time.microseconds()) / f64(enhanced_cold_matches)
			if original_avg > enhanced_avg {
				improvement := original_avg / enhanced_avg
				println('    🚀 增强版冷启动提升: ${improvement:.2f}x')
			}
		}
	}
	
	//Test hot cache performance
	start_time3 := time.now()
	mut enhanced_hot_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := enhanced_router.match_route('GET', path) {
				enhanced_hot_matches++
			}
		}
	}
	enhanced_hot_time := time.since(start_time3)
	
	start_time4 := time.now()
	mut original_hot_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := original_router.match_route('GET', path) {
				original_hot_matches++
			}
		}
	}
	original_hot_time := time.since(start_time4)
	
	println('\n  热缓存性能 (${iterations}轮 × ${test_paths.len}路径):')
	if enhanced_hot_matches > 0 {
		enhanced_avg := f64(enhanced_hot_time.microseconds()) / f64(enhanced_hot_matches)
		println('    增强版 FastRouter: ${enhanced_hot_time} (平均 ${enhanced_avg:.3f}μs)')
	}
	
	if original_hot_matches > 0 {
		original_avg := f64(original_hot_time.microseconds()) / f64(original_hot_matches)
		println('    原始 HybridRouter: ${original_hot_time} (平均 ${original_avg:.3f}μs)')
		
		if enhanced_hot_matches > 0 {
			enhanced_avg := f64(enhanced_hot_time.microseconds()) / f64(enhanced_hot_matches)
			if original_avg > enhanced_avg {
				improvement := original_avg / enhanced_avg
				println('    🚀 增强版热缓存提升: ${improvement:.2f}x')
			}
		}
	}
}

fn test_large_scale_comparison() {
	println('\n📊 大规模路由性能对比 (100个路由)...')
	
	mut enhanced_router := vono.FastRouter.new()
	mut original_router := vono.ContextHybridRouter.new()
	
	//Add a lot of routes
	for i in 0 .. 100 {
		route := '/api/v${i}/resources/:id/items/:item_id'
		
		enhanced_handler := vono.ContextHandler{
			path: route
			handler: fn (mut c vono.Context) http.Response {
				return c.text('enhanced')
			}
		}
		enhanced_router.add_route('GET', enhanced_handler, '') or {
			continue
		}
		
		original_handler := vono.ContextHandler{
			path: route
			handler: fn (mut c vono.Context) http.Response {
				return c.text('original')
			}
		}
		original_router.add_route('GET', original_handler, '')
	}
	
	// Test path (match routes in different locations)
	test_paths := [
		'/api/v1/resources/123/items/456',    // early match
		'/api/v25/resources/789/items/101',   // mid-term matching
		'/api/v50/resources/111/items/222',   // mid-term matching
		'/api/v75/resources/333/items/444',   // late match
		'/api/v99/resources/555/items/666'    //Final match
	]
	
	iterations := 2000
	
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
	mut original_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := original_router.match_route('GET', path) {
				original_matches++
			}
		}
	}
	original_time := time.since(start_time2)
	
	println('  大规模路由匹配 (100路由, ${iterations}轮 × ${test_paths.len}路径):')
	if enhanced_matches > 0 {
		enhanced_avg := f64(enhanced_time.microseconds()) / f64(enhanced_matches)
		println('    增强版 FastRouter: ${enhanced_time} (平均 ${enhanced_avg:.3f}μs)')
	}
	
	if original_matches > 0 {
		original_avg := f64(original_time.microseconds()) / f64(original_matches)
		println('    原始 HybridRouter: ${original_time} (平均 ${original_avg:.3f}μs)')
		
		if enhanced_matches > 0 {
			enhanced_avg := f64(enhanced_time.microseconds()) / f64(enhanced_matches)
			if original_avg > enhanced_avg {
				improvement := original_avg / enhanced_avg
				println('    🚀 增强版大规模提升: ${improvement:.2f}x')
			}
		}
	}
	
	// Display route distribution statistics
	enhanced_simple, enhanced_complex := enhanced_router.get_routes_by_complexity()
	println('\n  增强版路由复杂度分布:')
	println('    简单路由: ${enhanced_simple.len}')
	println('    复杂路由: ${enhanced_complex.len}')
}

fn test_complex_patterns_comparison() {
	println('\n📊 复杂路由模式性能对比...')
	
	mut enhanced_router := vono.FastRouter.new()
	mut original_router := vono.ContextHybridRouter.new()
	
	//Add complex dynamic routing
	complex_routes := [
		'/api/:version/users/:user_id/posts/:post_id/comments/:comment_id',
		'/shop/:category/:subcategory/products/:product_id/reviews/:review_id',
		'/admin/:module/:action/:resource_type/:resource_id',
		'/files/:year/:month/:day/:category/:filename',
		'/docs/:language/:version/:section/:subsection/:page'
	]
	
	for route in complex_routes {
		enhanced_handler := vono.ContextHandler{
			path: route
			handler: fn (mut c vono.Context) http.Response {
				return c.text('enhanced')
			}
		}
		enhanced_router.add_route('GET', enhanced_handler, '') or {
			continue
		}
		
		original_handler := vono.ContextHandler{
			path: route
			handler: fn (mut c vono.Context) http.Response {
				return c.text('original')
			}
		}
		original_router.add_route('GET', original_handler, '')
	}
	
	//Complex test path
	test_paths := [
		'/api/v1/users/123/posts/456/comments/789',
		'/shop/electronics/phones/products/999/reviews/111',
		'/admin/users/edit/profile/555',
		'/files/2023/12/26/images/photo.jpg',
		'/docs/en/v2/api/authentication/oauth'
	]
	
	iterations := 3000
	
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
	mut original_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := original_router.match_route('GET', path) {
				original_matches++
			}
		}
	}
	original_time := time.since(start_time2)
	
	println('  复杂模式匹配 (${iterations}轮 × ${test_paths.len}路径):')
	if enhanced_matches > 0 {
		enhanced_avg := f64(enhanced_time.microseconds()) / f64(enhanced_matches)
		println('    增强版 FastRouter: ${enhanced_time} (平均 ${enhanced_avg:.3f}μs)')
	}
	
	if original_matches > 0 {
		original_avg := f64(original_time.microseconds()) / f64(original_matches)
		println('    原始 HybridRouter: ${original_time} (平均 ${original_avg:.3f}μs)')
		
		if enhanced_matches > 0 {
			enhanced_avg := f64(enhanced_time.microseconds()) / f64(enhanced_matches)
			if original_avg > enhanced_avg {
				improvement := original_avg / enhanced_avg
				println('    🚀 增强版复杂模式提升: ${improvement:.2f}x')
			}
		}
	}
}

fn test_cache_efficiency_comparison() {
	println('\n📊 缓存效率对比...')
	
	mut enhanced_router := vono.FastRouter.new_with_cache_size(100)
	mut original_router := vono.ContextHybridRouter.new()
	
	//Add test route
	for i in 0 .. 20 {
		route := '/test${i}/:id'
		
		enhanced_handler := vono.ContextHandler{
			path: route
			handler: fn (mut c vono.Context) http.Response {
				return c.text('enhanced')
			}
		}
		enhanced_router.add_route('GET', enhanced_handler, '') or {
			continue
		}
		
		original_handler := vono.ContextHandler{
			path: route
			handler: fn (mut c vono.Context) http.Response {
				return c.text('original')
			}
		}
		original_router.add_route('GET', original_handler, '')
	}
	
	// Repeat access to the same path (test cache hit rate)
	mut repeated_paths := []string{}
	for i in 0 .. 10 {
		repeated_paths << '/test${i}/123'
	}
	
	// Perform multiple matches to fill the cache
	for _ in 0 .. 100 {
		for path in repeated_paths {
			enhanced_router.match_route('GET', path)
			original_router.match_route('GET', path)
		}
	}
	
	//Test cache hit performance
	iterations := 5000
	
	start_time1 := time.now()
	for _ in 0 .. iterations {
		for path in repeated_paths {
			enhanced_router.match_route('GET', path)
		}
	}
	enhanced_cache_time := time.since(start_time1)
	
	start_time2 := time.now()
	for _ in 0 .. iterations {
		for path in repeated_paths {
			original_router.match_route('GET', path)
		}
	}
	original_cache_time := time.since(start_time2)
	
	println('  缓存命中性能 (${iterations}轮 × ${repeated_paths.len}路径):')
	println('    增强版 FastRouter: ${enhanced_cache_time}')
	println('    原始 HybridRouter: ${original_cache_time}')
	
	if original_cache_time.microseconds() > enhanced_cache_time.microseconds() {
		improvement := f64(original_cache_time.microseconds()) / f64(enhanced_cache_time.microseconds())
		println('    🚀 增强版缓存提升: ${improvement:.2f}x')
	}
	
	// Display cache statistics
	enhanced_cache_size, enhanced_cache_capacity := enhanced_router.get_cache_stats()
	original_cache_size, original_cache_capacity := original_router.get_cache_stats()
	
	println('\n  缓存统计:')
	println('    增强版: ${enhanced_cache_size}/${enhanced_cache_capacity} (LRU)')
	println('    原始版: ${original_cache_size}/${original_cache_capacity} (LRU)')
	
	// Show detailed statistics
	enhanced_stats := enhanced_router.get_detailed_stats()
	println('\n  增强版详细统计:')
	for key, value in enhanced_stats {
		if key.starts_with('lru_') {
			println('    ${key}: ${value}')
		}
	}
}

fn test_memory_usage_comparison() {
	println('\n📊 内存使用对比...')
	
	mut enhanced_router := vono.FastRouter.new()
	mut original_router := vono.ContextHybridRouter.new()
	
	//Add a large number of routes to test memory usage
	route_count := 200
	
	for i in 0 .. route_count {
		route := '/api/v${i}/category/:cat/items/:id/details/:detail_id'
		
		enhanced_handler := vono.ContextHandler{
			path: route
			handler: fn (mut c vono.Context) http.Response {
				return c.text('enhanced')
			}
		}
		enhanced_router.add_route('GET', enhanced_handler, '') or {
			continue
		}
		
		original_handler := vono.ContextHandler{
			path: route
			handler: fn (mut c vono.Context) http.Response {
				return c.text('original')
			}
		}
		original_router.add_route('GET', original_handler, '')
	}
	
	//Fill cache
	for i in 0 .. 50 {
		path := '/api/v${i}/category/electronics/items/123/details/456'
		enhanced_router.match_route('GET', path)
		original_router.match_route('GET', path)
	}
	
	// Get statistics
	enhanced_static, enhanced_dynamic, enhanced_cache := enhanced_router.get_stats()
	original_static, original_dynamic := original_router.get_all_routes()
	original_cache_size, _ := original_router.get_cache_stats()
	original_regex_total, original_regex_compiled := original_router.get_regex_cache_stats()
	
	println('  路由统计对比:')
	println('    增强版 - 静态: ${enhanced_static}, 动态: ${enhanced_dynamic}, 缓存: ${enhanced_cache}')
	println('    原始版 - 静态: ${original_static.len}, 动态: ${original_dynamic.len}, 缓存: ${original_cache_size}')
	println('    原始版 - 正则缓存: ${original_regex_compiled}/${original_regex_total}')
	
	// Estimate memory usage
	enhanced_stats := enhanced_router.get_detailed_stats()
	if memory_estimate := enhanced_stats['lru_memory_usage_estimate'] {
		println('  增强版内存估算: ${memory_estimate} 字节')
	}
	
	//Display health status
	if enhanced_router.is_healthy() {
		println('  增强版健康状态: ✅ 正常')
	} else {
		println('  增强版健康状态: ❌ 异常')
	}
	
	println('\n  🎯 内存使用总结:')
	println('    - 增强版使用 LRU 缓存，自动管理内存')
	println('    - 原始版使用简单 map + 正则缓存')
	println('    - 增强版具有 TTL 和健康检查功能')
}