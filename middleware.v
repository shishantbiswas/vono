// middleware.v - middleware unified export module
// This module provides a unified access interface for all built-in middleware
// Usage: After importing vono, it can be called through vono.cors(), vono.jwt_middleware(), etc.
module vono

import net.http
import time
import rand

// ============================================================================
// Middleware export instructions
// ============================================================================
//
// This framework provides the following 9 built-in middleware:
//
// 1. CORS middleware (cors.v)
//    - cors(options ...CorsOptions) ContextMiddleware
// - used to handle cross-domain resource sharing
//
// 2. Cookie Helper (cookie.v)
//    - get_cookie(c Context, name string) ?string
//    - get_all_cookies(c Context) map[string]string
//    - set_cookie(mut c Context, name string, value string, options ...CookieOptions)
//    - delete_cookie(mut c Context, name string, options ...CookieOptions)
//    - set_signed_cookie(mut c Context, name string, value string, secret string, options ...CookieOptions) !
//    - get_signed_cookie(c Context, name string, secret string) !string
//
// 3. JWT middleware (jwt.v)
//    - jwt_middleware(options JwtOptions) ContextMiddleware
//    - sign_jwt(payload JwtPayload, secret string, alg JwtAlgorithm) !string
//    - verify_jwt(token string, secret string, alg JwtAlgorithm) !JwtPayload
//    - decode_jwt(token string) !JwtPayload
//    - get_jwt_payload(c Context) ?JwtPayload
//    - get_jwt_claim(c Context, key string) ?string
//
// 4. Bearer Auth middleware (bearer_auth.v)
//    - bearer_auth(options BearerAuthOptions) ContextMiddleware
//    - get_bearer_token(c Context) ?string
//
// 5. Compression middleware (compress.v)
//    - compress(options ...CompressOptions) ContextMiddleware
//    - decompress_gzip(data []u8) ![]u8
//    - decompress_deflate(data []u8) ![]u8
//
// 6. Rate limiting middleware (rate_limit.v)
//    - rate_limit(options RateLimitOptions) ContextMiddleware
//    - MemoryStore.new() &MemoryStore
//    - get_rate_limit_info(c Context) ?RateLimitInfo
//
// 7. Request verification system (validator.v)
//    - validator(target ValidationTarget, schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware
//    - v_string() StringSchema
//    - v_int() IntSchema
//    - v_float() FloatSchema
//    - v_bool() BoolSchema
//    - v_array(items Schema) ArraySchema
//    - v_object(properties map[string]Schema) ObjectSchema
//    - get_validated_data(c Context) map[string]string
//    - get_validated_json(c Context) ?string
//    - get_validated_field(c Context, field string) ?string
//
// 8. WebSocket Helper (websocket.v)
//    - upgrade_websocket(factory WSHandlerFactory, options ...WebSocketOptions) fn (mut Context) http.Response
// - Used to handle WebSocket connection upgrades and event handling
//
//    Types:
// - WebSocketOptions: configuration options (ping_interval, max_message_size, timeout, protocols)
// - WSReadyState: connection state enumeration (connecting, open, closing, closed)
// - WSMessageEvent: message event structure
// - WSCloseEvent: close event structure
// - WSContext: WebSocket context, provides send/send_bytes/send_json/close method
// - WSEvents: event handler configuration (on_open, on_message, on_close, on_error)
// - WSHandlerFactory: processor factory function type
//
//    Constants:
//    - ws_opcode_text, ws_opcode_binary, ws_opcode_close, ws_opcode_ping, ws_opcode_pong
//    - ws_close_normal, ws_close_going_away, ws_close_protocol_error, etc.
//
//    Helper Functions:
// - is_websocket_upgrade(c Context) bool: Check whether it is a WebSocket upgrade request
// - compute_accept_key(key string) string: compute Sec-WebSocket-Accept
// - encode_ws_frame(opcode u8, payload []u8, masked bool) []u8: encode WebSocket frame
// - decode_ws_frame(data []u8) !WSFrame: Decode WebSocket frame
//
// 9. Swagger UI middleware (swagger.v)
//    - swagger_ui(options ...SwaggerUIOptions) fn (mut Context) http.Response
//    - swagger_ui_handler(options ...SwaggerUIOptions) fn (mut Context) http.Response
// - used to provide an interactive API documentation interface
//
//    Types:
// - SwaggerUIOptions: configuration options
// - url: OpenAPI documentation URL (default: '/doc')
// - title: page title (default: 'API Documentation')
// - deep_linking: enable deep linking (default: true)
// - display_request_duration: display request duration (default: true)
// - default_models_expand_depth: model expansion depth (default: 1)
// - doc_expansion: document expansion method ('list', 'full', 'none')
// - filter: enable filtering
// - show_extensions: show extensions
// - show_common_extensions: Show common extensions (default: true)
// - try_it_out_enabled: enable Try it out (default: true)
// - custom_css: Custom CSS
// - custom_js: custom JavaScript
// - custom_css_url: Custom CSS URL
// - custom_js_url: Custom JavaScript URL
//
// OpenAPI documentation related (openapi.v):
// - OpenAPIDocument: OpenAPI document main structure
// - OpenAPIBuilder: Streaming API builder
// - app.doc(path, spec): Register OpenAPI document route
// - app.doc_fn(path, builder): Register the document route using the builder function
// - app.get_routes(): Get all routing information of the application
//
// Usage example:
// // 1. Create OpenAPI documentation
//      spec := vono.OpenAPIBuilder.new()
//          .openapi('3.0.0')
//          .title('My API')
//          .version('1.0.0')
//          .description('API description')
//          .server('https://api.example.com', 'Production')
//          .path('/users')
//              .get(vono.OpenAPIOperation{
//                  summary: 'Get all users'
//                  responses: { '200': vono.OpenAPIResponse{ description: 'Success' } }
//              })
//              .done()
//          .build()!
//
// // 2. Register OpenAPI document route
//      app.doc('/doc', spec)
//
// // 3. Register Swagger UI route
//      app.get('/ui', vono.swagger_ui(vono.SwaggerUIOptions{ url: '/doc' }))
//
// ============================================================================

