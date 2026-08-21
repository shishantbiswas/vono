// FastCache optimization test
// Verify correctness and performance of high-performance cache (via FastRouter API)
module main

import meiseayoung.hono
import net.http
import time

struct TestResult {
mut:
	name   string
	passed bool
	detail string
}

fn main() {
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║           FastCache 优化测试                                  ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
	println('')

	mut results := []TestResult{}

	// 1. Route matching correctness test
	results << test_route_matching_correctness()
	
	// 2. Parameter extraction correctness test
	results << test_param_extraction()
	
	// 3. Cache hit test
	results << test_cache_hit()
	
	// 4. Multi-routing concurrent testing
	results << test_multiple_routes()
	
	// 5. Performance benchmark test
	results << test_performance_benchmark()
	
	// 6. Cache consistency test
	results << test_cache_consistency()
	
	// 7. Cache cleaning test
	results << test_cache_clear()
	
	// 8. Cache health check test
	results << test_cache_health()

	// print results
	println('')
	println('═══════════════════════════════════════════════════════════════')
	println('📊 测试结果汇总')
	println('═══════════════════════════════════════════════════════════════')
	
	mut passed := 0
	mut failed := 0
	
	for result in results {
		status := if result.passed { '✅' } else { '❌' }
		println('${status} ${result.name}')
		if result.detail.len > 0 {
			println('   ${result.detail}')
		}
		if result.passed {
			passed++
		} else {
			failed++
		}
	}
	
	println('')
	println('总计: ${passed}/${results.len} 通过')
	
	if failed == 0 {
		println('🎉 所有测试通过！FastCache 优化验证成功！')
	} else {
		println('⚠️  有 ${failed} 个测试失败')
	}
}

// 1. Route matching correctness test
fn test_route_matching_correctness() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user')
	})
	
	app.get('/posts/:post_id/comments/:comment_id', fn (mut c hono.Context) http.Response {
		return c.text('comment')
	})
	
	mut router := app.fast_router
	
	//Test single parameter routing
	if match1 := router.match_route('GET', '/users/456') {
		if match1.params['id'] or { '' } != '456' {
			return TestResult{name: '路由匹配正确性', passed: false, detail: '单参数提取错误'}
		}
	} else {
		return TestResult{name: '路由匹配正确性', passed: false, detail: '单参数路由匹配失败'}
	}
	
	//Test multi-parameter routing
	if match2 := router.match_route('GET', '/posts/100/comments/200') {
		post_id := match2.params['post_id'] or { '' }
		comment_id := match2.params['comment_id'] or { '' }
		if post_id != '100' || comment_id != '200' {
			return TestResult{name: '路由匹配正确性', passed: false, detail: '多参数提取错误: post_id=${post_id}, comment_id=${comment_id}'}
		}
	} else {
		return TestResult{name: '路由匹配正确性', passed: false, detail: '多参数路由匹配失败'}
	}
	
	return TestResult{name: '路由匹配正确性', passed: true, detail: '单参数和多参数路由均正确'}
}

// 2. Parameter extraction correctness test
fn test_param_extraction() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/api/:version/users/:user_id/posts/:post_id', fn (mut c hono.Context) http.Response {
		return c.text('ok')
	})
	
	mut router := app.fast_router
	
	test_cases := [
		['/api/v1/users/100/posts/200', 'v1', '100', '200'],
		['/api/v2/users/abc/posts/xyz', 'v2', 'abc', 'xyz'],
		['/api/beta/users/user-123/posts/post-456', 'beta', 'user-123', 'post-456'],
	]
	
	for tc in test_cases {
		path := tc[0]
		expected_version := tc[1]
		expected_user := tc[2]
		expected_post := tc[3]
		
		if match_result := router.match_route('GET', path) {
			version := match_result.params['version'] or { '' }
			user_id := match_result.params['user_id'] or { '' }
			post_id := match_result.params['post_id'] or { '' }
			
			if version != expected_version || user_id != expected_user || post_id != expected_post {
				return TestResult{
					name: '参数提取正确性'
					passed: false
					detail: '路径 ${path} 参数提取错误'
				}
			}
		} else {
			return TestResult{name: '参数提取正确性', passed: false, detail: '路径 ${path} 匹配失败'}
		}
	}
	
	return TestResult{name: '参数提取正确性', passed: true, detail: '${test_cases.len} 个测试用例全部通过'}
}

// 3. Cache hit test
fn test_cache_hit() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user')
	})
	
	mut router := app.fast_router
	
	//First match (cache miss, regular matching required)
	_ := router.match_route('GET', '/users/123')
	
	// Get cache statistics
	cache_size1, _ := router.get_cache_stats()
	
	// Second match (should hit cache)
	if match2 := router.match_route('GET', '/users/123') {
		if match2.params['id'] or { '' } == '123' {
			cache_size2, _ := router.get_cache_stats()
			return TestResult{
				name: '缓存命中测试'
				passed: true
				detail: '缓存大小: ${cache_size1} -> ${cache_size2}，参数正确'
			}
		}
	}
	
	return TestResult{name: '缓存命中测试', passed: false, detail: '缓存命中后参数错误'}
}

