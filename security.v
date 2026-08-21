module vono

import os

//File type whitelist
const allowed_file_extensions = [
	//Document type
	'.txt', '.md', '.pdf', '.doc', '.docx',
	//Image type
	'.jpg', '.jpeg', '.png', '.gif', '.svg', '.ico', '.webp',
	//Audio and video type
	'.mp3', '.mp4', '.wav', '.avi', '.mov', '.webm',
	//compressed file
	'.zip', '.rar', '.7z', '.tar', '.gz',
	// Web file
	'.html', '.htm', '.css', '.js', '.json', '.xml',
	// font file
	'.ttf', '.otf', '.woff', '.woff2', '.eot'
]

// List of dangerous characters
const dangerous_chars = ['<', '>', '"', '|', '?', '*', '\x00', '\r', '\n']

// Danger path mode
const dangerous_patterns = [
	'..',      // Path traversal
	'~',       //User directory
	'$',       // environment variables
	'%',       // Windows environment variables
	'\\\\',    // UNC path
	'/..',     // Unix path traversal
	'\\..',    // Windows path traversal
	'../',     // Relative path traversal
	'..\\',    // Windows relative path traversal
]

//Secure path verification options
pub struct PathValidationOptions {
pub:
	allow_absolute_paths   bool     // Whether to allow absolute paths
	allow_hidden_files     bool     // Whether to allow hidden files (starting with .)
	check_file_extension   bool = true   // Whether to check the file extension whitelist
	max_path_length        int = 260     //Maximum path length (Windows limit)
	allowed_base_paths     []string      // List of allowed base paths
	custom_allowed_extensions []string   // Customize allowed extensions
}

//Default path validation options
pub fn default_path_validation_options() PathValidationOptions {
	return PathValidationOptions{}
}

// Enhanced path security checks
pub fn validate_file_path(path string, options PathValidationOptions) !string {
	// 1. Basic check
	if path.len == 0 {
		return error('Empty path not allowed')
	}
	
	if path.len > options.max_path_length {
		return error('Path too long: ${path.len} > ${options.max_path_length}')
	}
	
	// 2. Normalized path
	clean_path := normalize_path(path)
	
	// 3. Check for dangerous characters
	for dangerous_char in dangerous_chars {
		if clean_path.contains(dangerous_char) {
			return error('Dangerous character detected: ${dangerous_char}')
		}
	}
	
	// 4. Check for dangerous patterns
	for pattern in dangerous_patterns {
		if clean_path.contains(pattern) {
			return error('Dangerous path pattern detected: ${pattern}')
		}
	}
	
	// 5. Check absolute path
	if !options.allow_absolute_paths {
		if is_absolute_path(clean_path) {
			return error('Absolute paths not allowed')
		}
	}
	
	// 6. Check hidden files
	if !options.allow_hidden_files {
		if is_hidden_file(clean_path) {
			return error('Hidden files not allowed')
		}
	}
	
	// 7. Check file extension
	if options.check_file_extension {
		if !is_allowed_file_type(clean_path, options.custom_allowed_extensions) {
			return error('File type not allowed')
		}
	}
	
	// 8. Check base path restrictions
	if options.allowed_base_paths.len > 0 {
		if !is_within_allowed_paths(clean_path, options.allowed_base_paths) {
			return error('Path outside allowed directories')
		}
	}
	
	return clean_path
}

// path normalization
fn normalize_path(path string) string {
	// Remove extra whitespace characters
	mut clean_path := path.trim_space()
	
	// The unified path separator is /
	clean_path = clean_path.replace('\\', '/')
	
	// Remove duplicate path separators
	for clean_path.contains('//') {
		clean_path = clean_path.replace('//', '/')
	}
	
	// Remove trailing path separator
	if clean_path.ends_with('/') && clean_path.len > 1 {
		clean_path = clean_path[..clean_path.len - 1]
	}
	
	return clean_path
}

// Check if it is an absolute path
fn is_absolute_path(path string) bool {
	// Unix/Linux absolute path
	if path.starts_with('/') {
		return true
	}
	
	// Windows absolute path (C:, D:, etc.)
	if path.len >= 2 && path[1] == `:` {
		return true
	}
	
	// UNC path (\\server\share)
	if path.starts_with('//') {
		return true
	}
	
	return false
}

// Check if it is a hidden file
fn is_hidden_file(path string) bool {
	// Get the file name part
	parts := path.split('/')
	if parts.len == 0 {
		return false
	}
	
	filename := parts.last()
	return filename.starts_with('.') && filename != '.' && filename != '..'
}

// Check if the file type is allowed
fn is_allowed_file_type(path string, custom_extensions []string) bool {
	ext := os.file_ext(path).to_lower()
	
	// If there is no extension, reject
	if ext == '' {
		return false
	}
	
	// Check custom extension list
	if custom_extensions.len > 0 {
		return ext in custom_extensions
	}
	
	// Check the default whitelist
	return ext in allowed_file_extensions
}

