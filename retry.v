module hono

import time
import rand
import math

// ============================================================================
//Retry configuration
// ============================================================================

//Retry configuration structure
pub struct RetryConfig {
pub:
	max_retries     int  = 3      //Maximum number of retries
	initial_delay   int  = 1000   // Initial delay (milliseconds)
	max_delay       int  = 30000  //Maximum delay (milliseconds)
	multiplier      f64  = 2.0    // Delay multiplication factor
	jitter          bool = true   // Whether to add random jitter
	jitter_factor   f64  = 0.25   // Jitter factor (0.0 - 1.0)
}

//Default retry configuration
pub fn default_retry_config() RetryConfig {
	return RetryConfig{
		max_retries: 3
		initial_delay: 1000
		max_delay: 30000
		multiplier: 2.0
		jitter: true
		jitter_factor: 0.25
	}
}

// Aggressive retry configuration (more retries, shorter delays)
pub fn aggressive_retry_config() RetryConfig {
	return RetryConfig{
		max_retries: 5
		initial_delay: 500
		max_delay: 10000
		multiplier: 1.5
		jitter: true
		jitter_factor: 0.2
	}
}

// Conservative retry configuration (fewer retries, longer delays)
pub fn conservative_retry_config() RetryConfig {
	return RetryConfig{
		max_retries: 2
		initial_delay: 2000
		max_delay: 60000
		multiplier: 3.0
		jitter: true
		jitter_factor: 0.3
	}
}


// ============================================================================
//Retry result
// ============================================================================

//Retry execution results
pub struct RetryResult[T] {
pub:
	success       bool
	value         T
	total_retries int
	total_delay   int  //Total delay time (milliseconds)
	final_error   StorageError
	history       []RetryAttempt
}

//Create a successful retry result
fn new_retry_success[T](value T, total_retries int, total_delay int, history []RetryAttempt) RetryResult[T] {
	return RetryResult[T]{
		success: true
		value: value
		total_retries: total_retries
		total_delay: total_delay
		final_error: StorageError{}
		history: history
	}
}

//Create failed retry results
fn new_retry_failure[T](final_error StorageError, total_retries int, total_delay int, history []RetryAttempt) RetryResult[T] {
	return RetryResult[T]{
		success: false
		value: T{}
		total_retries: total_retries
		total_delay: total_delay
		final_error: final_error
		history: history
	}
}

// ============================================================================
//Retry the executor
// ============================================================================

//Retry the executor
pub struct RetryExecutor {
	config RetryConfig
}

// Create retry executor
pub fn new_retry_executor(config RetryConfig) RetryExecutor {
	return RetryExecutor{
		config: config
	}
}

// Create a retry executor with default configuration
pub fn new_default_retry_executor() RetryExecutor {
	return RetryExecutor{
		config: default_retry_config()
	}
}

// Calculate the delay time for the next retry
pub fn (r RetryExecutor) calculate_delay(attempt int) int {
	// Exponential backoff: delay = initial_delay * (multiplier ^ attempt)
	base_delay := f64(r.config.initial_delay) * math.pow(r.config.multiplier, f64(attempt))
	
	//Limit the maximum delay
	mut delay := int(math.min(base_delay, f64(r.config.max_delay)))
	
	//Add random jitter
	if r.config.jitter && delay > 0 {
		jitter_range := int(f64(delay) * r.config.jitter_factor)
		if jitter_range > 0 {
			jitter := rand.int_in_range(0, jitter_range * 2) or { 0 }
			delay = delay - jitter_range + jitter
		}
	}
	
	// Make sure the delay is not negative
	if delay < 0 {
		delay = 0
	}
	
	return delay
}


