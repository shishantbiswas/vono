module vono

import net.http

//Multipart form data items
pub struct MultipartItem {
pub:
	name     string
	filename string
	content  string
	content_type string
}

// Multipart parser
pub struct MultipartParser {
pub:
	boundary string
	data     string
}

// Create Multipart parser
pub fn new_multipart_parser(content_type string, data string) !MultipartParser {
	// Extract boundary from Content-Type
	boundary := extract_boundary(content_type) or {
		return error('Failed to extract boundary')
	}
	
	return MultipartParser{
		boundary: boundary
		data: data
	}
}

// Parse multipart data
pub fn (parser MultipartParser) parse() ![]MultipartItem {
	mut items := []MultipartItem{}
	// More robust segmentation method, compatible with different line breaks
	parts := parser.data.split('--${parser.boundary}')
	for _, part in parts {
		if part.trim_space() == '' || part.trim_space() == '--' || part.trim_space().starts_with('--') {
			continue
		}
		item := parser.parse_part(part) or { 
			continue 
		}
		items << item
	}
	return items
}

// Parse a single part
fn (parser MultipartParser) parse_part(part string) !MultipartItem {
	// Separate header and content
	header_content := part.split('\r\n\r\n')
	if header_content.len < 2 {
		return error('Invalid part format')
	}
	
	header := header_content[0]
	content := header_content[1..].join('\r\n\r\n')
	
	// Parse the header
	name := extract_header_value(header, 'name') or {
		return error('Missing name')
	}
	filename := extract_header_value(header, 'filename') or { '' }
	content_type := extract_header_value(header, 'Content-Type') or { 'text/plain' }
	
	return MultipartItem{
		name: name
		filename: filename
		content: content
		content_type: content_type
	}
}

// Extract boundary from Content-Type
fn extract_boundary(content_type string) !string {
	if !content_type.starts_with('multipart/form-data') {
		return error('Not multipart/form-data')
	}
	
	boundary_start := content_type.index('boundary=') or {
		return error('No boundary found')
	}
	mut boundary := content_type[boundary_start + 9..]
	
	// remove quotes
	if boundary.starts_with('"') && boundary.ends_with('"') {
		boundary = boundary[1..boundary.len - 1]
	}
	
	return boundary
}

//Extract value from header
fn extract_header_value(header string, key string) !string {
    // First find the Content-Disposition line
    for line in header.split('\r\n') {
        if line.starts_with('Content-Disposition:') {
            // Find key="value"
            key_eq := '${key}="'
            idx := line.index(key_eq) or { continue }
            start := idx + key_eq.len
            end := line.index_after('"', start) or { line.len }
            return line[start..end]
        }
    }
    return error('Key not found: $key')
}

// Parse multipart form data (convenience function)
pub fn parse_multipart_form(req http.Request) !map[string]MultipartItem {
	content_type := req.header.get_custom('Content-Type') or {
		return error('No Content-Type header')
	}
	
	parser := new_multipart_parser(content_type, req.data) or {
		return error('Failed to create parser: $err')
	}
	
	items := parser.parse() or {
		return error('Failed to parse multipart data: $err')
	}
	
	//Convert to map
	mut result := map[string]MultipartItem{}
	for item in items {
		result[item.name] = item
	}
	
	return result
}

// Get file data
pub fn (items map[string]MultipartItem) get_file(key string) !string {
	item := items[key] or {
		return error('File not found: $key')
	}
	return item.content
}

// Get form field value
pub fn (items map[string]MultipartItem) get(key string) !string {
	item := items[key] or {
		return error('Field not found: $key')
	}
	return item.content
}

// Check if it is a file
pub fn (items map[string]MultipartItem) is_file(key string) bool {
	item := items[key] or { return false }
	return item.filename != ''
}

// Get file name
pub fn (items map[string]MultipartItem) get_filename(key string) !string {
	item := items[key] or {
		return error('Item not found: $key')
	}
	return item.filename
}

// Get content type
pub fn (items map[string]MultipartItem) get_content_type(key string) !string {
	item := items[key] or {
		return error('Item not found: $key')
	}
	return item.content_type
} 