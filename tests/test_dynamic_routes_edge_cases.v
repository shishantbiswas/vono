import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== 动态路由边界情况测试 ===')
	
	//Test 1: Special characters and encodings
	test_special_characters()
	
	//Test 2: Long paths and deep nesting
	test_long_paths()
	
	//Test 3: Similar route conflict
	test_route_conflicts()
	
	//Test 4: Parameter boundary values
	test_parameter_boundaries()
	
	//Test 5: Performance degradation scenario
	test_performance_degradation()
	
	//Test 6: Memory usage test
	test_memory_usage()
	
	//Test 7: Concurrency safety test
	test_concurrent_access()
	
	//Test 8: Error recovery test
	test_error_recovery()
	
	println('✅ 动态路由边界情况测试完成')
}

fn test_special_characters() {
	println('\n📊 特殊字符和编码测试...')
	
	mut app := hono.Hono.new()
	
	//Routes containing special characters
	special_routes := [
		'/users/:user_id',
		'/files/:filename',
		'/search/:query',
		'/categories/:category_name',
		'/tags/:tag_name',
		'/paths/:path_segment',
	]
	
	for route in special_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('special response')
		})
	}
	
	// Test paths containing special characters - use string representation expect
	special_test_cases := [
		{ 'path': '/users/user123', 'expect': 'true', 'desc': '数字字母组合' },
		{ 'path': '/users/USER_123', 'expect': 'true', 'desc': '大写字母下划线' },
		{ 'path': '/files/my-file.txt', 'expect': 'true', 'desc': '连字符文件名' },
		{ 'path': '/files/my_file.txt', 'expect': 'true', 'desc': '下划线文件名' },
		{ 'path': '/search/hello%20world', 'expect': 'true', 'desc': 'URL编码空格' },
		{ 'path': '/categories/tech%26dev', 'expect': 'true', 'desc': 'URL编码&符号' },
		{ 'path': '/tags/c++', 'expect': 'true', 'desc': 'C++标签' },
		{ 'path': '/tags/node.js', 'expect': 'true', 'desc': '点号标签' },
		{ 'path': '/users/very-long-username-with-many-characters-123456789', 'expect': 'true', 'desc': '长用户名' },
		{ 'path': '/users/', 'expect': 'false', 'desc': '空参数' },
		{ 'path': '/users', 'expect': 'false', 'desc': '缺少参数' },
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in special_test_cases {
		start_time := time.now()
		expect_match := test_case['expect'] == 'true'
		
		if match_result := app.fast_router.match_route('GET', test_case['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			
			if expect_match {
				success_count++
				params := match_result.params.clone()
				mut param_value := 'none'
				for _, v in params {
					param_value = v
					break
				}
				println('  ✅ ${test_case['desc']}: ${test_case['path']} → ${param_value} (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: ${test_case['path']} - 意外匹配 (${match_time})')
			}
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			
			if !expect_match {
				success_count++
				println('  ✅ ${test_case['desc']}: ${test_case['path']} - 正确拒绝 (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: ${test_case['path']} - 匹配失败 (${match_time})')
			}
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(special_test_cases.len)
	println('  📈 特殊字符测试: ${success_count}/${special_test_cases.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_long_paths() {
	println('\n📊 长路径和深层嵌套测试...')
	
	mut app := hono.Hono.new()
	
	//Create nested routes of different depths
	nesting_levels := [3, 5, 7, 10, 15]
	
	for level in nesting_levels {
		mut route_parts := []string{}
		route_parts << ''
		
		for i in 0 .. level {
			route_parts << 'level${i}'
			route_parts << ':param${i}'
		}
		
		route := route_parts.join('/')
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('deep response')
		})
	}
	
	//Create long path test cases
	mut long_path_tests := []map[string]string{}
	
	for level in nesting_levels {
		mut path_parts := []string{}
		path_parts << ''
		
		for i in 0 .. level {
			path_parts << 'level${i}'
			path_parts << 'value${i}'
		}
		
		path := path_parts.join('/')
		long_path_tests << {
			'path': path
			'level': level.str()
			'expect': 'true'
		}
	}
	
	//Add some invalid long paths
	long_path_tests << {
		'path': '/level0/value0/level1/value1/level2/value2/level3/value3/extra'
		'level': 'invalid'
		'expect': 'false'
	}
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in long_path_tests {
		start_time := time.now()
		expect_match := test_case['expect'] == 'true'
		
		if match_result := app.fast_router.match_route('GET', test_case['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			
			if expect_match {
				success_count++
				param_count := match_result.params.len
				path_length := test_case['path'].len
				println('  ✅ 嵌套级别${test_case['level']}: ${param_count}参数, ${path_length}字符 (${match_time})')
			} else {
				println('  ❌ ${test_case['path']} - 意外匹配 (${match_time})')
			}
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			
			if !expect_match {
				success_count++
				println('  ✅ 无效路径正确拒绝: ${test_case['path']} (${match_time})')
			} else {
				println('  ❌ 嵌套级别${test_case['level']} - 匹配失败 (${match_time})')
			}
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(long_path_tests.len)
	println('  📈 长路径测试: ${success_count}/${long_path_tests.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_route_conflicts() {
	println('\n📊 相似路由冲突测试...')
	
	mut app := hono.Hono.new()
	
	//Add possible conflicting routes
	conflicting_routes := [
		'/users/profile',
		'/users/:id',
		'/posts/:id',
		'/posts/:post_id',
		'/api/users',
		'/api/:resource',
		'/api/:version/users',
		'/files/:category/:name',
		'/files/:type/:filename',
		'/admin',
		'/admin/:section',
		'/admin/users/:id',
	]
	
	for i, route in conflicting_routes {
		app.get(route, fn [i] (mut c hono.Context) http.Response {
			return c.text('response from route ${i}')
		})
	}
	
	//Test conflict resolution
	conflict_test_cases := [
		{ 'path': '/users/profile', 'desc': '静态路由优先' },
		{ 'path': '/users/123', 'desc': '动态路由匹配' },
		{ 'path': '/posts/456', 'desc': '第一个动态路由' },
		{ 'path': '/api/users', 'desc': '静态API路由' },
		{ 'path': '/api/posts', 'desc': '动态资源路由' },
		{ 'path': '/api/v1/users', 'desc': '版本化API路由' },
		{ 'path': '/files/images/photo.jpg', 'desc': '文件路由匹配' },
		{ 'path': '/admin', 'desc': '管理员首页' },
		{ 'path': '/admin/settings', 'desc': '管理员设置' },
		{ 'path': '/admin/users/789', 'desc': '管理员用户详情' },
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in conflict_test_cases {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', test_case['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			
			matched_pattern := match_result.path
			param_count := match_result.params.len
			println('  ✅ ${test_case['desc']}: ${test_case['path']} → ${matched_pattern} (${param_count}参数, ${match_time})')
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			println('  ❌ ${test_case['desc']}: ${test_case['path']} - 无匹配 (${match_time})')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(conflict_test_cases.len)
	println('  📈 路由冲突测试: ${success_count}/${conflict_test_cases.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_parameter_boundaries() {
	println('\n📊 参数边界值测试...')
	
	mut app := hono.Hono.new()
	
	//Parameter boundary test routing
	boundary_routes := [
		'/short/:id',
		'/long/:very_long_parameter_name',
		'/multi/:a/:b/:c/:d/:e',
		'/numeric/:number',
		'/mixed/:id/:name/:type',
	]
	
	for route in boundary_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('boundary response')
		})
	}
	
	// Boundary value test cases - use string representation expect
	boundary_test_cases := [
		{ 'path': '/short/1', 'desc': '单字符参数', 'expect': 'true' },
		{ 'path': '/short/a', 'desc': '单字母参数', 'expect': 'true' },
		{ 'path': '/long/this-is-a-very-long-parameter-value-with-many-characters-and-hyphens-123456789', 'desc': '超长参数值', 'expect': 'true' },
		{ 'path': '/multi/a/b/c/d/e', 'desc': '5个短参数', 'expect': 'true' },
		{ 'path': '/multi/param1/param2/param3/param4/param5', 'desc': '5个中等参数', 'expect': 'true' },
		{ 'path': '/numeric/0', 'desc': '零值', 'expect': 'true' },
		{ 'path': '/numeric/123456789', 'desc': '大数字', 'expect': 'true' },
		{ 'path': '/numeric/-123', 'desc': '负数', 'expect': 'true' },
		{ 'path': '/mixed/123/john-doe/admin', 'desc': '混合类型参数', 'expect': 'true' },
		{ 'path': '/mixed/0/a/x', 'desc': '最小混合参数', 'expect': 'true' },
		{ 'path': '/short/', 'desc': '空参数', 'expect': 'false' },
		{ 'path': '/multi/a/b/c/d', 'desc': '参数不足', 'expect': 'false' },
		{ 'path': '/multi/a/b/c/d/e/f', 'desc': '参数过多', 'expect': 'false' },
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in boundary_test_cases {
		start_time := time.now()
		expect_match := test_case['expect'] == 'true'
		
		if match_result := app.fast_router.match_route('GET', test_case['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			
			if expect_match {
				success_count++
				params := match_result.params.clone()
				mut param_info := []string{}
				for key, value in params {
					param_info << '${key}=${value}'
				}
				println('  ✅ ${test_case['desc']}: [${param_info.join(', ')}] (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: 意外匹配 (${match_time})')
			}
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			
			if !expect_match {
				success_count++
				println('  ✅ ${test_case['desc']}: 正确拒绝 (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: 匹配失败 (${match_time})')
			}
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(boundary_test_cases.len)
	println('  📈 参数边界测试: ${success_count}/${boundary_test_cases.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_performance_degradation() {
	println('\n📊 性能退化场景测试...')
	
	mut app := hono.Hono.new()
	
	// Create routing patterns that may cause performance degradation
	degradation_scenarios := [
		{ 'name': '相似路由模式', 'count': '100', 'pattern': '/api/v1/resources/:id/items/:item_id' },
		{ 'name': '复杂嵌套路由', 'count': '50', 'pattern': '/complex/:a/:b/:c/:d/:e/:f' },
		{ 'name': '长路径路由', 'count': '30', 'pattern': '/very/long/path/with/many/segments/:param1/:param2/:param3' },
	]
	
	for scenario in degradation_scenarios {
		println('  创建${scenario['name']} (${scenario['count']}个路由)...')
		
		count := scenario['count'].int()
		pattern := scenario['pattern']
		
		for i in 0 .. count {
			unique_pattern := pattern.replace(':id', ':id${i}').replace(':item_id', ':item_id${i}')
			
			app.get(unique_pattern, fn [i] (mut c hono.Context) http.Response {
				return c.text('response ${i}')
			})
		}
	}
	
	//Test performance degradation
	test_iterations := [10, 100, 1000, 5000]
	
	for iterations in test_iterations {
		println('  测试 ${iterations} 次匹配...')
		
		test_paths := [
			'/api/v1/resources/123/items/456',
			'/complex/a/b/c/d/e/f',
			'/very/long/path/with/many/segments/param1/param2/param3',
		]
		
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
		total_requests := iterations * test_paths.len
		avg_time := f64(total_time.microseconds()) / f64(total_requests)
		
		println('    ${iterations}次: ${match_count}/${total_requests} 匹配, 平均 ${avg_time:.3f}μs')
	}
	
	//display final statistics
	static_count, dynamic_count, cache_count := app.fast_router.get_stats()
	println('  📊 最终统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
}

fn test_memory_usage() {
	println('\n📊 内存使用测试...')
	
	mut app := hono.Hono.new()
	
	//Test the impact of routing of different sizes on memory
	memory_test_scales := [10, 50, 100, 500, 1000]
	
	for scale in memory_test_scales {
		println('  测试 ${scale} 个路由的内存使用...')
		
		// Clean up previous routes
		app = hono.Hono.new()
		
		//Add the specified number of routes
		for i in 0 .. scale {
			route_pattern := '/test${i}/:param1/:param2/:param3'
			app.get(route_pattern, fn [i] (mut c hono.Context) http.Response {
				return c.text('response ${i}')
			})
		}
		
		//Perform some matching operations to populate the cache
		for i in 0 .. 10 {
			test_path := '/test${i % scale}/value1/value2/value3'
			app.fast_router.match_route('GET', test_path)
		}
		
		// Get statistics
		_, dynamic_count, cache_count := app.fast_router.get_stats()
		
		println('    ${scale}个路由: 动态=${dynamic_count}, 缓存=${cache_count}')
		
		// Simple memory usage estimate
		estimated_memory := dynamic_count * 200 + cache_count * 150
		println('    估算内存使用: ~${estimated_memory} 字节')
	}
}

fn test_concurrent_access() {
	println('\n📊 并发安全测试...')
	
	mut app := hono.Hono.new()
	
	//Add some test routes
	concurrent_routes := [
		'/concurrent/:id',
		'/parallel/:type/:value',
		'/shared/:resource/:action',
	]
	
	for route in concurrent_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('concurrent response')
		})
	}
	
	// Simulate concurrent access
	test_paths := [
		'/concurrent/123',
		'/parallel/user/create',
		'/shared/database/read',
		'/concurrent/456',
		'/parallel/admin/delete',
		'/shared/cache/write',
	]
	
	println('  模拟并发路由匹配...')
	
	// Perform multiple matches quickly and continuously
	iterations := 1000
	start_time := time.now()
	mut success_count := 0
	
	for i in 0 .. iterations {
		path := test_paths[i % test_paths.len]
		if _ := app.fast_router.match_route('GET', path) {
			success_count++
		}
	}
	
	total_time := time.since(start_time)
	avg_time := f64(total_time.microseconds()) / f64(iterations)
	
	println('  📈 并发测试: ${success_count}/${iterations} 成功, 平均 ${avg_time:.3f}μs')
	
	// Check cache consistency
	_, dynamic_count, cache_count := app.fast_router.get_stats()
	println('  📊 缓存状态: 动态=${dynamic_count}, 缓存=${cache_count}')
}

fn test_error_recovery() {
	println('\n📊 错误恢复测试...')
	
	mut app := hono.Hono.new()
	
	//Add normal route
	app.get('/normal/:id', fn (mut c hono.Context) http.Response {
		return c.text('normal response')
	})
	
	// Test recovery from various error conditions - use string representation expect
	error_test_cases := [
		{ 'path': '/normal/123', 'desc': '正常路径', 'expect': 'true' },
		{ 'path': '/nonexistent', 'desc': '不存在的路径', 'expect': 'false' },
		{ 'path': '/normal/', 'desc': '空参数', 'expect': 'false' },
		{ 'path': '/normal', 'desc': '缺少参数', 'expect': 'false' },
		{ 'path': '', 'desc': '空路径', 'expect': 'false' },
		{ 'path': '/', 'desc': '根路径', 'expect': 'false' },
		{ 'path': '/normal/123/extra', 'desc': '额外路径段', 'expect': 'false' },
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in error_test_cases {
		start_time := time.now()
		expect_match := test_case['expect'] == 'true'
		
		//Test error recovery
		if _ := app.fast_router.match_route('GET', test_case['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			
			if expect_match {
				success_count++
				println('  ✅ ${test_case['desc']}: 正常匹配 (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: 意外匹配 (${match_time})')
			}
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			
			if !expect_match {
				success_count++
				println('  ✅ ${test_case['desc']}: 正确处理错误 (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: 匹配失败 (${match_time})')
			}
		}
		
		// Verify that the system is still working properly
		if _ := app.fast_router.match_route('GET', '/normal/recovery-test') {
			println('    ↳ 系统恢复正常')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(error_test_cases.len)
	println('  📈 错误恢复测试: ${success_count}/${error_test_cases.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}
