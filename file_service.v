module hono

import os
import time
import crypto.md5

// FileService unified file service layer
// Provide high-level file operation API, manage storage providers and metadata
@[heap]
pub struct FileService {
mut:
	provider      &StorageProvider = unsafe { nil }
	db            DatabaseManager
	config        FileServiceConfig
	chunk_manager ChunkManager
	// Configuration for hot reloading
	current_config StorageConfig
}

//FileService configuration
pub struct FileServiceConfig {
pub:
	storage        StorageConfig
	db_path        string = './storage/files.db'
	default_bucket string = 'default'
	chunk_size     int    = 5 * 1024 * 1024 // 5MB
	max_file_size  i64    = 5 * 1024 * 1024 * 1024 // 5GB
}

//File upload parameters
pub struct UploadParams {
pub:
	bucket       string
	filename     string
	content_type string
	metadata     string // Additional metadata in JSON format
}

//File upload results
pub struct UploadResult {
pub:
	file_uuid    string
	file_hash    string
	file_name    string
	file_size    i64
	file_type    string
	storage_type string
	bucket       string
	object_key   string
	etag         string
	created_at   i64
}

// Pre-signed URL result
pub struct PresignResult {
pub:
	url        string
	expires_at i64
	method     string
}

// ============================================================================
// Storage provider factory method
// ============================================================================

//Create a storage provider based on configuration
pub fn create_storage_provider(config StorageConfig) !&StorageProvider {
	match config.storage_type {
		.local {
			mut provider := new_local_storage(config.local)!
			return &provider
		}
		.s3 {
			mut provider := new_s3_storage(config.s3)!
			return &provider
		}
		.aliyun_oss {
			mut provider := new_aliyun_oss(config.aliyun_oss)!
			return &provider
		}
		.tencent_cos {
			mut provider := new_tencent_cos(config.tencent_cos)!
			return &provider
		}
	}
}

// Create a storage provider based on the storage type string
pub fn create_storage_provider_by_type(storage_type string, config StorageConfig) !&StorageProvider {
	match storage_type.to_lower() {
		'local' {
			mut provider := new_local_storage(config.local)!
			return &provider
		}
		's3' {
			mut provider := new_s3_storage(config.s3)!
			return &provider
		}
		'aliyun_oss', 'oss' {
			mut provider := new_aliyun_oss(config.aliyun_oss)!
			return &provider
		}
		'tencent_cos', 'cos' {
			mut provider := new_tencent_cos(config.tencent_cos)!
			return &provider
		}
		else {
			return error('Unknown storage type: ${storage_type}')
		}
	}
}

// ============================================================================
//FileService creation and initialization
// ============================================================================

//Create FileService
pub fn new_file_service(config FileServiceConfig) !FileService {
	//Verify storage configuration
	validation := validate_storage_config(config.storage)
	if !validation.valid {
		return error(validation.error_message)
	}

	// Make sure the database directory exists
	db_dir := os.dir(config.db_path)
	if db_dir != '' && db_dir != '.' {
		os.mkdir_all(db_dir) or {
			return error('Failed to create database directory: ${err}')
		}
	}

	//Create database manager
	mut db := new_database_manager(config.db_path)!

	//Create storage provider
	provider := create_storage_provider(config.storage)!

	//Create shard manager
	chunk_manager := new_chunk_manager_default(mut db, provider)

	return FileService{
		provider: provider
		db: db
		config: config
		chunk_manager: chunk_manager
		current_config: config.storage
	}
}

//Create a locally stored FileService using default configuration
pub fn new_local_file_service(base_path string, db_path string) !FileService {
	config := FileServiceConfig{
		storage: new_local_storage_config(base_path)
		db_path: db_path
		default_bucket: 'default'
	}
	return new_file_service(config)
}

//Create FileService from JSON configuration file
pub fn new_file_service_from_config_file(config_path string, db_path string) !FileService {
	storage_config := load_storage_config_from_file(config_path)!
	config := FileServiceConfig{
		storage: storage_config
		db_path: db_path
		default_bucket: get_default_bucket(storage_config)
	}
	return new_file_service(config)
}

