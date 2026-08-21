module vono

import os
import io
import time
import rand
import crypto.md5

// LocalStorage local storage provider
pub struct LocalStorage {
	config LocalStorageConfig
mut:
	// Memory storage used to track multipart uploads
	multipart_uploads map[string]MultipartUploadState
}

//Multiple upload status
struct MultipartUploadState {
mut:
	bucket       string
	key          string
	content_type string
	parts        map[int]PartInfo
	created_at   i64
}

//Create local storage provider
pub fn new_local_storage(config LocalStorageConfig) !LocalStorage {
	// Make sure the base directory exists
	if config.create_dirs {
		os.mkdir_all(config.base_path) or {
			return error('Failed to create base directory: ${err}')
		}
	}
	return LocalStorage{
		config: config
		multipart_uploads: map[string]MultipartUploadState{}
	}
}

// Get the full path of the file
fn (s LocalStorage) get_full_path(bucket string, key string) string {
	return os.join_path(s.config.base_path, bucket, key)
}

// Get bucket directory path
fn (s LocalStorage) get_bucket_path(bucket string) string {
	return os.join_path(s.config.base_path, bucket)
}

// Calculate the ETag (MD5) of the data
fn calculate_etag(data []u8) string {
	hash := md5.sum(data)
	mut result := ''
	for b in hash {
		result += '${b:02x}'
	}
	return '"${result}"'
}


// ============================================================================
// StorageProvider interface implementation - basic operations
// ============================================================================

//Upload file
pub fn (mut s LocalStorage) upload(bucket string, key string, data []u8, content_type string) !StorageResult {
	// Make sure the bucket directory exists
	bucket_path := s.get_bucket_path(bucket)
	if s.config.create_dirs {
		os.mkdir_all(bucket_path) or {
			return error(new_storage_error(.invalid_config, 'Failed to create bucket directory: ${err}',
				'local', 'upload').msg())
		}
	}

	// Get the full file path
	full_path := s.get_full_path(bucket, key)

	// Make sure the parent directory exists
	parent_dir := os.dir(full_path)
	if parent_dir != '' && parent_dir != '.' {
		os.mkdir_all(parent_dir) or {
			return error(new_storage_error(.invalid_config, 'Failed to create parent directory: ${err}',
				'local', 'upload').msg())
		}
	}

	// write to file
	os.write_file_array(full_path, data) or {
		return error(new_storage_error(.unknown, 'Failed to write file: ${err}', 'local',
			'upload').msg())
	}

	// Calculate ETag
	etag := calculate_etag(data)

	return new_storage_result(key, etag, i64(data.len))
}

// Streaming upload file
pub fn (mut s LocalStorage) upload_stream(bucket string, key string, mut reader io.Reader, size i64, content_type string) !StorageResult {
	// Make sure the bucket directory exists
	bucket_path := s.get_bucket_path(bucket)
	if s.config.create_dirs {
		os.mkdir_all(bucket_path) or {
			return error(new_storage_error(.invalid_config, 'Failed to create bucket directory: ${err}',
				'local', 'upload_stream').msg())
		}
	}

	// Get the full file path
	full_path := s.get_full_path(bucket, key)

	// Make sure the parent directory exists
	parent_dir := os.dir(full_path)
	if parent_dir != '' && parent_dir != '.' {
		os.mkdir_all(parent_dir) or {
			return error(new_storage_error(.invalid_config, 'Failed to create parent directory: ${err}',
				'local', 'upload_stream').msg())
		}
	}

	// read all data
	mut data := []u8{}
	mut buf := []u8{len: 8192}
	for {
		n := reader.read(mut buf) or { break }
		if n == 0 {
			break
		}
		data << buf[..n]
	}

	// write to file
	os.write_file_array(full_path, data) or {
		return error(new_storage_error(.unknown, 'Failed to write file: ${err}', 'local',
			'upload_stream').msg())
	}

	// Calculate ETag
	etag := calculate_etag(data)

	return new_storage_result(key, etag, i64(data.len))
}

// Download file
pub fn (s LocalStorage) download(bucket string, key string) ![]u8 {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return error(new_not_found_error('local', bucket, key).msg())
	}

	data := os.read_bytes(full_path) or {
		return error(new_storage_error(.unknown, 'Failed to read file: ${err}', 'local',
			'download').msg())
	}

	return data
}

// Streaming download file
pub fn (s LocalStorage) download_stream(bucket string, key string, mut writer io.Writer) !i64 {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return error(new_not_found_error('local', bucket, key).msg())
	}

	data := os.read_bytes(full_path) or {
		return error(new_storage_error(.unknown, 'Failed to read file: ${err}', 'local',
			'download_stream').msg())
	}

	written := writer.write(data) or {
		return error(new_storage_error(.unknown, 'Failed to write to stream: ${err}', 'local',
			'download_stream').msg())
	}

	return i64(written)
}

