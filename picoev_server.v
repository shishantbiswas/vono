module hono

import net
import net.http
import picoev
import picohttpparser

// picoev server configuration
pub struct PicoevConfig {
pub:
	port              int            = 8080
	host              string
	family            net.AddrFamily = .ip6
	timeout_secs      int            = 120    //High concurrency scenarios require longer timeout (original 8 seconds is too short)
	max_headers       int            = 100
	max_read          int            = 8192
	max_write         int            = 65536
	keepalive_timeout int            = 30     // Keep-Alive timeout extended to 30 seconds
	max_keepalive_req int            = 10000  //The maximum number of requests for a single connection is increased to 10000
}

// picoev request context
struct PicoevRequestContext {
mut:
	app    &Hono = unsafe { nil }
	config PicoevConfig
}

// Start the server using picoev
pub fn (mut app Hono) listen_picoev(port int) {
	app.listen_picoev_with_config(PicoevConfig{
		port: port
	})
}

// Start the server using picoev (with configuration)
pub fn (mut app Hono) listen_picoev_with_config(config PicoevConfig) {
	mut ctx := &PicoevRequestContext{
		app: unsafe { &app }
		config: config
	}
	
	mut pico := picoev.new(
		port: config.port
		host: config.host
		family: config.family
		timeout_secs: config.timeout_secs
		max_headers: config.max_headers
		max_read: config.max_read
		max_write: config.max_write
		cb: picoev_callback
		user_data: ctx
	) or {
		eprintln('[vono] Failed to create picoev server: ${err}')
		return
	}
	
	host_str := if config.host == '' { '127.0.0.1' } else { config.host }
	println('[vono] Listening on http://${host_str}:${config.port}/ (picoev)')
	
	pico.serve()
}

// ============================================================================
// WebSocket Upgrade Detection and Handling
// ============================================================================

// Check if a picoev request is a WebSocket upgrade request
fn is_picoev_ws_upgrade(req picohttpparser.Request) bool {
	mut has_upgrade := false
	mut has_connection := false
	mut has_ws_key := false
	
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		name_lower := h.name.to_lower()
		
		if name_lower == 'upgrade' {
			if h.value.to_lower() == 'websocket' {
				has_upgrade = true
			}
		} else if name_lower == 'connection' {
			if contains_ignore_case(h.value, 'upgrade') {
				has_connection = true
			}
		} else if name_lower == 'sec-websocket-key' {
			if h.value.len > 0 {
				has_ws_key = true
			}
		}
	}
	
	return has_upgrade && has_connection && has_ws_key
}

// Get WebSocket key from picoev request headers
fn get_picoev_ws_key(req picohttpparser.Request) string {
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		if eq_ignore_case(h.name, 'sec-websocket-key') {
			return h.value
		}
	}
	return ''
}

// Get WebSocket protocol from picoev request headers
fn get_picoev_ws_protocol(req picohttpparser.Request) string {
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		if eq_ignore_case(h.name, 'sec-websocket-protocol') {
			return h.value
		}
	}
	return ''
}

// Get WebSocket version from picoev request headers
fn get_picoev_ws_version(req picohttpparser.Request) string {
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		if eq_ignore_case(h.name, 'sec-websocket-version') {
			return h.value
		}
	}
	return '13'
}

// Handle WebSocket upgrade for picoev
fn handle_picoev_ws_upgrade(mut ctx PicoevRequestContext, req picohttpparser.Request, mut res picohttpparser.Response, route_match ContextRouteMatch, hono_ctx Context) bool {
	// Validate WebSocket version
	ws_version := get_picoev_ws_version(req)
	if ws_version != '13' {
		res.raw('HTTP/1.1 426 Upgrade Required\r\n')
		res.header('Sec-WebSocket-Version', '13')
		res.header('Content-Type', 'text/plain')
		res.body('Unsupported WebSocket version')
		res.end()
		return false
	}
	
	// Get WebSocket key
	ws_key := get_picoev_ws_key(req)
	if ws_key.len == 0 {
		res.raw('HTTP/1.1 400 Bad Request\r\n')
		res.header('Content-Type', 'text/plain')
		res.body('Missing Sec-WebSocket-Key header')
		res.end()
		return false
	}
	
	// Compute accept key
	accept_key := compute_accept_key(ws_key)
	
	// Execute the route handler to get WSEvents
	// The handler should return a 101 response with WebSocket context stored
	mut mutable_ctx := hono_ctx
	response := route_match.handler.handle(mut mutable_ctx)
	
	// Check if this is a WebSocket upgrade response
	if response.status_code != 101 {
		// Not a WebSocket upgrade, send the response as-is
		send_picoev_response(mut res, mutable_ctx, response, false, ctx.config)
		return false
	}
	
	// Negotiate subprotocol
	mut selected_protocol := ''
	if '_ws_protocol' in mutable_ctx.store {
		selected_protocol = mutable_ctx.store['_ws_protocol']
	}
	
	// Send WebSocket handshake response
	res.raw('HTTP/1.1 101 Switching Protocols\r\n')
	res.header('Upgrade', 'websocket')
	res.header('Connection', 'Upgrade')
	res.header('Sec-WebSocket-Accept', accept_key)
	if selected_protocol.len > 0 {
		res.header('Sec-WebSocket-Protocol', selected_protocol)
	}
	res.body('')
	res.end()
	
	return true
}

