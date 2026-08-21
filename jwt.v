module vono

import crypto.sha256
import crypto.sha512
import encoding.base64
import net.http
import time
import x.json2

// JwtAlgorithm enum - supported JWT signature algorithms
pub enum JwtAlgorithm {
	hs256
	hs384
	hs512
}

// JwtVerifyOptions structure - JWT verification options
pub struct JwtVerifyOptions {
pub:
	iss string        // Issuer verification
	exp bool = true   //Verify expiration time
	nbf bool = true   // Verification effective time
	iat bool = true   //Verify issuance time
}

// JwtOptions structure - JWT middleware configuration options
pub struct JwtOptions {
pub:
	secret         string                              //Key (required)
	alg            JwtAlgorithm = .hs256              // algorithm
	cookie         string                              //Read token from cookie
	header_name    string       = 'Authorization'     //Request header name
	verify_options JwtVerifyOptions = JwtVerifyOptions{}
}

// JwtPayload structure - JWT payload
pub struct JwtPayload {
pub mut:
	sub    string              // Subject
	iss    string              // Issuer
	aud    string              // Audience
	exp    i64                 // Expiration Time (Unix timestamp)
	nbf    i64                 // Not Before (Unix timestamp)
	iat    i64                 // Issued At (Unix timestamp)
	jti    string              // JWT ID
	claims map[string]string   //Custom declaration
}

// JwtHeader structure - JWT header
struct JwtHeader {
	alg string
	typ string
}

// JwtToken structure - complete JWT Token
struct JwtToken {
	header    JwtHeader
	payload   JwtPayload
	signature string
}

// base64url_encode - Base64URL encoding (without padding)
fn base64url_encode(data []u8) string {
	encoded := base64.encode(data)
	// Convert to URL safe format and remove padding
	return encoded.replace('+', '-').replace('/', '_').trim_right('=')
}

// base64url_decode - Base64URL decoding
fn base64url_decode(data string) ![]u8 {
	//Convert back to standard Base64 format
	mut standard := data.replace('-', '+').replace('_', '/')
	// add padding
	padding := (4 - standard.len % 4) % 4
	for _ in 0 .. padding {
		standard += '='
	}
	return base64.decode(standard)
}

// hmac_sha256 - HMAC-SHA256 signature
fn hmac_sha256(message []u8, secret []u8) []u8 {
	block_size := 64 // SHA256 block size

	// handle the key
	mut key := secret.clone()
	if key.len > block_size {
		// If the key is too long, hash it first
		hash_result := sha256.sum(key)
		key = []u8{len: 32}
		for i := 0; i < 32; i++ {
			key[i] = hash_result[i]
		}
	}
	// Pad to block size
	for key.len < block_size {
		key << u8(0)
	}

	// Calculate K' ⊕ ipad
	mut i_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		i_key_pad[i] = key[i] ^ u8(0x36)
	}

	// Calculate K' ⊕ opad
	mut o_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		o_key_pad[i] = key[i] ^ u8(0x5c)
	}

	// Calculate internal hash: H((K' ⊕ ipad) || m)
	mut inner_data := i_key_pad.clone()
	inner_data << message
	inner_hash_result := sha256.sum(inner_data)
	mut inner_hash := []u8{len: 32}
	for i := 0; i < 32; i++ {
		inner_hash[i] = inner_hash_result[i]
	}

	// Calculate outer hash: H((K' ⊕ opad) || inner_hash)
	mut outer_data := o_key_pad.clone()
	outer_data << inner_hash
	outer_hash_result := sha256.sum(outer_data)
	mut result := []u8{len: 32}
	for i := 0; i < 32; i++ {
		result[i] = outer_hash_result[i]
	}

	return result
}