// ============================================================================
//Middleware shortcut alias function
// Provide a more concise calling method, consistent with the Vono.js style
// ============================================================================

// cors_middleware - alias function for CORS middleware
// Usage example:
//   app.use(vono.cors_middleware())
//   app.use(vono.cors_middleware(CorsOptions{ origin: 'https://example.com' }))
pub fn cors_middleware(options ...CorsOptions) ContextMiddleware {
	return cors(...options)
}

// jwt_auth - Alias ​​function for JWT authentication middleware
// Usage example:
//   app.use('/api/*', vono.jwt_auth(JwtOptions{ secret: 'my-secret' }))
pub fn jwt_auth(options JwtOptions) ContextMiddleware {
	return jwt_middleware(options)
}

// bearer - Alias ​​function of Bearer Token authentication middleware
// Usage example:
//   app.use('/api/*', vono.bearer(BearerAuthOptions{ token: 'my-token' }))
pub fn bearer(options BearerAuthOptions) ContextMiddleware {
	return bearer_auth(options)
}

// gzip - alias function for compression middleware (default uses gzip)
// Usage example:
//   app.use(vono.gzip())
pub fn gzip(options ...CompressOptions) ContextMiddleware {
	if options.len > 0 {
		return compress(options[0])
	}
	return compress(CompressOptions{
		encoding: .gzip
	})
}

// deflate_compress - alias function for compression middleware (using deflate)
// Usage example:
//   app.use(vono.deflate_compress())
pub fn deflate_compress(options ...CompressOptions) ContextMiddleware {
	if options.len > 0 {
		return compress(options[0])
	}
	return compress(CompressOptions{
		encoding: .deflate
	})
}

// rate_limiter - Alias ​​function of rate limiting middleware
// Usage example:
//   store := MemoryStore.new()
//   app.use(vono.rate_limiter(RateLimitOptions{ store: store, limit: 100 }))
pub fn rate_limiter(options RateLimitOptions) ContextMiddleware {
	return rate_limit(options)
}

// validate_json - Convenience function for JSON body validation middleware
// Usage example:
//   app.post('/users', vono.validate_json(v_object({
//       'name': v_string().required()
//       'email': v_string().required()
//   })), handler)
pub fn validate_json(schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	return validator(.json, schema, ...options)
}

// validate_query - Convenience function for Query parameter validation middleware
// Usage example:
//   app.get('/search', vono.validate_query(v_object({
//       'q': v_string().required()
//       'page': v_int().min(1)
//   })), handler)
pub fn validate_query(schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	return validator(.query, schema, ...options)
}

// validate_params - Convenience function for Path parameter validation middleware
// Usage example:
//   app.get('/users/:id', vono.validate_params(v_object({
//       'id': v_int().required().min(1)
//   })), handler)
pub fn validate_params(schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	return validator(.param, schema, ...options)
}