// delete file
pub fn (s LocalStorage) delete(bucket string, key string) ! {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return error(new_not_found_error('local', bucket, key).msg())
	}

	os.rm(full_path) or {
		return error(new_storage_error(.unknown, 'Failed to delete file: ${err}', 'local',
			'delete').msg())
	}
}

// Check if the file exists
pub fn (s LocalStorage) exists(bucket string, key string) !bool {
	full_path := s.get_full_path(bucket, key)
	return os.exists(full_path) && os.is_file(full_path)
}


// ============================================================================
// StorageProvider interface implementation - metadata operation
// ============================================================================

// Get file metadata
pub fn (s LocalStorage) head(bucket string, key string) !ObjectInfo {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return error(new_not_found_error('local', bucket, key).msg())
	}

	// Get file information
	file_size := os.file_size(full_path)
	mtime := os.file_last_mod_unix(full_path)

	//Read file to calculate ETag
	data := os.read_bytes(full_path) or {
		return error(new_storage_error(.unknown, 'Failed to read file for metadata: ${err}',
			'local', 'head').msg())
	}
	etag := calculate_etag(data)

	//Infer content_type
	content_type := infer_content_type(key)

	return new_object_info(key, i64(file_size), etag, content_type, mtime)
}

// copy file
pub fn (mut s LocalStorage) copy(src_bucket string, src_key string, dst_bucket string, dst_key string) !StorageResult {
	src_path := s.get_full_path(src_bucket, src_key)

	if !os.exists(src_path) {
		return error(new_not_found_error('local', src_bucket, src_key).msg())
	}

	// Make sure the target bucket directory exists
	dst_bucket_path := s.get_bucket_path(dst_bucket)
	if s.config.create_dirs {
		os.mkdir_all(dst_bucket_path) or {
			return error(new_storage_error(.invalid_config, 'Failed to create destination bucket directory: ${err}',
				'local', 'copy').msg())
		}
	}

	dst_path := s.get_full_path(dst_bucket, dst_key)

	// Make sure the target parent directory exists
	parent_dir := os.dir(dst_path)
	if parent_dir != '' && parent_dir != '.' {
		os.mkdir_all(parent_dir) or {
			return error(new_storage_error(.invalid_config, 'Failed to create destination parent directory: ${err}',
				'local', 'copy').msg())
		}
	}

	// copy file
	os.cp(src_path, dst_path) or {
		return error(new_storage_error(.unknown, 'Failed to copy file: ${err}', 'local',
			'copy').msg())
	}

	// Read the file to calculate the ETag and size
	data := os.read_bytes(dst_path) or {
		return error(new_storage_error(.unknown, 'Failed to read copied file: ${err}', 'local',
			'copy').msg())
	}
	etag := calculate_etag(data)

	return new_storage_result(dst_key, etag, i64(data.len))
}

// ============================================================================
// StorageProvider interface implementation - list operation
// ============================================================================

// List files
pub fn (s LocalStorage) list(bucket string, options ListOptions) !ListResult {
	bucket_path := s.get_bucket_path(bucket)

	if !os.exists(bucket_path) {
		return error(new_bucket_not_found_error('local', bucket).msg())
	}

	mut objects := []ObjectInfo{}
	mut common_prefixes := []string{}

	// Recursively traverse the directory
	s.list_directory_recursive(bucket_path, bucket_path, options.prefix, options.delimiter,
		options.start_after, options.max_keys, mut objects, mut common_prefixes)

	// Check if there are more results
	is_truncated := objects.len >= options.max_keys
	next_marker := if is_truncated && objects.len > 0 { objects.last().key } else { '' }

	return new_list_result(objects, common_prefixes, is_truncated, next_marker)
}

