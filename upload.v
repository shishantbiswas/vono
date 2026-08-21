module vono

import net.http
import os
import crypto.md5
import x.json2
import time

// Multiple upload configuration
pub struct ChunkUploadConfig {
pub:
	chunk_size               int    = 1024 * 1024        // 1MB default shard size
	max_file_size            int    = 1024 * 1024 * 1024 // 1GB maximum file size
	max_chunk_size           int    = 10 * 1024 * 1024   // 10MB maximum shard size
	temp_dir                 string = './uploads/chunks' // Temporary shard directory (shards are saved under temp_dir/filehash/chunksize/)
	upload_dir               string = './uploads/files'  // Final file directory
	cleanup_delay            int    = 3600               // Clean up temporary files after 1 hour
	clear_chunks_on_complete bool // Whether to clear the shards after the upload is completed, not cleared by default
	db_path                  string = './uploads/files.db' // Database file path
	merge_buffer_size        int    = 8192                 // Buffer size when merging files (8KB)
	// New: storage configuration (optional, used to integrate FileService)
	use_file_service bool // Whether to use FileService for storage
}

// shard information
pub struct ChunkInfo {
pub:
	file_hash    string
	chunk_index  int
	total_chunks int
	filename     string
	file_size    int
	chunk_size   int
	upload_time  int
}

// File upload status
pub struct FileUploadStatus {
pub:
	file_hash    string
	filename     string
	total_chunks int
	file_size    int
	chunk_size   int
	created_at   int
pub mut:
	uploaded_chunks []int
	status          string
	updated_at      int
}

// Multipart upload manager
pub struct ChunkUploadManager {
pub mut:
	config       ChunkUploadConfig
	uploads      map[string]FileUploadStatus
	db           DatabaseManager
	file_service &FileService = unsafe { nil } // Optional FileService for cloud storage integration
}

// Create a multipart upload manager
pub fn new_chunk_upload_manager(config ChunkUploadConfig) ChunkUploadManager {
	// Make sure the directory exists
	os.mkdir_all(config.temp_dir) or { panic('Failed to create temp directory') }
	os.mkdir_all(config.upload_dir) or { panic('Failed to create upload directory') }

	// Create database manager
	db := new_database_manager(config.db_path) or {
		panic('Failed to create database manager: $err')
	}

	return ChunkUploadManager{
		config:       config
		uploads:      map[string]FileUploadStatus{}
		db:           db
		file_service: unsafe { nil }
	}
}

// Create a multipart upload manager (using an existing FileService)
// When FileService is provided, the merged file will be stored to the configured storage backend via FileService
pub fn new_chunk_upload_manager_with_storage(config ChunkUploadConfig, mut file_service FileService) ChunkUploadManager {
	// Make sure the temporary directory exists
	os.mkdir_all(config.temp_dir) or { panic('Failed to create temp directory') }

	// If you do not use FileService, you also need to create an upload directory
	if !config.use_file_service {
		os.mkdir_all(config.upload_dir) or { panic('Failed to create upload directory') }
	}

	// Create database manager
	db := new_database_manager(config.db_path) or {
		panic('Failed to create database manager: $err')
	}

	return ChunkUploadManager{
		config:       config
		uploads:      map[string]FileUploadStatus{}
		db:           db
		file_service: file_service
	}
}

// Create a multipart upload manager (automatically create a local FileService)
pub fn new_chunk_upload_manager_with_local_storage(config ChunkUploadConfig, storage_path string, db_path string) !ChunkUploadManager {
	// Make sure the temporary directory exists
	os.mkdir_all(config.temp_dir) or { return error('Failed to create temp directory: ${err}') }

	// Create local FileService
	mut file_service := new_local_file_service(storage_path, db_path)!

	// Create database manager
	db := new_database_manager(config.db_path) or {
		return error('Failed to create database manager: ${err}')
	}

	return ChunkUploadManager{
		config:       config
		uploads:      map[string]FileUploadStatus{}
		db:           db
		file_service: &file_service
	}
}