// Send WebSocket frame via picoev response
fn send_ws_frame_picoev(data []u8) ! {
	// This is a placeholder - actual implementation depends on picoev's raw socket access
	// In practice, we need to write directly to the socket fd
}

// picoev callback function
fn picoev_callback(user_data voidptr, req picohttpparser.Request, mut res picohttpparser.Response) {
	mut ctx := unsafe { &PicoevRequestContext(user_data) }
	
	if ctx.app == unsafe { nil } {
		res.http_500()
		res.end()
		return
	}
	
	path, query_map := parse_path_and_query(req.path)
	keepalive := check_keepalive_request(req)
	method_str := req.method
	
	// Check if this is a WebSocket upgrade request
	is_ws_upgrade := is_picoev_ws_upgrade(req)
	
	// Prioritize using fast routers
	if ctx.app.use_fast_router {
		if route_match := ctx.app.fast_router.match_route(method_str, path) {
			mut hono_ctx := create_picoev_context(req, route_match.params, query_map)
			
			// Handle WebSocket upgrade if detected
			if is_ws_upgrade {
				if handle_picoev_ws_upgrade(mut ctx, req, mut res, route_match, hono_ctx) {
					// WebSocket upgrade successful, connection is now in WebSocket mode
					return
				}
				// If upgrade failed, response was already sent
				return
			}
			
			// Optimization: Zero middleware fast path
			if !ctx.app.has_middlewares {
				response := route_match.handler.handle(mut hono_ctx)
				send_picoev_response(mut res, hono_ctx, response, keepalive, ctx.config)
				return
			}
			
			middlewares := get_middlewares_for_path_picoev_optimized(ctx.app, path)
			response := exec_middlewares_picoev(0, middlewares, mut hono_ctx, route_match.handler)
			send_picoev_response(mut res, hono_ctx, response, keepalive, ctx.config)
			return
		}
	}
	
	// Fallback to hybrid router
	if route_match := ctx.app.context_hybrid_router.match_route(method_str, path) {
		mut hono_ctx := create_picoev_context(req, route_match.params, query_map)
		
		// Handle WebSocket upgrade if detected
		if is_ws_upgrade {
			if handle_picoev_ws_upgrade(mut ctx, req, mut res, route_match, hono_ctx) {
				// WebSocket upgrade successful
				return
			}
			return
		}
		
		// Optimization: Zero middleware fast path
		if !ctx.app.has_middlewares {
			response := route_match.handler.handle(mut hono_ctx)
			send_picoev_response(mut res, hono_ctx, response, keepalive, ctx.config)
			return
		}
		
		middlewares := get_middlewares_for_path_picoev_optimized(ctx.app, path)
		response := exec_middlewares_picoev(0, middlewares, mut hono_ctx, route_match.handler)
		send_picoev_response(mut res, hono_ctx, response, keepalive, ctx.config)
		return
	}
	
	// 404 Not Found
	mut hono_ctx := create_picoev_context(req, map[string]string{}, query_map)
	
	if handler := ctx.app.not_found_handler {
		response := handler(mut hono_ctx)
		send_picoev_response(mut res, hono_ctx, response, keepalive, ctx.config)
		return
	}
	
	//Default 404 response
	res.raw('HTTP/1.1 404 Not Found\r\n')
	res.header('Content-Type', 'text/plain')
	res.header('Content-Length', '9')
	if keepalive {
		res.header('Connection', 'keep-alive')
		res.header('Keep-Alive', 'timeout=${ctx.config.keepalive_timeout}, max=${ctx.config.max_keepalive_req}')
	} else {
		res.header('Connection', 'close')
	}
	res.body('Not Found')
	res.end()
}

