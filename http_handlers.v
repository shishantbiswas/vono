module vono

import net.http
import x.json2
import os
import time

// ============================================================================
//HTTP request/response structure
// ============================================================================

//File upload request (JSON format)
pub struct UploadRequest {
pub:
	bucket       string @[json: 'bucket']
	filename     string @[json: 'filename']
	content_type string @[json: 'content_type']
	metadata     string @[json: 'metadata']
}

// Multipart upload initialization request
pub struct InitMultipartRequest {
pub:
	bucket       string @[json: 'bucket']
	filename     string @[json: 'filename']
	file_size    i64    @[json: 'file_size']
	content_type string @[json: 'content_type']
	chunk_size   int    @[json: 'chunk_size']
}

//Multiple upload completion request
pub struct CompleteMultipartRequest {
pub:
	upload_id string @[json: 'upload_id']
}

//Multiple upload cancellation request
pub struct AbortMultipartRequest {
pub:
	upload_id string @[json: 'upload_id']
}

// Pre-signed URL request
pub struct PresignRequest {
pub:
	file_uuid  string @[json: 'file_uuid']
	expires_in int    @[json: 'expires_in']
	method     string @[json: 'method']
}

//File list request
pub struct ListFilesRequest {
pub:
	bucket       string @[json: 'bucket']
	prefix       string @[json: 'prefix']
	storage_type string @[json: 'storage_type']
	limit        int    @[json: 'limit']
	offset       int    @[json: 'offset']
}

// Generic API response
pub struct StorageApiResponse {
pub:
	success bool   @[json: 'success']
	message string @[json: 'message']
	data    string @[json: 'data'] // JSON encoded data
}

// store error response
pub struct StorageErrorResponse {
pub:
	success bool   @[json: 'success']
	error   string @[json: 'error']
	code    int    @[json: 'code']
}

// ============================================================================
// HTTP handler
// ============================================================================

// Process file upload (single file)
// POST /upload
// Content-Type: multipart/form-data
// Form fields: file (file), bucket (optional), metadata (optional JSON)
pub fn (mut fs FileService) handle_upload(mut ctx Context) http.Response {
	// Parse multipart form data
	content_type := ctx.req.header.get(.content_type) or { '' }
	
	if !content_type.starts_with('multipart/form-data') {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Content-Type must be multipart/form-data'
			code: 400
		}))
	}
	
	//Use vono's multipart parser
	parser := new_multipart_parser(content_type, ctx.body) or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to parse multipart data: ${err}'
			code: 400
		}))
	}
	
	items := parser.parse() or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to parse form data: ${err}'
			code: 400
		}))
	}
	
	//Extract form fields
	mut file_data := []u8{}
	mut filename := ''
	mut file_content_type := 'application/octet-stream'
	mut bucket := ''
	mut metadata := ''
	
	for item in items {
		match item.name {
			'file' {
				file_data = item.content.bytes()
				filename = item.filename
				if item.content_type != '' {
					file_content_type = item.content_type
				}
			}
			'bucket' {
				bucket = item.content
			}
			'metadata' {
				metadata = item.content
			}
			'content_type' {
				file_content_type = item.content
			}
			else {}
		}
	}
	
	if file_data.len == 0 || filename == '' {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file data or filename'
			code: 400
		}))
	}
	
	//Upload file
	result := fs.upload_file(UploadParams{
		bucket: bucket
		filename: filename
		content_type: file_content_type
		metadata: metadata
	}, file_data) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Upload failed: ${err}'
			code: 500
		}))
	}
	
	ctx.status(201)
	return ctx.json(json2.encode[UploadResult](result))
}

