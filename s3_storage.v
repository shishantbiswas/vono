module hono

import io
import net.http
import net.urllib
import time
import crypto.sha256
import crypto.md5
import encoding.hex

// S3Storage S3 compatible storage provider
pub struct S3Storage {
	config S3Config
mut:
	// Memory storage used to track multipart uploads
	multipart_uploads map[string]S3MultipartUploadState
}

// S3 multipart upload status
struct S3MultipartUploadState {
mut:
	bucket       string
	key          string
	upload_id    string
	content_type string
	parts        map[int]PartInfo
	created_at   i64
}

// Create S3 storage provider
pub fn new_s3_storage(config S3Config) !S3Storage {
	//Verify configuration
	validation := validate_s3_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	return S3Storage{
		config: config
		multipart_uploads: map[string]S3MultipartUploadState{}
	}
}

// ============================================================================
// AWS Signature V4 signature implementation
// ============================================================================

// Information required to sign the request
struct S3SigningInfo {
	method          string
	uri             string
	query_string    string
	headers         map[string]string
	signed_headers  string
	payload_hash    string
	timestamp       time.Time
	date_stamp      string
	datetime_stamp  string
}

//Create signature information
fn (s S3Storage) create_signing_info(method string, uri string, query_params map[string]string, headers map[string]string, payload []u8) S3SigningInfo {
	now := time.utc()
	date_stamp := now.custom_format('YYYYMMDD')
	datetime_stamp := now.custom_format('YYYYMMDD') + 'T' + now.custom_format('HHmmss') + 'Z'

	// Calculate payload hash
	payload_hash := s.hash_payload(payload)

	// Build query string
	query_string := s.build_canonical_query_string(query_params)

	// Get the signature header list
	signed_headers := s.get_signed_headers(headers)

	return S3SigningInfo{
		method: method
		uri: uri
		query_string: query_string
		headers: headers
		signed_headers: signed_headers
		payload_hash: payload_hash
		timestamp: now
		date_stamp: date_stamp
		datetime_stamp: datetime_stamp
	}
}

// Calculate the SHA256 hash of the payload
fn (s S3Storage) hash_payload(payload []u8) string {
	if payload.len == 0 {
		// Hash of empty payload
		return 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
	}
	hash := sha256.sum(payload)
	return hex.encode(hash)
}

// Build canonical query string
fn (s S3Storage) build_canonical_query_string(params map[string]string) string {
	if params.len == 0 {
		return ''
	}

	// Get the sorted keys
	mut keys := params.keys()
	keys.sort()

	mut parts := []string{}
	for key in keys {
		encoded_key := urllib.query_escape(key)
		encoded_value := urllib.query_escape(params[key])
		parts << '${encoded_key}=${encoded_value}'
	}

	return parts.join('&')
}

// Get the signature header list (sorted by lowercase)
fn (s S3Storage) get_signed_headers(headers map[string]string) string {
	mut header_names := []string{}
	for key, _ in headers {
		header_names << key.to_lower()
	}
	header_names.sort()
	return header_names.join(';')
}

// Build specification request
fn (s S3Storage) build_canonical_request(info S3SigningInfo) string {
	// Build specification header
	mut canonical_headers := ''
	mut header_names := []string{}
	for key, _ in info.headers {
		header_names << key.to_lower()
	}
	header_names.sort()

	for name in header_names {
		// Find the original key (case insensitive)
		for key, value in info.headers {
			if key.to_lower() == name {
				canonical_headers += '${name}:${value.trim_space()}\n'
				break
			}
		}
	}

	return '${info.method}\n${info.uri}\n${info.query_string}\n${canonical_headers}\n${info.signed_headers}\n${info.payload_hash}'
}

//Construct the string to be signed
fn (s S3Storage) build_string_to_sign(info S3SigningInfo, canonical_request string) string {
	algorithm := 'AWS4-HMAC-SHA256'
	credential_scope := '${info.date_stamp}/${s.config.region}/s3/aws4_request'

	// Calculate the hash of the canonical request
	request_hash := sha256.sum(canonical_request.bytes())
	hashed_request := hex.encode(request_hash)

	return '${algorithm}\n${info.datetime_stamp}\n${credential_scope}\n${hashed_request}'
}