// Check if the client requests Keep-Alive - optimized version
// Avoid to_lower() creating new strings, use case-insensitive comparisons
fn check_keepalive_request(req picohttpparser.Request) bool {
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		// Case-insensitive comparison "connection"
		if h.name.len == 10 && eq_ignore_case(h.name, 'connection') {
			// Check if "keep-alive" is included (case insensitive)
			return contains_ignore_case(h.value, 'keep-alive')
		}
	}
	return true // HTTP/1.1 default Keep-Alive
}

// Case-insensitive string comparison (avoid allocation)
@[inline]
fn eq_ignore_case(a string, b string) bool {
	if a.len != b.len {
		return false
	}
	for i in 0 .. a.len {
		ca := a[i]
		cb := b[i]
		// Convert to lower case for comparison
		la := if ca >= `A` && ca <= `Z` { ca + 32 } else { ca }
		lb := if cb >= `A` && cb <= `Z` { cb + 32 } else { cb }
		if la != lb {
			return false
		}
	}
	return true
}

// Case-insensitive contains check (avoids allocation)
@[inline]
fn contains_ignore_case(haystack string, needle string) bool {
	if needle.len > haystack.len {
		return false
	}
	max_start := haystack.len - needle.len
	for i := 0; i <= max_start; i++ {
		mut found := true
		for j in 0 .. needle.len {
			ch := haystack[i + j]
			cn := needle[j]
			lh := if ch >= `A` && ch <= `Z` { ch + 32 } else { ch }
			ln := if cn >= `A` && cn <= `Z` { cn + 32 } else { cn }
			if lh != ln {
				found = false
				break
			}
		}
		if found {
			return true
		}
	}
	return false
}

// Get all middleware corresponding to the path (optimized version: use presorted prefix list)
fn get_middlewares_for_path_picoev_optimized(app &Hono, path string) []ContextMiddleware {
	// Optimization: When there is only global middleware, return the reference directly (avoid cloning)
	if app.route_middlewares.len == 0 {
		return app.context_middlewares
	}
	
	mut middlewares := app.context_middlewares.clone()
	
	// Optimization: Use pre-sorted prefix list (sorted at startup, no need to sort on every request)
	for prefix in app.sorted_middleware_prefixes {
		if path.starts_with(prefix) || prefix == '/' {
			if mws := app.route_middlewares[prefix] {
				middlewares << mws
			}
		}
	}
	
	return middlewares
}

// Get all middleware corresponding to the path (retain compatibility with old versions)
fn get_middlewares_for_path_picoev(app &Hono, path string) []ContextMiddleware {
	return get_middlewares_for_path_picoev_optimized(app, path)
}

//Execute middleware chain
fn exec_middlewares_picoev(idx int, middlewares []ContextMiddleware, mut ctx Context, handler IHandler) http.Response {
	if idx < middlewares.len {
		mw := middlewares[idx]
		return mw(mut ctx, fn [idx, middlewares, handler] (mut c Context) http.Response {
			return exec_middlewares_picoev(idx + 1, middlewares, mut c, handler)
		})
	}
	return handler.handle(mut ctx)
}

// Parse paths and query parameters - zero-allocation optimized version
// Use pointer traversal to avoid creating temporary arrays
fn parse_path_and_query(full_path string) (string, map[string]string) {
	mut query_map := map[string]string{}
	len := full_path.len
	
	if len == 0 {
		return full_path, query_map
	}
	
	// Fast path: most requests have no query parameters
	// Searching for '?' from back to front is usually faster (query parameters are at the end)
	mut query_start := -1
	for i := len - 1; i >= 0; i-- {
		if full_path[i] == `?` {
			query_start = i
			break
		}
	}
	
	// No query parameters, return directly (the most common case)
	if query_start == -1 {
		return full_path, query_map
	}
	
	path := full_path[..query_start]
	
	// Parse query parameters (single traversal, avoid split)
	mut key_start := query_start + 1
	mut key_end := -1
	mut value_start := -1
	
	for i := query_start + 1; i <= len; i++ {
		ch := if i < len { full_path[i] } else { `&` } // The end is treated as a separator
		
		if ch == `=` && key_end == -1 {
			key_end = i
			value_start = i + 1
		} else if ch == `&` {
			//Complete a key-value pair
			if key_end > key_start && value_start > 0 {
				key := full_path[key_start..key_end]
				value := if value_start < i { full_path[value_start..i] } else { '' }
				query_map[key] = value
			} else if key_end == -1 && i > key_start {
				// Only key without value (such as ?foo&bar=1)
				key := full_path[key_start..i]
				query_map[key] = ''
			}
			//Reset state
			key_start = i + 1
			key_end = -1
			value_start = -1
		}
	}
	
	return path, query_map
}