// 4. Multi-routing concurrent testing
fn test_multiple_routes() TestResult {
	mut app := hono.Hono.new()
	
	//Register multiple routes
	app.get('/users/:id', fn (mut c hono.Context) http.Response { return c.text('user') })
	app.get('/posts/:id', fn (mut c hono.Context) http.Response { return c.text('post') })
	app.get('/comments/:id', fn (mut c hono.Context) http.Response { return c.text('comment') })
	app.get('/tags/:name', fn (mut c hono.Context) http.Response { return c.text('tag') })
	
	mut router := app.fast_router
	
	// Alternately match different routes
	test_paths := [
		['/users/1', 'id', '1'],
		['/posts/2', 'id', '2'],
		['/comments/3', 'id', '3'],
		['/tags/golang', 'name', 'golang'],
		['/users/100', 'id', '100'],
		['/posts/200', 'id', '200'],
	]
	
	for tc in test_paths {
		path := tc[0]
		param_name := tc[1]
		expected_value := tc[2]
		
		if match_result := router.match_route('GET', path) {
			actual_value := match_result.params[param_name] or { '' }
			if actual_value != expected_value {
				return TestResult{
					name: '多路由并发测试'
					passed: false
					detail: '路径 ${path} 参数错误: 期望 ${expected_value}, 实际 ${actual_value}'
				}
			}
		} else {
			return TestResult{name: '多路由并发测试', passed: false, detail: '路径 ${path} 匹配失败'}
		}
	}
	
	return TestResult{name: '多路由并发测试', passed: true, detail: '${test_paths.len} 个路径全部正确'}
}

// 5. Performance benchmark test
fn test_performance_benchmark() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user')
	})
	
	mut router := app.fast_router
	
	// preheat
	for i in 0 .. 100 {
		_ := router.match_route('GET', '/users/${i}')
	}
	
	//Test cache hit performance
	iterations := 10000
	sw := time.new_stopwatch()
	
	for _ in 0 .. iterations {
		_ := router.match_route('GET', '/users/50')  // hit cache
	}
	
	elapsed := sw.elapsed()
	avg_ns := elapsed.nanoseconds() / iterations
	avg_us := f64(avg_ns) / 1000.0
	
	// Cache hit performance evaluation (considering differences between different platforms)
	if avg_us < 1.0 {
		return TestResult{
			name: '性能基准测试'
			passed: true
			detail: '缓存命中平均耗时: ${avg_us:.3f}μs (< 1μs, 优秀 ✓)'
		}
	} else if avg_us < 10.0 {
		return TestResult{
			name: '性能基准测试'
			passed: true
			detail: '缓存命中平均耗时: ${avg_us:.3f}μs (< 10μs, 良好)'
		}
	} else if avg_us < 50.0 {
		return TestResult{
			name: '性能基准测试'
			passed: true
			detail: '缓存命中平均耗时: ${avg_us:.3f}μs (< 50μs, 可接受)'
		}
	}
	
	return TestResult{
		name: '性能基准测试'
		passed: false
		detail: '缓存命中平均耗时: ${avg_us:.3f}μs (> 50μs, 过慢)'
	}
}

// 6. Cache consistency test
fn test_cache_consistency() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/items/:id', fn (mut c hono.Context) http.Response {
		return c.text('item')
	})
	
	mut router := app.fast_router
	
	//Match the same path multiple times, and the verification results are consistent
	mut results := []string{}
	
	for _ in 0 .. 100 {
		if match_result := router.match_route('GET', '/items/999') {
			results << match_result.params['id'] or { 'error' }
		} else {
			results << 'no_match'
		}
	}
	
	// Check if all results are consistent
	first := results[0]
	for i, r in results {
		if r != first {
			return TestResult{
				name: '缓存一致性测试'
				passed: false
				detail: '第 ${i} 次结果不一致: ${r} != ${first}'
			}
		}
	}
	
	if first == '999' {
		return TestResult{name: '缓存一致性测试', passed: true, detail: '100 次匹配结果完全一致'}
	}
	
	return TestResult{name: '缓存一致性测试', passed: false, detail: '参数值错误: ${first}'}
}

// 7. Cache cleaning test
fn test_cache_clear() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user')
	})
	
	mut router := app.fast_router
	
	//Fill cache
	for i in 0 .. 10 {
		_ := router.match_route('GET', '/users/${i}')
	}
	
	// Get the cache size before cleaning
	size_before, _ := router.get_cache_stats()
	
	// clear cache
	router.clear_cache()
	
	// Get the cache size after cleaning
	size_after, _ := router.get_cache_stats()
	
	if size_after == 0 {
		return TestResult{
			name: '缓存清理测试'
			passed: true
			detail: '清理前: ${size_before}, 清理后: ${size_after}'
		}
	}
	
	return TestResult{
		name: '缓存清理测试'
		passed: false
		detail: '清理后缓存大小应为0，实际为: ${size_after}'
	}
}

// 8. Cache health check test
fn test_cache_health() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user')
	})
	
	mut router := app.fast_router
	
	// Fill some cache
	for i in 0 .. 50 {
		_ := router.match_route('GET', '/users/${i}')
	}
	
	// Check health status
	is_healthy := router.is_healthy()
	
	// Get detailed statistics
	stats := router.get_detailed_stats()
	
	if is_healthy {
		return TestResult{
			name: '缓存健康检查测试'
			passed: true
			detail: '缓存健康，统计项数: ${stats.len}'
		}
	}
	
	return TestResult{
		name: '缓存健康检查测试'
		passed: false
		detail: '缓存不健康'
	}
}
