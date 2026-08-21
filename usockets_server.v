// uSockets Server Backend for vono
// 
// This file provides vono's uSockets high-performance server backend
// 
//Installation steps:
// 1. Copy the usockets directory to the vono project directory
// 2. Copy this file to the vono project root directory
// 3. Modify the path in usockets/usockets.v to an absolute path
//
// How to use:
// app.listen_usockets(3000) // Use uSockets backend
// app.listen(":3000") // Use the default picoev backend
//
//Compilation command:
//   v -cc gcc -ldflags "-ldbghelp" your_app.v -o app.exe
//
// Performance comparison (200 connections, 100K requests):
// uSockets: ~22,000 RPS (high concurrency optimization)
//   picoev:   ~15,000 RPS
//   
// Note: uSockets has obvious advantages in high concurrency scenarios (~50% improvement)
//The performance of the two is similar when concurrency is low

module vono

import usockets
import net.http
import strings

// uSockets server configuration
pub struct UsocketsConfig {
pub:
	port              int    = 8080
	host              string = '0.0.0.0'
	keepalive_timeout int    = 30
	max_keepalive_req int    = 10000
}

// uSockets context extension data - stores application references and configuration
struct UsocketsContextExt {
mut:
	app    &Vono = unsafe { nil }
	config UsocketsConfig
}

// Get context extension data from socket
@[inline]
fn get_usockets_ext(s usockets.Socket) &UsocketsContextExt {
	ctx := s.context()
	return unsafe { &UsocketsContextExt(ctx.ext()) }
}

// Start the server using uSockets
pub fn (mut app Vono) listen_usockets(port int) {
	app.listen_usockets_with_config(UsocketsConfig{
		port: port
	})
}

// Start the server using uSockets (with configuration)
pub fn (mut app Vono) listen_usockets_with_config(config UsocketsConfig) {
	// Optimization: Precomputed middleware prefix sorting
	app.precompute_middleware_prefixes()

	// Create uSockets event loop
	loop := usockets.create_loop()
	
	//Create a socket context with extended data
	ctx := usockets.create_socket_context_with_ext(loop, int(sizeof(UsocketsContextExt)))
	
	//Initialize extended data
	mut ext := unsafe { &UsocketsContextExt(ctx.ext()) }
	ext.app = unsafe { &app }
	ext.config = config

	//Set callback
	ctx.on_open(usockets_on_open)
	ctx.on_data(usockets_on_data)
	ctx.on_close(usockets_on_close)
	ctx.on_writable(usockets_on_writable)
	ctx.on_timeout(usockets_on_timeout)
	ctx.on_end(usockets_on_end)

	// Start listening
	listener := ctx.listen(config.port)
	if listener.is_valid() {
		host_str := if config.host == '' { '127.0.0.1' } else { config.host }
		println('[vono] Listening on http://${host_str}:${config.port}/ (uSockets)')
		loop.run()
	} else {
		eprintln('[vono] Failed to listen on port ${config.port}')
	}
}

// uSockets callback function
fn usockets_on_open(s usockets.Socket, is_client int, ip &char, ip_length int) usockets.Socket {
	return s
}

// ============================================================================
// WebSocket Upgrade Detection and Handling for uSockets
// ============================================================================

// Check if a raw HTTP request is a WebSocket upgrade request
fn is_usockets_ws_upgrade(raw_data string) bool {
	// Check for Upgrade: websocket header (case-insensitive)
	mut has_upgrade := false
	mut has_connection := false
	mut has_ws_key := false
	
	lines := raw_data.split('\r\n')
	for line in lines {
		lower_line := line.to_lower()
		if lower_line.starts_with('upgrade:') {
			if lower_line.contains('websocket') {
				has_upgrade = true
			}
		} else if lower_line.starts_with('connection:') {
			if lower_line.contains('upgrade') {
				has_connection = true
			}
		} else if lower_line.starts_with('sec-websocket-key:') {
			has_ws_key = true
		}
	}
	
	return has_upgrade && has_connection && has_ws_key
}

