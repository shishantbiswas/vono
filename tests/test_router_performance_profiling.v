import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== 路由性能详细分析 ===')
	
	//Test 1: Step-by-step performance analysis
	test_step_by_step_performance()
	
	//Test 2: Performance comparison of routing with different complexity
	test_complexity_performance()
	
	println('✅ 路由性能分析完成')
}

fn test_step_by_step_performance() {
	println('\n📊 分步骤性能分析...')
	
	mut router := hono.ContextHybridRouter.new()
	
	// test route
	route_path := '/api/:version/users/:user_id/posts/:post_id/comments/:comment_id'
	test_path := '/api/v1/users/123/posts/456/comments/789'
	
	handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('test')
		}
	}
	
	// Step 1: Add routing time
	start_time1 := time.now()
	router.add_route('GET', handler, '')
	add_route_time := time.since(start_time1)
	println('  添加路由时间: ${add_route_time}')
	
	// Step 2: First match (including compilation)
	start_time2 := time.now()
	result1 := router.match_route('GET', test_path)
	first_match_time := time.since(start_time2)
	println('  第一次匹配时间 (含编译): ${first_match_time}')
	
	if result1 != none {
		println('  ✅ 第一次匹配成功')
	}
	
	// Step 3: Second match (using cache)
	start_time3 := time.now()
	_ = router.match_route('GET', test_path)
	second_match_time := time.since(start_time3)
	println('  第二次匹配时间 (使用缓存): ${second_match_time}')
	
	// Step 4: Analyze cache status
	cache_size, cache_capacity := router.get_cache_stats()
	regex_total, regex_compiled := router.get_regex_cache_stats()
	println('  路由缓存: ${cache_size}/${cache_capacity}')
	println('  正则缓存: ${regex_compiled}/${regex_total}')
	
	// Step 5: Test pure regular matching time (safe access)
	if cached := router.regex_cache[route_path] {
		if cached.compiled {
			// First verify that the regular expression matches
			if cached.regex.matches_string(test_path) {
				start_time4 := time.now()
				for _ in 0 .. 1000 {
					cached.regex.matches_string(test_path)
				}
				pure_regex_time := time.since(start_time4)
				avg_regex_time := f64(pure_regex_time.microseconds()) / 1000.0
				println('  纯正则匹配平均时间: ${avg_regex_time:.3f}μs')
			} else {
				println('  ⚠️  正则表达式无法匹配测试路径')
			}
		}
	} else {
		println('  ⚠️  正则缓存中未找到路由')
	}
	
	// Step 6: Test parameter extraction time (security access)
	if cached := router.regex_cache[route_path] {
		if cached.compiled && cached.param_names.len > 0 {
			// Execute a match first to ensure that the regular state is correct
			if cached.regex.matches_string(test_path) {
				start_time5 := time.now()
				mut extract_count := 0
				for _ in 0 .. 1000 {
					//Rematch before each extraction
					if cached.regex.matches_string(test_path) {
						for param_name in cached.param_names {
							group := cached.regex.get_group_by_name(test_path, param_name)
							if group.len > 0 {
								extract_count++
							}
						}
					}
				}
				param_extract_time := time.since(start_time5)
				avg_param_time := f64(param_extract_time.microseconds()) / 1000.0
				println('  参数提取平均时间: ${avg_param_time:.3f}μs')
				println('  参数数量: ${cached.param_names.len}')
			}
		}
	}
}

fn test_complexity_performance() {
	println('\n📊 不同复杂度路由性能对比...')
	
	// Define routes of different complexity
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
		println('\n  测试: ${test_case['name']}')
		
		mut router := hono.ContextHybridRouter.new()
		
		handler := hono.ContextHandler{
			path: test_case['route']
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		
		router.add_route('GET', handler, '')
		
		// First match (compile)
		start_time1 := time.now()
		result1 := router.match_route('GET', test_case['path'])
		first_time := time.since(start_time1)
		
		//Multiple cache matches
		iterations := 10000
		start_time2 := time.now()
		mut cache_matches := 0
		for _ in 0 .. iterations {
			if _ := router.match_route('GET', test_case['path']) {
				cache_matches++
			}
		}
		cache_time := time.since(start_time2)
		
		if result1 != none {
			println('    第一次匹配: ${first_time}')
			if cache_matches > 0 {
				avg_cache_time := f64(cache_time.microseconds()) / f64(cache_matches)
				println('    平均缓存匹配: ${avg_cache_time:.3f}μs')
			}
			
			//Analyze routing complexity
			param_count := test_case['route'].count(':')
			path_segments := test_case['route'].split('/').len
			println('    参数数量: ${param_count}')
			println('    路径段数: ${path_segments}')
		} else {
			println('    ❌ 匹配失败')
		}
	}
	
	//Test the routing sorting effect
	println('\n  📈 测试路由排序效果...')
	
	mut router := hono.ContextHybridRouter.new()
	
	//Add routes of different complexity (deliberately added in order of decreasing complexity)
	routes := [
		'/api/:version/users/:user_id/posts/:post_id/comments/:comment_id',  // most complex
		'/api/:version/users/:user_id/posts/:post_id',                      // medium complex
		'/users/:id/posts/:post_id',                                        // simpler
		'/users/:id'                                                        // simplest
	]
	
	for route in routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	//Test the simplest route to match (should be matched first)
	simple_path := '/users/123'
	
	start_time := time.now()
	for _ in 0 .. 10000 {
		router.match_route('GET', simple_path)
	}
	sorted_time := time.since(start_time)
	
	avg_sorted_time := f64(sorted_time.microseconds()) / 10000.0
	println('    排序后简单路由平均匹配时间: ${avg_sorted_time:.3f}μs')
	
	//Display routing order
	_, dynamic_paths := router.get_all_routes()
	println('    路由排序后顺序:')
	for i, path in dynamic_paths {
		println('      ${i+1}. ${path}')
	}
}
