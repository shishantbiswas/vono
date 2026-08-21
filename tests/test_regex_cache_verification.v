import meiseayoung.vono
import time
import net.http

fn main() {
	println('=== 正则表达式缓存验证测试 ===')
	
	//Test 1: Verify that caching is actually working
	test_cache_actually_works()
	
	//Test 2: Verify cache hit rate
	test_cache_hit_rate()
	
	//Test 3: Compare performance before and after caching
	test_cache_performance_difference()
	
	println('✅ 正则表达式缓存验证完成')
}

fn test_cache_actually_works() {
	println('\n📊 验证缓存是否真正工作...')
	
	mut router := vono.ContextHybridRouter.new()
	
	//Add a dynamic route
	handler := vono.ContextHandler{
		path: '/users/:id/posts/:post_id'
		handler: fn (mut c vono.Context) http.Response {
			return c.text('test')
		}
	}
	router.add_route('GET', handler, '')
	
	test_path := '/users/123/posts/456'
	
	// Check initial cache status
	regex_total_before, regex_compiled_before := router.get_regex_cache_stats()
	println('  初始缓存状态: ${regex_compiled_before}/${regex_total_before} 已编译')
	
	// First match (regex should be compiled and cached)
	println('  第一次匹配 (应该编译正则表达式)...')
	start_time1 := time.now()
	result1 := router.match_route('GET', test_path)
	first_match_time := time.since(start_time1)
	
	// Check cache status
	regex_total_after1, regex_compiled_after1 := router.get_regex_cache_stats()
	println('  第一次匹配后缓存状态: ${regex_compiled_after1}/${regex_total_after1} 已编译')
	println('  第一次匹配时间: ${first_match_time}')
	
	if result1 != none {
		println('  ✅ 第一次匹配成功')
	} else {
		println('  ❌ 第一次匹配失败')
	}
	
	// Second match (should use cached regular expression)
	println('  第二次匹配 (应该使用缓存)...')
	start_time2 := time.now()
	result2 := router.match_route('GET', test_path)
	second_match_time := time.since(start_time2)
	
	// Check cache status
	regex_total_after2, regex_compiled_after2 := router.get_regex_cache_stats()
	println('  第二次匹配后缓存状态: ${regex_compiled_after2}/${regex_total_after2} 已编译')
	println('  第二次匹配时间: ${second_match_time}')
	
	if result2 != none {
		println('  ✅ 第二次匹配成功')
	} else {
		println('  ❌ 第二次匹配失败')
	}
	
	// Verify that the cache is actually working
	if regex_compiled_after1 > regex_compiled_before {
		println('  ✅ 正则表达式已被编译并缓存')
	} else {
		println('  ❌ 正则表达式缓存未生效')
	}
	
	if regex_compiled_after2 == regex_compiled_after1 {
		println('  ✅ 第二次匹配使用了缓存 (没有新的编译)')
	} else {
		println('  ❌ 第二次匹配没有使用缓存 (发生了新的编译)')
	}
	
	//Performance comparison
	if first_match_time.microseconds() > 0 && second_match_time.microseconds() > 0 {
		if first_match_time > second_match_time {
			improvement := f64(first_match_time.microseconds()) / f64(second_match_time.microseconds())
			println('  🚀 缓存带来的性能提升: ${improvement:.2f}x')
		} else {
			println('  ⚠️  第二次匹配没有明显的性能提升')
		}
	}
}

fn test_cache_hit_rate() {
	println('\n📊 测试缓存命中率...')
	
	mut router := vono.ContextHybridRouter.new()
	
	//Add multiple dynamic routes
	routes := [
		'/users/:id',
		'/posts/:post_id/comments/:comment_id',
		'/files/:category/:filename'
	]
	
	for route in routes {
		handler := vono.ContextHandler{
			path: route
			handler: fn (mut c vono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	// test path
	test_paths := [
		'/users/123',
		'/posts/456/comments/789',
		'/files/images/photo.jpg'
	]
	
	//Initial cache state
	regex_total_initial, regex_compiled_initial := router.get_regex_cache_stats()
	println('  初始缓存: ${regex_compiled_initial}/${regex_total_initial}')
	
	// First round of matching (all regular expressions should be compiled)
	println('  第一轮匹配 (编译阶段)...')
	for path in test_paths {
		router.match_route('GET', path)
	}
	
	regex_total_after_first, regex_compiled_after_first := router.get_regex_cache_stats()
	println('  第一轮后缓存: ${regex_compiled_after_first}/${regex_total_after_first}')
	
	//Multiple rounds of matching (cache should be used for all)
	println('  多轮匹配 (缓存阶段)...')
	for round in 1 .. 6 {
		for path in test_paths {
			router.match_route('GET', path)
		}
		
		regex_total_current, regex_compiled_current := router.get_regex_cache_stats()
		println('    第${round}轮后缓存: ${regex_compiled_current}/${regex_total_current}')
		
		if regex_compiled_current > regex_compiled_after_first {
			println('    ❌ 发现新的编译，缓存可能未正常工作')
		}
	}
	
	// final cache status
	_, regex_compiled_final := router.get_regex_cache_stats()
	
	if regex_compiled_final == regex_compiled_after_first {
		println('  ✅ 缓存命中率100% - 没有额外的编译')
	} else {
		println('  ❌ 缓存命中率不足 - 发生了额外的编译')
	}
}

fn test_cache_performance_difference() {
	println('\n📊 测试缓存性能差异...')
	
	mut router := vono.ContextHybridRouter.new()
	
	//Add complex dynamic routing
	handler := vono.ContextHandler{
		path: '/api/:version/users/:user_id/posts/:post_id/comments/:comment_id'
		handler: fn (mut c vono.Context) http.Response {
			return c.text('test')
		}
	}
	router.add_route('GET', handler, '')
	
	test_path := '/api/v1/users/123/posts/456/comments/789'
	
	// Clear the cache to ensure that the first match requires compilation
	router.clear_regex_cache()
	
	//Test first match (compile + match)
	iterations_first := 1
	start_time1 := time.now()
	for _ in 0 .. iterations_first {
		router.match_route('GET', test_path)
	}
	first_time := time.since(start_time1)
	
	// Test subsequent matches (match only, use cache)
	iterations_cached := 1000
	start_time2 := time.now()
	for _ in 0 .. iterations_cached {
		router.match_route('GET', test_path)
	}
	cached_time := time.since(start_time2)
	
	println('  第一次匹配 (编译+匹配): ${first_time}')
	println('  1000次缓存匹配: ${cached_time}')
	
	// Calculate average time
	avg_first := f64(first_time.microseconds()) / f64(iterations_first)
	avg_cached := f64(cached_time.microseconds()) / f64(iterations_cached)
	
	println('  平均第一次匹配时间: ${avg_first:.2f}μs')
	println('  平均缓存匹配时间: ${avg_cached:.2f}μs')
	
	if avg_first > avg_cached {
		improvement := avg_first / avg_cached
		println('  🚀 缓存性能提升: ${improvement:.2f}x')
		
		if improvement > 2.0 {
			println('  ✅ 缓存效果显著')
		} else {
			println('  ⚠️  缓存效果有限')
		}
	} else {
		println('  ❌ 缓存没有带来性能提升')
	}
	
	//Display final cache statistics
	router.analyze_router_performance()
}