// middleware_demo.v - middleware usage example
// This example shows the basic usage of all built-in middleware of the vono framework
module main

import vono
import net.http
import time

fn main() {
	mut app := vono.Vono.new()
	
	// ============================================================================
	// 1. CORS middleware example
	// ============================================================================
	//Basic usage: allow all sources
	app.use(vono.cors())
	
	// Advanced configuration example (commented out to avoid duplication)
	// app.use(vono.cors(vono.CorsOptions{
	// origin: 'https://example.com' // Only allow specific domain names
	// credentials: true // Allow credentials to be carried
	// max_age: 600 // Preflight request cache for 10 minutes
	//     allow_methods: ['GET', 'POST', 'PUT', 'DELETE']
	//     allow_headers: ['Content-Type', 'Authorization']
	// }))
	
	// ============================================================================
	// 2. Compression middleware example
	// ============================================================================
	// Use gzip compression (default)
	app.use(vono.gzip())
	
	// Or use deflate compression
	// app.use(vono.deflate_compress())
	
	// Custom compression configuration
	// app.use(vono.compress(vono.CompressOptions{
	//     encoding: .gzip
	// threshold: 2048 // Only compress responses larger than 2KB
	// level: 9 // Highest compression level
	// }))
	
	// ============================================================================
	// 3. Security response header middleware example
	// ============================================================================
	app.use(vono.secure_headers())
	
	// ============================================================================
	// 4. Request ID middleware example
	// ============================================================================
	app.use(vono.request_id())
	
	// ============================================================================
	// 5. Request timing middleware example
	// ============================================================================
	app.use(vono.timing())
	
	// ============================================================================
	// 6. Current limiting middleware example
	// ============================================================================
	//Create memory storage
	store := vono.MemoryStore.new()
	
	//Apply throttling middleware: up to 100 requests per minute
	app.use(vono.rate_limiter(vono.RateLimitOptions{
		store: store
		window_ms: 60000  // 1 minute
		limit: 100        // Max 100 requests
		headers: true     //Add current limiting response header
	}))
	
	// ============================================================================
	//Routing example
	// ============================================================================
	
	//Basic routing
	app.get('/', fn (mut c vono.Context) http.Response {
		return c.json('{"message": "Welcome to vono middleware demo!"}')
	})
	
	// Get request information
	app.get('/info', fn (mut c vono.Context) http.Response {
		// Get request ID
		request_id := c.get('request_id') or { 'unknown' }
		// Get client IP
		client_ip := c.get_client_ip()
		
		return c.json('{"request_id": "${request_id}", "client_ip": "${client_ip}"}')
	})
	
	// ============================================================================
	// 7. Cookie Helper example
	// ============================================================================
	
	//Set Cookie
	app.get('/cookie/set', fn (mut c vono.Context) http.Response {
		//Set normal cookies
		vono.set_cookie(mut c, 'session_id', 'abc123', vono.CookieOptions{
			http_only: true
			secure: false  // Set development environment to false
			max_age: 3600  // 1 hour
			path: '/'
		})
		
		return c.json('{"message": "Cookie set successfully"}')
	})
	
	// Get Cookie
	app.get('/cookie/get', fn (mut c vono.Context) http.Response {
		if session_id := vono.get_cookie(c, 'session_id') {
			return c.json('{"session_id": "${session_id}"}')
		}
		return c.json('{"error": "Cookie not found"}')
	})
	
	// Get all cookies
	app.get('/cookie/all', fn (mut c vono.Context) http.Response {
		cookies := vono.get_all_cookies(c)
		mut parts := []string{}
		for name, value in cookies {
			parts << '"${name}": "${value}"'
		}
		return c.json('{${parts.join(", ")}}')
	})
	
	//Delete Cookie
	app.get('/cookie/delete', fn (mut c vono.Context) http.Response {
		vono.delete_cookie(mut c, 'session_id')
		return c.json('{"message": "Cookie deleted"}')
	})
	
	//Signed Cookie Example
	app.get('/cookie/signed/set', fn (mut c vono.Context) http.Response {
		secret := 'my-secret-key-for-signing'
		vono.set_signed_cookie(mut c, 'user_data', 'user123', secret) or {
			c.status(500)
			return c.json('{"error": "Failed to set signed cookie"}')
		}
		return c.json('{"message": "Signed cookie set successfully"}')
	})
	
	app.get('/cookie/signed/get', fn (mut c vono.Context) http.Response {
		secret := 'my-secret-key-for-signing'
		user_data := vono.get_signed_cookie(c, 'user_data', secret) or {
			c.status(400)
			return c.json('{"error": "Invalid or missing signed cookie"}')
		}
		return c.json('{"user_data": "${user_data}"}')
	})
	
	// ============================================================================
	// 8. JWT middleware example
	// ============================================================================
	
	// Generate JWT Token
	app.post('/auth/login', fn (mut c vono.Context) http.Response {
		// In actual applications, user credentials should be verified here
		secret := 'my-jwt-secret-key'
		
		//Create JWT payload
		payload := vono.JwtPayload{
			sub: 'user123'
			iss: 'vono-demo'
			exp: time.now().unix() + 3600  // Expires in 1 hour
			iat: time.now().unix()
			claims: {
				'role': 'admin'
				'name': 'John Doe'
			}
		}
		
		//Sign JWT
		token := vono.sign_jwt(payload, secret, .hs256) or {
			c.status(500)
			return c.json('{"error": "Failed to generate token"}')
		}
		
		return c.json('{"token": "${token}"}')
	})
	
	//Verify JWT Token (manual verification example)
	app.get('/auth/verify', fn (mut c vono.Context) http.Response {
		secret := 'my-jwt-secret-key'
		
		// Get token from Authorization header
		auth_header := c.req.header.get_custom('Authorization') or {
			c.status(401)
			return c.json('{"error": "Missing Authorization header"}')
		}
		
		if !auth_header.starts_with('Bearer ') {
			c.status(401)
			return c.json('{"error": "Invalid Authorization format"}')
		}
		
		token := auth_header[7..]
		
		//Verify token
		payload := vono.verify_jwt(token, secret, .hs256) or {
			c.status(401)
			return c.json('{"error": "Invalid token: ${err}"}')
		}
		
		return c.json('{"sub": "${payload.sub}", "iss": "${payload.iss}"}')
	})
	
	// ============================================================================
	// 9. Bearer Auth middleware example (protecting specific routes)
	// ============================================================================
	
	//Create a protected sub-application
	mut protected_app := vono.Vono.new()
	
	// Apply Bearer Auth middleware
	protected_app.use(vono.bearer(vono.BearerAuthOptions{
		token: 'my-api-token'  // Simple static token
		realm: 'Protected API'
	}))
	
	protected_app.get('/data', fn (mut c vono.Context) http.Response {
		// Get the verified token
		token := vono.get_bearer_token(c) or { 'unknown' }
		return c.json('{"message": "Protected data", "token": "${token}"}')
	})
	
	//Mount the protected route
	app.route('/api', mut protected_app)
	
	// ============================================================================
	// 10. Request verification example
	// ============================================================================
	
	// JSON body validation
	app.post('/users', 
		vono.validate_json(vono.v_object({
			'name':  vono.v_string().required().min(2).max(50)
			'email': vono.v_string().required().pattern(r'^[\w\.-]+@[\w\.-]+\.\w+$')
			'age':   vono.v_int().min(0).max(150)
		})),
		fn (mut c vono.Context) http.Response {
			// Get verified data
			data := vono.get_validated_data(c)
			name := data['name'] or { '' }
			email := data['email'] or { '' }
			
			return c.json('{"message": "User created", "name": "${name}", "email": "${email}"}')
		}
	)
	
	// Query parameter verification
	app.get('/search',
		vono.validate_query(vono.v_object({
			'q':    vono.v_string().required().min(1)
			'page': vono.v_int().min(1)
			'size': vono.v_int().min(1).max(100)
		})),
		fn (mut c vono.Context) http.Response {
			q := vono.get_validated_field(c, 'q') or { '' }
			page := vono.get_validated_field(c, 'page') or { '1' }
			
			return c.json('{"query": "${q}", "page": ${page}}')
		}
	)
	
	// ============================================================================
	// 11. Middleware combination example
	// ============================================================================
	
	// Combine multiple middlewares
	combined := vono.combine_middlewares([
		vono.cors_middleware(),
		vono.secure_headers(),
		vono.timing(),
	])
	
	//Create a sub-application using composite middleware
	mut combined_app := vono.Vono.new()
	combined_app.use(combined)
	
	combined_app.get('/test', fn (mut c vono.Context) http.Response {
		duration := c.get('request_duration_ms') or { '0' }
		return c.json('{"message": "Combined middleware test", "duration_ms": "${duration}"}')
	})
	
	app.route('/combined', mut combined_app)
	
	// ============================================================================
	// Start the server
	// ============================================================================
	
	println('=== vono Middleware Demo ===')
	println('')
	println('Available endpoints:')
	println('  GET  /                    - Welcome message')
	println('  GET  /info                - Request info (ID, IP)')
	println('')
	println('Cookie endpoints:')
	println('  GET  /cookie/set          - Set a cookie')
	println('  GET  /cookie/get          - Get a cookie')
	println('  GET  /cookie/all          - Get all cookies')
	println('  GET  /cookie/delete       - Delete a cookie')
	println('  GET  /cookie/signed/set   - Set a signed cookie')
	println('  GET  /cookie/signed/get   - Get a signed cookie')
	println('')
	println('Auth endpoints:')
	println('  POST /auth/login          - Get JWT token')
	println('  GET  /auth/verify         - Verify JWT token')
	println('  GET  /api/data            - Protected endpoint (Bearer token: my-api-token)')
	println('')
	println('Validation endpoints:')
	println('  POST /users               - Create user (JSON body validation)')
	println('  GET  /search?q=xxx        - Search (query validation)')
	println('')
	println('Combined middleware:')
	println('  GET  /combined/test       - Test combined middlewares')
	println('')
	println('Starting server on http://localhost:3000')
	println('')
	
	app.listen(':3000')
}
