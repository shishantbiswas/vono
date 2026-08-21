module vono

import time
import crypto.md5

// Multipart upload manager
// Responsible for managing the life cycle of multipart uploads, including initialization, uploading parts, completing and canceling uploads
@[heap]
pub struct ChunkManager {
mut:
	db       DatabaseManager
	provider &StorageProvider = unsafe { nil }
	config   ChunkManagerConfig
}

// Sharding manager configuration
pub struct ChunkManagerConfig {
pub:
	default_chunk_size int = 5 * 1024 * 1024 // 5MB default shard size
	max_chunk_size     int = 100 * 1024 * 1024 // 100MB maximum shard size
	min_chunk_size     int = 1024 * 1024 // 1MB minimum shard size
	max_parts          int = 10000 //Maximum number of shards
	retry_count        int = 3 //Number of retries
	retry_delay_ms     int = 1000 //Retry delay (milliseconds)
}

// Upload progress information
pub struct UploadProgress {
pub:
	upload_id       string
	file_uuid       string
	file_name       string
	file_size       i64
	chunk_size      int
	total_chunks    int
	uploaded_chunks int
	uploaded_bytes  i64
	progress_pct    f64
	status          string
	pending_parts   []int
	created_at      i64
	updated_at      i64
}

//Multiple upload initialization parameters
pub struct InitMultipartParams {
pub:
	bucket       string
	object_key   string
	file_name    string
	file_size    i64
	content_type string
	chunk_size   int // Optional, use default value when 0
}

//Multiple upload results
pub struct ChunkUploadResult {
pub:
	upload_id   string
	part_number int
	etag        string
	size        i64
	success     bool
	error_msg   string
}


//Create shard manager
pub fn new_chunk_manager(mut db DatabaseManager, provider &StorageProvider, config ChunkManagerConfig) ChunkManager {
	return ChunkManager{
		db: db
		provider: unsafe { provider }
		config: config
	}
}

//Create a shard manager using default configuration
pub fn new_chunk_manager_default(mut db DatabaseManager, provider &StorageProvider) ChunkManager {
	return ChunkManager{
		db: db
		provider: unsafe { provider }
		config: ChunkManagerConfig{}
	}
}

// ============================================================================
// Core shard upload operation
// ============================================================================

//Initialize multipart upload
//Create a new multipart upload session and return upload_id
pub fn (mut cm ChunkManager) init_multipart(params InitMultipartParams) !MultipartUpload {
	// Validate parameters
	if params.bucket == '' {
		return error('Bucket name is required')
	}
	if params.object_key == '' {
		return error('Object key is required')
	}
	if params.file_size <= 0 {
		return error('File size must be positive')
	}

	// Determine the fragment size
	chunk_size := if params.chunk_size > 0 {
		cm.validate_chunk_size(params.chunk_size)
	} else {
		cm.config.default_chunk_size
	}

	// Calculate the total number of shards
	total_chunks := cm.calculate_total_chunks(params.file_size, chunk_size)
	if total_chunks > cm.config.max_parts {
		return error('File too large: would require ${total_chunks} parts, max is ${cm.config.max_parts}')
	}

	// Call the storage provider to initialize the multipart upload
	provider_upload_id := cm.provider.init_multipart(params.bucket, params.object_key,
		params.content_type)!

	//Create upload records in the database
	upload := cm.db.create_multipart_upload(MultipartUpload{
		upload_id: provider_upload_id
		file_name: params.file_name
		file_size: params.file_size
		chunk_size: chunk_size
		total_chunks: total_chunks
		bucket: params.bucket
		object_key: params.object_key
		content_type: params.content_type
	})!

	return upload
}

// Upload a single shard
pub fn (mut cm ChunkManager) upload_part(upload_id string, part_number int, data []u8) !ChunkUploadResult {
	// Get upload status
	upload := cm.db.get_multipart_upload(upload_id) or {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Upload not found: ${upload_id}'
		}
	}

	//Verify upload status
	if upload.status != 'uploading' {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Upload is not in uploading state: ${upload.status}'
		}
	}

	//Verify shard number
	if part_number < 1 || part_number > upload.total_chunks {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Invalid part number: ${part_number}, expected 1-${upload.total_chunks}'
		}
	}

	// Call the storage provider to upload the shards
	etag := cm.provider.upload_part(upload.bucket, upload.object_key, upload_id, part_number,
		data) or {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Failed to upload part: ${err}'
		}
	}

	//Record uploaded fragments
	cm.db.record_uploaded_part(upload_id, part_number, etag, i64(data.len)) or {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Failed to record uploaded part: ${err}'
		}
	}

	return ChunkUploadResult{
		upload_id: upload_id
		part_number: part_number
		etag: etag
		size: i64(data.len)
		success: true
		error_msg: ''
	}
}