// Handle multipart upload
pub fn (mut manager ChunkUploadManager) handle_chunk_upload(mut ctx Context) http.Response {
	// Parse multipart form data
	form_data := parse_multipart_form(ctx.req) or {
		return ctx.bad_request('Invalid form data: ${err}')
	}

	// Get and verify necessary parameters
	file_hash_raw := form_data.get('file_hash') or { return ctx.missing_parameter('file_hash') }

	// Verify file hash
	file_hash := validate_file_hash(file_hash_raw) or {
		return ctx.invalid_parameter('file_hash', err.msg())
	}

	chunk_index_str := form_data.get('chunk_index') or {
		return ctx.missing_parameter('chunk_index')
	}

	filename_raw := form_data.get('filename') or { return ctx.missing_parameter('filename') }

	// Verify file name
	filename := validate_filename(filename_raw) or {
		return ctx.invalid_parameter('filename', err.msg())
	}

	file_size_str := form_data.get('file_size') or { return ctx.missing_parameter('file_size') }

	// Verify file size
	file_size := validate_file_size(file_size_str, manager.config.max_file_size) or {
		return ctx.invalid_parameter('file_size', err.msg())
	}

	// Get the shard size parameter passed by the front end
	chunk_size_str := form_data.get('chunk_size') or { return ctx.missing_parameter('chunk_size') }

	// Verify shard size
	chunk_size := validate_file_size(chunk_size_str, manager.config.max_chunk_size) or {
		return ctx.invalid_parameter('chunk_size', err.msg())
	}

	// Verify shard index
	chunk_index := validate_chunk_index(chunk_index_str, 0) or { // 0 means no limit to the maximum value
		return ctx.invalid_parameter('chunk_index', err.msg())
	}

	// Get file data
	file_data := form_data.get_file('chunk') or { return ctx.missing_parameter('chunk') }

	// Verify shard data size
	if file_data.len > chunk_size {
		return ctx.validation_error('Chunk data size exceeds declared chunk_size', {
			'actual_size':   file_data.len.str()
			'declared_size': chunk_size.str()
		})
	}

	// Create directories grouped by file hash and shard size
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash, chunk_size.str())
	os.mkdir_all(chunk_dir) or {
		return ctx.file_operation_error('create_directory', chunk_dir, err.msg())
	}

	// Save the fragmented files to the hash/chunksize subdirectory
	chunk_path := os.join_path(chunk_dir, 'chunk_${chunk_index}.part')
	println('[DEBUG] Saving chunk to: $chunk_path')
	println('[DEBUG] Chunk dir exists: ${os.exists(chunk_dir)}')
	println('[DEBUG] Chunk data size: ${file_data.len} bytes')

	os.write_file(chunk_path, file_data) or {
		println('[DEBUG] Failed to save chunk: $err')
		return ctx.file_operation_error('save_chunk', chunk_path, err.msg())
	}

	// Update upload status
	manager.update_upload_status(file_hash, filename, chunk_index, file_size, chunk_size)

	println('[DEBUG] Updated upload status for file: $file_hash, chunk: $chunk_index')

	// Determine whether all fragments have been uploaded and automatically merge them
	// Use a log file to avoid traversing the shard files to calculate the total size
	mut all_chunk_uploaded := false
	merge_chunk_dir := os.join_path(manager.config.temp_dir, file_hash, chunk_size.str())

	if os.exists(merge_chunk_dir) {
		// Update the total size record of uploaded fragments
		manager.update_chunk_size_record(file_hash, chunk_size, file_data.len)

		// Read the total size of uploaded fragments
		total_chunk_size := manager.get_chunk_size_record(file_hash, chunk_size)

		println('[DEBUG] [MergeCheck] total_chunk_size=$total_chunk_size, file_size=$file_size, chunk_index=$chunk_index')

		// If the total size of the fragmented files >= file_size, it is considered possible to merge
		if total_chunk_size >= u64(file_size) {
			all_chunk_uploaded = true
			println('[DEBUG] All chunks uploaded based on size comparison')
		}
	}

	println('[DEBUG] All chunks uploaded: $all_chunk_uploaded')

	if all_chunk_uploaded {
		// Use the upload status in memory to get the number of shards to avoid traversing the file
		actual_total_chunks := manager.uploads[file_hash].uploaded_chunks.len

		// Get file extension
		file_ext := get_file_extension(filename)
		final_filename := '${file_hash}${file_ext}'

		// Check whether FileService is used for storage
		if manager.file_service != unsafe { nil } && manager.config.use_file_service {
			// Use FileService storage
			result := manager.merge_and_store_to_file_service(file_hash, filename, file_size,
				chunk_size) or {
				println('[DEBUG] Merge and store to FileService failed: $err')
				return ctx.file_operation_error('merge_and_store', file_hash, err.msg())
			}

			manager.uploads[file_hash].status = 'completed'
			manager.uploads[file_hash].updated_at = int(time.now().unix())

			if manager.config.clear_chunks_on_complete {
				manager.cleanup_chunks(file_hash, chunk_size)
			}

			return ctx.json('{"success": true, "all_chunk_uploaded": true, "file_uuid": "${result.file_uuid}", "storage_type": "${result.storage_type}", "message": "File uploaded successfully"}')
		}

		// Use local file system storage (original logic)
		final_path := os.join_path(manager.config.upload_dir, final_filename)

		// Check whether the final file already exists to avoid repeated merging
		if os.exists(final_path) {
			println('[DEBUG] Final file already exists: $final_path, skipping merge')
		} else {
			println('[DEBUG] Merging chunks to: $final_path')
			println('[DEBUG] Upload dir exists: ${os.exists(manager.config.upload_dir)}')
			println('[DEBUG] Actual total chunks: $actual_total_chunks')

			manager.merge_chunks(file_hash, actual_total_chunks, final_path, chunk_size) or {
				println('[DEBUG] Merge failed: $err')
				return ctx.file_operation_error('merge_chunks', final_path, err.msg())
			}
		}

		// Record file information in the database
		file_info := manager.db.insert_or_update_file_simple(file_hash, filename, i64(file_size),
			file_ext) or {
			println('[DEBUG] Failed to save file info to database: $err')
			// Even if the database fails to save, file merging will not be affected.
			FileInfo{}
		}

		manager.uploads[file_hash].status = 'completed'
		manager.uploads[file_hash].updated_at = int(time.now().unix())

		if manager.config.clear_chunks_on_complete {
			manager.cleanup_chunks(file_hash, chunk_size)
		}

		clean_file_path :=
			final_path.replace('\n', '').replace('\r', '').replace('\\', '\\\\').trim_space()
		return ctx.json('{"success": true, "all_chunk_uploaded": true, "file_path": "${clean_file_path}", "file_uuid": "${file_info.file_uuid}", "message": "File merged successfully"}')
	}
	// Not all uploaded, return normally
	return ctx.json('{"success": true, "chunk_index": $chunk_index, "all_chunk_uploaded": false, "message": "Chunk uploaded successfully"}')
}

