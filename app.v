module hono

import net.urllib
import net.http
import time

// Context router
struct ContextRouter {
mut:
	handlers struct {
	mut:
		get     []IHandler
		post    []IHandler
		put     []IHandler
		delete  []IHandler
		patch   []IHandler
		head    []IHandler
		options []IHandler
	}
}

// NotFound processor type
pub type NotFoundHandler = fn (mut c Context) http.Response

// Error handler type - use simple error messages and status codes
pub type ErrorHandler = fn (error_msg string, status_code int, mut c Context) http.Response

pub struct Hono {
mut:
	server            http.Server     = http.Server{}
	routes            map[string]Hono = {}
	base_path         string
	not_found_handler ?NotFoundHandler // Custom 404 handler
	error_handler     ?ErrorHandler    // Custom error handler
pub mut:
	context_router        ContextRouter = ContextRouter{}
	context_hybrid_router ContextHybridRouter
	context_trie_router   ContextTrieRouter
	fast_router           FastRouter // New: Fast Router
	use_fast_router       bool = true // New: whether to use fast router
	context_middlewares   []ContextMiddleware
	route_middlewares     map[string][]ContextMiddleware // Middleware corresponding to the routing prefix
	// Optimization: Pre-sorted middleware prefix list (calculated once at startup)
	sorted_middleware_prefixes []string
	// Optimization: Mark whether there is middleware (for zero middleware fast path)
	has_middlewares bool
}

// Context middleware type
type ContextMiddleware = fn (mut c Context, next fn (mut Context) http.Response) http.Response

// Context interface method
pub fn (mut app Hono) get(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{
		path:    path
		handler: handler
	}

	// Add to fast router
	if app.use_fast_router {
		app.fast_router.add_route('GET', h, '') or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('GET', h, '')
		}
	} else {
		app.context_hybrid_router.add_route('GET', h, '')
	}

	app.context_trie_router.add_route('GET', path, h)
	app.context_router.handlers.get << h
}

pub fn (mut app Hono) post(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{
		path:    path
		handler: handler
	}

	// Add to fast router
	if app.use_fast_router {
		app.fast_router.add_route('POST', h, '') or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('POST', h, '')
		}
	} else {
		app.context_hybrid_router.add_route('POST', h, '')
	}

	app.context_trie_router.add_route('POST', path, h)
	app.context_router.handlers.post << h
}

pub fn (mut app Hono) put(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}

	// Add to fast router
	if app.use_fast_router {
		app.fast_router.add_route('PUT', h, app.base_path) or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('PUT', h, app.base_path)
		}
	} else {
		app.context_hybrid_router.add_route('PUT', h, app.base_path)
	}

	app.context_router.handlers.put << h
	app.context_trie_router.add_route('PUT', path, h)
}

pub fn (mut app Hono) delete(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}

	// Add to fast router
	if app.use_fast_router {
		app.fast_router.add_route('DELETE', h, app.base_path) or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('DELETE', h, app.base_path)
		}
	} else {
		app.context_hybrid_router.add_route('DELETE', h, app.base_path)
	}

	app.context_router.handlers.delete << h
	app.context_trie_router.add_route('DELETE', path, h)
}

pub fn (mut app Hono) patch(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}

	// Add to fast router
	if app.use_fast_router {
		app.fast_router.add_route('PATCH', h, app.base_path) or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('PATCH', h, app.base_path)
		}
	} else {
		app.context_hybrid_router.add_route('PATCH', h, app.base_path)
	}

	app.context_router.handlers.patch << h
	app.context_trie_router.add_route('PATCH', path, h)
}

pub fn (mut app Hono) head(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}

	// Add to fast router
	if app.use_fast_router {
		app.fast_router.add_route('HEAD', h, app.base_path) or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('HEAD', h, app.base_path)
		}
	} else {
		app.context_hybrid_router.add_route('HEAD', h, app.base_path)
	}

	app.context_router.handlers.head << h
	app.context_trie_router.add_route('HEAD', path, h)
}

pub fn (mut app Hono) options(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}

	// Add to fast router
	if app.use_fast_router {
		app.fast_router.add_route('OPTIONS', h, app.base_path) or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('OPTIONS', h, app.base_path)
		}
	} else {
		app.context_hybrid_router.add_route('OPTIONS', h, app.base_path)
	}

	app.context_router.handlers.options << h
	app.context_trie_router.add_route('OPTIONS', path, h)
}