// Calculate signature key
fn (s S3Storage) get_signing_key(date_stamp string) []u8 {
	k_date := s3_hmac_sha256(('AWS4' + s.config.secret_key).bytes(), date_stamp.bytes())
	k_region := s3_hmac_sha256(k_date, s.config.region.bytes())
	k_service := s3_hmac_sha256(k_region, 's3'.bytes())
	k_signing := s3_hmac_sha256(k_service, 'aws4_request'.bytes())
	return k_signing
}

// Calculate signature
fn (s S3Storage) calculate_signature(info S3SigningInfo, string_to_sign string) string {
	signing_key := s.get_signing_key(info.date_stamp)
	signature := s3_hmac_sha256(signing_key, string_to_sign.bytes())
	return hex.encode(signature)
}

// HMAC-SHA256 implementation
fn s3_hmac_sha256(key []u8, data []u8) []u8 {
	block_size := 64
	mut k := key.clone()

	// If the key length is greater than block_size, hash first
	if k.len > block_size {
		k = sha256.sum(k)
	}

	// If the key length is less than block_size, fill it with 0
	for k.len < block_size {
		k << u8(0)
	}

	// Calculate inner and outer padding
	mut i_pad := []u8{len: block_size}
	mut o_pad := []u8{len: block_size}
	for i in 0 .. block_size {
		i_pad[i] = k[i] ^ u8(0x36)
		o_pad[i] = k[i] ^ u8(0x5c)
	}

	// inner hash: SHA256(i_pad || data)
	mut inner_data := i_pad.clone()
	inner_data << data
	inner_hash := sha256.sum(inner_data)

	// outer hash: SHA256(o_pad || inner_hash)
	mut outer_data := o_pad.clone()
	outer_data << inner_hash
	return sha256.sum(outer_data)
}

//Build the Authorization header
fn (s S3Storage) build_authorization_header(info S3SigningInfo, signature string) string {
	algorithm := 'AWS4-HMAC-SHA256'
	credential_scope := '${info.date_stamp}/${s.config.region}/s3/aws4_request'
	credential := '${s.config.access_key}/${credential_scope}'

	return '${algorithm} Credential=${credential}, SignedHeaders=${info.signed_headers}, Signature=${signature}'
}

// Sign the request and return the complete request headers
pub fn (s S3Storage) sign_request(method string, uri string, query_params map[string]string, mut headers map[string]string, payload []u8) map[string]string {
	//Add necessary headers
	host := s.get_host('')
	headers['Host'] = host

	//Create signature information
	info := s.create_signing_info(method, uri, query_params, headers, payload)

	//Add date header
	headers['x-amz-date'] = info.datetime_stamp
	headers['x-amz-content-sha256'] = info.payload_hash

	// Recreate signature information (including newly added headers)
	final_info := s.create_signing_info(method, uri, query_params, headers, payload)

	// Build specification request
	canonical_request := s.build_canonical_request(final_info)

	//Construct the string to be signed
	string_to_sign := s.build_string_to_sign(final_info, canonical_request)

	// Calculate signature
	signature := s.calculate_signature(final_info, string_to_sign)

	//Build the Authorization header
	headers['Authorization'] = s.build_authorization_header(final_info, signature)

	return headers
}

// ============================================================================
// HTTP request helper method
// ============================================================================

// Get the host name
fn (s S3Storage) get_host(bucket string) string {
	if s.config.path_style || bucket == '' {
		return s.config.endpoint
	}
	return '${bucket}.${s.config.endpoint}'
}

