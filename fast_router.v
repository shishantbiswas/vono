module hono

import regex

// Precompile routing entries
pub struct PrecompiledRoute {
pub:
	method      string
	pattern     string
	regex       regex.RE
	param_names []string
	handler     IHandler
	complexity  int  // Routing complexity score
}

// Compiled regular expression cache
pub struct FastCompiledRegex {
pub mut:
	regex       regex.RE
	param_names []string
	compiled    bool
}

// Fast router (enhanced version)
pub struct FastRouter {
pub mut:
	static_routes        map[string]IHandler
	static_route_results map[string]ContextRouteMatch  // Pre-allocated static routing results
	precompiled_routes   []PrecompiledRoute
	fast_cache           FastRouteCache       // Use high-performance cache instead of LRU
	lru_cache            ContextLRUCache      // Keep LRU cache for compatibility
	regex_cache          map[string]FastCompiledRegex  //Regular expression cache
	cache_enabled        bool = true
	sort_enabled         bool = true          // Whether to enable route sorting
	use_fast_cache       bool = true          // Whether to use high-performance cache
}

//Create a fast router
pub fn FastRouter.new() FastRouter {
	return FastRouter{
		static_routes: map[string]IHandler{}
		static_route_results: map[string]ContextRouteMatch{}
		precompiled_routes: []PrecompiledRoute{}
		fast_cache: FastRouteCache.new(10000)  // High-performance cache, 10,000 items
		lru_cache: ContextLRUCache.new(1000)   // LRU cache remains compatible
		regex_cache: map[string]FastCompiledRegex{}
		use_fast_cache: true
	}
}

// Create a fast router with custom cache size
pub fn FastRouter.new_with_cache_size(cache_size int) FastRouter {
	return FastRouter{
		static_routes: map[string]IHandler{}
		static_route_results: map[string]ContextRouteMatch{}
		precompiled_routes: []PrecompiledRoute{}
		fast_cache: FastRouteCache.new(cache_size * 10)  // High performance caching
		lru_cache: ContextLRUCache.new(cache_size)
		regex_cache: map[string]FastCompiledRegex{}
		use_fast_cache: true
	}
}

//Add route (precompiled)
pub fn (mut router FastRouter) add_route(method string, handler IHandler, base_path string) ! {
	full_path := handler.path
	
	//Static routes are stored directly and matching results are pre-allocated
	if !full_path.contains(':') && !full_path.contains('*') {
		key := '${method}:${full_path}'
		router.static_routes[key] = handler
		// Pre-allocate matching results to avoid creating new objects every time you query
		router.static_route_results[key] = ContextRouteMatch{
			handler: handler
			params: map[string]string{}
			path: full_path
			base_path: ''
		}
		return
	}
	
	//Dynamic routing precompilation
	compiled_route := router.precompile_route(method, handler) or {
		return error('Failed to precompile route ${full_path}: ${err}')
	}
	
	router.precompiled_routes << compiled_route
	
	// If sorting is enabled, sort by complexity
	if router.sort_enabled {
		router.sort_dynamic_routes()
	}
}

// Sort dynamic routes by routing complexity (simple routes first)
fn (mut router FastRouter) sort_dynamic_routes() {
	router.precompiled_routes.sort_with_compare(fn (a &PrecompiledRoute, b &PrecompiledRoute) int {
		if a.complexity < b.complexity {
			return -1
		} else if a.complexity > b.complexity {
			return 1
		}
		return 0
	})
}

// Calculate routing complexity score (FastRouter version)
fn calculate_fast_route_complexity(path string) int {
	mut score := 0
	
	// Number of parameters (+10 points for each parameter)
	score += path.count(':') * 10
	
	// Wildcards (+20 points for each wildcard)
	score += path.count('*') * 20
	
	//Number of path segments (+1 point for each segment)
	score += path.split('/').len
	
	// Special characters (+5 points each)
	special_chars := ['?', '+', '.', '(', ')', '[', ']', '{', '}', '^', '$', '|']
	for ch in special_chars {
		score += path.count(ch) * 5
	}
	
	return score
}

