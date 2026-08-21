module vono

import net.http
import compress.gzip
import compress.zlib

// CompressEncoding enum - supported compression encoding types
pub enum CompressEncoding {
	gzip
	deflate
}

// CompressOptions structure - compression configuration options
pub struct CompressOptions {
pub:
	encoding  ?CompressEncoding  //Specify the encoding, none means automatic selection
	threshold int = 1024         // Minimum compression size (bytes), default 1KB
	level     int = 128          // Compression level (0-4095 for gzip)
}

// compress - compression middleware factory function
// Return a ContextMiddleware for compressing the response body
pub fn compress(options ...CompressOptions) ContextMiddleware {
	opts := if options.len > 0 { options[0] } else { CompressOptions{} }
	
	return fn [opts] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// Execute the subsequent processor first to get the response
		mut response := next(mut c)
		
		// Check Cache-Control: no-transform
		if has_no_transform(response) {
			return response
		}
		
		// Check whether the response body size reaches the threshold
		if response.body.len < opts.threshold {
			return response
		}
		
		// Check if Content-Type is compressible
		content_type := get_response_content_type(response)
		if !is_compressible_content_type(content_type) {
			return response
		}
		
		// Check if the response has been compressed
		if is_already_compressed(response) {
			return response
		}
		
		// Get the encoding supported by the client
		accept_encoding := c.req.header.get_custom('Accept-Encoding') or { '' }
		if accept_encoding.len == 0 {
			return response
		}
		
		//Select compression encoding
		encoding := select_encoding(accept_encoding, opts.encoding)
		
		//Perform compression
		selected_encoding := encoding or { return response }
		compressed_body := compress_body(response.body, selected_encoding, opts.level) or {
			// Compression failed, return original response
			return response
		}
		
		// If it is larger after compression, return the original response
		if compressed_body.len >= response.body.len {
			return response
		}
		
		//Construct new response header
		mut new_header := http.new_header()
		
		//Copy the original header
		for key in response.header.keys() {
			values := response.header.custom_values(key)
			for value in values {
				// Skip Content-Length and reset later
				if key.to_lower() != 'content-length' {
					new_header.add_custom(key, value) or { continue }
				}
			}
		}
		
		//Set Content-Encoding
		encoding_str := if selected_encoding == .gzip { 'gzip' } else { 'deflate' }
		new_header.add_custom('Content-Encoding', encoding_str) or {}
		
		// Set new Content-Length
		new_header.add_custom('Content-Length', compressed_body.len.str()) or {}
		
		// Add Vary header to indicate that the response changes according to Accept-Encoding
		new_header.add_custom('Vary', 'Accept-Encoding') or {}
		
		return http.Response{
			status_code: response.status_code
			header: new_header
			body: compressed_body.bytestr()
		}
	}
}

// has_no_transform - Check if the response contains Cache-Control: no-transform
fn has_no_transform(response http.Response) bool {
	cache_control := response.header.get_custom('Cache-Control') or { '' }
	return cache_control.contains('no-transform')
}

// get_response_content_type - Get the Content-Type of the response
fn get_response_content_type(response http.Response) string {
	return response.header.get_custom('Content-Type') or { '' }
}

// is_compressible_content_type - Check if the Content-Type is compressible
fn is_compressible_content_type(content_type string) bool {
	if content_type.len == 0 {
		return true  //Compressible by default
	}
	
	ct_lower := content_type.to_lower()
	
	// Compressible MIME type
	compressible_types := [
		'text/',
		'application/json',
		'application/javascript',
		'application/xml',
		'application/xhtml+xml',
		'application/rss+xml',
		'application/atom+xml',
		'application/x-javascript',
		'application/x-font-ttf',
		'font/opentype',
		'font/ttf',
		'font/eot',
		'image/svg+xml',
		'image/x-icon',
		'image/vnd.microsoft.icon',
	]
	
	for ct in compressible_types {
		if ct_lower.starts_with(ct) || ct_lower.contains(ct) {
			return true
		}
	}
	
	// Incompressible type (compressed format)
	non_compressible_types := [
		'image/png',
		'image/jpeg',
		'image/gif',
		'image/webp',
		'video/',
		'audio/',
		'application/zip',
		'application/gzip',
		'application/x-gzip',
		'application/x-compress',
		'application/x-compressed',
		'application/x-bzip',
		'application/x-bzip2',
		'application/x-rar-compressed',
		'application/x-7z-compressed',
	]
	
	for ct in non_compressible_types {
		if ct_lower.starts_with(ct) || ct_lower.contains(ct) {
			return false
		}
	}
	
	return true
}

// is_already_compressed - Check if the response has been compressed
fn is_already_compressed(response http.Response) bool {
	content_encoding := response.header.get_custom('Content-Encoding') or { '' }
	return content_encoding.len > 0
}

// select_encoding - select the best compression encoding
fn select_encoding(accept_encoding string, preferred ?CompressEncoding) ?CompressEncoding {
	// If a preferred encoding is specified, check if the client supports it
	if pref := preferred {
		match pref {
			.gzip {
				if accepts_gzip(accept_encoding) {
					return .gzip
				}
			}
			.deflate {
				if accepts_deflate(accept_encoding) {
					return .deflate
				}
			}
		}
		return none
	}
	
	// Automatic selection: gzip first, deflate second
	if accepts_gzip(accept_encoding) {
		return .gzip
	}
	if accepts_deflate(accept_encoding) {
		return .deflate
	}
	
	return none
}

// accepts_gzip - Check if gzip encoding is accepted
fn accepts_gzip(accept_encoding string) bool {
	return accept_encoding.contains('gzip') || accept_encoding.contains('*')
}

// accepts_deflate - Check if deflate encoding is accepted
fn accepts_deflate(accept_encoding string) bool {
	return accept_encoding.contains('deflate') || accept_encoding.contains('*')
}

// compress_body - Compress response body
fn compress_body(body string, encoding CompressEncoding, level int) ![]u8 {
	data := body.bytes()
	
	match encoding {
		.gzip {
			return gzip.compress(data)
		}
		.deflate {
			return zlib.compress(data)
		}
	}
}

// decompress_gzip - decompress gzip data (for testing)
pub fn decompress_gzip(data []u8) ![]u8 {
	return gzip.decompress(data)
}

// decompress_deflate - decompress deflate data (for testing)
pub fn decompress_deflate(data []u8) ![]u8 {
	return zlib.decompress(data)
}
