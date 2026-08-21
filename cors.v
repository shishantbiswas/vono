module hono

import net.http

// CorsOrigin type - supports multiple source configuration methods
// Can be a string (single domain name or "*"), string array (multiple domain names) or callback function
pub type CorsOrigin = string | []string | fn (string, Context) string

// CorsOptions structure - CORS configuration options
pub struct CorsOptions {
pub:
	origin         CorsOrigin = '*'  // Allowed sources, all are allowed by default
	allow_methods  []string   = ['GET', 'HEAD', 'PUT', 'POST', 'DELETE', 'PATCH']
	allow_headers  []string   = []   // Allowed request headers
	expose_headers []string   = []   //Exposed response headers
	max_age        int             // Preflight request cache time (seconds), default 0
	credentials    bool            // Whether to allow credentials, default false
}

// cors - CORS middleware factory function
// Return a ContextMiddleware for handling cross-domain requests
pub fn cors(options ...CorsOptions) ContextMiddleware {
	opts := if options.len > 0 { options[0] } else { CorsOptions{} }
	
	return fn [opts] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// Get the Origin header of the request
		origin := c.req.header.get_custom('Origin') or { '' }
		
		// If there is no Origin header, continue processing directly
		if origin.len == 0 {
			return next(mut c)
		}
		
		// Calculate allowed Origins
		allowed_origin := get_allowed_origin(origin, opts.origin, c)
		
		// If Origin is not allowed, continue processing directly (without setting CORS header)
		if allowed_origin.len == 0 {
			return next(mut c)
		}
		
		// Set Access-Control-Allow-Origin
		c.headers['Access-Control-Allow-Origin'] = allowed_origin
		
		// Set Access-Control-Allow-Credentials
		if opts.credentials {
			c.headers['Access-Control-Allow-Credentials'] = 'true'
		}
		
		// Set Access-Control-Expose-Headers
		if opts.expose_headers.len > 0 {
			c.headers['Access-Control-Expose-Headers'] = opts.expose_headers.join(', ')
		}
		
		// Check if it is a preflight request (OPTIONS)
		if c.req.method == http.Method.options {
			return handle_preflight(mut c, opts)
		}
		
		// Non-preflight request, continue processing
		return next(mut c)
	}
}

// get_allowed_origin - calculates the allowed Origin based on configuration
fn get_allowed_origin(request_origin string, origin_config CorsOrigin, c Context) string {
	match origin_config {
		string {
			//Single string configuration
			if origin_config == '*' {
				// Wildcard, allow all sources
				return '*'
			}
			//Specific domain name, check whether it matches
			if origin_config == request_origin {
				return request_origin
			}
			return ''
		}
		[]string {
			//Multiple domain name configuration, check whether the request source is in the list
			for allowed in origin_config {
				if allowed == '*' {
					return '*'
				}
				if allowed == request_origin {
					return request_origin
				}
			}
			return ''
		}
		fn (string, Context) string {
			//Callback function configuration
			return origin_config(request_origin, c)
		}
	}
}

// handle_preflight - handles OPTIONS preflight requests
fn handle_preflight(mut c Context, opts CorsOptions) http.Response {
	// Set Access-Control-Allow-Methods
	if opts.allow_methods.len > 0 {
		c.headers['Access-Control-Allow-Methods'] = opts.allow_methods.join(', ')
	}
	
	// Set Access-Control-Allow-Headers
	if opts.allow_headers.len > 0 {
		c.headers['Access-Control-Allow-Headers'] = opts.allow_headers.join(', ')
	} else {
		// If not configured, try to use Access-Control-Request-Headers in the request
		if request_headers := c.req.header.get_custom('Access-Control-Request-Headers') {
			c.headers['Access-Control-Allow-Headers'] = request_headers
		}
	}
	
	// Set Access-Control-Max-Age
	if opts.max_age > 0 {
		c.headers['Access-Control-Max-Age'] = opts.max_age.str()
	}
	
	// Return 204 No Content
	c.status(204)
	
	mut headers := http.new_header()
	headers.add_custom('Connection', 'keep-alive') or {}
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	
	return http.Response{
		status_code: c.status_code
		header: headers
		body: ''
	}
}