//Perform the operation with retry (return []u8)
pub fn (r RetryExecutor) execute_bytes(operation fn () ![]u8, provider string, op_name string) RetryResult[[]u8] {
	mut history := []RetryAttempt{}
	mut total_delay := 0
	mut last_error := StorageError{}
	
	for attempt in 0 .. r.config.max_retries + 1 {
		// perform operations
		result := operation() or {
			// Parsing error
			error_msg := err.msg()
			storage_err := parse_error_message(error_msg, provider, op_name)
			
			// Check if retry is possible
			if !storage_err.is_retryable() {
				// No retry error, return immediately
				return new_retry_failure[[]u8](storage_err, attempt, total_delay, history)
			}
			
			last_error = storage_err
			
			// If there is still a chance to retry
			if attempt < r.config.max_retries {
				delay := r.calculate_delay(attempt)
				
				// Log retry attempts
				history << RetryAttempt{
					attempt_number: attempt + 1
					timestamp: time.now().unix()
					error_message: error_msg
					delay_ms: delay
				}
				
				total_delay += delay
				
				// Wait and try again
				if delay > 0 {
					time.sleep(delay * time.millisecond)
				}
			}
			continue
		}
		
		// Operation successful
		return new_retry_success[[]u8](result, attempt, total_delay, history)
	}
	
	// All retries failed
	mut final_error := last_error
	final_error.retry_history = history
	return new_retry_failure[[]u8](final_error, r.config.max_retries, total_delay, history)
}

//Perform operation with retry (return StorageResult)
pub fn (r RetryExecutor) execute_storage_result(operation fn () !StorageResult, provider string, op_name string) RetryResult[StorageResult] {
	mut history := []RetryAttempt{}
	mut total_delay := 0
	mut last_error := StorageError{}
	
	for attempt in 0 .. r.config.max_retries + 1 {
		// perform operations
		result := operation() or {
			// Parsing error
			error_msg := err.msg()
			storage_err := parse_error_message(error_msg, provider, op_name)
			
			// Check if retry is possible
			if !storage_err.is_retryable() {
				// No retry error, return immediately
				return new_retry_failure[StorageResult](storage_err, attempt, total_delay, history)
			}
			
			last_error = storage_err
			
			// If there is still a chance to retry
			if attempt < r.config.max_retries {
				delay := r.calculate_delay(attempt)
				
				// Log retry attempts
				history << RetryAttempt{
					attempt_number: attempt + 1
					timestamp: time.now().unix()
					error_message: error_msg
					delay_ms: delay
				}
				
				total_delay += delay
				
				// Wait and try again
				if delay > 0 {
					time.sleep(delay * time.millisecond)
				}
			}
			continue
		}
		
		// Operation successful
		return new_retry_success[StorageResult](result, attempt, total_delay, history)
	}
	
	// All retries failed
	mut final_error := last_error
	final_error.retry_history = history
	return new_retry_failure[StorageResult](final_error, r.config.max_retries, total_delay, history)
}


//Perform the operation with retry (return bool)
pub fn (r RetryExecutor) execute_bool(operation fn () !bool, provider string, op_name string) RetryResult[bool] {
	mut history := []RetryAttempt{}
	mut total_delay := 0
	mut last_error := StorageError{}
	
	for attempt in 0 .. r.config.max_retries + 1 {
		// perform operations
		result := operation() or {
			// Parsing error
			error_msg := err.msg()
			storage_err := parse_error_message(error_msg, provider, op_name)
			
			// Check if retry is possible
			if !storage_err.is_retryable() {
				// No retry error, return immediately
				return new_retry_failure[bool](storage_err, attempt, total_delay, history)
			}
			
			last_error = storage_err
			
			// If there is still a chance to retry
			if attempt < r.config.max_retries {
				delay := r.calculate_delay(attempt)
				
				// Log retry attempts
				history << RetryAttempt{
					attempt_number: attempt + 1
					timestamp: time.now().unix()
					error_message: error_msg
					delay_ms: delay
				}
				
				total_delay += delay
				
				// Wait and try again
				if delay > 0 {
					time.sleep(delay * time.millisecond)
				}
			}
			continue
		}
		
		// Operation successful
		return new_retry_success[bool](result, attempt, total_delay, history)
	}
	
	// All retries failed
	mut final_error := last_error
	final_error.retry_history = history
	return new_retry_failure[bool](final_error, r.config.max_retries, total_delay, history)
}