// ws() - Register a WebSocket route
// This method registers a WebSocket upgrade handler at the specified path.
// The factory function receives the HTTP Context and returns WSEvents configuration.
//
// Parameters:
//   path: The route path (supports path parameters like /ws/:room/:id)
//   factory: A function that receives the HTTP Context and returns WSEvents
//   options: Optional WebSocket configuration
//
// Example:
//   app.ws('/chat/:room', fn (c Context) WSEvents {
//       room := c.params['room'] or { 'default' }
//       return WSEvents{
//           on_open: fn (mut ws WSContext) {
//               ws.send('Welcome to room!') or {}
//           }
//           on_message: fn (event WSMessageEvent, mut ws WSContext) {
//               ws.send('Echo: ${event.data}') or {}
//           }
//       }
//   })
pub fn (mut app Hono) ws(path string, factory WSHandlerFactory, options ...WebSocketOptions) {
	// Create the WebSocket upgrade handler
	ws_handler := upgrade_websocket(factory, ...options)

	// Register as a GET route (WebSocket upgrades use GET method)
	app.get(path, ws_handler)
}

// all() method - registers the same handler for all HTTP methods
pub fn (mut app Hono) all(path string, handler fn (mut Context) http.Response) {
	app.get(path, handler)
	app.post(path, handler)
	app.put(path, handler)
	app.delete(path, handler)
	app.patch(path, handler)
	app.head(path, handler)
	app.options(path, handler)
}

// Context middleware
pub fn (mut app Hono) use(mw ContextMiddleware) {
	app.context_middlewares << mw
	app.has_middlewares = true
}

// Precomputed middleware prefix sorting (called before server startup)
pub fn (mut app Hono) precompute_middleware_prefixes() {
	app.sorted_middleware_prefixes = app.route_middlewares.keys()
	app.sorted_middleware_prefixes.sort(a.len < b.len)
	app.has_middlewares = app.context_middlewares.len > 0 || app.route_middlewares.len > 0
}

// notFound() - Custom 404 handler
pub fn (mut app Hono) not_found(handler NotFoundHandler) {
	app.not_found_handler = handler
}

// onError() - custom error handler
pub fn (mut app Hono) on_error(handler ErrorHandler) {
	app.error_handler = handler
}

struct ServerHanler {
mut:
	app Hono
}

fn server_hanler_new(app Hono) ServerHanler {
	return ServerHanler{
		app: app
	}
}

fn (mut s ServerHanler) handle(req http.Request) http.Response {
	url := urllib.parse(req.url) or {
		urllib.URL{
			path: '/'
		}
	}

	// Parse query - Optimization: Use url.raw_query directly to avoid additional parsing
	mut query_map := map[string]string{}
	if url.raw_query.len > 0 {
		query_map = parse_query_string_app(url.raw_query)
	}

	// Cache method string to avoid multiple calls to .str()
	method_str := req.method.str()

	// Try Context routing
	// Prioritize using fast routers
	if s.app.use_fast_router {
		if route_match := s.app.fast_router.match_route(method_str, url.path) {
			// param is provided by route matching results
			param_map := route_match.params.clone()
			// body
			body := req.data
			// Construct Context
			mut ctx := Context.new(req, param_map, query_map, body)

			// Optimization: Zero middleware fast path
			if !s.app.has_middlewares {
				return route_match.handler.handle(mut ctx)
			}

			// Get the middleware corresponding to the path
			middlewares := s.get_middlewares_for_path(url.path)
			// Onion model recursively executes middleware
			return s.exec_context_middlewares_with_list(0, middlewares, mut ctx, fn [route_match] (mut c Context) http.Response {
				return route_match.handler.handle(mut c)
			})
		}

		// If there is no match for the fast router, fall back to the hybrid router
		if route_match := s.app.context_hybrid_router.match_route(method_str, url.path) {
			// param is provided by route matching results
			param_map := route_match.params.clone()
			// body
			body := req.data
			// Construct Context
			mut ctx := Context.new(req, param_map, query_map, body)

			// Optimization: Zero middleware fast path
			if !s.app.has_middlewares {
				return route_match.handler.handle(mut ctx)
			}

			// Get the middleware corresponding to the path
			middlewares := s.get_middlewares_for_path(url.path)
			// Onion model recursively executes middleware
			return s.exec_context_middlewares_with_list(0, middlewares, mut ctx, fn [route_match] (mut c Context) http.Response {
				return route_match.handler.handle(mut c)
			})
		}
	} else {
		if route_match := s.app.context_hybrid_router.match_route(method_str, url.path) {
			// param is provided by route matching results
			param_map := route_match.params.clone()
			// body
			body := req.data
			// Construct Context
			mut ctx := Context.new(req, param_map, query_map, body)

			// Optimization: Zero middleware fast path
			if !s.app.has_middlewares {
				return route_match.handler.handle(mut ctx)
			}

			// Get the middleware corresponding to the path
			middlewares := s.get_middlewares_for_path(url.path)
			// Onion model recursively executes middleware
			return s.exec_context_middlewares_with_list(0, middlewares, mut ctx, fn [route_match] (mut c Context) http.Response {
				return route_match.handler.handle(mut c)
			})
		}
	}

	// If there is no matching route, use the notFound handler
	param_map := map[string]string{}
	body := req.data
	mut ctx := Context.new(req, param_map, query_map, body)

	// Use custom notFound handler or default 404 response
	if handler := s.app.not_found_handler {
		return s.exec_context_middlewares(0, mut ctx, handler)
	}

	// Default 404 response
	return s.exec_context_middlewares(0, mut ctx, fn (mut c Context) http.Response {
		c.status(404)
		return c.text('Not Found')
	})
}