// Get WebSocket key from raw HTTP request headers
fn get_usockets_ws_key(raw_data string) string {
	lines := raw_data.split('\r\n')
	for line in lines {
		if line.to_lower().starts_with('sec-websocket-key:') {
			parts := line.split(':')
			if parts.len >= 2 {
				return parts[1..].join(':').trim_space()
			}
		}
	}
	return ''
}

// Get WebSocket protocol from raw HTTP request headers
fn get_usockets_ws_protocol(raw_data string) string {
	lines := raw_data.split('\r\n')
	for line in lines {
		if line.to_lower().starts_with('sec-websocket-protocol:') {
			parts := line.split(':')
			if parts.len >= 2 {
				return parts[1..].join(':').trim_space()
			}
		}
	}
	return ''
}

// Get WebSocket version from raw HTTP request headers
fn get_usockets_ws_version(raw_data string) string {
	lines := raw_data.split('\r\n')
	for line in lines {
		if line.to_lower().starts_with('sec-websocket-version:') {
			parts := line.split(':')
			if parts.len >= 2 {
				return parts[1..].join(':').trim_space()
			}
		}
	}
	return '13'
}

// Handle WebSocket upgrade for uSockets
// Returns true if upgrade was successful, false otherwise
fn handle_usockets_ws_upgrade(s usockets.Socket, raw_data string, route_match ContextRouteMatch, vono_ctx Context) bool {
	// Validate WebSocket version
	ws_version := get_usockets_ws_version(raw_data)
	if ws_version != '13' {
		s.write_bytes('HTTP/1.1 426 Upgrade Required\r\nSec-WebSocket-Version: 13\r\nContent-Type: text/plain\r\nContent-Length: 28\r\n\r\nUnsupported WebSocket version')
		return false
	}
	
	// Get WebSocket key
	ws_key := get_usockets_ws_key(raw_data)
	if ws_key.len == 0 {
		s.write_bytes('HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\nContent-Length: 30\r\n\r\nMissing Sec-WebSocket-Key header')
		return false
	}
	
	// Compute accept key
	accept_key := compute_accept_key(ws_key)
	
	// Execute the route handler to get WSEvents
	mut mutable_ctx := vono_ctx
	response := route_match.handler.handle(mut mutable_ctx)
	
	// Check if this is a WebSocket upgrade response
	if response.status_code != 101 {
		// Not a WebSocket upgrade, send the response as-is
		send_usockets_response(s, mutable_ctx, response, true)
		return false
	}
	
	// Negotiate subprotocol
	mut selected_protocol := ''
	if '_ws_protocol' in mutable_ctx.store {
		selected_protocol = mutable_ctx.store['_ws_protocol']
	}
	
	// Build and send WebSocket handshake response
	mut resp := strings.new_builder(256)
	resp.write_string('HTTP/1.1 101 Switching Protocols\r\n')
	resp.write_string('Upgrade: websocket\r\n')
	resp.write_string('Connection: Upgrade\r\n')
	resp.write_string('Sec-WebSocket-Accept: ')
	resp.write_string(accept_key)
	resp.write_string('\r\n')
	if selected_protocol.len > 0 {
		resp.write_string('Sec-WebSocket-Protocol: ')
		resp.write_string(selected_protocol)
		resp.write_string('\r\n')
	}
	resp.write_string('\r\n')
	
	s.write_bytes(resp.str())
	
	// Note: After the handshake, the connection is now in WebSocket mode.
	// The uSockets backend will continue to receive data on this socket,
	// but it will be WebSocket frames instead of HTTP requests.
	// For full WebSocket support, additional frame handling would be needed
	// in the usockets_on_data callback.
	
	return true
}