//Complete multipart upload
// Merge all shards and create final file
pub fn (mut cm ChunkManager) complete_multipart(upload_id string) !StorageResult {
	// Get upload status
	upload := cm.db.get_multipart_upload(upload_id)!

	//Verify upload status
	if upload.status != 'uploading' {
		return error('Upload is not in uploading state: ${upload.status}')
	}

	// Get all uploaded shards
	uploaded_parts := cm.db.get_uploaded_parts(upload_id)!

	// Verify that all shards have been uploaded
	if uploaded_parts.len != upload.total_chunks {
		return error('Not all parts uploaded: ${uploaded_parts.len}/${upload.total_chunks}')
	}

	//Build a list of shard information
	mut parts := []PartInfo{}
	for part in uploaded_parts {
		parts << new_part_info(part.part_number, part.etag, part.size)
	}

	// Sort by fragment number
	parts.sort(a.part_number < b.part_number)

	// Call the storage provider to complete the upload
	result := cm.provider.complete_multipart(upload.bucket, upload.object_key, upload_id,
		parts)!

	//Update database status
	cm.db.update_multipart_status(upload_id, 'completed')!

	//Create a record in the file information table
	file_hash := calculate_chunk_file_hash(upload_id, upload.file_size)
	cm.db.insert_file(FileInfo{
		file_uuid: upload.file_uuid
		file_hash: file_hash
		file_name: upload.file_name
		file_size: upload.file_size
		file_type: upload.content_type
		storage_type: cm.provider.provider_name()
		bucket: upload.bucket
		object_key: upload.object_key
		metadata: ''
	}) or {
		// File already exists, ignore errors
	}

	return result
}

//Cancel multipart upload
// Clean up all uploaded shards and temporary data
pub fn (mut cm ChunkManager) abort_multipart(upload_id string) ! {
	// Get upload status
	upload := cm.db.get_multipart_upload(upload_id) or {
		return error('Upload not found: ${upload_id}')
	}

	// Call the storage provider to cancel the upload
	cm.provider.abort_multipart(upload.bucket, upload.object_key, upload_id) or {
		// Ignore storage provider errors and continue cleaning the database
	}

	//Update database status
	cm.db.update_multipart_status(upload_id, 'aborted')!

	// Delete upload records and shard records
	cm.db.delete_multipart_upload(upload_id)!
}

// ============================================================================
// Upload progress and status query
// ============================================================================

// Get upload progress
pub fn (cm ChunkManager) get_upload_progress(upload_id string) !UploadProgress {
	// Get upload status
	upload := cm.db.get_multipart_upload(upload_id)!

	// Get the uploaded fragments
	uploaded_parts := cm.db.get_uploaded_parts(upload_id)!

	// Calculate the number of bytes uploaded
	mut uploaded_bytes := i64(0)
	mut uploaded_part_numbers := map[int]bool{}
	for part in uploaded_parts {
		uploaded_bytes += part.size
		uploaded_part_numbers[part.part_number] = true
	}

	// Calculate the fragments to be uploaded
	mut pending_parts := []int{}
	for i in 1 .. upload.total_chunks + 1 {
		if i !in uploaded_part_numbers {
			pending_parts << i
		}
	}

	// Calculate progress percentage
	progress_pct := if upload.total_chunks > 0 {
		f64(uploaded_parts.len) / f64(upload.total_chunks) * 100.0
	} else {
		0.0
	}

	return UploadProgress{
		upload_id: upload_id
		file_uuid: upload.file_uuid
		file_name: upload.file_name
		file_size: upload.file_size
		chunk_size: upload.chunk_size
		total_chunks: upload.total_chunks
		uploaded_chunks: uploaded_parts.len
		uploaded_bytes: uploaded_bytes
		progress_pct: progress_pct
		status: upload.status
		pending_parts: pending_parts
		created_at: upload.created_at
		updated_at: upload.updated_at
	}
}

// Check whether the fragment has been uploaded
pub fn (cm ChunkManager) is_part_uploaded(upload_id string, part_number int) bool {
	return cm.db.is_part_uploaded(upload_id, part_number)
}

// Get the uploaded shard list
pub fn (cm ChunkManager) get_uploaded_parts(upload_id string) ![]UploadedPart {
	return cm.db.get_uploaded_parts(upload_id)
}