// hmac_sha384 - HMAC-SHA384 signature
fn hmac_sha384(message []u8, secret []u8) []u8 {
	block_size := 128 // SHA384 block size

	// handle the key
	mut key := secret.clone()
	if key.len > block_size {
		// If the key is too long, hash it first
		hash_result := sha512.sum384(key)
		key = []u8{len: 48}
		for i := 0; i < 48; i++ {
			key[i] = hash_result[i]
		}
	}
	// Pad to block size
	for key.len < block_size {
		key << u8(0)
	}

	// Calculate K' ⊕ ipad
	mut i_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		i_key_pad[i] = key[i] ^ u8(0x36)
	}

	// Calculate K' ⊕ opad
	mut o_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		o_key_pad[i] = key[i] ^ u8(0x5c)
	}

	// Calculate internal hash
	mut inner_data := i_key_pad.clone()
	inner_data << message
	inner_hash_result := sha512.sum384(inner_data)
	mut inner_hash := []u8{len: 48}
	for i := 0; i < 48; i++ {
		inner_hash[i] = inner_hash_result[i]
	}

	// Calculate external hash
	mut outer_data := o_key_pad.clone()
	outer_data << inner_hash
	outer_hash_result := sha512.sum384(outer_data)
	mut result := []u8{len: 48}
	for i := 0; i < 48; i++ {
		result[i] = outer_hash_result[i]
	}

	return result
}

// hmac_sha512 - HMAC-SHA512 signature
fn hmac_sha512(message []u8, secret []u8) []u8 {
	block_size := 128 // SHA512 block size

	// handle the key
	mut key := secret.clone()
	if key.len > block_size {
		// If the key is too long, hash it first
		hash_result := sha512.sum512(key)
		key = []u8{len: 64}
		for i := 0; i < 64; i++ {
			key[i] = hash_result[i]
		}
	}
	// Pad to block size
	for key.len < block_size {
		key << u8(0)
	}

	// Calculate K' ⊕ ipad
	mut i_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		i_key_pad[i] = key[i] ^ u8(0x36)
	}

	// Calculate K' ⊕ opad
	mut o_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		o_key_pad[i] = key[i] ^ u8(0x5c)
	}

	// Calculate internal hash
	mut inner_data := i_key_pad.clone()
	inner_data << message
	inner_hash_result := sha512.sum512(inner_data)
	mut inner_hash := []u8{len: 64}
	for i := 0; i < 64; i++ {
		inner_hash[i] = inner_hash_result[i]
	}

	// Calculate external hash
	mut outer_data := o_key_pad.clone()
	outer_data << inner_hash
	outer_hash_result := sha512.sum512(outer_data)
	mut result := []u8{len: 64}
	for i := 0; i < 64; i++ {
		result[i] = outer_hash_result[i]
	}

	return result
}

// sign_message - Sign message according to algorithm
fn sign_message(message []u8, secret []u8, alg JwtAlgorithm) []u8 {
	return match alg {
		.hs256 { hmac_sha256(message, secret) }
		.hs384 { hmac_sha384(message, secret) }
		.hs512 { hmac_sha512(message, secret) }
	}
}

// alg_to_string - Convert algorithm enum to string
fn alg_to_string(alg JwtAlgorithm) string {
	return match alg {
		.hs256 { 'HS256' }
		.hs384 { 'HS384' }
		.hs512 { 'HS512' }
	}
}

// string_to_alg - Convert a string to an algorithm enum
fn string_to_alg(s string) !JwtAlgorithm {
	return match s {
		'HS256' { JwtAlgorithm.hs256 }
		'HS384' { JwtAlgorithm.hs384 }
		'HS512' { JwtAlgorithm.hs512 }
		else { error('Unsupported algorithm: ${s}') }
	}
}


// sign_jwt - Create and sign a JWT token
//Return format: header.payload.signature
pub fn sign_jwt(payload JwtPayload, secret string, alg JwtAlgorithm) !string {
	if secret.len == 0 {
		return error('Secret is required')
	}

	// Build header
	header := JwtHeader{
		alg: alg_to_string(alg)
		typ: 'JWT'
	}

	//encoding header
	header_json := '{"alg":"${header.alg}","typ":"${header.typ}"}'
	header_encoded := base64url_encode(header_json.bytes())

	//encode payload
	payload_json := encode_payload(payload)
	payload_encoded := base64url_encode(payload_json.bytes())

	//Create signature input
	signing_input := '${header_encoded}.${payload_encoded}'

	// sign
	signature := sign_message(signing_input.bytes(), secret.bytes(), alg)
	signature_encoded := base64url_encode(signature)

	return '${signing_input}.${signature_encoded}'
}