// Merge request structure
pub struct MergeRequest {
pub:
	file_hash    string @[json: 'file_hash']
	filename     string
	total_chunks int @[json: 'total_chunks']
}

// Handle shard merge
pub fn (mut manager ChunkUploadManager) handle_chunk_merge(mut ctx Context) http.Response {
	// Use x.json2 to parse the request body
	merge_request := json2.decode[MergeRequest](ctx.body) or {
		return ctx.bad_request('Invalid request body: ${err}')
	}

	file_hash := merge_request.file_hash
	filename := merge_request.filename
	total_chunks := merge_request.total_chunks

	// Check upload status
	upload_status := manager.uploads[file_hash] or {
		return ctx.resource_not_found('upload', file_hash)
	}

	// Verify whether all shards have been uploaded
	if upload_status.uploaded_chunks.len != total_chunks {
		return ctx.validation_error('Not all chunks uploaded', {
			'uploaded': upload_status.uploaded_chunks.len.str()
			'total':    total_chunks.str()
		})
	}

	// Get the fragment size from the upload status
	chunk_size := upload_status.chunk_size

	// Check whether FileService is used for storage
	if manager.file_service != unsafe { nil } && manager.config.use_file_service {
		// Use FileService storage
		result := manager.merge_and_store_to_file_service(file_hash, filename,
			upload_status.file_size, chunk_size) or {
			return ctx.file_operation_error('merge_and_store', file_hash, err.msg())
		}

		// Update status is completed
		manager.uploads[file_hash].status = 'completed'
		manager.uploads[file_hash].updated_at = int(time.now().unix())

		// Clean up temporary shards
		manager.cleanup_chunks(file_hash, chunk_size)

		return ctx.json('{"success": true, "file_uuid": "${result.file_uuid}", "storage_type": "${result.storage_type}", "message": "File merged successfully"}')
	}

	// Use local file system storage (original logic)
	file_ext := get_file_extension(filename)
	final_filename := '${file_hash.trim_space()}${file_ext}'
	final_path := os.join_path(manager.config.upload_dir, final_filename)

	manager.merge_chunks(file_hash, total_chunks, final_path, chunk_size) or {
		return ctx.file_operation_error('merge_chunks', final_path, err.msg())
	}

	// Record file information in the database
	file_info := manager.db.insert_or_update_file_simple(file_hash, filename,
		i64(upload_status.file_size), file_ext) or {
		println('[DEBUG] Failed to save file info to database: $err')
		// Even if the database fails to save, file merging will not be affected.
		FileInfo{}
	}

	// Update status is completed
	manager.uploads[file_hash].status = 'completed'
	manager.uploads[file_hash].updated_at = int(time.now().unix())

	// Clean up temporary shards
	manager.cleanup_chunks(file_hash, chunk_size)

	// Return successful response
	clean_file_path2 :=
		final_path.replace('\n', '').replace('\r', '').replace('\\', '\\\\').trim_space()
	return ctx.json('{"success": true, "file_path": "${clean_file_path2}", "file_uuid": "${file_info.file_uuid}", "message": "File merged successfully"}')
}