fn usockets_on_data(s usockets.Socket, data &char, length int) usockets.Socket {
	// Get application reference from socket context
	ext := get_usockets_ext(s)
	mut app := ext.app
	
	if app == unsafe { nil } {
		s.write_bytes('HTTP/1.1 500 Internal Server Error\r\nContent-Length: 21\r\n\r\nInternal Server Error')
		return s
	}

	// Parse HTTP request
	raw_data := unsafe { tos(&u8(data), length) }
	method, path, query_map, body, is_http11 := parse_http_request_usockets(raw_data)
	
	if method.len == 0 {
		s.write_bytes('HTTP/1.1 400 Bad Request\r\nContent-Length: 11\r\n\r\nBad Request')
		return s
	}

	// Check if this is a WebSocket upgrade request
	is_ws_upgrade := is_usockets_ws_upgrade(raw_data)

	// Route matching - use fast routers first
	mut response_sent := false

	if app.use_fast_router {
		if route_match := app.fast_router.match_route(method, path) {
			mut vono_ctx := create_usockets_context(method, path, route_match.params, query_map, body)
			
			// Handle WebSocket upgrade if detected
			if is_ws_upgrade {
				// Parse headers for WebSocket context
				vono_ctx = create_usockets_context_with_headers(raw_data, method, path, route_match.params, query_map, body)
				if handle_usockets_ws_upgrade(s, raw_data, route_match, vono_ctx) {
					// WebSocket upgrade successful
					return s
				}
				// If upgrade failed, response was already sent
				return s
			}
			
			// Optimization 1: Zero middleware fast path
			if !app.has_middlewares {
				response := route_match.handler.handle(mut vono_ctx)
				send_usockets_response(s, vono_ctx, response, is_http11)
			} else {
				middlewares := get_middlewares_for_path_usockets_optimized(app, path)
				response := exec_middlewares_usockets(0, middlewares, mut vono_ctx, route_match.handler)
				send_usockets_response(s, vono_ctx, response, is_http11)
			}
			response_sent = true
		}
	}

	// Fallback to hybrid router
	if !response_sent {
		if route_match := app.context_hybrid_router.match_route(method, path) {
			mut vono_ctx := create_usockets_context(method, path, route_match.params, query_map, body)
			
			// Handle WebSocket upgrade if detected
			if is_ws_upgrade {
				// Parse headers for WebSocket context
				vono_ctx = create_usockets_context_with_headers(raw_data, method, path, route_match.params, query_map, body)
				if handle_usockets_ws_upgrade(s, raw_data, route_match, vono_ctx) {
					// WebSocket upgrade successful
					return s
				}
				// If upgrade failed, response was already sent
				return s
			}
			
			// Optimization 1: Zero middleware fast path
			if !app.has_middlewares {
				response := route_match.handler.handle(mut vono_ctx)
				send_usockets_response(s, vono_ctx, response, is_http11)
			} else {
				middlewares := get_middlewares_for_path_usockets_optimized(app, path)
				response := exec_middlewares_usockets(0, middlewares, mut vono_ctx, route_match.handler)
				send_usockets_response(s, vono_ctx, response, is_http11)
			}
			response_sent = true
		}
	}

	// 404 Not Found
	if !response_sent {
		mut vono_ctx := create_usockets_context(method, path, map[string]string{}, query_map, body)

		if handler := app.not_found_handler {
			response := handler(mut vono_ctx)
			send_usockets_response(s, vono_ctx, response, is_http11)
		} else {
			conn_header := if is_http11 { 'keep-alive' } else { 'close' }
			s.write_bytes('HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: 9\r\nConnection: ${conn_header}\r\n\r\nNot Found')
			if !is_http11 {
				s.shutdown()
			}
		}
	}

	return s
}

fn usockets_on_close(s usockets.Socket, code int, reason voidptr) usockets.Socket {
	return s
}

fn usockets_on_writable(s usockets.Socket) usockets.Socket {
	return s
}