// encode_payload - Encode JwtPayload into a JSON string
fn encode_payload(payload JwtPayload) string {
	mut parts := []string{}

	if payload.sub.len > 0 {
		parts << '"sub":"${escape_json_string(payload.sub)}"'
	}
	if payload.iss.len > 0 {
		parts << '"iss":"${escape_json_string(payload.iss)}"'
	}
	if payload.aud.len > 0 {
		parts << '"aud":"${escape_json_string(payload.aud)}"'
	}
	if payload.exp != 0 {
		parts << '"exp":${payload.exp}'
	}
	if payload.nbf != 0 {
		parts << '"nbf":${payload.nbf}'
	}
	if payload.iat != 0 {
		parts << '"iat":${payload.iat}'
	}
	if payload.jti.len > 0 {
		parts << '"jti":"${escape_json_string(payload.jti)}"'
	}

	//Add custom declaration
	for key, value in payload.claims {
		parts << '"${escape_json_string(key)}":"${escape_json_string(value)}"'
	}

	return '{${parts.join(",")}}'
}

// escape_json_string - Escape special characters in a JSON string
fn escape_json_string(s string) string {
	mut result := []u8{}
	for c in s.bytes() {
		match c {
			`"` { result << `\\`; result << `"` }
			`\\` { result << `\\`; result << `\\` }
			`\n` { result << `\\`; result << `n` }
			`\r` { result << `\\`; result << `r` }
			`\t` { result << `\\`; result << `t` }
			else { result << c }
		}
	}
	return result.bytestr()
}

// decode_jwt - decode JWT token (does not verify signature)
// Return the decoded payload
pub fn decode_jwt(token string) !JwtPayload {
	parts := token.split('.')
	if parts.len != 3 {
		return error('Invalid token format')
	}

	//Decode payload
	payload_bytes := base64url_decode(parts[1])!
	payload_json := payload_bytes.bytestr()

	return parse_payload(payload_json)
}

// parse_payload - Parse JSON payload into JwtPayload structure
fn parse_payload(json_str string) !JwtPayload {
	raw := json2.decode[json2.Any](json_str) or {
		return error('Invalid JSON payload: ${err}')
	}

	obj := raw.as_map()

	mut payload := JwtPayload{
		claims: map[string]string{}
	}

	// Parse the standard declaration
	if 'sub' in obj {
		payload.sub = obj['sub'] or { json2.Any('') }.str()
	}
	if 'iss' in obj {
		payload.iss = obj['iss'] or { json2.Any('') }.str()
	}
	if 'aud' in obj {
		payload.aud = obj['aud'] or { json2.Any('') }.str()
	}
	if 'exp' in obj {
		payload.exp = (obj['exp'] or { json2.Any(0) }).i64()
	}
	if 'nbf' in obj {
		payload.nbf = (obj['nbf'] or { json2.Any(0) }).i64()
	}
	if 'iat' in obj {
		payload.iat = (obj['iat'] or { json2.Any(0) }).i64()
	}
	if 'jti' in obj {
		payload.jti = obj['jti'] or { json2.Any('') }.str()
	}

	// Parse custom declaration
	standard_claims := ['sub', 'iss', 'aud', 'exp', 'nbf', 'iat', 'jti']
	for key, value in obj {
		if key !in standard_claims {
			payload.claims[key] = value.str()
		}
	}

	return payload
}


// verify_jwt - Verify JWT token and return payload
// Verify signature, expiration time, effective time, etc.
pub fn verify_jwt(token string, secret string, alg JwtAlgorithm) !JwtPayload {
	if secret.len == 0 {
		return error('Secret is required')
	}

	parts := token.split('.')
	if parts.len != 3 {
		return error('Invalid token format')
	}

	//Decode header and verify algorithm
	header_bytes := base64url_decode(parts[0])!
	header_json := header_bytes.bytestr()
	header_raw := json2.decode[json2.Any](header_json) or {
		return error('Invalid header JSON: ${err}')
	}
	header_obj := header_raw.as_map()

	token_alg_str := (header_obj['alg'] or { json2.Any('') }).str()
	token_alg := string_to_alg(token_alg_str)!

	// Verify algorithm consistency
	if token_alg != alg {
		return error('Algorithm mismatch: expected ${alg_to_string(alg)}, got ${token_alg_str}')
	}

	//Verify signature
	signing_input := '${parts[0]}.${parts[1]}'
	expected_signature := sign_message(signing_input.bytes(), secret.bytes(), alg)
	expected_signature_encoded := base64url_encode(expected_signature)

	if !constant_time_compare_jwt(parts[2], expected_signature_encoded) {
		return error('Invalid signature')
	}

	//Decode payload
	payload := decode_jwt(token)!

	return payload
}