// Get upload status
pub fn (manager ChunkUploadManager) get_upload_status(mut ctx Context) http.Response {
	file_hash := ctx.query['file_hash'] or { return ctx.missing_parameter('file_hash') }

	upload_status := manager.uploads[file_hash] or {
		return ctx.resource_not_found('upload', file_hash)
	}

	return ctx.json(json2.encode[FileUploadStatus](upload_status))
}

// Update upload status
pub fn (mut manager ChunkUploadManager) update_upload_status(file_hash string, filename string, chunk_index int, file_size int, chunk_size int) {
	now := int(time.now().unix())

	if file_hash !in manager.uploads {
		manager.uploads[file_hash] = FileUploadStatus{
			file_hash:       file_hash
			filename:        filename
			total_chunks:    0 // No longer use fixed total_chunks, instead use dynamic calculation
			uploaded_chunks: []
			file_size:       file_size
			chunk_size:      chunk_size
			status:          'uploading'
			created_at:      now
			updated_at:      now
		}
	}

	// Add uploaded shard index
	if chunk_index !in manager.uploads[file_hash].uploaded_chunks {
		manager.uploads[file_hash].uploaded_chunks << chunk_index
	}

	manager.uploads[file_hash].updated_at = now
}

// Merge shards - streaming version, reduce memory usage
fn (mut manager ChunkUploadManager) merge_chunks(file_hash string, total_chunks int, final_path string, chunk_size int) ! {
	println('[DEBUG] Merge chunks called with:')
	println('[DEBUG]   file_hash: $file_hash')
	println('[DEBUG]   total_chunks: $total_chunks')
	println('[DEBUG]   final_path: $final_path')
	println('[DEBUG]   chunk_size: $chunk_size')
	println('[DEBUG]   upload_dir: ${manager.config.upload_dir}')

	// Make sure the upload directory exists
	os.mkdir_all(manager.config.upload_dir) or {
		return error('Failed to create upload directory: $err')
	}

	// Check directory permissions
	if !os.is_writable(manager.config.upload_dir) {
		return error('Upload directory is not writable: ${manager.config.upload_dir}')
	}

	println('[DEBUG] Creating final file: $final_path')

	// If the file already exists, return success directly.
	if os.exists(final_path) {
		println('[DEBUG] Final file already exists, skipping creation')
		return
	}

	// Clean the path and create the final file
	clean_path := final_path.trim_space()
	abs_path := os.abs_path(clean_path)
	println('[DEBUG] Absolute path: "$abs_path"')

	mut final_file := os.create(abs_path) or {
		println('[DEBUG] File creation failed with error: $err')
		return error('Failed to create final file: $err')
	}
	defer { final_file.close() }

	// Streaming merge shards, using configurable buffer size
	buffer_size := manager.config.merge_buffer_size
	mut buffer := []u8{len: buffer_size}

	for i in 0 .. total_chunks {
		chunk_path := os.join_path(manager.config.temp_dir, file_hash.trim_space(),
			chunk_size.str(), 'chunk_${i}.part')
		println('[DEBUG] Processing chunk: $chunk_path')

		if !os.exists(chunk_path) {
			return error('Chunk file not found: $chunk_path')
		}

		// Streaming reading and writing of sharded files
		mut chunk_file := os.open(chunk_path) or { return error('Failed to open chunk $i: $err') }

		mut bytes_copied := 0
		for {
			bytes_read := chunk_file.read(mut buffer) or { break }
			if bytes_read == 0 { break
			 }

			final_file.write(buffer[..bytes_read]) or {
				chunk_file.close()
				return error('Failed to write chunk $i data: $err')
			}

			bytes_copied += bytes_read
		}

		chunk_file.close()
		println('[DEBUG] Chunk $i merged successfully, size: ${bytes_copied} bytes')
	}

	println('[DEBUG] All chunks merged successfully to: $final_path')
}

