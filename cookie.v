module vono

import time
import crypto.sha256
import encoding.base64

// SameSite enum - Cookie's SameSite property
pub enum SameSite {
	strict
	lax
	none_
}

// CookieOptions structure - Cookie configuration options
pub struct CookieOptions {
pub:
	path      string    = '/'
	domain    string
	max_age   int                    // Second
	expires   ?time.Time
	http_only bool
	secure    bool
	same_site SameSite  = .lax
}

// get_cookie - Gets the cookie value of the specified name from the request
// Return the Cookie value, or none if it does not exist
pub fn get_cookie(c Context, name string) ?string {
	cookie_header := c.req.header.get_custom('Cookie') or { return none }
	
	if cookie_header.len == 0 {
		return none
	}
	
	// Parse Cookie header
	cookies := parse_cookie_header(cookie_header)
	
	if name in cookies {
		return cookies[name]
	}
	
	return none
}

// get_all_cookies - Get all cookies in the request
// Return a map containing the names and values ​​of all cookies
pub fn get_all_cookies(c Context) map[string]string {
	cookie_header := c.req.header.get_custom('Cookie') or { return map[string]string{} }
	
	if cookie_header.len == 0 {
		return map[string]string{}
	}
	
	return parse_cookie_header(cookie_header)
}


// set_cookie - Set Cookie
// Add the cookie to the response's Set-Cookie header
pub fn set_cookie(mut c Context, name string, value string, options ...CookieOptions) {
	opts := if options.len > 0 { options[0] } else { CookieOptions{} }
	
	cookie_str := build_cookie_string(name, value, opts)
	
	//Add to response header
	// If there is already a Set-Cookie header, it needs to be appended
	if existing := c.headers['Set-Cookie'] {
		c.headers['Set-Cookie'] = '${existing}, ${cookie_str}'
	} else {
		c.headers['Set-Cookie'] = cookie_str
	}
}

//delete_cookie - Delete Cookie
// Delete the cookie by setting the expiration time to the past
pub fn delete_cookie(mut c Context, name string, options ...CookieOptions) {
	mut opts := if options.len > 0 { options[0] } else { CookieOptions{} }
	
	//Set max_age to 0 or a negative number, and set the expiration time to the past
	expired_time := time.unix(0)
	
	//Create a new option, retain path and domain, but set expiration
	delete_opts := CookieOptions{
		path: opts.path
		domain: opts.domain
		max_age: 0
		expires: expired_time
		http_only: opts.http_only
		secure: opts.secure
		same_site: opts.same_site
	}
	
	cookie_str := build_cookie_string(name, '', delete_opts)
	
	if existing := c.headers['Set-Cookie'] {
		c.headers['Set-Cookie'] = '${existing}, ${cookie_str}'
	} else {
		c.headers['Set-Cookie'] = cookie_str
	}
}

// parse_cookie_header - Parse Cookie request header
// Parse the "name1=value1; name2=value2" format into map
fn parse_cookie_header(header string) map[string]string {
	mut cookies := map[string]string{}
	
	// Split by semicolon
	pairs := header.split(';')
	
	for pair in pairs {
		trimmed := pair.trim_space()
		if trimmed.len == 0 {
			continue
		}
		
		// Find the position of the first equal sign
		eq_pos := trimmed.index('=') or { continue }
		
		if eq_pos == 0 {
			continue
		}
		
		name := trimmed[..eq_pos].trim_space()
		value := if eq_pos + 1 < trimmed.len {
			trimmed[eq_pos + 1..].trim_space()
		} else {
			''
		}
		
		// Remove quotes from both sides of the value (if any)
		cleaned_value := if value.len >= 2 && value[0] == `"` && value[value.len - 1] == `"` {
			value[1..value.len - 1]
		} else {
			value
		}
		
		cookies[name] = cleaned_value
	}
	
	return cookies
}


