module vono

import net.http
import time
import sync

// RateLimitEntry structure - rate limiting entry
pub struct RateLimitEntry {
pub mut:
	count    int   //Current request count
	reset_at i64   // Reset time (Unix millisecond timestamp)
}

// RateLimitStore interface - current limiting storage backend
pub interface RateLimitStore {
mut:
	// increment - increment the count and return the current count and reset time
	// Parameters: key - client identification, window_ms - time window (milliseconds)
	// Return: (current count, reset timestamp)
	increment(key string, window_ms i64) (int, i64)
	// reset - resets the count for the specified key
	reset(key string)
}

// MemoryStore structure - memory storage implementation
pub struct MemoryStore {
mut:
	data map[string]RateLimitEntry
	mtx  sync.Mutex  // Thread safety lock
}

// MemoryStore.new - Create a new memory store
pub fn MemoryStore.new() &MemoryStore {
	return &MemoryStore{
		data: map[string]RateLimitEntry{}
	}
}

// increment - increment the count and return the current count and reset time
pub fn (mut s MemoryStore) increment(key string, window_ms i64) (int, i64) {
	s.mtx.@lock()
	defer { s.mtx.unlock() }
	
	now := time.now().unix_milli()
	
	// Check if entry exists
	if key in s.data {
		mut entry := s.data[key]
		
		// Check if reset is required (window has expired)
		if now >= entry.reset_at {
			// Window has expired, reset count
			entry.count = 1
			entry.reset_at = now + window_ms
		} else {
			//In the window, increase the count
			entry.count++
		}
		
		s.data[key] = entry
		return entry.count, entry.reset_at
	}
	
	// new item
	new_entry := RateLimitEntry{
		count: 1
		reset_at: now + window_ms
	}
	s.data[key] = new_entry
	
	return new_entry.count, new_entry.reset_at
}

// reset - resets the count for the specified key
pub fn (mut s MemoryStore) reset(key string) {
	s.mtx.@lock()
	defer { s.mtx.unlock() }
	
	s.data.delete(key)
}

// get_entry - Get the entry for the specified key (for testing)
pub fn (s MemoryStore) get_entry(key string) ?RateLimitEntry {
	if key in s.data {
		return s.data[key]
	}
	return none
}

// cleanup_expired - clean up expired entries (optional maintenance method)
pub fn (mut s MemoryStore) cleanup_expired() {
	s.mtx.@lock()
	defer { s.mtx.unlock() }
	
	now := time.now().unix_milli()
	mut keys_to_delete := []string{}
	
	for key, entry in s.data {
		if now >= entry.reset_at {
			keys_to_delete << key
		}
	}
	
	for key in keys_to_delete {
		s.data.delete(key)
	}
}


// RateLimitOptions structure - current limiting configuration options
pub struct RateLimitOptions {
pub:
	window_ms     i64 = 60000                           //Time window (milliseconds), default 1 minute
	limit         int = 100                             //Maximum number of requests within the window, default 100
	key_generator ?fn (Context) string                  // Client ID generator
	skip          ?fn (Context) bool                    // Skip the current limiting condition
	handler       ?fn (mut Context, RateLimitInfo) http.Response  // Customized current limiting response
	store         &MemoryStore                          // Storage backend (required)
	headers       bool = true                           // Whether to add a current limiting header, the default is true
}

// RateLimitInfo structure - rate limiting information (passed to custom handler)
pub struct RateLimitInfo {
pub:
	limit     int   //Maximum number of requests
	remaining int   //Number of remaining requests
	reset_at  i64   //Reset timestamp (milliseconds)
}

// rate_limit - rate limiting middleware factory function
// Return a ContextMiddleware for limiting request frequency
// Note: store parameter must be provided
pub fn rate_limit(options RateLimitOptions) ContextMiddleware {
	mut store := options.store
	
	return fn [options, mut store] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// Check whether the current limit is skipped
		if skip_fn := options.skip {
			if skip_fn(c) {
				return next(mut c)
			}
		}
		
		// Generate client identification key
		key := generate_rate_limit_key(c, options.key_generator)
		
		//increment count
		count, reset_at := store.increment(key, options.window_ms)
		
		// Calculate the number of remaining requests
		remaining := if count > options.limit { 0 } else { options.limit - count }
		
		//Set the current limiting response header
		if options.headers {
			set_rate_limit_headers(mut c, options.limit, remaining, reset_at)
		}
		
		// Check if the limit is exceeded
		if count > options.limit {
			//Create current limiting information
			info := RateLimitInfo{
				limit: options.limit
				remaining: 0
				reset_at: reset_at
			}
			
			// Use custom handler or default response
			if custom_handler := options.handler {
				return custom_handler(mut c, info)
			}
			
			return rate_limit_exceeded_response(mut c, reset_at)
		}
		
		// Continue processing the request
		return next(mut c)
	}
}

// generate_rate_limit_key - generate client identification key
fn generate_rate_limit_key(c Context, key_generator ?fn (Context) string) string {
	// Use custom key generator
	if gen_fn := key_generator {
		return gen_fn(c)
	}
	
	//Use client IP by default
	return c.get_client_ip()
}

// set_rate_limit_headers - Set rate limit response headers
fn set_rate_limit_headers(mut c Context, limit int, remaining int, reset_at i64) {
	c.headers['X-RateLimit-Limit'] = limit.str()
	c.headers['X-RateLimit-Remaining'] = remaining.str()
	// Convert millisecond timestamp to seconds (HTTP standard)
	c.headers['X-RateLimit-Reset'] = (reset_at / 1000).str()
}

// rate_limit_exceeded_response - returns 429 rate limit response
fn rate_limit_exceeded_response(mut c Context, reset_at i64) http.Response {
	c.status(429)
	
	// Calculate Retry-After (seconds)
	now := time.now().unix_milli()
	retry_after := if reset_at > now { (reset_at - now) / 1000 } else { i64(0) }
	if retry_after > 0 {
		c.headers['Retry-After'] = retry_after.str()
	}
	
	return c.json('{"error":"Too Many Requests","message":"Rate limit exceeded. Please try again later."}')
}

// get_rate_limit_info - Get rate limit information from Context
// This is a convenience method for getting the current request's current request status in the handler.
pub fn get_rate_limit_info(c Context) ?RateLimitInfo {
	limit_str := c.headers['X-RateLimit-Limit'] or { return none }
	remaining_str := c.headers['X-RateLimit-Remaining'] or { return none }
	reset_str := c.headers['X-RateLimit-Reset'] or { return none }
	
	return RateLimitInfo{
		limit: limit_str.int()
		remaining: remaining_str.int()
		reset_at: reset_str.i64() * 1000  // Convert back to milliseconds
	}
}