// List directory contents recursively
fn (s LocalStorage) list_directory_recursive(base_path string, current_path string, prefix string, delimiter string, start_after string, max_keys int, mut objects []ObjectInfo, mut common_prefixes []string) {
	if objects.len >= max_keys {
		return
	}

	entries := os.ls(current_path) or { return }

	for entry in entries {
		if objects.len >= max_keys {
			return
		}

		entry_path := os.join_path(current_path, entry)
		// Calculate the key relative to bucket
		relative_key := entry_path.replace(base_path + os.path_separator, '').replace(os.path_separator,
			'/')

		// Check for prefix matching
		if prefix != '' && !relative_key.starts_with(prefix) {
			continue
		}

		// Check start_after
		if start_after != '' && relative_key <= start_after {
			continue
		}

		if os.is_dir(entry_path) {
			// If there is a delimiter, add it to common_prefixes
			if delimiter != '' {
				prefix_key := relative_key + '/'
				if prefix_key !in common_prefixes {
					common_prefixes << prefix_key
				}
			} else {
				// Recursively traverse subdirectories
				s.list_directory_recursive(base_path, entry_path, prefix, delimiter,
					start_after, max_keys, mut objects, mut common_prefixes)
			}
		} else {
			// document
			file_size := os.file_size(entry_path)
			mtime := os.file_last_mod_unix(entry_path)

			//Read file to calculate ETag
			data := os.read_bytes(entry_path) or { continue }
			etag := calculate_etag(data)
			content_type := infer_content_type(relative_key)

			objects << new_object_info(relative_key, i64(file_size), etag, content_type,
				mtime)
		}
	}
}


// ============================================================================
// StorageProvider interface implementation - pre-signed URL
// ============================================================================

// Generate pre-signed URL
pub fn (s LocalStorage) presign_url(bucket string, key string, options PresignOptions) !string {
	full_path := s.get_full_path(bucket, key)

	// For GET requests, check if the file exists
	if options.method == 'GET' && !os.exists(full_path) {
		return error(new_not_found_error('local', bucket, key).msg())
	}

	// Local storage returns HTTP URL or file path
	if s.config.url_prefix != '' {
		// Return HTTP URL
		return '${s.config.url_prefix}/${bucket}/${key}'
	} else {
		//Return local file path
		return full_path
	}
}

// ============================================================================
//StorageProvider interface implementation - multipart upload
// ============================================================================

//Initialize multipart upload
pub fn (mut s LocalStorage) init_multipart(bucket string, key string, content_type string) !string {
	// Make sure the bucket directory exists
	bucket_path := s.get_bucket_path(bucket)
	if s.config.create_dirs {
		os.mkdir_all(bucket_path) or {
			return error(new_storage_error(.invalid_config, 'Failed to create bucket directory: ${err}',
				'local', 'init_multipart').msg())
		}
	}

	// Generate upload_id
	upload_id := generate_upload_id()

	//Create temporary directory storage shards
	temp_dir := os.join_path(s.config.base_path, '.multipart', upload_id)
	os.mkdir_all(temp_dir) or {
		return error(new_storage_error(.unknown, 'Failed to create temp directory: ${err}',
			'local', 'init_multipart').msg())
	}

	//Record upload status
	s.multipart_uploads[upload_id] = MultipartUploadState{
		bucket: bucket
		key: key
		content_type: content_type
		parts: map[int]PartInfo{}
		created_at: time.now().unix()
	}

	return upload_id
}

//Upload fragments
pub fn (mut s LocalStorage) upload_part(bucket string, key string, upload_id string, part_number int, data []u8) !string {
	// Check if the upload exists
	if upload_id !in s.multipart_uploads {
		return error(new_storage_error(.object_not_found, 'Multipart upload not found: ${upload_id}',
			'local', 'upload_part').msg())
	}

	//Write fragmented file
	temp_dir := os.join_path(s.config.base_path, '.multipart', upload_id)
	part_path := os.join_path(temp_dir, '${part_number}')

	os.write_file_array(part_path, data) or {
		return error(new_storage_error(.unknown, 'Failed to write part: ${err}', 'local',
			'upload_part').msg())
	}

	// Calculate ETag
	etag := calculate_etag(data)

	//Update upload status
	mut upload_state := s.multipart_uploads[upload_id]
	upload_state.parts[part_number] = new_part_info(part_number, etag, i64(data.len))
	s.multipart_uploads[upload_id] = upload_state

	return etag
}

