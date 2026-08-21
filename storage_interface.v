module vono

import io

//Storage operation results
pub struct StorageResult {
pub:
	success    bool
	object_key string
	etag       string
	size       i64
	error_msg  string
}

//File object information
pub struct ObjectInfo {
pub:
	key           string
	size          i64
	etag          string
	content_type  string
	last_modified i64
	metadata      map[string]string
}

// list options
pub struct ListOptions {
pub:
	prefix      string
	delimiter   string
	max_keys    int = 1000
	start_after string
}

// list results
pub struct ListResult {
pub:
	objects         []ObjectInfo
	common_prefixes []string
	is_truncated    bool
	next_marker     string
}

// Pre-signed URL options
pub struct PresignOptions {
pub:
	expires_in   int    = 3600 // Second
	method       string = 'GET'
	content_type string
}

// shard information
pub struct PartInfo {
pub:
	part_number int
	etag        string
	size        i64
}


// Unified storage interface
pub interface StorageProvider {
mut:
	//Basic operations
	upload(bucket string, key string, data []u8, content_type string) !StorageResult
	upload_stream(bucket string, key string, mut reader io.Reader, size i64, content_type string) !StorageResult
	download(bucket string, key string) ![]u8
	download_stream(bucket string, key string, mut writer io.Writer) !i64
	delete(bucket string, key string) !
	exists(bucket string, key string) !bool
	// Metadata operations
	head(bucket string, key string) !ObjectInfo
	copy(src_bucket string, src_key string, dst_bucket string, dst_key string) !StorageResult
	// list operations
	list(bucket string, options ListOptions) !ListResult
	// Pre-signed URL
	presign_url(bucket string, key string, options PresignOptions) !string
	//Multiple upload
	init_multipart(bucket string, key string, content_type string) !string //return upload_id
	upload_part(bucket string, key string, upload_id string, part_number int, data []u8) !string //return etag
	complete_multipart(bucket string, key string, upload_id string, parts []PartInfo) !StorageResult
	abort_multipart(bucket string, key string, upload_id string) !
	// Bucket operations
	create_bucket(bucket string) !
	delete_bucket(bucket string) !
	bucket_exists(bucket string) !bool
	// Get provider name
	provider_name() string
}

//Create successful stored result
pub fn new_storage_result(object_key string, etag string, size i64) StorageResult {
	return StorageResult{
		success: true
		object_key: object_key
		etag: etag
		size: size
		error_msg: ''
	}
}

//Create failed stored results
pub fn new_storage_error_result(error_msg string) StorageResult {
	return StorageResult{
		success: false
		object_key: ''
		etag: ''
		size: 0
		error_msg: error_msg
	}
}

//Create object information
pub fn new_object_info(key string, size i64, etag string, content_type string, last_modified i64) ObjectInfo {
	return ObjectInfo{
		key: key
		size: size
		etag: etag
		content_type: content_type
		last_modified: last_modified
		metadata: map[string]string{}
	}
}

//Create object information with metadata
pub fn new_object_info_with_metadata(key string, size i64, etag string, content_type string, last_modified i64, metadata map[string]string) ObjectInfo {
	return ObjectInfo{
		key: key
		size: size
		etag: etag
		content_type: content_type
		last_modified: last_modified
		metadata: metadata
	}
}

//Create an empty list of results
pub fn new_empty_list_result() ListResult {
	return ListResult{
		objects: []ObjectInfo{}
		common_prefixes: []string{}
		is_truncated: false
		next_marker: ''
	}
}

//Create list results
pub fn new_list_result(objects []ObjectInfo, common_prefixes []string, is_truncated bool, next_marker string) ListResult {
	return ListResult{
		objects: objects
		common_prefixes: common_prefixes
		is_truncated: is_truncated
		next_marker: next_marker
	}
}

//Create shard information
pub fn new_part_info(part_number int, etag string, size i64) PartInfo {
	return PartInfo{
		part_number: part_number
		etag: etag
		size: size
	}
}
