// veb vs vono performance comparison test
// Run: v run benchmark_veb_vs_hono.v
// 
//Test content:
// 1. Route matching performance (pure routing, no server startup)
// 2. Static routing vs dynamic routing performance comparison
// 3. Cache hit rate analysis

module main

import time
import meiseayoung.hono
import net.http

// ============================================
// test configuration
// ============================================
const iterations = 10000
const warmup_iterations = 1000

// test path
const static_paths = [
	'/',
	'/api/health',
	'/api/users',
]

const dynamic_paths = [
	'/api/users/123',
	'/api/users/456/posts',
	'/api/users/789/posts/101',
	'/api/categories/electronics/items/phone',
]

// ============================================
// Simple router (simulates veb's route matching method)
// ============================================
struct SimpleRouter {
mut:
	static_routes  map[string]string
	dynamic_routes []DynamicRoute
}

struct DynamicRoute {
	pattern    string
	param_names []string
}

fn SimpleRouter.new() SimpleRouter {
	return SimpleRouter{
		static_routes: map[string]string{}
		dynamic_routes: []DynamicRoute{}
	}
}

fn (mut r SimpleRouter) add_static(path string) {
	r.static_routes[path] = path
}

fn (mut r SimpleRouter) add_dynamic(pattern string, param_names []string) {
	r.dynamic_routes << DynamicRoute{pattern, param_names}
}

// Simple dynamic route matching (simulating the linear scan method of veb)
fn (r SimpleRouter) match_route(path string) (bool, map[string]string) {
	// 1. Try static matching first
	if path in r.static_routes {
		return true, map[string]string{}
	}
	
	// 2. Dynamic route matching (linear scan)
	path_parts := path.split('/').filter(it.len > 0)
	
	for route in r.dynamic_routes {
		pattern_parts := route.pattern.split('/').filter(it.len > 0)
		
		if path_parts.len != pattern_parts.len {
			continue
		}
		
		mut matched := true
		mut params := map[string]string{}
		mut param_idx := 0
		
		for i, part in pattern_parts {
			if part.starts_with(':') {
				//Parameter matching
				if param_idx < route.param_names.len {
					params[route.param_names[param_idx]] = path_parts[i]
					param_idx++
				}
			} else if part != path_parts[i] {
				matched = false
				break
			}
		}
		
		if matched {
			return true, params
		}
	}
	
	return false, map[string]string{}
}

// ============================================
//Benchmark function
// ============================================
struct BenchmarkResult {
	name           string
	total_time_ns  i64
	avg_time_ns    i64
	min_time_ns    i64
	max_time_ns    i64
	ops_per_sec    f64
	iterations     int
}

fn benchmark(name string, iterations int, f fn () bool) BenchmarkResult {
	mut times := []i64{cap: iterations}
	mut min_time := i64(9223372036854775807)
	mut max_time := i64(0)
	
	// preheat
	for _ in 0 .. warmup_iterations {
		f()
	}
	
	//Formal testing
	for _ in 0 .. iterations {
		sw := time.new_stopwatch()
		f()
		elapsed := sw.elapsed().nanoseconds()
		times << elapsed
		
		if elapsed < min_time {
			min_time = elapsed
		}
		if elapsed > max_time {
			max_time = elapsed
		}
	}
	
	mut total := i64(0)
	for t in times {
		total += t
	}
	
	avg := total / iterations
	ops_per_sec := 1_000_000_000.0 / f64(avg)
	
	return BenchmarkResult{
		name: name
		total_time_ns: total
		avg_time_ns: avg
		min_time_ns: min_time
		max_time_ns: max_time
		ops_per_sec: ops_per_sec
		iterations: iterations
	}
}

fn print_result(r BenchmarkResult) {
	println('┌─────────────────────────────────────────────────────────────┐')
	println('│ ${r.name:-59} │')
	println('├─────────────────────────────────────────────────────────────┤')
	println('│ 迭代次数: ${r.iterations:-48} │')
	println('│ 总耗时:   ${r.total_time_ns / 1_000_000:-45} ms │')
	println('│ 平均耗时: ${r.avg_time_ns:-45} ns │')
	println('│ 最小耗时: ${r.min_time_ns:-45} ns │')
	println('│ 最大耗时: ${r.max_time_ns:-45} ns │')
	println('│ 吞吐量:   ${r.ops_per_sec:-42.0} ops/s │')
	println('└─────────────────────────────────────────────────────────────┘')
}

fn print_comparison(name string, simple_result BenchmarkResult, hono_result BenchmarkResult) {
	speedup := f64(simple_result.avg_time_ns) / f64(hono_result.avg_time_ns)
	winner := if speedup > 1.0 { 'vono' } else { 'SimpleRouter' }
	ratio := if speedup > 1.0 { speedup } else { 1.0 / speedup }
	
	println('')
	println('═══════════════════════════════════════════════════════════════')
	println(' ${name} 对比结果')
	println('═══════════════════════════════════════════════════════════════')
	println(' SimpleRouter: ${simple_result.avg_time_ns} ns/op (${simple_result.ops_per_sec:.0} ops/s)')
	println(' vono:       ${hono_result.avg_time_ns} ns/op (${hono_result.ops_per_sec:.0} ops/s)')
	println(' 胜出:         ${winner} (快 ${ratio:.2}x)')
	println('═══════════════════════════════════════════════════════════════')
}