// Process file download
// GET /download/:file_uuid
pub fn (mut fs FileService) handle_download(mut ctx Context) http.Response {
	file_uuid := ctx.params['file_uuid'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file_uuid parameter'
			code: 400
		}))
	}
	
	// Get file information
	file_info := fs.get_file_info(file_uuid) or {
		ctx.status(404)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'File not found: ${err}'
			code: 404
		}))
	}
	
	// Check the Range request
	range_header := ctx.req.header.get_custom('Range') or { '' }
	
	if range_header != '' {
		return fs.handle_range_download(mut ctx, file_info, range_header)
	}
	
	// Download file
	data := fs.download_file(file_uuid) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Download failed: ${err}'
			code: 500
		}))
	}
	
	//Set response headers
	ctx.headers['Content-Type'] = file_info.file_type
	ctx.headers['Content-Length'] = data.len.str()
	ctx.headers['Content-Disposition'] = 'attachment; filename="${file_info.file_name}"'
	ctx.headers['Accept-Ranges'] = 'bytes'
	ctx.headers['ETag'] = '"${file_info.file_hash}"'
	
	ctx.status(200)
	mut headers := http.new_header()
	for key, value in ctx.headers {
		headers.add_custom(key, value) or { continue }
	}
	
	return http.Response{
		status_code: 200
		header: headers
		body: data.bytestr()
	}
}

// Handle Range request download
fn (mut fs FileService) handle_range_download(mut ctx Context, file_info FileInfo, range_header string) http.Response {
	// Parse the Range header
	if !range_header.starts_with('bytes=') {
		ctx.status(416)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid Range header'
			code: 416
		}))
	}
	
	range_spec := range_header[6..]
	parts := range_spec.split('-')
	if parts.len != 2 {
		ctx.status(416)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid Range format'
			code: 416
		}))
	}
	
	file_size := file_info.file_size
	mut start := i64(0)
	mut end := file_size - 1
	
	if parts[0] != '' {
		start = parts[0].i64()
	}
	if parts[1] != '' {
		end = parts[1].i64()
	}
	
	// Validation scope
	if start < 0 || start >= file_size || end < start || end >= file_size {
		ctx.status(416)
		ctx.headers['Content-Range'] = 'bytes */${file_size}'
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Range not satisfiable'
			code: 416
		}))
	}
	
	// Download the complete file
	data := fs.download_file(file_info.file_uuid) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Download failed: ${err}'
			code: 500
		}))
	}
	
	//Extract range data
	range_data := data[int(start)..int(end) + 1]
	content_length := end - start + 1
	
	//Set response headers
	ctx.headers['Content-Type'] = file_info.file_type
	ctx.headers['Content-Length'] = content_length.str()
	ctx.headers['Content-Range'] = 'bytes ${start}-${end}/${file_size}'
	ctx.headers['Accept-Ranges'] = 'bytes'
	ctx.headers['ETag'] = '"${file_info.file_hash}"'
	
	ctx.status(206)
	mut headers := http.new_header()
	for key, value in ctx.headers {
		headers.add_custom(key, value) or { continue }
	}
	
	return http.Response{
		status_code: 206
		header: headers
		body: range_data.bytestr()
	}
}

// Handle file deletion
// DELETE /files/:file_uuid
pub fn (mut fs FileService) handle_delete(mut ctx Context) http.Response {
	file_uuid := ctx.params['file_uuid'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file_uuid parameter'
			code: 400
		}))
	}
	
	// delete file
	fs.delete_file(file_uuid) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Delete failed: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[StorageApiResponse](StorageApiResponse{
		success: true
		message: 'File deleted successfully'
		data: ''
	}))
}


// ============================================================================
//Multiple upload processor
// ============================================================================

//Initialize multipart upload
// POST /multipart/init
pub fn (mut fs FileService) handle_init_multipart(mut ctx Context) http.Response {
	// Parse the request body
	req := json2.decode[InitMultipartRequest](ctx.body) or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid request body: ${err}'
			code: 400
		}))
	}
	
	if req.filename == '' || req.file_size <= 0 {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing required fields: filename and file_size'
			code: 400
		}))
	}
	
	// Generate object key
	object_key := generate_multipart_object_key(req.filename)
	
	//Initialize multipart upload
	upload := fs.init_multipart_upload(InitMultipartParams{
		bucket: req.bucket
		object_key: object_key
		file_name: req.filename
		file_size: req.file_size
		content_type: req.content_type
		chunk_size: req.chunk_size
	}) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to init multipart upload: ${err}'
			code: 500
		}))
	}
	
	ctx.status(201)
	return ctx.json(json2.encode[MultipartUpload](upload))
}