// Get all middleware corresponding to the path (global + routing prefix matching) - optimized version
fn (s ServerHanler) get_middlewares_for_path(path string) []ContextMiddleware {
	// Optimization: When there is only global middleware, return the reference directly (avoid cloning)
	if s.app.route_middlewares.len == 0 {
		return s.app.context_middlewares
	}

	mut middlewares := s.app.context_middlewares.clone()

	// Optimization: Use pre-sorted prefix list (sorted at startup, no need to sort on every request)
	for prefix in s.app.sorted_middleware_prefixes {
		if path.starts_with(prefix) || prefix == '/' {
			if mws := s.app.route_middlewares[prefix] {
				middlewares << mws
			}
		}
	}

	return middlewares
}

// Execute using the specified middleware list
fn (mut s ServerHanler) exec_context_middlewares_with_list(idx int, middlewares []ContextMiddleware, mut ctx Context, handler fn (mut Context) http.Response) http.Response {
	if idx < middlewares.len {
		mw := middlewares[idx]
		return mw(mut ctx, fn [mut s, idx, middlewares, handler] (mut c Context) http.Response {
			return s.exec_context_middlewares_with_list(idx + 1, middlewares, mut c, handler)
		})
	} else {
		return handler(mut ctx)
	}
}

// Context version of middleware execution function
fn (mut s ServerHanler) exec_context_middlewares(idx int, mut ctx Context, handler fn (mut Context) http.Response) http.Response {
	if idx < s.app.context_middlewares.len {
		mw := s.app.context_middlewares[idx]
		return mw(mut ctx, fn [mut s, idx, handler] (mut c Context) http.Response {
			return s.exec_context_middlewares(idx + 1, mut c, handler)
		})
	} else {
		return handler(mut ctx)
	}
}

pub fn (mut app Hono) listen(port string) {
	// Parse port number
	port_num := port.trim(':').int()
	if port_num <= 0 {
		eprintln('[vono] Invalid port: ${port}')
		return
	}

	// Optimization: Precomputed middleware prefix sorting
	app.precompute_middleware_prefixes()

	// Use optimized configuration of picoev high-performance server (supports high concurrency)
	app.listen_picoev_with_config(PicoevConfig{
		port:              port_num
		timeout_secs:      120   // High concurrency scenarios require longer timeouts
		keepalive_timeout: 30    // Keep-Alive timeout 30 seconds
		max_keepalive_req: 10000 // Maximum number of requests for a single connection
	})
}