//Create FileService from environment variables
pub fn new_file_service_from_env(db_path string) !FileService {
	storage_config := load_storage_config_from_env()!
	config := FileServiceConfig{
		storage: storage_config
		db_path: db_path
		default_bucket: get_default_bucket(storage_config)
	}
	return new_file_service(config)
}

// Get the default bucket
fn get_default_bucket(config StorageConfig) string {
	match config.storage_type {
		.local { return 'default' }
		.s3 { return config.s3.default_bucket }
		.aliyun_oss { return config.aliyun_oss.default_bucket }
		.tencent_cos { return config.tencent_cos.default_bucket }
	}
}


// ============================================================================
// Advanced file operation API
// ============================================================================

//Upload file
pub fn (mut fs FileService) upload_file(params UploadParams, data []u8) !UploadResult {
	bucket := if params.bucket != '' { params.bucket } else { fs.config.default_bucket }
	
	// Check file size
	if i64(data.len) > fs.config.max_file_size {
		return error('File size exceeds maximum allowed size: ${data.len} > ${fs.config.max_file_size}')
	}

	// Calculate file hash
	file_hash := calculate_md5_hash(data)

	// Generate object key
	object_key := generate_object_key(params.filename, file_hash)

	// Determine content_type
	content_type := if params.content_type != '' {
		params.content_type
	} else {
		infer_content_type(params.filename)
	}

	// Upload to storage provider
	result := fs.provider.upload(bucket, object_key, data, content_type)!

	//Save file metadata to database
	file_info := fs.db.insert_file(FileInfo{
		file_hash: file_hash
		file_name: params.filename
		file_size: i64(data.len)
		file_type: content_type
		storage_type: fs.provider.provider_name()
		bucket: bucket
		object_key: object_key
		metadata: params.metadata
	})!

	return UploadResult{
		file_uuid: file_info.file_uuid
		file_hash: file_hash
		file_name: params.filename
		file_size: i64(data.len)
		file_type: content_type
		storage_type: fs.provider.provider_name()
		bucket: bucket
		object_key: object_key
		etag: result.etag
		created_at: file_info.created_at
	}
}

// Download file (via UUID)
pub fn (mut fs FileService) download_file(file_uuid string) ![]u8 {
	// Get file metadata
	file_info := fs.db.get_file_by_uuid(file_uuid)!

	// Download from storage provider
	return fs.provider.download(file_info.bucket, file_info.object_key)
}

// Download file (via bucket and key)
pub fn (mut fs FileService) download_file_by_key(bucket string, object_key string) ![]u8 {
	return fs.provider.download(bucket, object_key)
}

// Delete file (via UUID)
pub fn (mut fs FileService) delete_file(file_uuid string) ! {
	// Get file metadata
	file_info := fs.db.get_file_by_uuid(file_uuid)!

	// Remove from storage provider
	fs.provider.delete(file_info.bucket, file_info.object_key)!

	//Remove metadata from database
	fs.db.delete_file(file_uuid)!
}

// Get file information (via UUID)
pub fn (fs FileService) get_file_info(file_uuid string) !FileInfo {
	return fs.db.get_file_by_uuid(file_uuid)
}

// Get file information (via hash)
pub fn (fs FileService) get_file_by_hash(file_hash string) !FileInfo {
	return fs.db.get_file_by_hash(file_hash)
}

// Check if the file exists (via UUID)
pub fn (fs FileService) file_exists(file_uuid string) bool {
	return fs.db.file_exists(file_uuid)
}

// Check if the file exists (via bucket and key)
pub fn (mut fs FileService) file_exists_by_key(bucket string, object_key string) !bool {
	return fs.provider.exists(bucket, object_key)
}