// validate_headers - Convenience function for Header validation middleware
// Usage example:
//   app.use(vono.validate_headers(v_object({
//       'X-API-Key': v_string().required()
//   })))
pub fn validate_headers(schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	return validator(.header, schema, ...options)
}

// validate_form - Convenience function for Form data validation middleware
// Usage example:
//   app.post('/login', vono.validate_form(v_object({
//       'username': v_string().required()
//       'password': v_string().required().min(6)
//   })), handler)
pub fn validate_form(schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	return validator(.form, schema, ...options)
}

// ============================================================================
//Middleware combination tool
// ============================================================================

// combine_middlewares - combines multiple middlewares into one
// Usage example:
//   combined := vono.combine_middlewares([
//       vono.cors_middleware(),
//       vono.gzip(),
//       vono.rate_limiter(options)
//   ])
//   app.use(combined)
pub fn combine_middlewares(middlewares []ContextMiddleware) ContextMiddleware {
	return fn [middlewares] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// Recursive execution middleware chain
		return execute_middleware_chain(0, middlewares, mut c, next)
	}
}

// execute_middleware_chain - recursive execution middleware chain
fn execute_middleware_chain(idx int, middlewares []ContextMiddleware, mut c Context, final_next fn (mut Context) http.Response) http.Response {
	if idx >= middlewares.len {
		return final_next(mut c)
	}
	
	mw := middlewares[idx]
	return mw(mut c, fn [idx, middlewares, final_next] (mut ctx Context) http.Response {
		return execute_middleware_chain(idx + 1, middlewares, mut ctx, final_next)
	})
}

// ============================================================================
// Pre-configured middleware factory
// ============================================================================

// secure_headers - secure response header middleware
//Add commonly used security response headers
pub fn secure_headers() ContextMiddleware {
	return fn (mut c Context, next fn (mut Context) http.Response) http.Response {
		//Set security response header
		c.headers['X-Content-Type-Options'] = 'nosniff'
		c.headers['X-Frame-Options'] = 'DENY'
		c.headers['X-XSS-Protection'] = '1; mode=block'
		c.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
		
		return next(mut c)
	}
}

// request_id - request ID middleware
// Generate a unique ID for each request
pub fn request_id() ContextMiddleware {
	return fn (mut c Context, next fn (mut Context) http.Response) http.Response {
		// Check if there is already a request ID
		existing_id := c.req.header.get_custom('X-Request-ID') or { '' }
		
		request_id := if existing_id.len > 0 {
			existing_id
		} else {
			generate_request_id()
		}
		
		// Store in Context
		c.set('request_id', request_id)
		
		//Add to response header
		c.headers['X-Request-ID'] = request_id
		
		return next(mut c)
	}
}

// generate_request_id - Generate a simple request ID
fn generate_request_id() string {
	timestamp := time.now().unix_milli()
	random_part := rand.u32()
	return '${timestamp:x}-${random_part:08x}'
}

// timing - request timing middleware
// Record request processing time
pub fn timing() ContextMiddleware {
	return fn (mut c Context, next fn (mut Context) http.Response) http.Response {
		start := time.now()
		
		//Perform subsequent processing
		response := next(mut c)
		
		// Calculation time
		duration := time.since(start)
		duration_ms := duration.milliseconds()
		
		// Store in Context
		c.set('request_duration_ms', duration_ms.str())
		
		//Add to response header
		c.headers['X-Response-Time'] = '${duration_ms}ms'
		
		return response
	}
}


// ============================================================================
// Swagger UI middleware export
// ============================================================================
//
// Swagger UI middleware provides an interactive API document interface and supports the OpenAPI 3.0/3.1 specification.
//The main functions are exported through swagger.v and openapi.v files, including:
//
// Core function:
// - swagger_ui(options...) - Create a Swagger UI handler
// - swagger_ui_handler(options...) - Alias ​​for swagger_ui
// - app.doc(path, spec) - Register the OpenAPI document route
// - app.doc_fn(path, builder) - Register the document route using the builder function
//
//Type definition:
// - SwaggerUIOptions - Swagger UI configuration options
// - OpenAPIDocument - OpenAPI document main structure
// - OpenAPIBuilder - Streaming API builder
// - OpenAPIInfo, OpenAPIServer, OpenAPIPathItem, OpenAPIOperation, etc.
//
// Usage example:
// // Create OpenAPI documentation
//   spec := vono.OpenAPIBuilder.new()
//       .openapi('3.0.0')
//       .title('My API')
//       .version('1.0.0')
//       .build()!
//
// // Register documents and UI routes
//   app.doc('/doc', spec)
//   app.get('/ui', vono.swagger_ui(vono.SwaggerUIOptions{ url: '/doc' }))
//
//With custom options:
//   app.get('/swagger', vono.swagger_ui(vono.SwaggerUIOptions{
//       url: '/api/doc'
//       title: 'My API Documentation'
//       deep_linking: true
//       display_request_duration: true
//       doc_expansion: 'list'
//       try_it_out_enabled: true
//   }))
// ============================================================================

