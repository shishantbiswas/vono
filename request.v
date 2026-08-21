module vono

import net.http
import net.urllib
import os
import strings

// Context structure, similar to the implementation of Vono.js
pub struct Context {
pub:
	req    http.Request
	params map[string]string
	query  map[string]string
	url    string
	path   string  //The path of the current request
pub mut:
	status_code int = 200
	headers     map[string]string
	body        string
	store       map[string]string  //Middleware data storage
}

//Context constructor
pub fn Context.new(req http.Request, params map[string]string, query map[string]string, body string) Context {
	// Parse the URL to get the path
	url := urllib.parse(req.url) or {
		urllib.URL{
			path: '/'
		}
	}
	return Context{
		req: req
		params: params
		query: query
		body: body
		url: url.str()  // Set to the complete URL string
		path: url.path  //Set the path attribute
		headers: map[string]string{}
		store: map[string]string{}  //Initialize middleware data storage
	}
}

//Convenience method for Context - returns http.Response directly
pub fn (mut c Context) json(data string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Content-Type', 'application/json; charset=utf-8') or { }
	headers.add_custom('Connection', 'keep-alive') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: data
	}
}

pub fn (mut c Context) text(data string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Content-Type', 'text/plain; charset=utf-8') or { }
	headers.add_custom('Connection', 'keep-alive') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: data
	}
}

pub fn (mut c Context) html(data string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Content-Type', 'text/html; charset=utf-8') or { }
	headers.add_custom('Connection', 'keep-alive') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: data
	}
}

// file method - serve a file directly from the context
pub fn (mut c Context) file(file_path string) http.Response {
	return c.file_with_options(file_path, FileOptions{})
}