// Merge shards and store them in FileService
// When FileService is configured, store the merged file to the configured storage backend through FileService
fn (mut manager ChunkUploadManager) merge_and_store_to_file_service(file_hash string, filename string, file_size int, chunk_size int) !UploadResult {
	upload_status := manager.uploads[file_hash] or { return error('Upload status not found') }

	total_chunks := upload_status.uploaded_chunks.len
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash, chunk_size.str())

	// Streaming merge shards into memory
	mut final_data := []u8{}
	buffer_size := manager.config.merge_buffer_size
	mut buffer := []u8{len: buffer_size}

	for i in 0 .. total_chunks {
		chunk_path := os.join_path(chunk_dir, 'chunk_${i}.part')

		if !os.exists(chunk_path) {
			return error('Chunk file not found: ${chunk_path}')
		}

		mut chunk_file := os.open(chunk_path) or {
			return error('Failed to open chunk ${i}: ${err}')
		}

		for {
			bytes_read := chunk_file.read(mut buffer) or { break }
			if bytes_read == 0 { break
			 }
			final_data << buffer[..bytes_read]
		}

		chunk_file.close()
	}

	// Get content_type
	content_type := infer_content_type(filename)

	// Use FileService to upload files
	result := manager.file_service.upload_file(UploadParams{
		filename:     filename
		content_type: content_type
		metadata:     '{"original_hash": "${file_hash}", "chunk_count": ${total_chunks}}'
	}, final_data)!

	return result
}

// Clean up temporary shards
fn (mut manager ChunkUploadManager) cleanup_chunks(file_hash string, chunk_size int) {
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
	if os.exists(chunk_dir) {
		// Clean up shard size records
		manager.cleanup_chunk_size_record(file_hash, chunk_size)

		// Delete the entire shard directory
		os.rmdir_all(chunk_dir) or { println('[DEBUG] Failed to remove chunk directory: $err') }
	}
}

// Public cleanup method
pub fn (mut manager ChunkUploadManager) cleanup_chunks_public(file_hash string, chunk_size int) {
	manager.cleanup_chunks(file_hash, chunk_size)
}

// Internal merge processing method
pub fn (mut manager ChunkUploadManager) handle_chunk_merge_internal(file_hash string, filename string, total_chunks int, final_path string, chunk_size int, file_size int, file_ext string) ! {
	// Perform merge
	manager.merge_chunks(file_hash, total_chunks, final_path, chunk_size) or {
		return error('Failed to merge chunks: $err')
	}

	// Record file information in the database
	manager.db.insert_or_update_file_simple(file_hash, filename, i64(file_size), file_ext) or {
		println('[DEBUG] Failed to save file info to database: $err')
		// Even if the database fails to save, file merging will not be affected.
	}
}