// Get pre-signed URL
pub fn (mut fs FileService) get_presigned_url(file_uuid string, expires_in int) !PresignResult {
	// Get file metadata
	file_info := fs.db.get_file_by_uuid(file_uuid)!

	// Generate pre-signed URL
	url := fs.provider.presign_url(file_info.bucket, file_info.object_key, PresignOptions{
		expires_in: expires_in
		method: 'GET'
	})!

	return PresignResult{
		url: url
		expires_at: time.now().unix() + i64(expires_in)
		method: 'GET'
	}
}

// Get the pre-signed upload URL
pub fn (mut fs FileService) get_presigned_upload_url(bucket string, object_key string, expires_in int, content_type string) !PresignResult {
	url := fs.provider.presign_url(bucket, object_key, PresignOptions{
		expires_in: expires_in
		method: 'PUT'
		content_type: content_type
	})!

	return PresignResult{
		url: url
		expires_at: time.now().unix() + i64(expires_in)
		method: 'PUT'
	}
}

// List files
pub fn (fs FileService) list_files(options FileListOptions) !FileListResult {
	return fs.db.list_files(options)
}

//Update file metadata
pub fn (mut fs FileService) update_file_metadata(file_uuid string, file_name string, file_type string, metadata string) !FileInfo {
	return fs.db.update_file(file_uuid, file_name, file_type, metadata)
}

// copy file
pub fn (mut fs FileService) copy_file(file_uuid string, dst_bucket string, dst_key string) !UploadResult {
	// Get source file information
	src_info := fs.db.get_file_by_uuid(file_uuid)!

	// copy file
	result := fs.provider.copy(src_info.bucket, src_info.object_key, dst_bucket, dst_key)!

	//Save new file metadata
	new_info := fs.db.insert_file(FileInfo{
		file_hash: src_info.file_hash
		file_name: src_info.file_name
		file_size: src_info.file_size
		file_type: src_info.file_type
		storage_type: fs.provider.provider_name()
		bucket: dst_bucket
		object_key: dst_key
		metadata: src_info.metadata
	})!

	return UploadResult{
		file_uuid: new_info.file_uuid
		file_hash: src_info.file_hash
		file_name: src_info.file_name
		file_size: src_info.file_size
		file_type: src_info.file_type
		storage_type: fs.provider.provider_name()
		bucket: dst_bucket
		object_key: dst_key
		etag: result.etag
		created_at: new_info.created_at
	}
}


// ============================================================================
//Multiple upload operation
// ============================================================================

//Initialize multipart upload
pub fn (mut fs FileService) init_multipart_upload(params InitMultipartParams) !MultipartUpload {
	mut p := params
	if p.bucket == '' {
		p = InitMultipartParams{
			...params
			bucket: fs.config.default_bucket
		}
	}
	if p.chunk_size == 0 {
		p = InitMultipartParams{
			...p
			chunk_size: fs.config.chunk_size
		}
	}
	return fs.chunk_manager.init_multipart(p)
}

//Upload fragments
pub fn (mut fs FileService) upload_part(upload_id string, part_number int, data []u8) !ChunkUploadResult {
	return fs.chunk_manager.upload_part(upload_id, part_number, data)
}

//Complete multipart upload
pub fn (mut fs FileService) complete_multipart_upload(upload_id string) !StorageResult {
	return fs.chunk_manager.complete_multipart(upload_id)
}

//Cancel multipart upload
pub fn (mut fs FileService) abort_multipart_upload(upload_id string) ! {
	return fs.chunk_manager.abort_multipart(upload_id)
}

// Get upload progress
pub fn (fs FileService) get_upload_progress(upload_id string) !UploadProgress {
	return fs.chunk_manager.get_upload_progress(upload_id)
}

// Get the list of shards to be uploaded
pub fn (fs FileService) get_pending_parts(upload_id string) ![]int {
	return fs.chunk_manager.get_pending_parts(upload_id)
}

// ============================================================================
// Provider switching
// ============================================================================