//Execute the operation with retry (no return value)
pub fn (r RetryExecutor) execute_void(operation fn () !, provider string, op_name string) RetryResult[bool] {
	mut history := []RetryAttempt{}
	mut total_delay := 0
	mut last_error := StorageError{}
	
	for attempt in 0 .. r.config.max_retries + 1 {
		// perform operations
		operation() or {
			// Parsing error
			error_msg := err.msg()
			storage_err := parse_error_message(error_msg, provider, op_name)
			
			// Check if retry is possible
			if !storage_err.is_retryable() {
				// No retry error, return immediately
				return new_retry_failure[bool](storage_err, attempt, total_delay, history)
			}
			
			last_error = storage_err
			
			// If there is still a chance to retry
			if attempt < r.config.max_retries {
				delay := r.calculate_delay(attempt)
				
				// Log retry attempts
				history << RetryAttempt{
					attempt_number: attempt + 1
					timestamp: time.now().unix()
					error_message: error_msg
					delay_ms: delay
				}
				
				total_delay += delay
				
				// Wait and try again
				if delay > 0 {
					time.sleep(delay * time.millisecond)
				}
			}
			continue
		}
		
		// Operation successful
		return new_retry_success[bool](true, attempt, total_delay, history)
	}
	
	// All retries failed
	mut final_error := last_error
	final_error.retry_history = history
	return new_retry_failure[bool](final_error, r.config.max_retries, total_delay, history)
}


//Perform operation with retry (return string)
pub fn (r RetryExecutor) execute_string(operation fn () !string, provider string, op_name string) RetryResult[string] {
	mut history := []RetryAttempt{}
	mut total_delay := 0
	mut last_error := StorageError{}
	
	for attempt in 0 .. r.config.max_retries + 1 {
		// perform operations
		result := operation() or {
			// Parsing error
			error_msg := err.msg()
			storage_err := parse_error_message(error_msg, provider, op_name)
			
			// Check if retry is possible
			if !storage_err.is_retryable() {
				// No retry error, return immediately
				return new_retry_failure[string](storage_err, attempt, total_delay, history)
			}
			
			last_error = storage_err
			
			// If there is still a chance to retry
			if attempt < r.config.max_retries {
				delay := r.calculate_delay(attempt)
				
				// Log retry attempts
				history << RetryAttempt{
					attempt_number: attempt + 1
					timestamp: time.now().unix()
					error_message: error_msg
					delay_ms: delay
				}
				
				total_delay += delay
				
				// Wait and try again
				if delay > 0 {
					time.sleep(delay * time.millisecond)
				}
			}
			continue
		}
		
		// Operation successful
		return new_retry_success[string](result, attempt, total_delay, history)
	}
	
	// All retries failed
	mut final_error := last_error
	final_error.retry_history = history
	return new_retry_failure[string](final_error, r.config.max_retries, total_delay, history)
}

// ============================================================================
// helper function
// ============================================================================

// Parse StorageError from error message
fn parse_error_message(error_msg string, provider string, operation string) StorageError {
	//Try to extract information from the error message
	// Format: "provider/operation: message (kind: xxx, http_status: yyy)"
	
	// Check if a known error type keyword is included
	kind := detect_error_kind_from_message(error_msg)
	
	//Try to extract HTTP status code
	http_status := extract_http_status_from_message(error_msg)
	
	return StorageError{
		kind: kind
		message: error_msg
		provider: provider
		operation: operation
		http_status: http_status
		retry_count: 0
		details: map[string]string{}
		retry_history: []RetryAttempt{}
	}
}

