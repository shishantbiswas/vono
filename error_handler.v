module vono

import net.http
import x.json2

// Error type enumeration
pub enum ErrorType {
	bad_request = 400
	unauthorized = 401
	forbidden = 403
	not_found = 404
	method_not_allowed = 405
	conflict = 409
	payload_too_large = 413
	unsupported_media_type = 415
	unprocessable_entity = 422
	internal_server_error = 500
	not_implemented = 501
	bad_gateway = 502
	service_unavailable = 503
}

// Standardized error response structure
pub struct ErrorResponse {
pub:
	error       string
	message     string
	code        int
	timestamp   string
	path        string
	details     map[string]string
}

// Error handler interface
pub interface IErrorHandler {
	handle_error(mut c Context, error_type ErrorType, message string, details map[string]string) http.Response
}

//Default error handler
pub struct DefaultErrorHandler {}

// Implement the error handler interface
pub fn (eh DefaultErrorHandler) handle_error(mut c Context, error_type ErrorType, message string, details map[string]string) http.Response {
	error_response := ErrorResponse{
		error: get_error_name(error_type)
		message: message
		code: int(error_type)
		timestamp: get_current_timestamp()
		path: c.path
		details: details
	}
	
	c.status(int(error_type))
	return c.json(json2.encode[ErrorResponse](error_response))
}

// Get the error name
fn get_error_name(error_type ErrorType) string {
	return match error_type {
		.bad_request { 'Bad Request' }
		.unauthorized { 'Unauthorized' }
		.forbidden { 'Forbidden' }
		.not_found { 'Not Found' }
		.method_not_allowed { 'Method Not Allowed' }
		.conflict { 'Conflict' }
		.payload_too_large { 'Payload Too Large' }
		.unsupported_media_type { 'Unsupported Media Type' }
		.unprocessable_entity { 'Unprocessable Entity' }
		.internal_server_error { 'Internal Server Error' }
		.not_implemented { 'Not Implemented' }
		.bad_gateway { 'Bad Gateway' }
		.service_unavailable { 'Service Unavailable' }
	}
}

// Get the current timestamp
fn get_current_timestamp() string {
	// Simplified timestamp implementation
	return '2025-12-26T00:00:00Z'
}

// Context extension method - convenient error handling
pub fn (mut c Context) error_response(error_type ErrorType, message string) http.Response {
	return c.error_response_with_details(error_type, message, map[string]string{})
}

pub fn (mut c Context) error_response_with_details(error_type ErrorType, message string, details map[string]string) http.Response {
	handler := DefaultErrorHandler{}
	return handler.handle_error(mut c, error_type, message, details)
}

//Common error handling shortcuts
pub fn (mut c Context) bad_request(message string) http.Response {
	return c.error_response(.bad_request, message)
}

pub fn (mut c Context) unauthorized(message string) http.Response {
	return c.error_response(.unauthorized, message)
}

pub fn (mut c Context) forbidden(message string) http.Response {
	return c.error_response(.forbidden, message)
}

pub fn (mut c Context) not_found(message string) http.Response {
	return c.error_response(.not_found, message)
}

pub fn (mut c Context) internal_error(message string) http.Response {
	return c.error_response(.internal_server_error, message)
}

pub fn (mut c Context) validation_error(message string, field_errors map[string]string) http.Response {
	return c.error_response_with_details(.unprocessable_entity, message, field_errors)
}

//Parameter validation error handling
pub fn (mut c Context) missing_parameter(param_name string) http.Response {
	return c.bad_request('Missing required parameter: ${param_name}')
}

pub fn (mut c Context) invalid_parameter(param_name string, reason string) http.Response {
	details := {
		'parameter': param_name
		'reason': reason
	}
	return c.error_response_with_details(.bad_request, 'Invalid parameter: ${param_name}', details)
}

// Resource related error handling
pub fn (mut c Context) resource_not_found(resource_type string, resource_id string) http.Response {
	details := {
		'resource_type': resource_type
		'resource_id': resource_id
	}
	return c.error_response_with_details(.not_found, '${resource_type} not found', details)
}

pub fn (mut c Context) resource_conflict(resource_type string, reason string) http.Response {
	details := {
		'resource_type': resource_type
		'reason': reason
	}
	return c.error_response_with_details(.conflict, 'Resource conflict: ${reason}', details)
}

//File operation error handling
pub fn (mut c Context) file_operation_error(operation string, filename string, reason string) http.Response {
	details := {
		'operation': operation
		'filename': filename
		'reason': reason
	}
	return c.error_response_with_details(.internal_server_error, 'File operation failed: ${operation}', details)
}

//Database operation error handling
pub fn (mut c Context) database_error(operation string, reason string) http.Response {
	details := {
		'operation': operation
		'reason': reason
	}
	return c.error_response_with_details(.internal_server_error, 'Database operation failed', details)
}

//Verification result processing
pub fn handle_validation_result[T](mut c Context, result !T, param_name string) !T {
	return result or {
		// http.Response cannot be returned directly here, it needs to be processed at the calling site
		return error('Validation failed for ${param_name}: ${err}')
	}
}

//Global error handling middleware
pub fn error_handling_middleware() fn (mut Context, fn (mut Context) http.Response) http.Response {
	return fn (mut c Context, next fn (mut Context) http.Response) http.Response {
		//Catch panic and convert into error response
		//V language currently does not support try-catch. A structured error handling framework is provided here.
		response := next(mut c)
		
		// If the response status code is an error status, ensure that the response format is consistent
		if c.status_code >= 400 {
			// If the response body is not in standard error format, convert it to standard error format
			if !response.body.contains('"error"') {
				error_type := match c.status_code {
					400 { ErrorType.bad_request }
					401 { ErrorType.unauthorized }
					403 { ErrorType.forbidden }
					404 { ErrorType.not_found }
					409 { ErrorType.conflict }
					422 { ErrorType.unprocessable_entity }
					500 { ErrorType.internal_server_error }
					else { ErrorType.internal_server_error }
				}
				return c.error_response(error_type, response.body)
			}
		}
		
		return response
	}
}

// Error logging
pub struct ErrorLogger {
mut:
	enabled bool = true
}

pub fn (mut logger ErrorLogger) log_error(error_response ErrorResponse, request_info string) {
	if !logger.enabled {
		return
	}
	
	println('[ERROR] ${error_response.timestamp} - ${error_response.code} ${error_response.error}')
	println('  Path: ${error_response.path}')
	println('  Message: ${error_response.message}')
	if error_response.details.len > 0 {
		println('  Details: ${error_response.details}')
	}
	println('  Request: ${request_info}')
}

//Create error log instance
pub fn new_error_logger() ErrorLogger {
	return ErrorLogger{
		enabled: true
	}
}