// Get the full URL
fn (s S3Storage) get_url(bucket string, key string, query_params map[string]string) string {
	scheme := if s.config.use_ssl { 'https' } else { 'http' }
	host := s.get_host(bucket)

	mut path := ''
	if s.config.path_style {
		if bucket != '' {
			path = '/${bucket}'
		}
		if key != '' {
			path += '/${key}'
		}
	} else {
		if key != '' {
			path = '/${key}'
		}
	}

	if path == '' {
		path = '/'
	}

	mut url := '${scheme}://${host}${path}'

	if query_params.len > 0 {
		query_string := s.build_canonical_query_string(query_params)
		url += '?${query_string}'
	}

	return url
}

// Get URI path
fn (s S3Storage) get_uri_path(bucket string, key string) string {
	if s.config.path_style {
		mut path := ''
		if bucket != '' {
			path = '/${bucket}'
		}
		if key != '' {
			path += '/${key}'
		}
		if path == '' {
			return '/'
		}
		return path
	} else {
		if key != '' {
			return '/${key}'
		}
		return '/'
	}
}

//Perform HTTP request
fn (s S3Storage) do_request(method http.Method, bucket string, key string, query_params map[string]string, extra_headers map[string]string, payload []u8) !http.Response {
	url := s.get_url(bucket, key, query_params)
	uri := s.get_uri_path(bucket, key)

	// Prepare request headers
	mut headers := extra_headers.clone()

	// Signature request
	signed_headers := s.sign_request(method.str(), uri, query_params, mut headers, payload)

	// Build http.Header
	mut http_header := http.Header{}
	for k, v in signed_headers {
		http_header.add_custom(k, v) or {}
	}

	//Execute the request
	mut config := http.FetchConfig{
		url: url
		method: method
		header: http_header
		data: payload.bytestr()
	}

	response := http.fetch(config) or {
		return error(new_timeout_error('s3', method.str()).msg())
	}

	return response
}

// Parse S3 error response
fn (s S3Storage) parse_error_response(response http.Response, operation string) StorageError {
	status := response.status_code

	// Determine the error type based on the status code
	kind := match status {
		403 { StorageErrorKind.access_denied }
		404 { StorageErrorKind.object_not_found }
		409 { StorageErrorKind.bucket_not_found }
		429 { StorageErrorKind.rate_limited }
		500, 502, 503, 504 { StorageErrorKind.service_unavailable }
		else { StorageErrorKind.unknown }
	}

	// Attempt to parse the error message from the response body
	message := if response.body.len > 0 {
		s.extract_error_message(response.body)
	} else {
		'HTTP ${status}'
	}

	return new_storage_error_with_status(kind, message, 's3', operation, status)
}

//Extract the error message from the XML error response
fn (s S3Storage) extract_error_message(body string) string {
	// Simple XML parsing, extract <Message> tag content
	if message_start := body.index('<Message>') {
		if message_end := body.index('</Message>') {
			return body[message_start + 9..message_end]
		}
	}
	return body
}