// build_cookie_string - build the value of the Set-Cookie header
fn build_cookie_string(name string, value string, opts CookieOptions) string {
	mut parts := []string{}
	
	//Basic name=value
	parts << '${name}=${value}'
	
	// Path
	if opts.path.len > 0 {
		parts << 'Path=${opts.path}'
	}
	
	// Domain
	if opts.domain.len > 0 {
		parts << 'Domain=${opts.domain}'
	}
	
	// Max-Age
	if opts.max_age != 0 {
		parts << 'Max-Age=${opts.max_age}'
	}
	
	// Expires
	if expires := opts.expires {
		// Format to HTTP date format: Wed, 09 Jun 2021 10:18:14 GMT
		expires_str := format_cookie_date(expires)
		parts << 'Expires=${expires_str}'
	}
	
	// HttpOnly
	if opts.http_only {
		parts << 'HttpOnly'
	}
	
	// Secure
	if opts.secure {
		parts << 'Secure'
	}
	
	// SameSite
	match opts.same_site {
		.strict { parts << 'SameSite=Strict' }
		.lax { parts << 'SameSite=Lax' }
		.none_ { parts << 'SameSite=None' }
	}
	
	return parts.join('; ')
}

// format_cookie_date - Format time in Cookie date format
// Format: Wed, 09 Jun 2021 10:18:14 GMT
fn format_cookie_date(t time.Time) string {
	days := ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	
	day_name := days[t.day_of_week()]
	month_name := months[t.month - 1]
	
	return '${day_name}, ${t.day:02} ${month_name} ${t.year} ${t.hour:02}:${t.minute:02}:${t.second:02} GMT'
}

// set_signed_cookie - Set signed cookie
// Sign the cookie value using HMAC-SHA256
pub fn set_signed_cookie(mut c Context, name string, value string, secret string, options ...CookieOptions) ! {
	if secret.len == 0 {
		return error('Secret is required for signed cookies')
	}
	
	// Generate signature
	signature := generate_hmac_signature(value, secret)
	
	// Combine value and signature: value.signature
	signed_value := '${value}.${signature}'
	
	opts := if options.len > 0 { options[0] } else { CookieOptions{} }
	set_cookie(mut c, name, signed_value, opts)
}

// get_signed_cookie - Get and verify signed cookies
// Verify the signature and return the original value if valid, otherwise return an error
pub fn get_signed_cookie(c Context, name string, secret string) !string {
	if secret.len == 0 {
		return error('Secret is required for signed cookies')
	}
	
	// Get cookie value
	signed_value := get_cookie(c, name) or {
		return error('Cookie not found: ${name}')
	}
	
	// Separate value and signature
	dot_pos := signed_value.last_index('.') or {
		return error('Invalid signed cookie format')
	}
	
	if dot_pos == 0 || dot_pos >= signed_value.len - 1 {
		return error('Invalid signed cookie format')
	}
	
	value := signed_value[..dot_pos]
	signature := signed_value[dot_pos + 1..]
	
	//Verify signature
	expected_signature := generate_hmac_signature(value, secret)
	
	if !constant_time_compare(signature, expected_signature) {
		return error('Invalid signature')
	}
	
	return value
}


// generate_hmac_signature - Generate a signature using HMAC-SHA256
fn generate_hmac_signature(value string, secret string) string {
	// Manually implement HMAC-SHA256
	// HMAC(K, m) = H((K' ⊕ opad) || H((K' ⊕ ipad) || m))
	// Where K' is the processed key, ipad = 0x36, opad = 0x5c
	
	block_size := 64 // SHA256 block size
	
	// handle the key
	mut key := secret.bytes()
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
	inner_data << value.bytes()
	inner_hash_result := sha256.sum(inner_data)
	mut inner_hash := []u8{len: 32}
	for i := 0; i < 32; i++ {
		inner_hash[i] = inner_hash_result[i]
	}
	
	// Calculate outer hash: H((K' ⊕ opad) || inner_hash)
	mut outer_data := o_key_pad.clone()
	outer_data << inner_hash
	outer_hash_result := sha256.sum(outer_data)
	mut outer_hash := []u8{len: 32}
	for i := 0; i < 32; i++ {
		outer_hash[i] = outer_hash_result[i]
	}
	
	// Base64URL encoding (without padding)
	return base64.url_encode(outer_hash).replace('=', '')
}

// constant_time_compare - constant time comparison to prevent timing attacks
fn constant_time_compare(a string, b string) bool {
	if a.len != b.len {
		return false
	}
	
	mut result := u8(0)
	for i := 0; i < a.len; i++ {
		result |= a[i] ^ b[i]
	}
	
	return result == 0
}