// List all uploads in progress
pub fn (cm ChunkManager) list_pending_uploads() ![]MultipartUpload {
	return cm.db.list_pending_multipart_uploads()
}


// ============================================================================
// Shard retry and recovery
// ============================================================================

//Retry uploading a single shard
// Retry logic with exponential backoff
pub fn (mut cm ChunkManager) retry_upload_part(upload_id string, part_number int, data []u8) !ChunkUploadResult {
	mut last_error := ''
	mut delay := cm.config.retry_delay_ms

	for attempt in 0 .. cm.config.retry_count + 1 {
		result := cm.upload_part(upload_id, part_number, data)!

		if result.success {
			return result
		}

		last_error = result.error_msg

		// Check if it is a retryable error
		if !cm.is_retryable_error(result.error_msg) {
			return result
		}

		// If this is not the last attempt, wait and try again
		if attempt < cm.config.retry_count {
			time.sleep(delay * time.millisecond)
			delay = delay * 2 // exponential backoff
			if delay > 30000 {
				delay = 30000 //Maximum delay 30 seconds
			}
		}
	}

	return ChunkUploadResult{
		upload_id: upload_id
		part_number: part_number
		success: false
		error_msg: 'All retry attempts failed: ${last_error}'
	}
}

//Resume upload (resume upload after breakpoint)
//Return the list of shards to be uploaded
pub fn (cm ChunkManager) get_pending_parts(upload_id string) ![]int {
	progress := cm.get_upload_progress(upload_id)!
	return progress.pending_parts
}

//Batch upload pending shards
// data_provider is a function that returns shard data based on the shard number
pub fn (mut cm ChunkManager) upload_pending_parts(upload_id string, data_provider fn (int) ![]u8) ![]ChunkUploadResult {
	pending_parts := cm.get_pending_parts(upload_id)!

	mut results := []ChunkUploadResult{}
	for part_number in pending_parts {
		data := data_provider(part_number) or {
			results << ChunkUploadResult{
				upload_id: upload_id
				part_number: part_number
				success: false
				error_msg: 'Failed to get data for part ${part_number}: ${err}'
			}
			continue
		}

		result := cm.retry_upload_part(upload_id, part_number, data) or {
			results << ChunkUploadResult{
				upload_id: upload_id
				part_number: part_number
				success: false
				error_msg: 'Failed to upload part ${part_number}: ${err}'
			}
			continue
		}

		results << result
	}

	return results
}

// ============================================================================
// Helper method
// ============================================================================

// Verify shard size
fn (cm ChunkManager) validate_chunk_size(size int) int {
	if size < cm.config.min_chunk_size {
		return cm.config.min_chunk_size
	}
	if size > cm.config.max_chunk_size {
		return cm.config.max_chunk_size
	}
	return size
}

// Calculate the total number of shards
fn (cm ChunkManager) calculate_total_chunks(file_size i64, chunk_size int) int {
	chunks := file_size / i64(chunk_size)
	if file_size % i64(chunk_size) > 0 {
		return int(chunks) + 1
	}
	return int(chunks)
}

// Determine whether the error can be retried
fn (cm ChunkManager) is_retryable_error(error_msg string) bool {
	retryable_keywords := ['timeout', 'connection', 'network', 'unavailable', 'rate limit',
		'temporary']
	lower_msg := error_msg.to_lower()
	for keyword in retryable_keywords {
		if lower_msg.contains(keyword) {
			return true
		}
	}
	return false
}

// Calculate file hash (for file records)
fn calculate_chunk_file_hash(upload_id string, file_size i64) string {
	// Generate a simple hash using upload_id and file_size
	//In actual applications, MD5/SHA256 of the file content should be used
	data := '${upload_id}-${file_size}'.bytes()
	hash := md5.sum(data)
	mut result := ''
	for b in hash {
		result += '${b:02x}'
	}
	return result
}

// Get the data range of the fragment
pub fn (cm ChunkManager) get_part_range(upload_id string, part_number int) !(i64, i64) {
	upload := cm.db.get_multipart_upload(upload_id)!

	if part_number < 1 || part_number > upload.total_chunks {
		return error('Invalid part number: ${part_number}')
	}

	start := i64(part_number - 1) * i64(upload.chunk_size)
	mut end := start + i64(upload.chunk_size) - 1

	//The last fragment may be smaller than chunk_size
	if end >= upload.file_size {
		end = upload.file_size - 1
	}

	return start, end
}

// Get the expected size of the shard
pub fn (cm ChunkManager) get_expected_part_size(upload_id string, part_number int) !i64 {
	start, end := cm.get_part_range(upload_id, part_number)!
	return end - start + 1
}