//Upload fragments
// POST /multipart/upload/:upload_id/:part_number
pub fn (mut fs FileService) handle_upload_part(mut ctx Context) http.Response {
	upload_id := ctx.params['upload_id'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing upload_id parameter'
			code: 400
		}))
	}
	
	part_number_str := ctx.params['part_number'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing part_number parameter'
			code: 400
		}))
	}
	
	part_number := part_number_str.int()
	if part_number < 1 {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid part_number: must be >= 1'
			code: 400
		}))
	}
	
	// Get shard data
	data := ctx.body.bytes()
	if data.len == 0 {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Empty part data'
			code: 400
		}))
	}
	
	//Upload fragments
	result := fs.upload_part(upload_id, part_number, data) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to upload part: ${err}'
			code: 500
		}))
	}
	
	if !result.success {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: result.error_msg
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[ChunkUploadResult](result))
}

//Complete multipart upload
// POST /multipart/complete
pub fn (mut fs FileService) handle_complete_multipart(mut ctx Context) http.Response {
	// Parse the request body
	req := json2.decode[CompleteMultipartRequest](ctx.body) or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid request body: ${err}'
			code: 400
		}))
	}
	
	if req.upload_id == '' {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing upload_id'
			code: 400
		}))
	}
	
	//Complete upload
	result := fs.complete_multipart_upload(req.upload_id) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to complete multipart upload: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[StorageResult](result))
}

//Cancel multipart upload
// POST /multipart/abort
pub fn (mut fs FileService) handle_abort_multipart(mut ctx Context) http.Response {
	// Parse the request body
	req := json2.decode[AbortMultipartRequest](ctx.body) or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid request body: ${err}'
			code: 400
		}))
	}
	
	if req.upload_id == '' {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing upload_id'
			code: 400
		}))
	}
	
	// Cancel upload
	fs.abort_multipart_upload(req.upload_id) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to abort multipart upload: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[StorageApiResponse](StorageApiResponse{
		success: true
		message: 'Multipart upload aborted'
		data: ''
	}))
}

// Get upload progress
// GET /multipart/progress/:upload_id
pub fn (fs FileService) handle_upload_progress(mut ctx Context) http.Response {
	upload_id := ctx.params['upload_id'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing upload_id parameter'
			code: 400
		}))
	}
	
	// Get progress
	progress := fs.get_upload_progress(upload_id) or {
		ctx.status(404)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Upload not found: ${err}'
			code: 404
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[UploadProgress](progress))
}


// ============================================================================
//File list and metadata processor
// ============================================================================

// Get file list
// GET /files?bucket=xxx&prefix=xxx&limit=100&offset=0
pub fn (fs FileService) handle_list_files(mut ctx Context) http.Response {
	bucket := ctx.query['bucket'] or { '' }
	prefix := ctx.query['prefix'] or { '' }
	storage_type := ctx.query['storage_type'] or { '' }
	limit_str := ctx.query['limit'] or { '100' }
	offset_str := ctx.query['offset'] or { '0' }
	
	limit := limit_str.int()
	offset := offset_str.int()
	
	//Query file list
	result := fs.list_files(FileListOptions{
		bucket: bucket
		prefix: prefix
		storage_type: storage_type
		limit: if limit > 0 { limit } else { 100 }
		offset: if offset >= 0 { offset } else { 0 }
	}) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to list files: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[FileListResult](result))
}