// file_with_options method - serve a file with custom options
pub fn (mut c Context) file_with_options(file_path string, options FileOptions) http.Response {
	// Enhanced security checks
	validation_options := PathValidationOptions{
		allow_absolute_paths: false
		allow_hidden_files: false
		check_file_extension: true
	}
	
	safe_file_path := validate_file_path(file_path, validation_options) or {
		c.status(403)
		return c.text('Forbidden: $err')
	}
	
	// Check if the file exists
	if !os.exists(safe_file_path) {
		c.status(404)
		return c.text('File Not Found')
	}
	
	// Check if it is a directory
	if os.is_dir(safe_file_path) {
		c.status(400)
		return c.text('Cannot serve directory')
	}
	
	//Read file content
	file_content := os.read_file(safe_file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	// Get file information
	file_info := os.stat(safe_file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	//Set status code
	if options.status_code > 0 {
		c.status(options.status_code)
	} else {
		c.status(200)
	}
	
	//Set Content-Type
	if options.content_type != '' {
		c.headers['Content-Type'] = options.content_type
	} else {
		content_type := get_safe_content_type(safe_file_path)
		c.headers['Content-Type'] = content_type
	}
	
	//Set Content-Length
	c.headers['Content-Length'] = file_content.len.str()
	
	//Set Last-Modified
	if options.last_modified {
		last_modified := format_http_date(file_info.mtime)
		c.headers['Last-Modified'] = last_modified
	}
	
	//Set ETag
	if options.etag {
		etag := generate_file_etag(file_content, file_info.mtime)
		c.headers['ETag'] = etag
		
		// Check If-None-Match
		if_none_match := c.req.header.get_custom('If-None-Match') or { '' }
		if if_none_match == etag {
			c.status(304)
			// Build response headers
			mut headers := http.new_header()
			for key, value in c.headers {
				headers.add_custom(key, value) or { continue }
			}
			return http.Response{
				status_code: c.status_code
				header: headers
				body: ''
			}
		}
	}
	
	//Set Cache-Control
	if options.max_age > 0 {
		c.headers['Cache-Control'] = 'public, max-age=${options.max_age}'
	} else if options.no_cache {
		c.headers['Cache-Control'] = 'no-cache'
	}
	
	//Set custom header
	for key, value in options.headers {
		c.headers[key] = value
	}
	
	//Return file content
	mut headers := http.new_header()
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: file_content
	}
}

// FileOptions struct for configuring file serving
pub struct FileOptions {
pub:
	status_code    int              // Custom status code, 0 means using the default 200
	content_type   string          // Custom Content-Type
	last_modified  bool = true          // Whether to set the Last-Modified header
	etag          bool = true           // Whether to set the ETag header
	max_age       int               // Cache time (seconds)
	no_cache      bool          // Whether to disable caching
	headers       map[string]string     // Custom response header
	// Streaming configuration
	stream_threshold u64 = 50 * 1024 * 1024  // 50MB, above this size use streaming
	buffer_size      int = 8192              // Streaming buffer size (8KB)
	enable_range     bool = true             // Whether to support Range request
	compress         bool                    // Whether to enable compression (for streaming)
}

// Get Content-Type based on file extension
fn get_file_content_type(file_path string) string {
	ext := os.file_ext(file_path).to_lower()
	
	match ext {
		'.html', '.htm' { return 'text/html; charset=utf-8' }
		'.css' { return 'text/css; charset=utf-8' }
		'.js' { return 'application/javascript; charset=utf-8' }
		'.json' { return 'application/json; charset=utf-8' }
		'.xml' { return 'application/xml; charset=utf-8' }
		'.txt' { return 'text/plain; charset=utf-8' }
		'.md' { return 'text/markdown; charset=utf-8' }
		'.pdf' { return 'application/pdf' }
		'.png' { return 'image/png' }
		'.jpg', '.jpeg' { return 'image/jpeg' }
		'.gif' { return 'image/gif' }
		'.svg' { return 'image/svg+xml' }
		'.ico' { return 'image/x-icon' }
		'.woff' { return 'font/woff' }
		'.woff2' { return 'font/woff2' }
		'.ttf' { return 'font/ttf' }
		'.eot' { return 'application/vnd.ms-fontobject' }
		'.otf' { return 'font/otf' }
		'.mp4' { return 'video/mp4' }
		'.webm' { return 'video/webm' }
		'.mp3' { return 'audio/mpeg' }
		'.wav' { return 'audio/wav' }
		'.zip' { return 'application/zip' }
		'.tar' { return 'application/x-tar' }
		'.gz' { return 'application/gzip' }
		else { return 'application/octet-stream' }
	}
}

// Generate ETag
fn generate_file_etag(content string, mod_time i64) string {
	// Simplified ETag generation
	// Actual applications may require more complex hash algorithms
	return '"${content.len}-${mod_time}"'
}

pub fn (mut c Context) status(code int) {
	c.status_code = code
}

// get method - get middleware data from the store
pub fn (c Context) get(key string) ?string {
	if key in c.store {
		return c.store[key]
	}
	return none
}

// set method - stores middleware data in the store
pub fn (mut c Context) set(key string, value string) {
	c.store[key] = value
}

// get_client_ip method - Get the client IP address
// Get it from the X-Forwarded-For and X-Real-IP headers first, otherwise get it from the connection information
pub fn (c Context) get_client_ip() string {
	// Try to get from X-Forwarded-For header (proxy scenario)
	if forwarded_for := c.req.header.get_custom('X-Forwarded-For') {
		// X-Forwarded-For may contain multiple IPs, take the first one
		ips := forwarded_for.split(',')
		if ips.len > 0 {
			ip := ips[0].trim_space()
			if ip != '' {
				return ip
			}
		}
	}
	
	//Try to get from X-Real-IP header
	if real_ip := c.req.header.get_custom('X-Real-IP') {
		trimmed := real_ip.trim_space()
		if trimmed != '' {
			return trimmed
		}
	}
	
	// Get from request URL or connection information
	// Note: http.Request in V language may not have a direct remote address field
	// Return a default value here, which may need to be adjusted according to the server implementation in actual use.
	return '127.0.0.1'
}

// redirect method - redirect to a URL with optional status code
pub fn (mut c Context) redirect(url string, status_code ...int) http.Response {
	// Set default status code to 302 (Found) if not provided
	mut code := 302
	if status_code.len > 0 {
		code = status_code[0]
	}
	
	// Set the status code
	c.status(code)
	
	// Set the Location header
	c.headers['Location'] = url
	
	// Build and return the response
	mut headers := http.new_header()
	headers.add_custom('Connection', 'keep-alive') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	
	return http.Response{
		status_code: c.status_code
		header: headers
		body: ''
	}
}



//Processor interface, using Context
pub interface IHandler {
	path string
	handle(mut c Context) http.Response
}

// Generic processor type, use Context
pub type ContextHandlerFn = fn (mut Context) http.Response

// Context processor structure
pub struct ContextHandler {
pub:
	path    string
	handler fn (mut Context) http.Response = unsafe { nil }
}

// Implement the IHandler interface
pub fn (ch ContextHandler) handle(mut c Context) http.Response {
	return ch.handler(mut c)
}

// Range request structure
struct RangeRequest {
	start u64
	end   u64
	total u64
}

// Parse the Range request header
fn parse_range_header(range_header string, file_size u64) ?RangeRequest {
	if !range_header.starts_with('bytes=') {
		return none
	}
	
	range_part := range_header[6..] // Remove 'bytes=' prefix
	parts := range_part.split('-')
	
	if parts.len != 2 {
		return none
	}
	
	start_str := parts[0].trim_space()
	end_str := parts[1].trim_space()
	
	mut start := u64(0)
	mut end := file_size - 1
	
	if start_str != '' {
		start = start_str.u64()
	}
	
	if end_str != '' {
		end = end_str.u64()
		if end >= file_size {
			end = file_size - 1
		}
	}
	
	if start > end || start >= file_size {
		return none
	}
	
	return RangeRequest{
		start: start
		end: end
		total: file_size
	}
}

//Streaming file transfer method
pub fn (mut c Context) file_stream(file_path string) http.Response {
	return c.file_stream_with_options(file_path, FileOptions{})
}

// Streaming file transfer method with options
pub fn (mut c Context) file_stream_with_options(file_path string, options FileOptions) http.Response {
	// security check
	if !is_safe_file_path(file_path) {
		c.status(403)
		return c.text('Forbidden')
	}
	
	// Check if the file exists
	if !os.exists(file_path) {
		c.status(404)
		return c.text('File Not Found')
	}
	
	// Check if it is a directory
	if os.is_dir(file_path) {
		c.status(400)
		return c.text('Cannot serve directory')
	}
	
	// Get file information
	file_info := os.stat(file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	file_size := u64(file_info.size)
	
	// Check whether the Range request is processed
	mut range_req := ?RangeRequest(none)
	if options.enable_range {
		if range_header := c.req.header.get_custom('Range') {
			range_req = parse_range_header(range_header, file_size)
		}
	}
	
	//Set basic response headers
	if options.content_type != '' {
		c.headers['Content-Type'] = options.content_type
	} else {
		content_type := get_file_content_type(file_path)
		c.headers['Content-Type'] = content_type
	}
	
	//Set cache related headers
	if options.last_modified {
		last_modified := format_http_date(file_info.mtime)
		c.headers['Last-Modified'] = last_modified
	}
	
	if options.max_age > 0 {
		c.headers['Cache-Control'] = 'public, max-age=${options.max_age}'
	} else if options.no_cache {
		c.headers['Cache-Control'] = 'no-cache'
	}
	
	//Set custom header
	for key, value in options.headers {
		c.headers[key] = value
	}
	
	// Handle Range request
	if range_request := range_req {
		return c.handle_range_request(file_path, range_request, options)
	}
	
	//Set the full file response header
	c.headers['Content-Length'] = file_size.str()
	c.headers['Accept-Ranges'] = 'bytes'
	
	//If the file is small, read it directly into memory
	if file_size <= options.stream_threshold {
		file_content := os.read_file(file_path) or {
			c.status(500)
			return c.text('Internal Server Error')
		}
		
		//Set ETag (only for small files)
		if options.etag {
			etag := generate_file_etag(file_content, file_info.mtime)
			c.headers['ETag'] = etag
			
			// Check If-None-Match
			if_none_match := c.req.header.get_custom('If-None-Match') or { '' }
			if if_none_match == etag {
				c.status(304)
				return c.build_headers_response('')
			}
		}
		
		c.status(200)
		return c.build_headers_response(file_content)
	}
	
	//Use streaming for large files
	c.status(200)
	return c.stream_large_file(file_path, file_size, options)
}

// Handle Range request
fn (mut c Context) handle_range_request(file_path string, range_req RangeRequest, options FileOptions) http.Response {
	content_length := range_req.end - range_req.start + 1
	
	//Set the Range response header
	c.status(206) // Partial Content
	c.headers['Content-Length'] = content_length.str()
	c.headers['Content-Range'] = 'bytes ${range_req.start}-${range_req.end}/${range_req.total}'
	c.headers['Accept-Ranges'] = 'bytes'
	
	//Read the file contents of the specified range
	mut file := os.open(file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	defer { file.close() }
	
	// jump to starting position
	file.seek(int(range_req.start), .start) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	//Read range contents
	mut buffer := []u8{len: int(content_length)}
	bytes_read := file.read(mut buffer) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	if bytes_read != int(content_length) {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	return c.build_headers_response(buffer.bytestr())
}

// Stream large files
fn (mut c Context) stream_large_file(file_path string, file_size u64, options FileOptions) http.Response {
	// Note: http.Response in V language does not directly support streaming
	//Here we implement a method of reading in chunks, but we still need to read the entire file into memory
	// For true streaming, support needs to be provided at the framework level
	
	mut file := os.open(file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	defer { file.close() }
	
	mut content := strings.new_builder(int(file_size))
	mut buffer := []u8{len: options.buffer_size}
	
	for {
		bytes_read := file.read(mut buffer) or { break }
		if bytes_read == 0 {
			break
		}
		content.write(buffer[..bytes_read]) or { break }
		if bytes_read < options.buffer_size {
			break
		}
	}
	
	return c.build_headers_response(content.str())
}

// Construct a response with headers
fn (mut c Context) build_headers_response(body string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Connection', 'keep-alive') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: body
	}
}

//Smart file serving method (automatically selects streaming or memory transfer)
pub fn (mut c Context) file_smart(file_path string) http.Response {
	return c.file_smart_with_options(file_path, FileOptions{})
}

//Smart file service method with options
pub fn (mut c Context) file_smart_with_options(file_path string, options FileOptions) http.Response {
	// Get file size
	if !os.exists(file_path) {
		c.status(404)
		return c.text('File Not Found')
	}
	
	file_info := os.stat(file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	file_size := u64(file_info.size)
	
	//Select the transfer method based on file size
	if file_size > options.stream_threshold {
		return c.file_stream_with_options(file_path, options)
	} else {
		return c.file_with_options(file_path, options)
	}
}