// Detect error type from error message
fn detect_error_kind_from_message(msg string) StorageErrorKind {
	lower_msg := msg.to_lower()
	
	//retryable error
	if lower_msg.contains('timeout') || lower_msg.contains('timed out') {
		return .network_timeout
	}
	if lower_msg.contains('service unavailable') || lower_msg.contains('503') {
		return .service_unavailable
	}
	if lower_msg.contains('rate limit') || lower_msg.contains('too many requests') || lower_msg.contains('429') {
		return .rate_limited
	}
	if lower_msg.contains('connection reset') || lower_msg.contains('connection refused') {
		return .connection_reset
	}
	if lower_msg.contains('temporary') || lower_msg.contains('retry') {
		return .temporary_failure
	}
	
	// No retry error
	if lower_msg.contains('invalid credentials') || lower_msg.contains('401') || lower_msg.contains('unauthorized') {
		return .invalid_credentials
	}
	if lower_msg.contains('access denied') || lower_msg.contains('403') || lower_msg.contains('forbidden') {
		return .access_denied
	}
	if lower_msg.contains('bucket not found') || lower_msg.contains('nosuchbucket') {
		return .bucket_not_found
	}
	if lower_msg.contains('not found') || lower_msg.contains('404') || lower_msg.contains('nosuchkey') {
		return .object_not_found
	}
	if lower_msg.contains('invalid') && (lower_msg.contains('key') || lower_msg.contains('name')) {
		return .invalid_object_key
	}
	if lower_msg.contains('quota') || lower_msg.contains('limit exceeded') {
		return .quota_exceeded
	}
	if lower_msg.contains('config') {
		return .invalid_config
	}
	
	return .unknown
}

//Extract HTTP status code from error message
fn extract_http_status_from_message(msg string) int {
	// Try to find the "http_status: xxx" pattern
	if status_idx := msg.index('http_status:') {
		start := status_idx + 12
		mut end := start
		for end < msg.len && (msg[end].is_digit() || msg[end] == ` `) {
			end++
		}
		status_str := msg[start..end].trim_space()
		return status_str.int()
	}
	
	//Try to find common HTTP status codes
	status_codes := [400, 401, 403, 404, 409, 413, 429, 500, 502, 503, 504]
	for code in status_codes {
		if msg.contains(code.str()) {
			return code
		}
	}
	
	return 0
}


// ============================================================================
//Simplified retry function
// ============================================================================

// Use default configuration to perform operations with retries (return []u8)
pub fn retry_bytes(operation fn () ![]u8, provider string, op_name string) RetryResult[[]u8] {
	executor := new_default_retry_executor()
	return executor.execute_bytes(operation, provider, op_name)
}

// Perform operation with retry using default configuration (returns StorageResult)
pub fn retry_storage_result(operation fn () !StorageResult, provider string, op_name string) RetryResult[StorageResult] {
	executor := new_default_retry_executor()
	return executor.execute_storage_result(operation, provider, op_name)
}

// Use default configuration to perform operations with retries (returns bool)
pub fn retry_bool(operation fn () !bool, provider string, op_name string) RetryResult[bool] {
	executor := new_default_retry_executor()
	return executor.execute_bool(operation, provider, op_name)
}

// Use default configuration to perform operations with retries (no return value)
pub fn retry_void(operation fn () !, provider string, op_name string) RetryResult[bool] {
	executor := new_default_retry_executor()
	return executor.execute_void(operation, provider, op_name)
}

// Use default configuration to perform operations with retries (returns string)
pub fn retry_string(operation fn () !string, provider string, op_name string) RetryResult[string] {
	executor := new_default_retry_executor()
	return executor.execute_string(operation, provider, op_name)
}

// Use custom configuration to perform operations with retries (return []u8)
pub fn retry_bytes_with_config(operation fn () ![]u8, provider string, op_name string, config RetryConfig) RetryResult[[]u8] {
	executor := new_retry_executor(config)
	return executor.execute_bytes(operation, provider, op_name)
}

// Use custom configuration to perform operations with retry (return StorageResult)
pub fn retry_storage_result_with_config(operation fn () !StorageResult, provider string, op_name string, config RetryConfig) RetryResult[StorageResult] {
	executor := new_retry_executor(config)
	return executor.execute_storage_result(operation, provider, op_name)
}