// verify_jwt_with_options - JWT verification with options
// Verify signature, expiration time, effective time, issuer, etc.
pub fn verify_jwt_with_options(token string, secret string, alg JwtAlgorithm, options JwtVerifyOptions) !JwtPayload {
	// Do basic verification first
	payload := verify_jwt(token, secret, alg)!

	now := time.now().unix()

	//Verify expiration time
	if options.exp && payload.exp != 0 {
		if now > payload.exp {
			return error('Token expired')
		}
	}

	// Verification effective time
	if options.nbf && payload.nbf != 0 {
		if now < payload.nbf {
			return error('Token not yet valid')
		}
	}

	//Verify the issuer
	if options.iss.len > 0 {
		if payload.iss != options.iss {
			return error('Invalid issuer: expected ${options.iss}, got ${payload.iss}')
		}
	}

	return payload
}

// constant_time_compare_jwt - constant time comparison to prevent timing attacks
fn constant_time_compare_jwt(a string, b string) bool {
	if a.len != b.len {
		return false
	}

	mut result := u8(0)
	for i := 0; i < a.len; i++ {
		result |= a[i] ^ b[i]
	}

	return result == 0
}


// jwt - JWT middleware factory function
// Return a ContextMiddleware for validating JWT token
pub fn jwt_middleware(options JwtOptions) ContextMiddleware {
	return fn [options] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// Get token
		token := get_jwt_token(c, options) or {
			c.status(401)
			return c.json('{"error":"Unauthorized","message":"${err}"}')
		}

		//Verify token
		payload := verify_jwt_with_options(token, options.secret, options.alg, options.verify_options) or {
			c.status(401)
			return c.json('{"error":"Unauthorized","message":"${err}"}')
		}

		// Store payload into Context
		store_jwt_payload(mut c, payload)

		// Continue processing the request
		return next(mut c)
	}
}

// get_jwt_token - Get the JWT token from the request
fn get_jwt_token(c Context, options JwtOptions) !string {
	// Read from Cookie first
	if options.cookie.len > 0 {
		if cookie_token := get_cookie(c, options.cookie) {
			return cookie_token
		}
	}

	// read from header
	header_value := c.req.header.get_custom(options.header_name) or {
		return error('Missing authorization header')
	}

	if header_value.len == 0 {
		return error('Missing authorization header')
	}

	// Parse Bearer token
	if header_value.starts_with('Bearer ') {
		token := header_value[7..].trim_space()
		if token.len == 0 {
			return error('Invalid token format')
		}
		return token
	}

	// If it is not in Bearer format, return the entire value directly
	return header_value
}

// store_jwt_payload - Stores the JWT payload into the Context
fn store_jwt_payload(mut c Context, payload JwtPayload) {
	//Storage standard declaration
	if payload.sub.len > 0 {
		c.set('jwt_sub', payload.sub)
	}
	if payload.iss.len > 0 {
		c.set('jwt_iss', payload.iss)
	}
	if payload.aud.len > 0 {
		c.set('jwt_aud', payload.aud)
	}
	if payload.exp != 0 {
		c.set('jwt_exp', payload.exp.str())
	}
	if payload.nbf != 0 {
		c.set('jwt_nbf', payload.nbf.str())
	}
	if payload.iat != 0 {
		c.set('jwt_iat', payload.iat.str())
	}
	if payload.jti.len > 0 {
		c.set('jwt_jti', payload.jti)
	}

	// store custom declaration
	for key, value in payload.claims {
		c.set('jwt_${key}', value)
	}

	// Store the complete payload JSON (for easy retrieval)
	c.set('jwt_payload', encode_payload(payload))
}

// get_jwt_payload - Get JWT payload from Context
// This is a convenience method for getting the verified JWT payload in the handler
pub fn get_jwt_payload(c Context) ?JwtPayload {
	payload_json := c.get('jwt_payload') or { return none }
	payload := parse_payload(payload_json) or { return none }
	return payload
}

// get_jwt_claim - Get a single JWT claim from the Context
pub fn get_jwt_claim(c Context, key string) ?string {
	return c.get('jwt_${key}')
}