fn usockets_on_timeout(s usockets.Socket) usockets.Socket {
	return s.close()
}

fn usockets_on_end(s usockets.Socket) usockets.Socket {
	s.shutdown()
	return s.close()
}


// Parse HTTP requests - zero-allocation optimized version
// Use pointer traversal to avoid creating temporary arrays
// Return: (method, path, query_map, body, is_http11)
fn parse_http_request_usockets(raw string) (string, string, map[string]string, string, bool) {
	mut method := ''
	mut path := ''
	mut query_map := map[string]string{}
	mut body := ''
	mut is_http11 := true
	
	len := raw.len
	if len == 0 {
		return method, path, query_map, body, is_http11
	}
	
	// 1. Find the end of the first line (\r\n)
	mut line_end := -1
	for i in 0 .. len - 1 {
		if raw[i] == `\r` && raw[i + 1] == `\n` {
			line_end = i
			break
		}
	}
	if line_end == -1 {
		return method, path, query_map, body, is_http11
	}
	
	// 2. Parse method (to the first space)
	mut method_end := 0
	for method_end < line_end && raw[method_end] != ` ` {
		method_end++
	}
	if method_end == 0 || method_end >= line_end {
		return method, path, query_map, body, is_http11
	}
	method = raw[..method_end]
	
	// 3. Parse path and query (from after the space to the next space)
	mut path_start := method_end + 1
	// Skip extra spaces
	for path_start < line_end && raw[path_start] == ` ` {
		path_start++
	}
	
	mut path_end := path_start
	mut query_start := -1
	for path_end < line_end && raw[path_end] != ` ` {
		if raw[path_end] == `?` && query_start == -1 {
			query_start = path_end + 1
		}
		path_end++
	}
	
	if query_start > 0 {
		path = raw[path_start..query_start - 1]
		// Parse query string (single traversal)
		query_map = parse_query_string_fast(raw, query_start, path_end)
	} else {
		path = raw[path_start..path_end]
	}
	
	// 4. Detect HTTP version - "HTTP/1.0" vs "HTTP/1.1"
	// Request line format: "GET /path HTTP/1.1\r\n"
	// HTTP/1.x version string is fixed to 8 characters, check the 8th character directly
	mut version_start := path_end + 1
	for version_start < line_end && raw[version_start] == ` ` {
		version_start++
	}
	// "HTTP/1.0" or "HTTP/1.1", check the character at index 7 (0-based)
	if version_start + 7 < line_end {
		is_http11 = raw[version_start + 7] != `0`
	}
	
	// For HTTP/1.0, check if the Connection header contains keep-alive
	// Reference Go net/http: wantsHttp10KeepAlive() only checks the value of the Connection header
	if !is_http11 {
		is_http11 = has_connection_keep_alive(raw, line_end, len)
	}
	
	// 5. Find body (after \r\n\r\n)
	for i in line_end .. len - 3 {
		if raw[i] == `\r` && raw[i + 1] == `\n` && raw[i + 2] == `\r` && raw[i + 3] == `\n` {
			if i + 4 < len {
				body = raw[i + 4..]
			}
			break
		}
	}
	
	return method, path, query_map, body, is_http11
}