// swagger - short alias for the Swagger UI handler
// Usage example:
//   app.get('/docs', vono.swagger(vono.SwaggerUIOptions{ url: '/doc' }))
pub fn swagger(options ...SwaggerUIOptions) fn (mut Context) http.Response {
	return swagger_ui(...options)
}

// openapi_ui - Another alias for the Swagger UI handler
// Usage example:
//   app.get('/api-docs', vono.openapi_ui(vono.SwaggerUIOptions{ url: '/openapi.json' }))
pub fn openapi_ui(options ...SwaggerUIOptions) fn (mut Context) http.Response {
	return swagger_ui(...options)
}


// ============================================================================
// WebSocket Helper export
// ============================================================================
//
// WebSocket Helper provides server-side WebSocket support and implements the RFC 6455 protocol.
//The main functions are exported through the websocket.v file, including:
//
// Core function:
// - upgrade_websocket(factory, options...) - Create WebSocket upgrade handler
// - is_websocket_upgrade(c) - Check if it is a WebSocket upgrade request
//
//Type definition:
// - WebSocketOptions - configuration options
// - WSReadyState - connection state enumeration
// - WSMessageEvent - message event
// - WSCloseEvent - close event
// - WSContext - WebSocket context
// - WSEvents - event handler configuration
// - WSHandlerFactory - Processor factory type
//
// constants:
// - ws_opcode_* - WebSocket opcodes
// - ws_close_* - WebSocket close status code
//
// Frame processing function:
// - encode_ws_frame() - Encode WebSocket frame
// - decode_ws_frame() - Decode WebSocket frames
// - compute_accept_key() - compute the handshake response key
//
// Usage example:
//   app.get('/ws', vono.upgrade_websocket(fn (c vono.Context) vono.WSEvents {
//       return vono.WSEvents{
//           on_open: fn (mut ws vono.WSContext) {
//               ws.send('Welcome!') or {}
//           }
//           on_message: fn (event vono.WSMessageEvent, mut ws vono.WSContext) {
//               ws.send('Echo: ${event.data}') or {}
//           }
//           on_close: fn (event vono.WSCloseEvent, mut ws vono.WSContext) {
//               println('Closed: ${event.code}')
//           }
//       }
//   }))
//
//With configuration options:
//   app.get('/ws', vono.upgrade_websocket(factory, vono.WebSocketOptions{
// ping_interval: 30000 // 30 seconds ping interval
// max_message_size: 1048576 // 1MB maximum message size
// timeout: 60000 // 60 seconds timeout
// protocols: ['chat', 'json'] // Supported sub-protocols
//   }))
// ============================================================================

// websocket - Alias ​​function for WebSocket upgrade handler
// Usage example:
//   app.get('/ws', vono.websocket(fn (c vono.Context) vono.WSEvents {
//       return vono.WSEvents{
//           on_message: fn (event vono.WSMessageEvent, mut ws vono.WSContext) {
//               ws.send('Echo: ${event.data}') or {}
//           }
//       }
//   }))
pub fn websocket(factory WSHandlerFactory, options ...WebSocketOptions) fn (mut Context) http.Response {
	return upgrade_websocket(factory, ...options)
}

// ws - Short alias for the WebSocket upgrade handler
// Usage example:
//   app.get('/ws', vono.ws(handler_factory))
pub fn ws(factory WSHandlerFactory, options ...WebSocketOptions) fn (mut Context) http.Response {
	return upgrade_websocket(factory, ...options)
}

// is_ws_upgrade - Checks if the request is an alias for a WebSocket upgrade request
// Usage example:
//   if vono.is_ws_upgrade(c) {
//       // Handle WebSocket upgrade
//   }
pub fn is_ws_upgrade(c Context) bool {
	return is_websocket_upgrade(c)
}