// Generate file hash
pub fn generate_file_hash(data string) string {
	return md5.sum(data.bytes()).hex()
}

// Verify file integrity
pub fn verify_file_integrity(file_path string, expected_hash string) bool {
	file_data := os.read_file(file_path) or { return false }
	actual_hash := generate_file_hash(file_data)
	return actual_hash == expected_hash
}

// Get file extension
fn get_file_extension(filename string) string {
	parts := filename.split('.')
	if parts.len > 1 {
		return '.${parts.last()}'
	}
	return ''
}

// Update shard size record
pub fn (mut manager ChunkUploadManager) update_chunk_size_record(file_hash string, chunk_size int, current_chunk_size int) {
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
	size_record_path := os.join_path(chunk_dir, 'total_size.record')

	// Make sure the directory exists
	os.mkdir_all(chunk_dir) or {
		println('[DEBUG] Failed to create chunk directory: $err')
		return
	}

	// Read the existing total size record
	mut total_size := u64(0)
	if os.exists(size_record_path) {
		size_data := os.read_file(size_record_path) or { '0' }
		total_size = size_data.u64()
	}

	// Update total size
	total_size += u64(current_chunk_size)

	// Write the updated total size
	os.write_file(size_record_path, total_size.str()) or {
		println('[DEBUG] Failed to write size record: $err')
	}

	println('[DEBUG] Updated size record: $total_size bytes')
}

// Get fragment size record
pub fn (manager ChunkUploadManager) get_chunk_size_record(file_hash string, chunk_size int) u64 {
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
	size_record_path := os.join_path(chunk_dir, 'total_size.record')

	if os.exists(size_record_path) {
		size_data := os.read_file(size_record_path) or { '0' }
		return size_data.u64()
	}

	return u64(0)
}

// Clean up shard size records
pub fn (mut manager ChunkUploadManager) cleanup_chunk_size_record(file_hash string, chunk_size int) {
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
	size_record_path := os.join_path(chunk_dir, 'total_size.record')

	if os.exists(size_record_path) {
		os.rm(size_record_path) or { println('[DEBUG] Failed to remove size record: $err') }
	}
}

// Clean up the file upload status (called when the file is deleted)
pub fn (mut manager ChunkUploadManager) cleanup_upload_status(file_hash string) {
	if file_hash in manager.uploads {
		manager.uploads.delete(file_hash)
	}
}

// Check and clean up invalid upload status
pub fn (mut manager ChunkUploadManager) cleanup_invalid_status() {
	mut to_delete := []string{}

	for file_hash, upload_status in manager.uploads {
		// Check if the final file exists
		final_path := os.join_path(manager.config.upload_dir, upload_status.filename.trim_space())
		if !os.exists(final_path) {
			// If the final file does not exist, check whether all fragmented files exist
			mut all_chunks_exist := true
			chunk_size := upload_status.chunk_size
			chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(),
				chunk_size.str())

			// Dynamically check fragmented files
			for i := 0; true; i++ {
				chunk_path := os.join_path(chunk_dir, 'chunk_${i}.part')
				if !os.exists(chunk_path) {
					break
				}
				// If at least one shard is found, the upload is in progress
				all_chunks_exist = false
				break
			}

			// If no fragment files are found, clean up the status
			if all_chunks_exist {
				to_delete << file_hash
			}
		}
	}

	// Delete invalid status
	for file_hash in to_delete {
		manager.uploads.delete(file_hash)
	}
}

// Close the manager (release resources)
pub fn (mut manager ChunkUploadManager) close() {
	// Close database connection
	manager.db.close()

	// If FileService is used, also close it
	if manager.file_service != unsafe { nil } {
		manager.file_service.close()
	}
}

// Check whether FileService is used
pub fn (manager ChunkUploadManager) uses_file_service() bool {
	return manager.file_service != unsafe { nil } && manager.config.use_file_service
}

// Get the FileService (if it exists)
pub fn (manager ChunkUploadManager) get_file_service() ?&FileService {
	if manager.file_service != unsafe { nil } {
		return manager.file_service
	}
	return none
}