//Switch storage provider
pub fn (mut fs FileService) switch_provider(config StorageConfig) ! {
	//Verify new configuration
	validation := validate_storage_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	//Create a new storage provider
	new_provider := create_storage_provider(config)!

	// update provider
	fs.provider = new_provider
	fs.current_config = config

	// Update the provider of the shard manager
	fs.chunk_manager = new_chunk_manager_default(mut fs.db, new_provider)
}

//Switch to local storage
pub fn (mut fs FileService) switch_to_local(base_path string) ! {
	config := new_local_storage_config(base_path)
	fs.switch_provider(config)!
}

// Switch to S3 storage
pub fn (mut fs FileService) switch_to_s3(endpoint string, access_key string, secret_key string, bucket string) ! {
	config := new_s3_storage_config(endpoint, access_key, secret_key, bucket)
	fs.switch_provider(config)!
}

//Switch to MinIO storage
pub fn (mut fs FileService) switch_to_minio(endpoint string, access_key string, secret_key string, bucket string) ! {
	config := new_minio_storage_config(endpoint, access_key, secret_key, bucket)
	fs.switch_provider(config)!
}

//Switch to Alibaba Cloud OSS
pub fn (mut fs FileService) switch_to_aliyun_oss(endpoint string, access_key_id string, access_key_secret string, bucket string) ! {
	config := new_aliyun_oss_storage_config(endpoint, access_key_id, access_key_secret, bucket)
	fs.switch_provider(config)!
}

//Switch to Tencent Cloud COS
pub fn (mut fs FileService) switch_to_tencent_cos(secret_id string, secret_key string, region string, bucket string) ! {
	config := new_tencent_cos_storage_config(secret_id, secret_key, region, bucket)
	fs.switch_provider(config)!
}

// Hot load configuration from configuration file
pub fn (mut fs FileService) reload_config_from_file(config_path string) ! {
	config := load_storage_config_from_file(config_path)!
	fs.switch_provider(config)!
}

// Hot load configuration from environment variables
pub fn (mut fs FileService) reload_config_from_env() ! {
	config := load_storage_config_from_env()!
	fs.switch_provider(config)!
}


// ============================================================================
//Status and information query
// ============================================================================

// Get the current storage provider name
pub fn (mut fs FileService) get_current_provider_name() string {
	return fs.provider.provider_name()
}

// Get the current storage type
pub fn (fs FileService) get_current_storage_type() StorageType {
	return fs.current_config.storage_type
}

// Get the current configuration
pub fn (fs FileService) get_current_config() StorageConfig {
	return fs.current_config
}

// Get the default bucket
pub fn (fs FileService) get_default_bucket() string {
	return fs.config.default_bucket
}

// Get the fragment size
pub fn (fs FileService) get_chunk_size() int {
	return fs.config.chunk_size
}

// Get the maximum file size
pub fn (fs FileService) get_max_file_size() i64 {
	return fs.config.max_file_size
}

// Check if bucket exists
pub fn (mut fs FileService) bucket_exists(bucket string) !bool {
	return fs.provider.bucket_exists(bucket)
}

//Create bucket
pub fn (mut fs FileService) create_bucket(bucket string) ! {
	return fs.provider.create_bucket(bucket)
}

// delete bucket
pub fn (mut fs FileService) delete_bucket(bucket string) ! {
	return fs.provider.delete_bucket(bucket)
}

// Close FileService
pub fn (mut fs FileService) close() {
	fs.db.close()
}

// ============================================================================
// helper function
// ============================================================================

// Calculate MD5 hash
fn calculate_md5_hash(data []u8) string {
	hash := md5.sum(data)
	mut result := ''
	for b in hash {
		result += '${b:02x}'
	}
	return result
}

// Generate object key
fn generate_object_key(filename string, file_hash string) string {
	// Organize files using date and hash prefixes
	now := time.now()
	date_prefix := now.custom_format('YYYY/MM/DD')
	hash_prefix := file_hash[..8]
	
	// Get file extension
	ext := os.file_ext(filename)
	
	return '${date_prefix}/${hash_prefix}/${file_hash}${ext}'
}