// Create picoev context - optimized version
// Lazy conversion of http.Request, only when really needed
fn create_picoev_context(req picohttpparser.Request, params map[string]string, query map[string]string) Context {
	//Extract pure path (without query parameters)
	path := extract_path_only(req.path)
	
	return Context{
		req: convert_picoev_request(req)
		params: params
		query: query
		body: req.body
		url: req.path
		path: path
		status_code: 200
		headers: map[string]string{}
	}
}

//Quick extraction path (excluding query parameters)
@[inline]
fn extract_path_only(full_path string) string {
	for i in 0 .. full_path.len {
		if full_path[i] == `?` {
			return full_path[..i]
		}
	}
	return full_path
}

//Convert picoev request - optimized version
// Use precomputed method mapping to avoid string comparisons
fn convert_picoev_request(req picohttpparser.Request) http.Request {
	mut headers := http.new_header()
	
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		headers.add_custom(h.name, h.value) or { continue }
	}
	
	return http.Request{
		method: parse_http_method_fast(req.method)
		url: req.path
		data: req.body
		header: headers
	}
}

// Fast HTTP method parsing (based on first character and length)
@[inline]
fn parse_http_method_fast(method string) http.Method {
	len := method.len
	if len == 0 {
		return http.Method.get
	}
	
	// Quick branch based on first character
	match method[0] {
		`G` {
			if len == 3 { return http.Method.get }
		}
		`P` {
			if len == 4 && method[1] == `O` { return http.Method.post }
			if len == 3 && method[1] == `U` { return http.Method.put }
			if len == 5 { return http.Method.patch }
		}
		`D` {
			if len == 6 { return http.Method.delete }
		}
		`H` {
			if len == 4 { return http.Method.head }
		}
		`O` {
			if len == 7 { return http.Method.options }
		}
		else {}
	}
	return http.Method.get
}

//Send picoev response - optimized version
fn send_picoev_response(mut res picohttpparser.Response, ctx Context, response http.Response, keepalive bool, config PicoevConfig) {
	// Check if this is a streaming response
	if is_streaming_response(ctx) {
		// Handle streaming response
		handle_picoev_streaming_response(mut res, ctx, config)
		return
	}
	
	status_code := if ctx.status_code != 0 { ctx.status_code } else { response.status_code }
	
	if status_code == 200 {
		res.http_ok()
	} else {
		res.raw('HTTP/1.1 ${status_code} ${get_status_text(status_code)}\r\n')
	}
	
	mut has_content_type := false
	mut has_connection := false
	
	for key, value in ctx.headers {
		// Use fast case-insensitive comparison
		key_len := key.len
		if key_len == 14 && eq_ignore_case(key, 'content-length') {
			continue // Skip Content-Length
		}
		res.header(key, value)
		if key_len == 12 && eq_ignore_case(key, 'content-type') {
			has_content_type = true
		} else if key_len == 10 && eq_ignore_case(key, 'connection') {
			has_connection = true
		}
	}
	
	if !has_content_type {
		if content_type := response.header.get(.content_type) {
			res.header('Content-Type', content_type)
			has_content_type = true
		}
	}
	
	if !has_content_type {
		res.header('Content-Type', 'text/plain; charset=utf-8')
	}
	
	if !has_connection {
		if keepalive {
			res.header('Connection', 'keep-alive')
			res.header('Keep-Alive', 'timeout=${config.keepalive_timeout}, max=${config.max_keepalive_req}')
		} else {
			res.header('Connection', 'close')
		}
	}
	
	res.body(response.body)
	res.end()
}