// Check if the path is within the allowed base paths
fn is_within_allowed_paths(path string, allowed_paths []string) bool {
	for allowed_path in allowed_paths {
		normalized_allowed := normalize_path(allowed_path)
		if path.starts_with(normalized_allowed) {
			return true
		}
	}
	return false
}

// Convenience function: basic path security check (backwards compatible)
pub fn is_safe_path(path string) bool {
	result := validate_file_path(path, default_path_validation_options()) or { return false }
	return result.len > 0
}

// Convenience function: file path security check (backward compatibility)
pub fn is_safe_file_path(path string) bool {
	return is_safe_path(path)
}

// Input validation: file hash
pub fn validate_file_hash(hash string) !string {
	if hash.len == 0 {
		return error('File hash cannot be empty')
	}
	
	// MD5 hash length check
	if hash.len != 32 {
		return error('Invalid hash length: expected 32, got ${hash.len}')
	}
	
	// Check if it contains only hexadecimal characters
	for ch in hash {
		if !ch.is_hex_digit() {
			return error('Invalid hash character: ${ch}')
		}
	}
	
	return hash.to_lower()
}

// Input validation: shard index
pub fn validate_chunk_index(index_str string, max_chunks int) !int {
	if index_str.len == 0 {
		return error('Chunk index cannot be empty')
	}
	
	// Check if it only contains numbers
	for ch in index_str {
		if !ch.is_digit() {
			return error('Chunk index must be a number')
		}
	}
	
	index := index_str.int()
	
	if index < 0 {
		return error('Chunk index cannot be negative')
	}
	
	if max_chunks > 0 && index >= max_chunks {
		return error('Chunk index ${index} exceeds maximum ${max_chunks}')
	}
	
	return index
}

// Input validation: file size
pub fn validate_file_size(size_str string, max_size int) !int {
	if size_str.len == 0 {
		return error('File size cannot be empty')
	}
	
	// Check if it only contains numbers
	for ch in size_str {
		if !ch.is_digit() {
			return error('File size must be a number')
		}
	}
	
	size := size_str.int()
	
	if size <= 0 {
		return error('File size must be positive')
	}
	
	if size > max_size {
		return error('File size ${size} exceeds maximum ${max_size}')
	}
	
	return size
}

//Input validation: file name
pub fn validate_filename(filename string) !string {
	if filename.len == 0 {
		return error('Filename cannot be empty')
	}
	
	if filename.len > 255 {
		return error('Filename too long: ${filename.len} > 255')
	}
	
	// Check for dangerous characters
	for dangerous_char in dangerous_chars {
		if filename.contains(dangerous_char) {
			return error('Dangerous character in filename: ${dangerous_char}')
		}
	}
	
	// Check reserved names (Windows)
	reserved_names := ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 
					   'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 
					   'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9']
	
	name_without_ext := filename.split('.')[0].to_upper()
	if name_without_ext in reserved_names {
		return error('Reserved filename not allowed: ${filename}')
	}
	
	return filename
}

// Safe content type detection
pub fn get_safe_content_type(file_path string) string {
	ext := os.file_ext(file_path).to_lower()
	
	// Only return content types that are known to be safe
	match ext {
		'.html', '.htm' { return 'text/html; charset=utf-8' }
		'.css' { return 'text/css; charset=utf-8' }
		'.js' { return 'application/javascript; charset=utf-8' }
		'.json' { return 'application/json; charset=utf-8' }
		'.xml' { return 'application/xml; charset=utf-8' }
		'.txt' { return 'text/plain; charset=utf-8' }
		'.md' { return 'text/markdown; charset=utf-8' }
		'.pdf' { return 'application/pdf' }
		'.png' { return 'image/png' }
		'.jpg', '.jpeg' { return 'image/jpeg' }
		'.gif' { return 'image/gif' }
		'.svg' { return 'image/svg+xml' }
		'.ico' { return 'image/x-icon' }
		'.woff' { return 'font/woff' }
		'.woff2' { return 'font/woff2' }
		'.ttf' { return 'font/ttf' }
		'.eot' { return 'application/vnd.ms-fontobject' }
		'.otf' { return 'font/otf' }
		'.mp4' { return 'video/mp4' }
		'.webm' { return 'video/webm' }
		'.mp3' { return 'audio/mpeg' }
		'.wav' { return 'audio/wav' }
		'.zip' { return 'application/zip' }
		'.tar' { return 'application/x-tar' }
		'.gz' { return 'application/gzip' }
		else { 
			// For unknown types, return a safe default type
			return 'application/octet-stream'
		}
	}
}