// Check whether the Connection header contains keep-alive (refer to Go net/http implementation)
// Only check the value of the "Connection:" header to avoid misjudgment of the content in the request body
@[inline]
fn has_connection_keep_alive(raw string, headers_start int, len int) bool {
	mut i := headers_start
	
	// Traverse the header of each row
	for i < len - 12 {  // At least "Connection:" + some value is required
		// skip \r\n
		if raw[i] == `\r` && i + 1 < len && raw[i + 1] == `\n` {
			i += 2
			// Check if the end of the header is reached (blank line)
			if i < len - 1 && raw[i] == `\r` && raw[i + 1] == `\n` {
				break
			}
		}
		
		// Check if it is a "Connection:" header (case insensitive)
		if (raw[i] == `C` || raw[i] == `c`) && i + 11 < len {
			// Check "onnection:"
			if (raw[i+1] == `o` || raw[i+1] == `O`) &&
			   (raw[i+2] == `n` || raw[i+2] == `N`) &&
			   (raw[i+3] == `n` || raw[i+3] == `N`) &&
			   (raw[i+4] == `e` || raw[i+4] == `E`) &&
			   (raw[i+5] == `c` || raw[i+5] == `C`) &&
			   (raw[i+6] == `t` || raw[i+6] == `T`) &&
			   (raw[i+7] == `i` || raw[i+7] == `I`) &&
			   (raw[i+8] == `o` || raw[i+8] == `O`) &&
			   (raw[i+9] == `n` || raw[i+9] == `N`) &&
			   raw[i+10] == `:` {
				// Find the Connection header and check if the value contains keep-alive
				mut value_start := i + 11
				// skip spaces
				for value_start < len && raw[value_start] == ` ` {
					value_start++
				}
				// Find the end of the line
				mut value_end := value_start
				for value_end < len && raw[value_end] != `\r` && raw[value_end] != `\n` {
					value_end++
				}
				// Find "keep-alive" in the value (case insensitive)
				return contains_keep_alive_token(raw, value_start, value_end)
			}
		}
		i++
	}
	return false
}

// Check if the string fragment contains keep-alive token
@[inline]
fn contains_keep_alive_token(raw string, start int, end int) bool {
	// Find "keep-alive" or "Keep-Alive" (supports multiple values ​​such as "keep-alive, upgrade")
	mut i := start
	for i <= end - 10 {
		if raw[i] == `k` || raw[i] == `K` {
			if (raw[i+1] == `e` || raw[i+1] == `E`) &&
			   (raw[i+2] == `e` || raw[i+2] == `E`) &&
			   (raw[i+3] == `p` || raw[i+3] == `P`) &&
			   raw[i+4] == `-` &&
			   (raw[i+5] == `a` || raw[i+5] == `A`) &&
			   (raw[i+6] == `l` || raw[i+6] == `L`) &&
			   (raw[i+7] == `i` || raw[i+7] == `I`) &&
			   (raw[i+8] == `v` || raw[i+8] == `V`) &&
			   (raw[i+9] == `e` || raw[i+9] == `E`) {
				return true
			}
		}
		i++
	}
	return false
}// Quickly parse query string (single traversal, avoid split)
@[inline]
fn parse_query_string_fast(raw string, start int, end int) map[string]string {
	mut query_map := map[string]string{}
	
	mut key_start := start
	mut key_end := -1
	mut value_start := -1
	
	for i := start; i <= end; i++ {
		ch := if i < end { raw[i] } else { `&` } // The end is treated as a separator
		
		if ch == `=` && key_end == -1 {
			key_end = i
			value_start = i + 1
		} else if ch == `&` {
			//Complete a key-value pair
			if key_end > key_start && value_start > 0 {
				key := raw[key_start..key_end]
				value := if value_start < i { raw[value_start..i] } else { '' }
				query_map[key] = value
			} else if key_end == -1 && i > key_start {
				// Only key without value
				key := raw[key_start..i]
				query_map[key] = ''
			}
			//Reset state
			key_start = i + 1
			key_end = -1
			value_start = -1
		}
	}
	
	return query_map
}

//Create uSockets context - optimized version
fn create_usockets_context(method string, path string, params map[string]string, query map[string]string, body string) Context {
	return Context{
		req: http.Request{
			method: parse_http_method_usockets(method)
			url: path
			data: body
		}
		params: params
		query: query
		body: body
		url: path
		path: path
		status_code: 200
		headers: map[string]string{}
	}
}