// ============================================
// Main test function
// ============================================
fn main() {
	println('')
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║         veb vs vono 路由性能对比测试                        ║')
	println('║         (SimpleRouter 模拟 veb 的路由匹配方式)                ║')
	println('╠═══════════════════════════════════════════════════════════════╣')
	println('║ 测试配置:                                                     ║')
	println('║   - 迭代次数: ${iterations:-46} ║')
	println('║   - 预热次数: ${warmup_iterations:-46} ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
	println('')
	
	//Initialize SimpleRouter
	mut simple_router := SimpleRouter.new()
	simple_router.add_static('/')
	simple_router.add_static('/api/health')
	simple_router.add_static('/api/users')
	simple_router.add_dynamic('/api/users/:id', ['id'])
	simple_router.add_dynamic('/api/users/:id/posts', ['id'])
	simple_router.add_dynamic('/api/users/:user_id/posts/:post_id', ['user_id', 'post_id'])
	simple_router.add_dynamic('/api/categories/:cat/items/:item', ['cat', 'item'])
	
	//Initialize vono
	mut hono_app := hono.Hono.new()
	hono_app.get('/', fn (mut c hono.Context) http.Response {
		return c.text('Hello World')
	})
	hono_app.get('/api/health', fn (mut c hono.Context) http.Response {
		return c.text('OK')
	})
	hono_app.get('/api/users', fn (mut c hono.Context) http.Response {
		return c.json('{"users": []}')
	})
	hono_app.get('/api/users/:id', fn (mut c hono.Context) http.Response {
		return c.json('{"id": "123"}')
	})
	hono_app.get('/api/users/:id/posts', fn (mut c hono.Context) http.Response {
		return c.json('{"posts": []}')
	})
	hono_app.get('/api/users/:user_id/posts/:post_id', fn (mut c hono.Context) http.Response {
		return c.json('{"post": {}}')
	})
	hono_app.get('/api/categories/:cat/items/:item', fn (mut c hono.Context) http.Response {
		return c.json('{"item": {}}')
	})
	
	// ============================================
	//Test 1: Static routing performance
	// ============================================
	println('\n【测试 1】静态路由匹配性能')
	println('─────────────────────────────────────────────────────────────────')
	
	simple_static_result := benchmark('SimpleRouter 静态路由', iterations, fn [simple_router] () bool {
		for path in static_paths {
			simple_router.match_route(path)
		}
		return true
	})
	print_result(simple_static_result)
	
	hono_static_result := benchmark('vono 静态路由', iterations, fn [mut hono_app] () bool {
		for path in static_paths {
			hono_app.fast_router.match_route('GET', path) or { continue }
		}
		return true
	})
	print_result(hono_static_result)
	
	print_comparison('静态路由', simple_static_result, hono_static_result)
	
	// ============================================
	//Test 2: Dynamic routing performance
	// ============================================
	println('\n【测试 2】动态路由匹配性能')
	println('─────────────────────────────────────────────────────────────────')
	
	simple_dynamic_result := benchmark('SimpleRouter 动态路由', iterations, fn [simple_router] () bool {
		for path in dynamic_paths {
			simple_router.match_route(path)
		}
		return true
	})
	print_result(simple_dynamic_result)
	
	hono_dynamic_result := benchmark('vono 动态路由', iterations, fn [mut hono_app] () bool {
		for path in dynamic_paths {
			hono_app.fast_router.match_route('GET', path) or { continue }
		}
		return true
	})
	print_result(hono_dynamic_result)
	
	print_comparison('动态路由', simple_dynamic_result, hono_dynamic_result)
	
	// ============================================
	// Test 3: Hybrid routing performance
	// ============================================
	println('\n【测试 3】混合路由匹配性能（静态 + 动态）')
	println('─────────────────────────────────────────────────────────────────')
	
	mut all_paths := []string{}
	all_paths << static_paths
	all_paths << dynamic_paths
	
	simple_mixed_result := benchmark('SimpleRouter 混合路由', iterations, fn [simple_router, all_paths] () bool {
		for path in all_paths {
			simple_router.match_route(path)
		}
		return true
	})
	print_result(simple_mixed_result)
	
	hono_mixed_result := benchmark('vono 混合路由', iterations, fn [mut hono_app, all_paths] () bool {
		for path in all_paths {
			hono_app.fast_router.match_route('GET', path) or { continue }
		}
		return true
	})
	print_result(hono_mixed_result)
	
	print_comparison('混合路由', simple_mixed_result, hono_mixed_result)
	
	// ============================================
	// Router statistics
	// ============================================
	println('\n【路由器统计信息】')
	println('─────────────────────────────────────────────────────────────────')
	
	static_count, dynamic_count, cache_count, _ := hono_app.get_router_stats()
	println('vono FastRouter:')
	println('  - 静态路由数: ${static_count}')
	println('  - 动态路由数: ${dynamic_count}')
	println('  - 缓存条目数: ${cache_count}')
	
	println('')
	println('SimpleRouter:')
	println('  - 静态路由数: ${simple_router.static_routes.len}')
	println('  - 动态路由数: ${simple_router.dynamic_routes.len}')
	
	// ============================================
	// Summarize
	// ============================================
	println('\n')
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║                        测试总结                               ║')
	println('╠═══════════════════════════════════════════════════════════════╣')
	println('║ 1. 静态路由: SimpleRouter 使用 map 直接查找，通常更快        ║')
	println('║ 2. 动态路由: vono 使用 Trie + 缓存，性能更稳定             ║')
	println('║ 3. vono 的优势在于动态路由性能一致，不随复杂度增加而下降   ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
}