// ============================================================================
//Resumable upload support
// ============================================================================

// Resume uploading session information
// Used to restore the upload status after the client reconnects
pub struct ResumeInfo {
pub:
	upload_id       string
	file_uuid       string
	file_name       string
	file_size       i64
	chunk_size      int
	total_chunks    int
	uploaded_chunks int
	pending_parts   []int
	can_resume      bool
	error_msg       string
}

// Get the information needed to resume uploading
pub fn (cm ChunkManager) get_resume_info(upload_id string) ResumeInfo {
	upload := cm.db.get_multipart_upload(upload_id) or {
		return ResumeInfo{
			upload_id: upload_id
			can_resume: false
			error_msg: 'Upload not found: ${upload_id}'
		}
	}

	// Only uploads in the uploading state can be resumed
	if upload.status != 'uploading' {
		return ResumeInfo{
			upload_id: upload_id
			file_uuid: upload.file_uuid
			file_name: upload.file_name
			file_size: upload.file_size
			chunk_size: upload.chunk_size
			total_chunks: upload.total_chunks
			can_resume: false
			error_msg: 'Upload is in ${upload.status} state, cannot resume'
		}
	}

	// Get progress information
	progress := cm.get_upload_progress(upload_id) or {
		return ResumeInfo{
			upload_id: upload_id
			file_uuid: upload.file_uuid
			file_name: upload.file_name
			file_size: upload.file_size
			chunk_size: upload.chunk_size
			total_chunks: upload.total_chunks
			can_resume: false
			error_msg: 'Failed to get upload progress: ${err}'
		}
	}

	return ResumeInfo{
		upload_id: upload_id
		file_uuid: upload.file_uuid
		file_name: upload.file_name
		file_size: upload.file_size
		chunk_size: upload.chunk_size
		total_chunks: upload.total_chunks
		uploaded_chunks: progress.uploaded_chunks
		pending_parts: progress.pending_parts
		can_resume: true
		error_msg: ''
	}
}

// Find resumable uploads based on file name
pub fn (cm ChunkManager) find_resumable_upload(file_name string, file_size i64) ?MultipartUpload {
	pending_uploads := cm.db.list_pending_multipart_uploads() or { return none }

	for upload in pending_uploads {
		if upload.file_name == file_name && upload.file_size == file_size {
			return upload
		}
	}

	return none
}

// Check if the upload can be completed (all shards have been uploaded)
pub fn (cm ChunkManager) can_complete(upload_id string) bool {
	progress := cm.get_upload_progress(upload_id) or { return false }
	return progress.pending_parts.len == 0 && progress.status == 'uploading'
}

// Get detailed status report of upload
pub struct UploadStatusReport {
pub:
	upload_id         string
	status            string
	file_name         string
	file_size         i64
	total_chunks      int
	uploaded_chunks   int
	pending_chunks    int
	uploaded_bytes    i64
	remaining_bytes   i64
	progress_pct      f64
	estimated_time_ms i64 // Estimated remaining time based on average upload speed
	can_complete      bool
	can_resume        bool
}

// Get detailed upload status report
pub fn (cm ChunkManager) get_status_report(upload_id string) !UploadStatusReport {
	progress := cm.get_upload_progress(upload_id)!

	remaining_bytes := progress.file_size - progress.uploaded_bytes
	can_complete := progress.pending_parts.len == 0 && progress.status == 'uploading'
	can_resume := progress.status == 'uploading' && progress.pending_parts.len > 0

	return UploadStatusReport{
		upload_id: upload_id
		status: progress.status
		file_name: progress.file_name
		file_size: progress.file_size
		total_chunks: progress.total_chunks
		uploaded_chunks: progress.uploaded_chunks
		pending_chunks: progress.pending_parts.len
		uploaded_bytes: progress.uploaded_bytes
		remaining_bytes: remaining_bytes
		progress_pct: progress.progress_pct
		estimated_time_ms: 0 // Need historical data to estimate
		can_complete: can_complete
		can_resume: can_resume
	}
}

// Clean up expired uploads (uploads that have not been updated after the specified time)
pub fn (mut cm ChunkManager) cleanup_stale_uploads(max_age_seconds i64) !int {
	pending_uploads := cm.db.list_pending_multipart_uploads()!
	now := time.now().unix()
	mut cleaned := 0

	for upload in pending_uploads {
		if now - upload.updated_at > max_age_seconds {
			cm.abort_multipart(upload.upload_id) or { continue }
			cleaned++
		}
	}

	return cleaned
}
