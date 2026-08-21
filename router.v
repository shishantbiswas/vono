module hono

import regex

//Routing node type
enum RouteType {
	static
	dynamic
	wildcard
}

// Compiled regular expression cache
pub struct CompiledRegex {
pub mut:
	regex       regex.RE
	param_names []string
	compiled    bool
}

// Context routing node
struct ContextRouteNode {
mut:
	path      string
	handler   IHandler
	route_type RouteType
	children  map[string]&ContextRouteNode
	param_name string
	base_path string
}

// Context route matching result
pub struct ContextRouteMatch {
pub:
	handler IHandler
	params  map[string]string
	path    string
	base_path string
}

// Context hybrid router
pub struct ContextHybridRouter {
pub mut:
	static_routes  map[string]IHandler
	dynamic_routes []IHandler
	cache          ContextLRUCache
	regex_cache    map[string]CompiledRegex  // New: Regular expression cache
}

//ContextHybridRouter constructor
pub fn ContextHybridRouter.new() ContextHybridRouter {
	return ContextHybridRouter{
		static_routes: map[string]IHandler{}
		dynamic_routes: []IHandler{}
		cache: ContextLRUCache.new(1000)
		regex_cache: map[string]CompiledRegex{}
	}
}

// Determine whether the path is a static path
fn is_static_path(path string) bool {
	return !path.contains(':') && !path.contains('*') && !path.contains('?') && !path.contains('+')
}

// Determine whether the path is a dynamic path
fn is_dynamic_path(path string) bool {
	return path.contains(':') || path.contains('*') || path.contains('?') || path.contains('+')
}

// Context version of the regular matching function (optimized version, using cache)
pub fn (mut router ContextHybridRouter) match_path_with_regex(real_path string, reg_path string) (bool, regex.RE, []string) {
	//Check cache first
	if cached := router.regex_cache[reg_path] {
		if cached.compiled {
			return cached.regex.matches_string(real_path), cached.regex, cached.param_names
		}
	}
	
	// If not in cache, compile and cache
	mut compiled_regex := CompiledRegex{}
	mut replaced_path := reg_path
	mut param_names := []string{}
	
	// Handle multiple asterisks **
	if reg_path.contains('**') {
		// Replace ** with .*
		replaced_path = reg_path.replace('**', '.*')
		mut reg := regex.regex_opt(replaced_path) or { return false, regex.RE{}, []string{} }
		compiled_regex = CompiledRegex{
			regex: reg
			param_names: []string{}
			compiled: true
		}
		router.regex_cache[reg_path] = compiled_regex
		return reg.matches_string(real_path), reg, []string{}
	}
	
	// handle single asterisk *
	if reg_path.contains('*') {
		// Replace * with [^/]*
		replaced_path = reg_path.replace('*', '[^/]*')
		mut reg := regex.regex_opt(replaced_path) or { return false, regex.RE{}, []string{} }
		compiled_regex = CompiledRegex{
			regex: reg
			param_names: []string{}
			compiled: true
		}
		router.regex_cache[reg_path] = compiled_regex
		return reg.matches_string(real_path), reg, []string{}
	}
	
	// Processing parameters :param
	if reg_path.contains(':') {
		//Pre-extract parameter names (to avoid repeated extraction during matching)
		mut param_reg := regex.regex_opt(r':[a-zA-Z_][a-zA-Z0-9_]*') or { return false, regex.RE{}, []string{} }
		all_params := param_reg.find_all_str(reg_path)
		for param in all_params {
			param_names << param[1..]  //remove colon
		}
		
		//Escape special characters in batches (reduce multiple replace calls)
		special_chars := ['?', '+', '.', '(', ')', '[', ']', '{', '}', '^', '$', '|']
		for ch in special_chars {
			replaced_path = replaced_path.replace(ch, '\\${ch}')
		}
		
		//Replace parameters with named capture groups
		replaced_path = param_reg.replace_by_fn(replaced_path, fn (re regex.RE, in_txt string, start int, end int) string {
			param_name := in_txt[start+1..end]
			return '(?P<${param_name}>[^/]+)'
		})
		
		//Add anchor point
		replaced_path = '^${replaced_path}$'
		
		//Compile regular expression
		mut reg := regex.regex_opt(replaced_path) or { return false, regex.RE{}, []string{} }
		
		//Cache compilation results
		compiled_regex = CompiledRegex{
			regex: reg
			param_names: param_names
			compiled: true
		}
		router.regex_cache[reg_path] = compiled_regex
		
		return reg.matches_string(real_path), reg, param_names
	}
	
	return false, regex.RE{}, []string{}
}

//Add Context route
pub fn (mut router ContextHybridRouter) add_route(method string, handler IHandler, base_path string) {
	full_path := handler.path
	if is_static_path(full_path) {
		router.static_routes['${method}:${full_path}'] = handler
	} else {
		router.dynamic_routes << handler
		// Sort by routing complexity, simple routes will be matched first
		router.sort_dynamic_routes()
	}
}