// Precompile routing
fn (router FastRouter) precompile_route(method string, handler IHandler) !PrecompiledRoute {
	route_path := handler.path
	
	// Calculate routing complexity
	complexity := calculate_fast_route_complexity(route_path)
	
	//Extract parameter name
	mut param_names := []string{}
	mut param_reg := regex.regex_opt(r':[a-zA-Z_][a-zA-Z0-9_]*') or {
		return error('Failed to create param regex')
	}
	
	all_params := param_reg.find_all_str(route_path)
	for param in all_params {
		param_names << param[1..]  //remove colon
	}
	
	// Build regular expression
	mut regex_pattern := route_path
	
	//Escape special characters
	special_chars := ['?', '+', '.', '(', ')', '[', ']', '{', '}', '^', '$', '|']
	for ch in special_chars {
		regex_pattern = regex_pattern.replace(ch, '\\${ch}')
	}
	
	//Replace parameters with named capture groups
	regex_pattern = param_reg.replace_by_fn(regex_pattern, fn (re regex.RE, in_txt string, start int, end int) string {
		param_name := in_txt[start+1..end]
		return '(?P<${param_name}>[^/]+)'
	})
	
	//Add anchor point
	regex_pattern = '^${regex_pattern}$'
	
	//Compile regular expression
	compiled_regex := regex.regex_opt(regex_pattern) or {
		return error('Failed to compile regex: ${regex_pattern}')
	}
	
	return PrecompiledRoute{
		method: method
		pattern: route_path
		regex: compiled_regex
		param_names: param_names
		handler: handler
		complexity: complexity
	}
}

// Fast route matching (optimized version: static route skip caching + pre-allocated results + high-performance caching)
pub fn (mut router FastRouter) match_route(method string, path string) ?ContextRouteMatch {
	// Optimization: only splice the cache key once and reuse it for static routing and cache lookup
	cache_key := '${method}:${path}'
	
	// 1. Static routing directly returns pre-allocated results (zero allocation)
	if result := router.static_route_results[cache_key] {
		return result
	}
	
	// 2. Dynamic routing first checks the high-performance cache (zero-overhead search)
	if router.cache_enabled && router.use_fast_cache {
		if cached := router.fast_cache.get(cache_key) {
			return cached
		}
	} else if router.cache_enabled {
		// Fallback to LRU cache
		if cached := router.lru_cache.get(cache_key) {
			return cached
		}
	}
	
	// 3. Precompiled dynamic route matching (sorted by complexity)
	for route in router.precompiled_routes {
		if route.method != method {
			continue
		}
		
		if route.regex.matches_string(path) {
			//Extract parameters
			mut params := map[string]string{}
			for param_name in route.param_names {
				group := route.regex.get_group_by_name(path, param_name)
				params[param_name] = group
			}
			
			result := ContextRouteMatch{
				handler: route.handler
				params: params
				path: route.pattern
				base_path: ''
			}
			
			//Cache dynamic routing results
			if router.cache_enabled {
				if router.use_fast_cache {
					router.fast_cache.put(cache_key, result)
				} else {
					router.lru_cache.put(cache_key, result)
				}
			}
			
			return result
		}
	}
	
	return none
}

// Get routing statistics
pub fn (router FastRouter) get_stats() (int, int, int) {
	cache_size, _ := router.lru_cache.get_stats()
	return router.static_routes.len, router.precompiled_routes.len, cache_size
}

// Get detailed statistics
pub fn (mut router FastRouter) get_detailed_stats() map[string]i64 {
	cache_stats := router.lru_cache.get_detailed_stats()
	
	mut regex_compiled := 0
	for _, cached_regex in router.regex_cache {
		if cached_regex.compiled {
			regex_compiled++
		}
	}
	
	mut stats := map[string]i64{}
	stats['static_routes'] = i64(router.static_routes.len)
	stats['dynamic_routes'] = i64(router.precompiled_routes.len)
	stats['regex_cache_total'] = i64(router.regex_cache.len)
	stats['regex_cache_compiled'] = i64(regex_compiled)
	stats['cache_enabled'] = if router.cache_enabled { 1 } else { 0 }
	stats['sort_enabled'] = if router.sort_enabled { 1 } else { 0 }
	
	// Merge LRU cache statistics
	for key, value in cache_stats {
		stats['lru_${key}'] = value
	}
	
	return stats
}

// Get cache statistics
pub fn (router FastRouter) get_cache_stats() (int, int) {
	return router.lru_cache.get_stats()
}

// Get regular expression cache statistics
pub fn (router FastRouter) get_regex_cache_stats() (int, int) {
	mut compiled_count := 0
	for _, cached_regex in router.regex_cache {
		if cached_regex.compiled {
			compiled_count++
		}
	}
	return router.regex_cache.len, compiled_count
}

// clear cache
pub fn (mut router FastRouter) clear_cache() {
	router.lru_cache.clear()
}

// Clear the regular expression cache
pub fn (mut router FastRouter) clear_regex_cache() {
	router.regex_cache.clear()
}