// Get file information
// GET /files/:file_uuid/info
pub fn (fs FileService) handle_get_file_info(mut ctx Context) http.Response {
	file_uuid := ctx.params['file_uuid'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file_uuid parameter'
			code: 400
		}))
	}
	
	// Get file information
	file_info := fs.get_file_info(file_uuid) or {
		ctx.status(404)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'File not found: ${err}'
			code: 404
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[FileInfo](file_info))
}

// Get pre-signed URL
// POST /presign
pub fn (mut fs FileService) handle_presign(mut ctx Context) http.Response {
	// Parse the request body
	req := json2.decode[PresignRequest](ctx.body) or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid request body: ${err}'
			code: 400
		}))
	}
	
	if req.file_uuid == '' {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file_uuid'
			code: 400
		}))
	}
	
	expires_in := if req.expires_in > 0 { req.expires_in } else { 3600 }
	
	// Generate pre-signed URL
	result := fs.get_presigned_url(req.file_uuid, expires_in) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to generate presigned URL: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[PresignResult](result))
}

// Get the pre-signed URL (GET method)
// GET /presign/:file_uuid?expires_in=3600
pub fn (mut fs FileService) handle_presign_get(mut ctx Context) http.Response {
	file_uuid := ctx.params['file_uuid'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file_uuid parameter'
			code: 400
		}))
	}
	
	expires_in_str := ctx.query['expires_in'] or { '3600' }
	mut expires_in := expires_in_str.int()
	if expires_in <= 0 {
		expires_in = 3600
	}
	
	// Generate pre-signed URL
	result := fs.get_presigned_url(file_uuid, expires_in) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to generate presigned URL: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[PresignResult](result))
}


// ============================================================================
// helper function
// ============================================================================

// Generate the object key for multipart upload
fn generate_multipart_object_key(filename string) string {
	now := time.now()
	date_prefix := now.custom_format('YYYY/MM/DD')
	uuid := generate_file_uuid()
	ext := os.file_ext(filename)
	return '${date_prefix}/${uuid}${ext}'
}

// ============================================================================
//Route registration
// ============================================================================

//Register all file service routes
// prefix: routing prefix, such as "/api/storage"
pub fn (mut fs FileService) register_routes(mut app Vono, prefix string) {
	//File upload
	app.post('${prefix}/upload', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_upload(mut ctx)
	})
	
	//File download
	app.get('${prefix}/download/:file_uuid', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_download(mut ctx)
	})
	
	//File deletion
	app.delete('${prefix}/files/:file_uuid', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_delete(mut ctx)
	})
	
	// file list
	app.get('${prefix}/files', fn [fs] (mut ctx Context) http.Response {
		return fs.handle_list_files(mut ctx)
	})
	
	//File information
	app.get('${prefix}/files/:file_uuid/info', fn [fs] (mut ctx Context) http.Response {
		return fs.handle_get_file_info(mut ctx)
	})
	
	// Pre-signed URL (POST)
	app.post('${prefix}/presign', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_presign(mut ctx)
	})
	
	// Pre-signed URL (GET)
	app.get('${prefix}/presign/:file_uuid', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_presign_get(mut ctx)
	})
	
	// Multipart upload - initialization
	app.post('${prefix}/multipart/init', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_init_multipart(mut ctx)
	})
	
	// Multipart upload - Upload parts
	app.post('${prefix}/multipart/upload/:upload_id/:part_number', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_upload_part(mut ctx)
	})
	
	// Multipart upload - complete
	app.post('${prefix}/multipart/complete', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_complete_multipart(mut ctx)
	})
	
	// Multipart upload - cancel
	app.post('${prefix}/multipart/abort', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_abort_multipart(mut ctx)
	})
	
	// Multipart upload - progress query
	app.get('${prefix}/multipart/progress/:upload_id', fn [fs] (mut ctx Context) http.Response {
		return fs.handle_upload_progress(mut ctx)
	})
}

// Register simplified route (without prefix)
pub fn (mut fs FileService) register_default_routes(mut app Vono) {
	fs.register_routes(mut app, '/storage')
}