// ============================================================================
// Streaming Response Handling for Picoev
// ============================================================================

// handle_picoev_streaming_response - Handle a streaming response using PicoevStreamWriter
// This function:
// 1. Sends the HTTP headers for streaming directly to socket fd
// 2. Creates a PicoevStreamWriter with the socket fd
// 3. Executes the streaming callback
// 4. Handles errors and cleanup
fn handle_picoev_streaming_response(mut res picohttpparser.Response, ctx Context, config PicoevConfig) {
	// Get stream configuration
	stream_config := get_stream_config(ctx) or {
		// Fallback to error response if stream config not found
		res.raw('HTTP/1.1 500 Internal Server Error\r\n')
		res.header('Content-Type', 'text/plain')
		res.body('Stream configuration not found')
		res.end()
		return
	}
	
	// Determine status code
	status_code := if ctx.status_code != 0 { ctx.status_code } else { 200 }
	
	// Build HTTP headers string for direct socket write
	mut headers_str := 'HTTP/1.1 ${status_code} ${get_status_text(status_code)}\r\n'
	
	// Add headers from context
	mut has_transfer_encoding := false
	mut has_connection := false
	
	for key, value in ctx.headers {
		key_len := key.len
		// Skip Content-Length for streaming (we use chunked encoding)
		if key_len == 14 && eq_ignore_case(key, 'content-length') {
			continue
		}
		headers_str += '${key}: ${value}\r\n'
		if key_len == 17 && eq_ignore_case(key, 'transfer-encoding') {
			has_transfer_encoding = true
		} else if key_len == 10 && eq_ignore_case(key, 'connection') {
			has_connection = true
		}
	}
	
	// Ensure Transfer-Encoding: chunked is set
	if !has_transfer_encoding {
		headers_str += 'Transfer-Encoding: chunked\r\n'
	}
	
	// Ensure Connection header is set for streaming
	if !has_connection {
		headers_str += 'Connection: keep-alive\r\n'
		headers_str += 'Keep-Alive: timeout=${config.timeout_secs}\r\n'
	}
	
	// End headers section
	headers_str += '\r\n'
	
	// Write headers directly to socket fd for immediate delivery
	fd := res.fd
	write_to_socket_fd(fd, headers_str.bytes()) or {
		eprintln('[Picoev Stream Error] Failed to write headers: ${err.msg()}')
		cleanup_stream_config(ctx)
		return
	}
	
	// Create PicoevStreamWriter for streaming (uses fd directly)
	mut writer := PicoevStreamWriter.new(res)
	
	// Create StreamContext with the writer
	mut stream_ctx := StreamContext.new(writer)
	
	// Execute the streaming callback
	stream_config.callback(mut stream_ctx) or {
		// Handle error
		if error_handler := stream_config.error_handler {
			error_handler(err, mut stream_ctx)
		} else {
			// Default: log error to console
			eprintln('[Picoev Stream Error] ${err.msg()}')
		}
	}
	
	// Auto-close the stream when callback completes
	stream_ctx.close()
	
	// Cleanup the stored configuration
	cleanup_stream_config(ctx)
}

// write_to_socket_fd - Helper function to write bytes directly to socket fd
// Used for sending HTTP headers before streaming begins
fn write_to_socket_fd(fd int, data []u8) ! {
	if data.len == 0 {
		return
	}
	mut total_written := 0
	for total_written < data.len {
		remaining := data.len - total_written
		ptr := unsafe { &u8(data.data) + total_written }
		written := C.send(fd, ptr, remaining, 0)
		if written < 0 {
			return error('Failed to write to socket')
		}
		if written == 0 {
			return error('Connection closed by peer')
		}
		total_written += written
	}
}

// Get status code text
fn get_status_text(code int) string {
	return match code {
		101 { 'Switching Protocols' }
		200 { 'OK' }
		201 { 'Created' }
		204 { 'No Content' }
		301 { 'Moved Permanently' }
		302 { 'Found' }
		304 { 'Not Modified' }
		400 { 'Bad Request' }
		401 { 'Unauthorized' }
		403 { 'Forbidden' }
		404 { 'Not Found' }
		405 { 'Method Not Allowed' }
		426 { 'Upgrade Required' }
		500 { 'Internal Server Error' }
		502 { 'Bad Gateway' }
		503 { 'Service Unavailable' }
		else { 'Unknown' }
	}
}
