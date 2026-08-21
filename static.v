module vono

import os
import net.http

// Static file service configuration
pub struct StaticOptions {
pub:
	root        string = './public'  //Static file root directory
	path        string = '/'         // URL path prefix
	index       string = 'index.html' //Default index file
	dotfiles    bool                  // Whether to allow access to files starting with .
	etag        bool   = true        // Whether to enable ETag
	last_modified bool = true        // Whether to enable Last-Modified
	max_age     int                  // Cache time (seconds)
	headers     map[string]string    // Custom response header
}

//Default static file configuration
pub fn default_static_options() StaticOptions {
	return StaticOptions{
		root: './public'
		path: '/'
		index: 'index.html'
		dotfiles: false
		etag: true
		last_modified: true
		max_age: 0
		headers: map[string]string{}
	}
}

//Static file serving middleware
pub fn serve_static(options StaticOptions) fn (mut Context, fn (mut Context) http.Response) http.Response {
	return fn [options] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// Check whether the request path matches the static file path
		if !c.path.starts_with(options.path) {
			return next(mut c)
		}
		
		//Extract file path
		mut file_path := c.path[options.path.len..]
		if file_path.starts_with('/') {
			file_path = file_path[1..]
		}
		if file_path == '' {
			file_path = options.index
		}
		
		//Debug information
		println('[DEBUG] Static file request:')
		println('  Path: ${c.path}')
		println('  Path prefix: ${options.path}')
		println('  File path: ${file_path}')
		println('  Root: ${options.root}')
		
		// Security check: prevent path traversal attacks
		// NOTE: File extension is not checked as this may be an API route rather than a static file
		// If the file does not exist, next(mut c) will be called later to continue processing.
		validation_options := PathValidationOptions{
			allow_absolute_paths: false
			allow_hidden_files: options.dotfiles
			check_file_extension: false  // Don't check extension, let file existence check decide
			allowed_base_paths: []
		}
		
		safe_file_path := validate_file_path(file_path, validation_options) or {
			println('  [DEBUG] Path validation failed: $err')
			// Path verification fails (such as containing dangerous patterns such as ..) and is passed to the next processor
			// Only return 403 for real security issues
			if err.msg().contains('Dangerous') {
				c.status(403)
				return c.text('Forbidden')
			}
			//Other cases (such as no extension) are passed to the next processor
			return next(mut c)
		}
		
		// Check if access point file is allowed
		if !options.dotfiles && file_path.starts_with('.') {
			println('  [DEBUG] Dot file access blocked')
			c.status(403)
			return c.text('Forbidden')
		}
		
		// Build the complete file path
		full_path := os.join_path(options.root, safe_file_path)
		println('  Full path: ${full_path}')
		
		// Check if the file exists
		if !os.exists(full_path) {
			println('  [DEBUG] File not found: ${full_path}')
			return next(mut c)
		}
		
		println('  [DEBUG] File found, serving...')
		
		// Check if it is a directory
		if os.is_dir(full_path) {
			//Try to provide index file
			index_path := os.join_path(full_path, options.index)
			if os.exists(index_path) {
				return serve_file(mut c, index_path, options)
			}
			//If there is no index file, return 404
			c.status(404)
			return c.text('Not Found')
		}
		
		// Provide files
		return serve_file(mut c, full_path, options)
	}
}

// Serve a single file
fn serve_file(mut c Context, file_path string, options StaticOptions) http.Response {
	//Read file content
	file_content := os.read_file(file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	// Get file information
	file_info := os.stat(file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	//Set status code
	c.status(200)
	
	//Set Content-Type
	content_type := get_safe_content_type(file_path)
	c.headers['Content-Type'] = content_type
	
	//Set Content-Length
	c.headers['Content-Length'] = file_content.len.str()
	
	//Set Last-Modified
	if options.last_modified {
		last_modified := format_http_date(file_info.mtime)
		c.headers['Last-Modified'] = last_modified
	}
	
	//Set ETag
	if options.etag {
		etag := generate_etag(file_content, file_info.mtime)
		c.headers['ETag'] = etag
		
		// Check If-None-Match
		if_none_match := c.req.header.get_custom('If-None-Match') or { '' }
		if if_none_match == etag {
			c.status(304)
			// Build response headers
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
	}
	
	//Set Cache-Control
	if options.max_age > 0 {
		c.headers['Cache-Control'] = 'public, max-age=${options.max_age}'
	} else {
		c.headers['Cache-Control'] = 'no-cache'
	}
	
	//Set custom header
	for key, value in options.headers {
		c.headers[key] = value
	}
	
	// Set Keep-Alive
	c.headers['Connection'] = 'keep-alive'
	
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

// Get Content-Type based on file extension
fn get_content_type(file_path string) string {
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

//Format HTTP date
fn format_http_date(time i64) string {
	// Simplified HTTP date formatting
	// Actual applications may require more complex implementations
	return time.str()
}

// Generate ETag
fn generate_etag(content string, mod_time i64) string {
	// Simplified ETag generation
	// Actual applications may require more complex hash algorithms
	return '"${content.len}-${mod_time}"'
}

// Convenience function: use the static file service with default configuration
pub fn serve_static_default() fn (mut Context, fn (mut Context) http.Response) http.Response {
	return serve_static(default_static_options())
}

// Convenience function: static file service in the specified root directory
pub fn serve_static_root(root string) fn (mut Context, fn (mut Context) http.Response) http.Response {
	options := StaticOptions{
		root: root
		path: '/'
		index: 'index.html'
		dotfiles: false
		etag: true
		last_modified: true
		max_age: 0
		headers: map[string]string{}
	}
	return serve_static(options)
}

// Convenience function: static file service with specified path prefix
pub fn serve_static_path(path string, root string) fn (mut Context, fn (mut Context) http.Response) http.Response {
	options := StaticOptions{
		root: root
		path: path
		index: 'index.html'
		dotfiles: false
		etag: true
		last_modified: true
		max_age: 0
		headers: map[string]string{}
	}
	return serve_static(options)
} 