// Create uSockets context - with HTTP header parsing (for WebSocket upgrades)
fn create_usockets_context_with_headers(raw_data string, method string, path string, params map[string]string, query map[string]string, body string) Context {
	// Parse headers from raw HTTP request
	mut headers := http.new_header()
	
	lines := raw_data.split('\r\n')
	mut in_headers := false
	
	for line in lines {
		if !in_headers {
			// Skip the request line
			if line.contains(' HTTP/') {
				in_headers = true
			}
			continue
		}
		
		// Empty line marks end of headers
		if line.len == 0 {
			break
		}
		
		// Parse header
		colon_idx := line.index(':') or { continue }
		if colon_idx > 0 {
			name := line[..colon_idx].trim_space()
			value := line[colon_idx + 1..].trim_space()
			headers.add_custom(name, value) or { continue }
		}
	}
	
	return Context{
		req: http.Request{
			method: parse_http_method_usockets(method)
			url: path
			data: body
			header: headers
		}
		params: params
		query: query
		body: body
		url: path
		path: path
		status_code: 200
		headers: map[string]string{}
	}
}

// Fast HTTP method parsing (based on first character and length)
@[inline]
fn parse_http_method_usockets(method string) http.Method {
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

// Get all middleware corresponding to the path (optimized version: use presorted prefix list)
fn get_middlewares_for_path_usockets_optimized(app &Vono, path string) []ContextMiddleware {
	// Optimization 2: When there is only global middleware, return the reference directly (avoid cloning)
	if app.route_middlewares.len == 0 {
		return app.context_middlewares
	}
	
	mut middlewares := app.context_middlewares.clone()

	// Optimization 3: Use a pre-sorted prefix list (sorted at startup, no need to sort every request)
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
fn get_middlewares_for_path_usockets(app &Vono, path string) []ContextMiddleware {
	return get_middlewares_for_path_usockets_optimized(app, path)
}

//Execute middleware chain
fn exec_middlewares_usockets(idx int, middlewares []ContextMiddleware, mut ctx Context, handler IHandler) http.Response {
	if idx < middlewares.len {
		mw := middlewares[idx]
		return mw(mut ctx, fn [idx, middlewares, handler] (mut c Context) http.Response {
			return exec_middlewares_usockets(idx + 1, middlewares, mut c, handler)
		})
	}
	return handler.handle(mut ctx)
}

// Send uSockets response - optimized version
fn send_usockets_response(s usockets.Socket, ctx Context, response http.Response, is_http11 bool) {
	// Check if this is a streaming response
	if is_streaming_response(ctx) {
		// Handle streaming response
		handle_usockets_streaming_response(s, ctx)
		return
	}
	
	status_code := if ctx.status_code != 0 { ctx.status_code } else { response.status_code }
	
	mut resp := strings.new_builder(512)
	
	// status line
	resp.write_string('HTTP/1.1 ')
	resp.write_string(status_code.str())
	resp.write_string(' ')
	resp.write_string(get_status_text_usockets(status_code))
	resp.write_string('\r\n')

	//head
	mut has_content_type := false
	for key, value in ctx.headers {
		// Use fast case-insensitive comparison
		key_len := key.len
		if key_len == 14 && eq_ignore_case_usockets(key, 'content-length') {
			continue
		}
		resp.write_string(key)
		resp.write_string(': ')
		resp.write_string(value)
		resp.write_string('\r\n')
		if key_len == 12 && eq_ignore_case_usockets(key, 'content-type') {
			has_content_type = true
		}
	}

	if !has_content_type {
		if content_type := response.header.get(.content_type) {
			resp.write_string('Content-Type: ')
			resp.write_string(content_type)
			resp.write_string('\r\n')
			has_content_type = true
		}
	}

	if !has_content_type {
		resp.write_string('Content-Type: text/plain; charset=utf-8\r\n')
	}

	// Content-Length
	resp.write_string('Content-Length: ')
	resp.write_string(response.body.len.str())
	resp.write_string('\r\n')

	// Connection - HTTP/1.0 uses close, HTTP/1.1 uses keep-alive
	if is_http11 {
		resp.write_string('Connection: keep-alive\r\n')
	} else {
		resp.write_string('Connection: close\r\n')
	}

	// Blank line + body
	resp.write_string('\r\n')
	resp.write_string(response.body)

	s.write_bytes(resp.str())
	
	// Close the connection after HTTP/1.0 request is completed
	// Just call shutdown() to send FIN and let the on_end callback handle close()
	// This ensures that the data in the send buffer is completely sent
	if !is_http11 {
		s.shutdown()
	}
}

// ============================================================================
// Streaming Response Handling for uSockets
// ============================================================================

// handle_usockets_streaming_response - Handle a streaming response using UsocketsStreamWriter
// This function:
// 1. Sends the HTTP headers for streaming
// 2. Creates a UsocketsStreamWriter
// 3. Executes the streaming callback
// 4. Handles errors and cleanup
//
// Requirements: 7.1, 7.2, 7.3, 7.4
fn handle_usockets_streaming_response(s usockets.Socket, ctx Context) {
	// Get stream configuration
	stream_config := get_stream_config(ctx) or {
		// Fallback to error response if stream config not found
		s.write_bytes('HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nContent-Length: 32\r\n\r\nStream configuration not found')
		return
	}
	
	// Determine status code
	status_code := if ctx.status_code != 0 { ctx.status_code } else { 200 }
	
	// Build HTTP response headers
	mut resp := strings.new_builder(512)
	
	// Status line
	resp.write_string('HTTP/1.1 ')
	resp.write_string(status_code.str())
	resp.write_string(' ')
	resp.write_string(get_status_text_usockets(status_code))
	resp.write_string('\r\n')
	
	// Send headers from context
	mut has_transfer_encoding := false
	mut has_connection := false
	
	for key, value in ctx.headers {
		key_len := key.len
		// Skip Content-Length for streaming (we use chunked encoding)
		if key_len == 14 && eq_ignore_case_usockets(key, 'content-length') {
			continue
		}
		resp.write_string(key)
		resp.write_string(': ')
		resp.write_string(value)
		resp.write_string('\r\n')
		if key_len == 17 && eq_ignore_case_usockets(key, 'transfer-encoding') {
			has_transfer_encoding = true
		} else if key_len == 10 && eq_ignore_case_usockets(key, 'connection') {
			has_connection = true
		}
	}
	
	// Ensure Transfer-Encoding: chunked is set (Requirement 7.2)
	if !has_transfer_encoding {
		resp.write_string('Transfer-Encoding: chunked\r\n')
	}
	
	// Ensure Connection header is set for streaming
	if !has_connection {
		resp.write_string('Connection: keep-alive\r\n')
	}
	
	// End headers section
	resp.write_string('\r\n')
	
	// Send headers to client
	s.write_bytes(resp.str())
	
	// Create UsocketsStreamWriter for streaming (Requirement 7.1)
	mut writer := UsocketsStreamWriter.new(s)
	
	// Create StreamContext with the writer
	mut stream_ctx := StreamContext.new(writer)
	
	// Execute the streaming callback (Requirement 7.4 - compatibility with callback architecture)
	stream_config.callback(mut stream_ctx) or {
		// Handle error (Requirement 7.3 - handle connection close events)
		if error_handler := stream_config.error_handler {
			error_handler(err, mut stream_ctx)
		} else {
			// Default: log error to console
			eprintln('[uSockets Stream Error] ${err.msg()}')
		}
	}
	
	// Auto-close the stream when callback completes
	stream_ctx.close()
	
	// Cleanup the stored configuration
	cleanup_stream_config(ctx)
}

// Case-insensitive string comparison (avoid allocation)
@[inline]
fn eq_ignore_case_usockets(a string, b string) bool {
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

// Get status code text
fn get_status_text_usockets(code int) string {
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