// Sort dynamic routes by routing complexity (simple routes first)
fn (mut router ContextHybridRouter) sort_dynamic_routes() {
	router.dynamic_routes.sort_with_compare(fn (a &IHandler, b &IHandler) int {
		// Calculate the routing complexity score (the lower the score, the simpler, priority is given to matching)
		score_a := calculate_route_complexity(a.path)
		score_b := calculate_route_complexity(b.path)
		
		if score_a < score_b {
			return -1
		} else if score_a > score_b {
			return 1
		}
		return 0
	})
}

// Calculate routing complexity score
fn calculate_route_complexity(path string) int {
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

//Context version of static path matching
pub fn (router ContextHybridRouter) match_static_route(method string, path string) ?IHandler {
	key := '${method}:${path}'
	if key in router.static_routes {
		return router.static_routes[key]
	}
	return none
}

//Context version of dynamic path matching (retaining compatibility with old versions)
fn (mut router ContextHybridRouter) match_dynamic_route(method string, path string) ?ContextRouteMatch {
	cache_key := '${method}:${path}'
	return router.match_dynamic_route_with_key(cache_key, method, path)
}

// Context version of the main matching function (optimized version: reuse cache key)
pub fn (mut router ContextHybridRouter) match_route(method string, path string) ?ContextRouteMatch {
	// Optimization: only splice cache key once
	cache_key := '${method}:${path}'
	
	// 1. Try static path matching first (fastest)
	if cache_key in router.static_routes {
		return ContextRouteMatch{
			handler: router.static_routes[cache_key]
			params: map[string]string{}
			path: path
			base_path: ''
		}
	}
	
	// 2. Try dynamic path matching again (reuse cache_key)
	return router.match_dynamic_route_with_key(cache_key, method, path)
}

//Context version of dynamic path matching (optimized version: receiving precomputed cache_key)
fn (mut router ContextHybridRouter) match_dynamic_route_with_key(cache_key string, method string, path string) ?ContextRouteMatch {
	//Check cache first
	if cached := router.cache.get(cache_key) {
		return cached
	}
	
	for handler in router.dynamic_routes {
		match_result, replaced_path_reg, param_names := router.match_path_with_regex(path, handler.path)
		if match_result {
			mut param_map := map[string]string{}
			
			// Directly use compiled regular expressions and cached parameter names
			for param_name in param_names {
				group := replaced_path_reg.get_group_by_name(path, param_name)
				param_map[param_name] = group
			}
			
			route_match := ContextRouteMatch{
				handler: handler
				params: param_map
				path: handler.path
				base_path: ''
			}
			router.cache.put(cache_key, route_match)
			return route_match
		}
	}
	return none
}

//Context version gets all routes
pub fn (router ContextHybridRouter) get_all_routes() ([]string, []string) {
	mut static_paths := []string{}
	mut dynamic_paths := []string{}
	
	for key in router.static_routes.keys() {
		static_paths << key
	}
	
	for handler in router.dynamic_routes {
		dynamic_paths << handler.path
	}
	
	return static_paths, dynamic_paths
}

// Get cache statistics
pub fn (router ContextHybridRouter) get_cache_stats() (int, int) {
	return router.cache.get_stats()
}

// clear cache
pub fn (mut router ContextHybridRouter) clear_cache() {
	router.cache.clear()
}

// Get regular expression cache statistics
pub fn (router ContextHybridRouter) get_regex_cache_stats() (int, int) {
	mut compiled_count := 0
	for _, cached_regex in router.regex_cache {
		if cached_regex.compiled {
			compiled_count++
		}
	}
	return router.regex_cache.len, compiled_count
}

// Clear the regular expression cache
pub fn (mut router ContextHybridRouter) clear_regex_cache() {
	router.regex_cache.clear()
}

// Warm up regular expression cache
pub fn (mut router ContextHybridRouter) warmup_regex_cache() {
	println('[INFO] Warming up regex cache...')
	mut warmed_count := 0
	
	for handler in router.dynamic_routes {
		if handler.path.contains(':') || handler.path.contains('*') {
			// Precompile regular expressions for dynamic routing
			router.match_path_with_regex('/dummy/path', handler.path)
			warmed_count++
		}
	}
	
	total_cached, compiled_cached := router.get_regex_cache_stats()
	println('[INFO] Regex cache warmup completed: ${warmed_count} patterns warmed, ${compiled_cached}/${total_cached} compiled')
}

// Routing performance analysis
pub fn (router ContextHybridRouter) analyze_router_performance() {
	cache_size, cache_hits := router.get_cache_stats()
	regex_total, regex_compiled := router.get_regex_cache_stats()
	
	println('[PERFORMANCE] Router Analysis:')
	println('  Static Routes: ${router.static_routes.len}')
	println('  Dynamic Routes: ${router.dynamic_routes.len}')
	println('  Route Cache: ${cache_hits}/${cache_size} hits')
	println('  Regex Cache: ${regex_compiled}/${regex_total} compiled')
}

 