//Force clear expired cache
pub fn (mut router FastRouter) force_cleanup_expired() {
	router.lru_cache.force_cleanup_expired()
}

// Enable/disable cache
pub fn (mut router FastRouter) set_cache_enabled(enabled bool) {
	router.cache_enabled = enabled
	if !enabled {
		router.clear_cache()
	}
}

// Enable/disable route sorting
pub fn (mut router FastRouter) set_sort_enabled(enabled bool) {
	router.sort_enabled = enabled
	if enabled {
		router.sort_dynamic_routes()
	}
}

//Set cache TTL
pub fn (mut router FastRouter) set_cache_ttl(ttl_seconds i64) {
	router.lru_cache.set_ttl(ttl_seconds)
}

//Set cache cleaning interval
pub fn (mut router FastRouter) set_cache_cleanup_interval(interval_seconds i64) {
	router.lru_cache.set_cleanup_interval(interval_seconds)
}

// Check router health status
pub fn (mut router FastRouter) is_healthy() bool {
	return router.lru_cache.is_healthy()
}

// Warm up cache
pub fn (mut router FastRouter) warmup_cache(common_paths []string, method string) {
	if !router.cache_enabled {
		return
	}
	
	for path in common_paths {
		router.match_route(method, path)
	}
}

// Warm up regular expression cache
pub fn (mut router FastRouter) warmup_regex_cache() {
	println('[INFO] Warming up FastRouter regex cache...')
	warmed_count := router.precompiled_routes.len
	
	// Precompiled routes already have compiled regular expressions
	// Some preheating operations can be performed here
	
	println('[INFO] FastRouter regex cache warmup completed: ${warmed_count} patterns ready')
}

// Intelligent preheating (based on routing complexity)
pub fn (mut router FastRouter) smart_warmup(sample_paths []string) {
	if !router.cache_enabled {
		return
	}
	
	println('[INFO] Starting smart warmup for FastRouter...')
	
	// Preheat by complexity group
	mut simple_routes := []string{}
	mut complex_routes := []string{}
	
	for route in router.precompiled_routes {
		if route.complexity <= 20 {
			simple_routes << route.pattern
		} else {
			complex_routes << route.pattern
		}
	}
	
	// Preheat simple routing first
	for path in sample_paths {
		router.match_route('GET', path)
	}
	
	println('[INFO] Smart warmup completed: ${simple_routes.len} simple, ${complex_routes.len} complex routes')
}

// Get all routes
pub fn (router FastRouter) get_all_routes() ([]string, []string) {
	mut static_paths := []string{}
	mut dynamic_paths := []string{}
	
	for key in router.static_routes.keys() {
		static_paths << key
	}
	
	for route in router.precompiled_routes {
		dynamic_paths << '${route.method}:${route.pattern} (complexity: ${route.complexity})'
	}
	
	return static_paths, dynamic_paths
}

// Get routes grouped by complexity
pub fn (router FastRouter) get_routes_by_complexity() ([]PrecompiledRoute, []PrecompiledRoute) {
	mut simple_routes := []PrecompiledRoute{}
	mut complex_routes := []PrecompiledRoute{}
	
	for route in router.precompiled_routes {
		if route.complexity <= 30 {
			simple_routes << route
		} else {
			complex_routes << route
		}
	}
	
	return simple_routes, complex_routes
}

//Performance analysis
pub fn (mut router FastRouter) analyze_performance() {
	static_count, dynamic_count, cache_count := router.get_stats()
	regex_total, regex_compiled := router.get_regex_cache_stats()
	
	println('[ENHANCED FAST ROUTER] Performance Analysis:')
	println('  Static Routes: ${static_count}')
	println('  Precompiled Dynamic Routes: ${dynamic_count}')
	println('  LRU Cache Size: ${cache_count}')
	println('  Regex Cache: ${regex_compiled}/${regex_total} compiled')
	println('  Cache Enabled: ${router.cache_enabled}')
	println('  Sort Enabled: ${router.sort_enabled}')
	
	//Display routing complexity distribution
	simple_routes, complex_routes := router.get_routes_by_complexity()
	println('  Route Complexity Distribution:')
	println('    Simple Routes (≤30): ${simple_routes.len}')
	println('    Complex Routes (>30): ${complex_routes.len}')
	
	//Display cache health status
	if router.is_healthy() {
		println('  Cache Health: ✅ Healthy')
	} else {
		println('  Cache Health: ⚠️  Issues detected')
	}
	
	// Show detailed statistics
	detailed_stats := router.get_detailed_stats()
	println('  Detailed Stats:')
	for key, value in detailed_stats {
		println('    ${key}: ${value}')
	}
}