// Start using traditional http.Server (preserve compatibility)
pub fn (mut app Hono) listen_http(port string) {
	app.server.addr = port
	app.server.handler = server_hanler_new(app)
	// Add timeout configuration to support better Keep-Alive
	app.server.read_timeout = 60 * time.second
	app.server.write_timeout = 60 * time.second
	app.server.listen_and_serve()
}

pub fn (mut app Hono) route(prefix string, mut subapp Hono) {
	// Save sub-application reference
	app.routes[prefix] = subapp

	// Merge the middleware of the sub-application into the route prefix
	if subapp.context_middlewares.len > 0 {
		if prefix in app.route_middlewares {
			app.route_middlewares[prefix] << subapp.context_middlewares
		} else {
			app.route_middlewares[prefix] = subapp.context_middlewares.clone()
		}
		app.has_middlewares = true
	}

	// Inherit the notFound and onError handlers of the child application (if the main application does not set them)
	if app.not_found_handler == none && subapp.not_found_handler != none {
		// The notFound of the sub-application only takes effect on this prefix and is not inherited from the main application.
		// If necessary, you can handle it separately when the sub-application route matching fails.
	}

	// Merge the routes of the sub-application to all routers of the main application
	// Use helper functions to handle each HTTP method
	app.merge_routes_for_method('GET', prefix, subapp.context_router.handlers.get)
	app.merge_routes_for_method('POST', prefix, subapp.context_router.handlers.post)
	app.merge_routes_for_method('PUT', prefix, subapp.context_router.handlers.put)
	app.merge_routes_for_method('DELETE', prefix, subapp.context_router.handlers.delete)
	app.merge_routes_for_method('PATCH', prefix, subapp.context_router.handlers.patch)
	app.merge_routes_for_method('HEAD', prefix, subapp.context_router.handlers.head)
	app.merge_routes_for_method('OPTIONS', prefix, subapp.context_router.handlers.options)
}

// Auxiliary function: merge routes for specified HTTP methods
fn (mut app Hono) merge_routes_for_method(method string, prefix string, handlers []IHandler) {
	for handler in handlers {
		// Create new path with prefix
		mut new_path := ''
		if handler.path == '/' || handler.path == '' {
			// If the sub-route is the root path, use the prefix directly
			new_path = prefix
		} else if handler.path.starts_with('/') {
			new_path = '${prefix}${handler.path}'
		} else {
			new_path = '${prefix}/${handler.path}'
		}

		// Create a wrapper handler with a new path (implements the IHandler interface)
		new_handler := PrefixedHandler{
			path:  new_path
			inner: handler
		}

		// Create ContextHandler for trie_router
		trie_handler := ContextHandler{
			path:    new_path
			handler: fn [handler] (mut c Context) http.Response {
				return handler.handle(mut c)
			}
		}

		// Add to the corresponding handlers list
		match method {
			'GET' { app.context_router.handlers.get << new_handler }
			'POST' { app.context_router.handlers.post << new_handler }
			'PUT' { app.context_router.handlers.put << new_handler }
			'DELETE' { app.context_router.handlers.delete << new_handler }
			'PATCH' { app.context_router.handlers.patch << new_handler }
			'HEAD' { app.context_router.handlers.head << new_handler }
			'OPTIONS' { app.context_router.handlers.options << new_handler }
			else {}
		}

		// Add to fast router
		if app.use_fast_router {
			app.fast_router.add_route(method, new_handler, '') or {
				app.context_hybrid_router.add_route(method, new_handler, '')
			}
		} else {
			app.context_hybrid_router.add_route(method, new_handler, '')
		}
		app.context_trie_router.add_route(method, new_path, trie_handler)
	}
}

// Handler wrapper with prefix, implementing IHandler interface
pub struct PrefixedHandler {
pub:
	path  string
	inner IHandler
}

// Implement the handle method of the IHandler interface
pub fn (h PrefixedHandler) handle(mut c Context) http.Response {
	return h.inner.handle(mut c)
}

pub fn (mut app Hono) set_base_path(base_path string) {
	app.base_path = base_path
}

// Routing statistics
pub fn (app Hono) get_router_stats() (int, int, int, int) {
	if app.use_fast_router {
		static_count, dynamic_count, cache_count := app.fast_router.get_stats()
		return static_count, dynamic_count, cache_count, 0
	} else {
		static_paths, dynamic_paths := app.context_hybrid_router.get_all_routes()
		cache_size, cache_capacity := app.context_hybrid_router.get_cache_stats()
		return static_paths.len, dynamic_paths.len, cache_size, cache_capacity
	}
}

