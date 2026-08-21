import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== 路由正则表达式缓存优化测试 ===')
	
	//Test 1: Regular expression caching effect
	test_regex_cache_performance()
	
	//Test 2: Cache warm-up effect
	test_cache_warmup()
	
	//Test 3: Performance Analysis
	test_performance_analysis()
	
	println('✅ 路由正则表达式缓存测试完成')
}

fn test_regex_cache_performance() {
	println('\n📊 测试正则表达式缓存性能...')
	
	mut router := hono.ContextHybridRouter.new()
	
	//Add some dynamic routing
	dynamic_routes := [
		'/users/:id',
		'/posts/:post_id/comments/:comment_id',
		'/api/v1/users/:user_id/posts/:post_id',
		'/files/:category/:filename',
		'/search/*query',
		'/admin/users/:id/settings',
		'/api/v2/projects/:project_id/tasks/:task_id'
	]
	
	for route in dynamic_routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	println('  添加了${dynamic_routes.len}个动态路由')
	
	// test path
	test_paths := [
		'/users/123',
		'/posts/456/comments/789',
		'/api/v1/users/101/posts/202',
		'/files/images/photo.jpg',
		'/search/test-query',
		'/admin/users/555/settings',
		'/api/v2/projects/777/tasks/888'
	]
	
	// First match (compiled regular expression)
	start_time1 := time.now()
	mut first_matches := 0
	for _ in 0 .. 1000 {
		for path in test_paths {
			if _ := router.match_route('GET', path) {
				first_matches++
			}
		}
	}
	first_run_time := time.since(start_time1)
	
	// Second match (using cached regular expression)
	start_time2 := time.now()
	mut second_matches := 0
	for _ in 0 .. 1000 {
		for path in test_paths {
			if _ := router.match_route('GET', path) {
				second_matches++
			}
		}
	}
	second_run_time := time.since(start_time2)
	
	println('  第一次运行 (1000次 × ${test_paths.len}路径): ${first_run_time}')
	println('  第二次运行 (1000次 × ${test_paths.len}路径): ${second_run_time}')
	println('  第一次匹配: ${first_matches}')
	println('  第二次匹配: ${second_matches}')
	
	if first_run_time.milliseconds() > 0 && second_run_time.milliseconds() > 0 {
		improvement := f64(first_run_time.milliseconds()) / f64(second_run_time.milliseconds())
		println('  缓存性能提升: ${improvement:.2f}x')
	}
	
	println('  正则缓存优化已启用')
}

fn test_cache_warmup() {
	println('\n📊 测试缓存预热效果...')
	
	mut router := hono.ContextHybridRouter.new()
	
	//Add dynamic route
	for i in 0 .. 10 {
		route := '/api/v${i}/items/:id'
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	println('  添加了10个动态路由')
	
	//Perform warm-up
	router.warmup_regex_cache()
	
	println('  ✅ 预热完成')
}

fn test_performance_analysis() {
	println('\n📊 测试性能分析功能...')
	
	mut router := hono.ContextHybridRouter.new()
	
	//Add static route
	static_routes := ['/api/health', '/api/status', '/api/info']
	for route in static_routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('static')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	//Add dynamic route
	dynamic_routes := ['/users/:id', '/posts/:id/comments', '/files/:category/:name']
	for route in dynamic_routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('dynamic')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	//Perform some matching operations
	test_paths := ['/api/health', '/users/123', '/posts/456/comments', '/files/docs/readme.txt']
	for _ in 0 .. 100 {
		for path in test_paths {
			router.match_route('GET', path)
		}
	}
	
	//Display performance analysis
	router.analyze_router_performance()
}