// Calculate the ETag (MD5) of the data
fn (s S3Storage) calculate_s3_etag(data []u8) string {
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
pub fn (mut s S3Storage) upload(bucket string, key string, data []u8, content_type string) !StorageResult {
	mut headers := map[string]string{}
	headers['Content-Type'] = content_type
	headers['Content-Length'] = data.len.str()

	response := s.do_request(.put, bucket, key, map[string]string{}, headers, data)!

	if response.status_code != 200 {
		return error(s.parse_error_response(response, 'upload').msg())
	}

	// Get ETag from response header
	etag := response.header.get_custom('ETag') or { s.calculate_s3_etag(data) }

	return new_storage_result(key, etag, i64(data.len))
}

// Streaming upload file
pub fn (mut s S3Storage) upload_stream(bucket string, key string, mut reader io.Reader, size i64, content_type string) !StorageResult {
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

	return s.upload(bucket, key, data, content_type)
}

// Download file
pub fn (s S3Storage) download(bucket string, key string) ![]u8 {
	response := s.do_request(.get, bucket, key, map[string]string{}, map[string]string{},
		[]u8{})!

	if response.status_code == 404 {
		return error(new_not_found_error('s3', bucket, key).msg())
	}

	if response.status_code != 200 {
		return error(s.parse_error_response(response, 'download').msg())
	}

	return response.body.bytes()
}

// Streaming download file
pub fn (s S3Storage) download_stream(bucket string, key string, mut writer io.Writer) !i64 {
	data := s.download(bucket, key)!
	written := writer.write(data) or {
		return error(new_storage_error(.unknown, 'Failed to write to stream: ${err}', 's3',
			'download_stream').msg())
	}
	return i64(written)
}

// delete file
pub fn (s S3Storage) delete(bucket string, key string) ! {
	response := s.do_request(.delete, bucket, key, map[string]string{}, map[string]string{},
		[]u8{})!

	// S3 returns 204 indicating successful deletion
	if response.status_code != 204 && response.status_code != 200 {
		if response.status_code == 404 {
			return error(new_not_found_error('s3', bucket, key).msg())
		}
		return error(s.parse_error_response(response, 'delete').msg())
	}
}

// Check if the file exists
pub fn (s S3Storage) exists(bucket string, key string) !bool {
	response := s.do_request(.head, bucket, key, map[string]string{}, map[string]string{},
		[]u8{})!

	if response.status_code == 200 {
		return true
	}
	if response.status_code == 404 {
		return false
	}

	return error(s.parse_error_response(response, 'exists').msg())
}

// ============================================================================
// StorageProvider interface implementation - metadata operation
// ============================================================================

// Get file metadata
pub fn (s S3Storage) head(bucket string, key string) !ObjectInfo {
	response := s.do_request(.head, bucket, key, map[string]string{}, map[string]string{},
		[]u8{})!

	if response.status_code == 404 {
		return error(new_not_found_error('s3', bucket, key).msg())
	}

	if response.status_code != 200 {
		return error(s.parse_error_response(response, 'head').msg())
	}

	// Parse response headers
	content_length := response.header.get_custom('Content-Length') or { '0' }
	etag := response.header.get_custom('ETag') or { '' }
	content_type := response.header.get_custom('Content-Type') or { 'application/octet-stream' }
	last_modified_str := response.header.get_custom('Last-Modified') or { '' }

	// Parse Last-Modified time
	last_modified := s3_parse_http_date(last_modified_str)

	return new_object_info(key, content_length.i64(), etag, content_type, last_modified)
}

// copy file
pub fn (mut s S3Storage) copy(src_bucket string, src_key string, dst_bucket string, dst_key string) !StorageResult {
	mut headers := map[string]string{}
	// S3 copy source format
	copy_source := '/${src_bucket}/${src_key}'
	headers['x-amz-copy-source'] = copy_source

	response := s.do_request(.put, dst_bucket, dst_key, map[string]string{}, headers, []u8{})!

	if response.status_code != 200 {
		return error(s.parse_error_response(response, 'copy').msg())
	}

	// Parse ETag from response
	etag := s.extract_copy_result_etag(response.body)

	// Get the size of the copied file
	head_info := s.head(dst_bucket, dst_key) or {
		return new_storage_result(dst_key, etag, 0)
	}

	return new_storage_result(dst_key, etag, head_info.size)
}

// Extract ETag from copy result XML
fn (s S3Storage) extract_copy_result_etag(body string) string {
	if etag_start := body.index('<ETag>') {
		if etag_end := body.index('</ETag>') {
			return body[etag_start + 6..etag_end]
		}
	}
	return ''
}

// ============================================================================
// StorageProvider interface implementation - list operation
// ============================================================================

// List files
pub fn (s S3Storage) list(bucket string, options ListOptions) !ListResult {
	mut query_params := map[string]string{}
	query_params['list-type'] = '2' //Use ListObjectsV2

	if options.prefix != '' {
		query_params['prefix'] = options.prefix
	}
	if options.delimiter != '' {
		query_params['delimiter'] = options.delimiter
	}
	if options.max_keys > 0 {
		query_params['max-keys'] = options.max_keys.str()
	}
	if options.start_after != '' {
		query_params['start-after'] = options.start_after
	}

	response := s.do_request(.get, bucket, '', query_params, map[string]string{}, []u8{})!

	if response.status_code == 404 {
		return error(new_bucket_not_found_error('s3', bucket).msg())
	}

	if response.status_code != 200 {
		return error(s.parse_error_response(response, 'list').msg())
	}

	// Parse the XML response
	return s.parse_list_objects_response(response.body)
}

// Parse ListObjectsV2 response
fn (s S3Storage) parse_list_objects_response(body string) !ListResult {
	mut objects := []ObjectInfo{}
	mut common_prefixes := []string{}
	mut is_truncated := false
	mut next_marker := ''

	// Parse IsTruncated
	if truncated_start := body.index('<IsTruncated>') {
		if truncated_end := body.index('</IsTruncated>') {
			truncated_str := body[truncated_start + 13..truncated_end]
			is_truncated = truncated_str == 'true'
		}
	}

	// Parse NextContinuationToken
	if token_start := body.index('<NextContinuationToken>') {
		if token_end := body.index('</NextContinuationToken>') {
			next_marker = body[token_start + 23..token_end]
		}
	}

	// Parse Contents
	mut search_pos := 0
	for {
		content_start := body.index_after('<Contents>', search_pos) or { break }
		content_end := body.index_after('</Contents>', content_start) or { break }
		content_xml := body[content_start..content_end + 11]

		obj := s.parse_object_from_xml(content_xml)
		objects << obj

		search_pos = content_end + 11
	}

	// Parse CommonPrefixes
	search_pos = 0
	for {
		prefix_start := body.index_after('<CommonPrefixes>', search_pos) or { break }
		prefix_end := body.index_after('</CommonPrefixes>', prefix_start) or { break }
		prefix_xml := body[prefix_start..prefix_end + 17]

		if p_start := prefix_xml.index('<Prefix>') {
			if p_end := prefix_xml.index('</Prefix>') {
				common_prefixes << prefix_xml[p_start + 8..p_end]
			}
		}

		search_pos = prefix_end + 17
	}

	return new_list_result(objects, common_prefixes, is_truncated, next_marker)
}

// Parse single object information from XML
fn (s S3Storage) parse_object_from_xml(xml string) ObjectInfo {
	mut key := ''
	mut size := i64(0)
	mut etag := ''
	mut last_modified := i64(0)

	if key_start := xml.index('<Key>') {
		if key_end := xml.index('</Key>') {
			key = xml[key_start + 5..key_end]
		}
	}

	if size_start := xml.index('<Size>') {
		if size_end := xml.index('</Size>') {
			size = xml[size_start + 6..size_end].i64()
		}
	}

	if etag_start := xml.index('<ETag>') {
		if etag_end := xml.index('</ETag>') {
			etag = xml[etag_start + 6..etag_end]
		}
	}

	if lm_start := xml.index('<LastModified>') {
		if lm_end := xml.index('</LastModified>') {
			lm_str := xml[lm_start + 14..lm_end]
			last_modified = s3_parse_iso8601_date(lm_str)
		}
	}

	content_type := infer_content_type(key)

	return new_object_info(key, size, etag, content_type, last_modified)
}


// ============================================================================
//StorageProvider interface implementation - Bucket operation
// ============================================================================

//Create bucket
pub fn (s S3Storage) create_bucket(bucket string) ! {
	mut headers := map[string]string{}

	// If it is not us-east-1, you need to specify the location constraint
	mut payload := []u8{}
	if s.config.region != 'us-east-1' {
		location_constraint := '<CreateBucketConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><LocationConstraint>${s.config.region}</LocationConstraint></CreateBucketConfiguration>'
		payload = location_constraint.bytes()
		headers['Content-Type'] = 'application/xml'
	}

	response := s.do_request(.put, bucket, '', map[string]string{}, headers, payload)!

	// 200 or 409 (BucketAlreadyOwnedByYou) is considered successful
	if response.status_code != 200 && response.status_code != 409 {
		return error(s.parse_error_response(response, 'create_bucket').msg())
	}
}

// delete bucket
pub fn (s S3Storage) delete_bucket(bucket string) ! {
	response := s.do_request(.delete, bucket, '', map[string]string{}, map[string]string{},
		[]u8{})!

	if response.status_code != 204 && response.status_code != 200 {
		if response.status_code == 404 {
			return error(new_bucket_not_found_error('s3', bucket).msg())
		}
		return error(s.parse_error_response(response, 'delete_bucket').msg())
	}
}

// Check if bucket exists
pub fn (s S3Storage) bucket_exists(bucket string) !bool {
	response := s.do_request(.head, bucket, '', map[string]string{}, map[string]string{},
		[]u8{})!

	if response.status_code == 200 {
		return true
	}
	if response.status_code == 404 {
		return false
	}

	return error(s.parse_error_response(response, 'bucket_exists').msg())
}

// Get provider name
pub fn (s S3Storage) provider_name() string {
	return 's3'
}


// ============================================================================
// helper function
// ============================================================================

// Parse HTTP date format
fn s3_parse_http_date(date_str string) i64 {
	if date_str == '' {
		return 0
	}
	// HTTP translated comment: "Mon, 02 Jan 2006 15:04:05 GMT"
	// Simplify processing and return the current time
	return time.now().unix()
}

// Parse ISO8601 date format
fn s3_parse_iso8601_date(date_str string) i64 {
	if date_str == '' {
		return 0
	}
	// ISO8601 format: "2006-01-02T15:04:05.000Z"
	// Simplify processing and return the current time
	return time.now().unix()
}

// ============================================================================
//StorageProvider interface implementation - multipart upload
// ============================================================================

//Initialize multipart upload
pub fn (mut s S3Storage) init_multipart(bucket string, key string, content_type string) !string {
	mut query_params := map[string]string{}
	query_params['uploads'] = ''

	mut headers := map[string]string{}
	if content_type != '' {
		headers['Content-Type'] = content_type
	}

	response := s.do_request(.post, bucket, key, query_params, headers, []u8{})!

	if response.status_code != 200 {
		return error(s.parse_error_response(response, 'init_multipart').msg())
	}

	//Extract the UploadId from the XML response
	upload_id := s.extract_upload_id(response.body)
	if upload_id == '' {
		return error(new_storage_error(.unknown, 'Failed to parse UploadId from response',
			's3', 'init_multipart').msg())
	}

	//Record upload status
	s.multipart_uploads[upload_id] = S3MultipartUploadState{
		bucket: bucket
		key: key
		upload_id: upload_id
		content_type: content_type
		parts: map[int]PartInfo{}
		created_at: time.now().unix()
	}

	return upload_id
}


// Extract UploadId from InitiateMultipartUploadResult XML
fn (s S3Storage) extract_upload_id(body string) string {
	if id_start := body.index('<UploadId>') {
		if id_end := body.index('</UploadId>') {
			return body[id_start + 10..id_end]
		}
	}
	return ''
}

//Upload fragments
pub fn (mut s S3Storage) upload_part(bucket string, key string, upload_id string, part_number int, data []u8) !string {
	mut query_params := map[string]string{}
	query_params['partNumber'] = part_number.str()
	query_params['uploadId'] = upload_id

	mut headers := map[string]string{}
	headers['Content-Length'] = data.len.str()

	response := s.do_request(.put, bucket, key, query_params, headers, data)!

	if response.status_code != 200 {
		return error(s.parse_error_response(response, 'upload_part').msg())
	}

	// Get ETag from response header
	etag := response.header.get_custom('ETag') or { s.calculate_s3_etag(data) }

	//Update upload status
	if upload_id in s.multipart_uploads {
		mut upload_state := s.multipart_uploads[upload_id]
		upload_state.parts[part_number] = new_part_info(part_number, etag, i64(data.len))
		s.multipart_uploads[upload_id] = upload_state
	}

	return etag
}

//Complete multipart upload
pub fn (mut s S3Storage) complete_multipart(bucket string, key string, upload_id string, parts []PartInfo) !StorageResult {
	mut query_params := map[string]string{}
	query_params['uploadId'] = upload_id

	// Build CompleteMultipartUpload XML
	mut xml_parts := '<CompleteMultipartUpload>'
	for part in parts {
		xml_parts += '<Part>'
		xml_parts += '<PartNumber>${part.part_number}</PartNumber>'
		xml_parts += '<ETag>${part.etag}</ETag>'
		xml_parts += '</Part>'
	}
	xml_parts += '</CompleteMultipartUpload>'

	mut headers := map[string]string{}
	headers['Content-Type'] = 'application/xml'

	payload := xml_parts.bytes()
	response := s.do_request(.post, bucket, key, query_params, headers, payload)!

	if response.status_code != 200 {
		return error(s.parse_error_response(response, 'complete_multipart').msg())
	}

	// Parse ETag from response
	etag := s.extract_complete_multipart_etag(response.body)

	// Calculate total size
	mut total_size := i64(0)
	for part in parts {
		total_size += part.size
	}

	// Clear upload status
	s.multipart_uploads.delete(upload_id)

	return new_storage_result(key, etag, total_size)
}


// Extract ETag from CompleteMultipartUploadResult XML
fn (s S3Storage) extract_complete_multipart_etag(body string) string {
	if etag_start := body.index('<ETag>') {
		if etag_end := body.index('</ETag>') {
			return body[etag_start + 6..etag_end]
		}
	}
	return ''
}

//Cancel multipart upload
pub fn (mut s S3Storage) abort_multipart(bucket string, key string, upload_id string) ! {
	mut query_params := map[string]string{}
	query_params['uploadId'] = upload_id

	response := s.do_request(.delete, bucket, key, query_params, map[string]string{}, []u8{})!

	if response.status_code != 204 && response.status_code != 200 {
		return error(s.parse_error_response(response, 'abort_multipart').msg())
	}

	// Clear upload status
	s.multipart_uploads.delete(upload_id)
}

// ============================================================================
// StorageProvider interface implementation - pre-signed URL
// ============================================================================

// Generate pre-signed URL
pub fn (s S3Storage) presign_url(bucket string, key string, options PresignOptions) !string {
	now := time.utc()
	date_stamp := now.custom_format('YYYYMMDD')
	datetime_stamp := now.custom_format('YYYYMMDD') + 'T' + now.custom_format('HHmmss') + 'Z'

	// Build query parameters
	mut query_params := map[string]string{}
	query_params['X-Amz-Algorithm'] = 'AWS4-HMAC-SHA256'

	credential_scope := '${date_stamp}/${s.config.region}/s3/aws4_request'
	query_params['X-Amz-Credential'] = '${s.config.access_key}/${credential_scope}'
	query_params['X-Amz-Date'] = datetime_stamp
	query_params['X-Amz-Expires'] = options.expires_in.str()
	query_params['X-Amz-SignedHeaders'] = 'host'

	// Build URI
	uri := s.get_uri_path(bucket, key)

	// Build specification request
	host := s.get_host(bucket)
	canonical_headers := 'host:${host}\n'
	signed_headers := 'host'
	payload_hash := 'UNSIGNED-PAYLOAD'

	query_string := s.build_canonical_query_string(query_params)

	canonical_request := '${options.method}\n${uri}\n${query_string}\n${canonical_headers}\n${signed_headers}\n${payload_hash}'

	//Construct the string to be signed
	request_hash := sha256.sum(canonical_request.bytes())
	hashed_request := hex.encode(request_hash)
	string_to_sign := 'AWS4-HMAC-SHA256\n${datetime_stamp}\n${credential_scope}\n${hashed_request}'

	// Calculate signature
	signing_key := s.get_signing_key(date_stamp)
	signature := s3_hmac_sha256(signing_key, string_to_sign.bytes())
	signature_hex := hex.encode(signature)

	//Add signature to query parameters
	query_params['X-Amz-Signature'] = signature_hex

	// Build final URL
	return s.get_url(bucket, key, query_params)
}
