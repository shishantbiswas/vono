module vono

import net.http

// BearerToken type - supports single token or multi-token configuration
pub type BearerToken = string | []string

// BearerAuthOptions structure - Bearer Auth configuration options
pub struct BearerAuthOptions {
pub:
	token         BearerToken                         //Token configuration (required)
	realm         string                              // WWW-Authenticate realm
	prefix        string       = 'Bearer'             // Authentication prefix, default "Bearer"
	header_name   string       = 'Authorization'      //Request header name, default "Authorization"
	hash_function ?fn (string) string                 // Hash function (for safe comparison)
	verify_token  ?fn (string, Context) bool          // Custom verification callback
}

// bearer_auth - Bearer Auth middleware factory function
// Return a ContextMiddleware for verifying Bearer Token
pub fn bearer_auth(options BearerAuthOptions) ContextMiddleware {
	return fn [options] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// Get the Authorization header
		auth_header := c.req.header.get_custom(options.header_name) or {
			return unauthorized_response(mut c, options.realm, 'Missing authorization header')
		}

		if auth_header.len == 0 {
			return unauthorized_response(mut c, options.realm, 'Missing authorization header')
		}

		// parse token
		token := extract_bearer_token(auth_header, options.prefix) or {
			return unauthorized_response(mut c, options.realm, 'Invalid token format')
		}

		//Verify token
		if !validate_bearer_token(token, options, c) {
			return unauthorized_response(mut c, options.realm, 'Invalid token')
		}

		// Store token in Context (for subsequent use)
		c.set('bearer_token', token)

		// Continue processing the request
		return next(mut c)
	}
}

// extract_bearer_token - extract token from Authorization header
fn extract_bearer_token(auth_header string, prefix string) !string {
	expected_prefix := '${prefix} '

	if !auth_header.starts_with(expected_prefix) {
		return error('Invalid authorization format')
	}

	token := auth_header[expected_prefix.len..].trim_space()

	if token.len == 0 {
		return error('Empty token')
	}

	return token
}

// validate_bearer_token - validate Bearer Token
fn validate_bearer_token(token string, options BearerAuthOptions, c Context) bool {
	// Prioritize using custom verification callbacks
	if verify_fn := options.verify_token {
		return verify_fn(token, c)
	}

	// Use configured token for verification
	match options.token {
		string {
			//Single token verification
			return secure_token_compare(token, options.token, options.hash_function)
		}
		[]string {
			//Multi-token verification
			for valid_token in options.token {
				if secure_token_compare(token, valid_token, options.hash_function) {
					return true
				}
			}
			return false
		}
	}
}

// secure_token_compare - secure token comparison (prevent timing attacks)
fn secure_token_compare(provided string, expected string, hash_fn ?fn (string) string) bool {
	// If a hash function is provided, hash the token first
	if hash_function := hash_fn {
		hashed_provided := hash_function(provided)
		hashed_expected := hash_function(expected)
		return constant_time_compare_bearer(hashed_provided, hashed_expected)
	}

	// Use constant time comparison directly
	return constant_time_compare_bearer(provided, expected)
}

// constant_time_compare_bearer - constant time string comparison to prevent timing attacks
fn constant_time_compare_bearer(a string, b string) bool {
	if a.len != b.len {
		return false
	}

	mut result := u8(0)
	for i := 0; i < a.len; i++ {
		result |= a[i] ^ b[i]
	}

	return result == 0
}

// unauthorized_response - returns 401 unauthorized response
fn unauthorized_response(mut c Context, realm string, message string) http.Response {
	c.status(401)

	// Set WWW-Authenticate header
	mut www_auth := 'Bearer'
	if realm.len > 0 {
		www_auth = 'Bearer realm="${realm}"'
	}
	c.headers['WWW-Authenticate'] = www_auth

	return c.json('{"error":"Unauthorized","message":"${message}"}')
}

// get_bearer_token - Get the verified Bearer Token from the Context
// This is a convenience method for getting the verified token in the handler
pub fn get_bearer_token(c Context) ?string {
	return c.get('bearer_token')
}