//Complete multipart upload
pub fn (mut s LocalStorage) complete_multipart(bucket string, key string, upload_id string, parts []PartInfo) !StorageResult {
	// Check if the upload exists
	if upload_id !in s.multipart_uploads {
		return error(new_storage_error(.object_not_found, 'Multipart upload not found: ${upload_id}',
			'local', 'complete_multipart').msg())
	}

	_ := s.multipart_uploads[upload_id] // Verify that the upload exists
	temp_dir := os.join_path(s.config.base_path, '.multipart', upload_id)

	// Merge all shards
	mut final_data := []u8{}
	for part in parts {
		part_path := os.join_path(temp_dir, '${part.part_number}')
		part_data := os.read_bytes(part_path) or {
			return error(new_storage_error(.object_not_found, 'Part not found: ${part.part_number}',
				'local', 'complete_multipart').msg())
		}
		final_data << part_data
	}

	//Write final file
	full_path := s.get_full_path(bucket, key)

	// Make sure the parent directory exists
	parent_dir := os.dir(full_path)
	if parent_dir != '' && parent_dir != '.' {
		os.mkdir_all(parent_dir) or {
			return error(new_storage_error(.invalid_config, 'Failed to create parent directory: ${err}',
				'local', 'complete_multipart').msg())
		}
	}

	os.write_file_array(full_path, final_data) or {
		return error(new_storage_error(.unknown, 'Failed to write final file: ${err}',
			'local', 'complete_multipart').msg())
	}

	// Clean up temporary files
	os.rmdir_all(temp_dir) or {}

	//Delete upload status
	s.multipart_uploads.delete(upload_id)

	// Calculate ETag
	etag := calculate_etag(final_data)

	return new_storage_result(key, etag, i64(final_data.len))
}

//Cancel multipart upload
pub fn (mut s LocalStorage) abort_multipart(bucket string, key string, upload_id string) ! {
	// Check if the upload exists
	if upload_id !in s.multipart_uploads {
		return error(new_storage_error(.object_not_found, 'Multipart upload not found: ${upload_id}',
			'local', 'abort_multipart').msg())
	}

	// Clean up temporary files
	temp_dir := os.join_path(s.config.base_path, '.multipart', upload_id)
	os.rmdir_all(temp_dir) or {}

	//Delete upload status
	s.multipart_uploads.delete(upload_id)
}


// ============================================================================
//StorageProvider interface implementation - Bucket operation
// ============================================================================

//Create bucket
pub fn (s LocalStorage) create_bucket(bucket string) ! {
	bucket_path := s.get_bucket_path(bucket)

	if os.exists(bucket_path) {
		return // Bucket already exists, no error will be reported
	}

	os.mkdir_all(bucket_path) or {
		return error(new_storage_error(.unknown, 'Failed to create bucket: ${err}', 'local',
			'create_bucket').msg())
	}
}

// delete bucket
pub fn (s LocalStorage) delete_bucket(bucket string) ! {
	bucket_path := s.get_bucket_path(bucket)

	if !os.exists(bucket_path) {
		return error(new_bucket_not_found_error('local', bucket).msg())
	}

	// Check if bucket is empty
	entries := os.ls(bucket_path) or { []string{} }
	if entries.len > 0 {
		return error(new_storage_error(.access_denied, 'Bucket is not empty', 'local',
			'delete_bucket').msg())
	}

	os.rmdir(bucket_path) or {
		return error(new_storage_error(.unknown, 'Failed to delete bucket: ${err}', 'local',
			'delete_bucket').msg())
	}
}

// Check if bucket exists
pub fn (s LocalStorage) bucket_exists(bucket string) !bool {
	bucket_path := s.get_bucket_path(bucket)
	return os.exists(bucket_path) && os.is_dir(bucket_path)
}

// Get provider name
pub fn (s LocalStorage) provider_name() string {
	return 'local'
}

// ============================================================================
// helper function
// ============================================================================

// Generate upload ID
fn generate_upload_id() string {
	now := time.now().unix_nano()
	random_bytes := rand.bytes(8) or { []u8{len: 8} }
	mut random_hex := ''
	for b in random_bytes {
		random_hex += '${b:02x}'
	}
	return '${now}-${random_hex}'
}

// Infer content_type based on file extension
fn infer_content_type(key string) string {
	ext := os.file_ext(key).to_lower()
	match ext {
		'.html', '.htm' { return 'text/html' }
		'.css' { return 'text/css' }
		'.js' { return 'application/javascript' }
		'.json' { return 'application/json' }
		'.xml' { return 'application/xml' }
		'.txt' { return 'text/plain' }
		'.png' { return 'image/png' }
		'.jpg', '.jpeg' { return 'image/jpeg' }
		'.gif' { return 'image/gif' }
		'.svg' { return 'image/svg+xml' }
		'.webp' { return 'image/webp' }
		'.ico' { return 'image/x-icon' }
		'.pdf' { return 'application/pdf' }
		'.zip' { return 'application/zip' }
		'.gz', '.gzip' { return 'application/gzip' }
		'.tar' { return 'application/x-tar' }
		'.mp3' { return 'audio/mpeg' }
		'.mp4' { return 'video/mp4' }
		'.webm' { return 'video/webm' }
		'.woff' { return 'font/woff' }
		'.woff2' { return 'font/woff2' }
		'.ttf' { return 'font/ttf' }
		'.otf' { return 'font/otf' }
		else { return 'application/octet-stream' }
	}
}
