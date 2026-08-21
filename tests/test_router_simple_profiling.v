import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== 简化路由性能分析 ===')
	
	//Test the compilation time of routes of different complexity
	test_compilation_time()
	
	//Test the routing sorting effect
	test_route_sorting_effect()
	
	println('✅ 简化路由性能分析完成')
}

fn test_compilation_time() {
	println('\n📊 不同复杂度路由编译时间对比...')
	
	test_cases := [
		{
			'name': '简单路由 (1个参数)'
			'route': '/users/:id'
			'path': '/users/123'
		},
		{
			'name': '中等路由 (2个参数)'
			'route': '/users/:id/posts/:post_id'
			'path': '/users/123/posts/456'
		},
		{
			'name': '复杂路由 (3个参数)'
			'route': '/api/:version/users/:user_id/posts/:post_id'
			'path': '/api/v1/users/123/posts/456'
		},
		{
			'name': '很复杂路由 (5个参数)'
			'route': '/api/:version/users/:user_id/posts/:post_id/comments/:comment_id/replies/:reply_id'
			'path': '/api/v1/users/123/posts/456/comments/789/replies/101'
		}
	]
	
	for test_case in test_cases {
		println('\n  ${test_case['name']}:')
		
		mut router := hono.ContextHybridRouter.new()
		
		handler := hono.ContextHandler{
			path: test_case['route']
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		
		//Add route
		router.add_route('GET', handler, '')
		
		// Clear cache to ensure compilation is required
		router.clear_regex_cache()
		
		// Test compilation time (first match)
		start_time := time.now()
		result := router.match_route('GET', test_case['path'])
		compile_time := time.since(start_time)
		
		if result != none {
			println('    编译+匹配时间: ${compile_time}')
		} else {
			println('    ❌ 匹配失败')
			continue
		}
		
		//Test cache matching time
		iterations := 10000
		start_time2 := time.now()
		mut cache_matches := 0
		for _ in 0 .. iterations {
			if _ := router.match_route('GET', test_case['path']) {
				cache_matches++
			}
		}
		cache_time := time.since(start_time2)
		
		if cache_matches > 0 {
			avg_cache_time := f64(cache_time.microseconds()) / f64(cache_matches)
			println('    平均缓存匹配: ${avg_cache_time:.3f}μs')
		}
		
		//Analyze routing characteristics
		param_count := test_case['route'].count(':')
		segment_count := test_case['route'].split('/').len
		println('    参数数量: ${param_count}')
		println('    路径段数: ${segment_count}')
		
		// Check cache status
		regex_total, regex_compiled := router.get_regex_cache_stats()
		println('    正则缓存: ${regex_compiled}/${regex_total}')
	}
}

fn test_route_sorting_effect() {
	println('\n📊 测试路由排序效果...')
	
	// Create two routers: one with sorting and one without
	mut sorted_router := hono.ContextHybridRouter.new()
	mut unsorted_router := hono.ContextHybridRouter.new()
	
	// Define routes (in order of decreasing complexity)
	routes := [
		'/api/:version/users/:user_id/posts/:post_id/comments/:comment_id/replies/:reply_id',  // most complex
		'/api/:version/users/:user_id/posts/:post_id/comments/:comment_id',                   // Very complicated
		'/api/:version/users/:user_id/posts/:post_id',                                        // medium complex
		'/users/:id/posts/:post_id',                                                          // simpler
		'/users/:id'                                                                          // simplest
	]
	
	//Add to sorting router (will be automatically sorted)
	for route in routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		sorted_router.add_route('GET', handler, '')
	}
	
	// Manually add to unsorted router (maintain original order)
	for route in routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		unsorted_router.dynamic_routes << handler
	}
	
	//Test matching the simplest route
	simple_path := '/users/123'
	iterations := 50000
	
	println('  测试路径: ${simple_path}')
	println('  测试次数: ${iterations}')
	
	//Test sorting router
	start_time1 := time.now()
	mut sorted_matches := 0
	for _ in 0 .. iterations {
		if _ := sorted_router.match_route('GET', simple_path) {
			sorted_matches++
		}
	}
	sorted_time := time.since(start_time1)
	
	//Test unsorted routers
	start_time2 := time.now()
	mut unsorted_matches := 0
	for _ in 0 .. iterations {
		if _ := unsorted_router.match_route('GET', simple_path) {
			unsorted_matches++
		}
	}
	unsorted_time := time.since(start_time2)
	
	println('\n  结果对比:')
	if sorted_matches > 0 {
		avg_sorted := f64(sorted_time.microseconds()) / f64(sorted_matches)
		println('    排序路由器平均时间: ${avg_sorted:.3f}μs')
	}
	
	if unsorted_matches > 0 {
		avg_unsorted := f64(unsorted_time.microseconds()) / f64(unsorted_matches)
		println('    未排序路由器平均时间: ${avg_unsorted:.3f}μs')
		
		if sorted_matches > 0 {
			avg_sorted := f64(sorted_time.microseconds()) / f64(sorted_matches)
			if avg_unsorted > avg_sorted {
				improvement := avg_unsorted / avg_sorted
				println('    排序优化效果: ${improvement:.2f}x 提升')
			} else {
				println('    排序没有带来明显优化')
			}
		}
	}
	
	//Display routing order
	_, sorted_paths := sorted_router.get_all_routes()
	println('\n  排序后的路由顺序:')
	for i, path in sorted_paths {
		param_count := path.count(':')
		println('    ${i+1}. ${path} (${param_count}个参数)')
	}
	
	println('\n  原始路由顺序:')
	for i, handler in unsorted_router.dynamic_routes {
		param_count := handler.path.count(':')
		println('    ${i+1}. ${handler.path} (${param_count}个参数)')
	}
}