module hono

import net.http

// response tool
pub struct Response {
}

// Create HTML response
pub fn Response.html(content string) http.Response {
	return http.Response{
		status_code: 200
		header: http.new_header(key: .content_type, value: 'text/html; charset=utf-8')
		body: content
	}
}

// Create JSON response
pub fn Response.json(content string) http.Response {
	return http.Response{
		status_code: 200
		header: http.new_header(key: .content_type, value: 'application/json; charset=utf-8')
		body: content
	}
}

//Create text response
pub fn Response.text(content string) http.Response {
	return http.Response{
		status_code: 200
		header: http.new_header(key: .content_type, value: 'text/plain; charset=utf-8')
		body: content
	}
}

// Create error response
pub fn Response.error(status_code int, message string) http.Response {
	return http.Response{
		status_code: status_code
		body: message
	}
}