// clear cache
pub fn (mut app Hono) clear_cache() {
	if app.use_fast_router {
		app.fast_router.clear_cache()
	} else {
		app.context_hybrid_router.clear_cache()
	}
}

// Enable/disable fast router
pub fn (mut app Hono) set_fast_router_enabled(enabled bool) {
	app.use_fast_router = enabled
	println('[INFO] FastRouter ${if enabled { 'enabled' } else { 'disabled' }}')
}

// Get router performance analysis
pub fn (mut app Hono) analyze_router_performance() {
	if app.use_fast_router {
		app.fast_router.analyze_performance()
	} else {
		app.context_hybrid_router.analyze_router_performance()
	}
}

pub fn Hono.new() Hono {
	return Hono{
		server:                     http.Server{}
		routes:                     map[string]Hono{}
		base_path:                  ''
		not_found_handler:          none
		error_handler:              none
		context_router:             ContextRouter{}
		context_hybrid_router:      ContextHybridRouter.new()
		context_trie_router:        ContextTrieRouter.new()
		fast_router:                FastRouter.new()
		use_fast_router:            true
		route_middlewares:          map[string][]ContextMiddleware{}
		sorted_middleware_prefixes: []string{}
		has_middlewares:            false
	}
}

// ============================================================================
// OpenAPI documentation convenience methods (Task 9.1)
// ============================================================================

// doc - registers the OpenAPI document route
// Register a GET route at the specified path and return the JSON format of the OpenAPI document
// Set Content-Type: application/json
// Usage example:
//   spec := OpenAPIBuilder.new()
//       .openapi('3.0.0')
//       .title('My API')
//       .version('1.0.0')
//       .build()!
//   app.doc('/doc', spec)
pub fn (mut app Hono) doc(path string, spec OpenAPIDocument) {
	// Pre-serialize OpenAPI documents into JSON strings
	json_content := spec.to_json_str()

	// Register GET route to return JSON
	app.get(path, fn [json_content] (mut c Context) http.Response {
		return http.Response{
			status_code: 200
			header:      http.new_header(
				key:   .content_type
				value: 'application/json; charset=utf-8'
			)
			body:        json_content
		}
	})
}

// doc_fn - Register an OpenAPI document route using a builder function
// Allow lazy construction of OpenAPI documents, calling the builder function on every request
// Usage example:
//   app.doc_fn('/doc', fn () OpenAPIDocument {
//       return OpenAPIBuilder.new()
//           .openapi('3.0.0')
//           .title('My API')
//           .version('1.0.0')
//           .build() or { panic(err) }
//   })
pub fn (mut app Hono) doc_fn(path string, builder fn () OpenAPIDocument) {
	app.get(path, fn [builder] (mut c Context) http.Response {
		// Call the builder function on every request
		spec := builder()
		json_content := spec.to_json_str()

		return http.Response{
			status_code: 200
			header:      http.new_header(
				key:   .content_type
				value: 'application/json; charset=utf-8'
			)
			body:        json_content
		}
	})
}

// Quickly parse query string (single traversal, avoid split) - app.v version
@[inline]
fn parse_query_string_app(query_str string) map[string]string {
	mut query_map := map[string]string{}
	len := query_str.len

	if len == 0 {
		return query_map
	}

	mut key_start := 0
	mut key_end := -1
	mut value_start := -1

	for i := 0; i <= len; i++ {
		ch := if i < len { query_str[i] } else { `&` } // The end is treated as a separator

		if ch == `=` && key_end == -1 {
			key_end = i
			value_start = i + 1
		} else if ch == `&` {
			// Complete a key-value pair
			if key_end > key_start && value_start > 0 {
				key := query_str[key_start..key_end]
				value := if value_start < i { query_str[value_start..i] } else { '' }
				query_map[key] = value
			} else if key_end == -1 && i > key_start {
				// Only key without value
				key := query_str[key_start..i]
				query_map[key] = ''
			}
			// Reset state
			key_start = i + 1
			key_end = -1
			value_start = -1
		}
	}

	return query_map
}
