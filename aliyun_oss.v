module vono

import io
import net.http
import net.urllib
import time
import crypto.sha1
import crypto.md5
import encoding.base64

// AliyunOSS Alibaba Cloud OSS storage provider
pub struct AliyunOSS {
	config AliyunOSSConfig
mut:
	// Memory storage used to track multipart uploads
	multipart_uploads map[string]OSSMultipartUploadState
	// Whether to use the intranet endpoint
	use_internal bool
}

// OSS fragment upload status
struct OSSMultipartUploadState {
mut:
	bucket       string
	key          string
	upload_id    string
	content_type string
	parts        map[int]PartInfo
	created_at   i64
}

//Create Alibaba Cloud OSS storage provider
pub fn new_aliyun_oss(config AliyunOSSConfig) !AliyunOSS {
	//Verify configuration
	validation := validate_aliyun_oss_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	return AliyunOSS{
		config: config
		multipart_uploads: map[string]OSSMultipartUploadState{}
		use_internal: false
	}
}

//Create Alibaba Cloud OSS storage provider using intranet endpoint
pub fn new_aliyun_oss_internal(config AliyunOSSConfig) !AliyunOSS {
	//Verify configuration
	validation := validate_aliyun_oss_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	if config.internal_endpoint == '' {
		return error('Internal endpoint is not configured')
	}

	return AliyunOSS{
		config: config
		multipart_uploads: map[string]OSSMultipartUploadState{}
		use_internal: true
	}
}


//Switch to the intranet endpoint
pub fn (mut o AliyunOSS) switch_to_internal() ! {
	if o.config.internal_endpoint == '' {
		return error('Internal endpoint is not configured')
	}
	o.use_internal = true
}

//Switch to the external network endpoint
pub fn (mut o AliyunOSS) switch_to_external() {
	o.use_internal = false
}

// Get the currently used endpoint
pub fn (o AliyunOSS) get_current_endpoint() string {
	if o.use_internal && o.config.internal_endpoint != '' {
		return o.config.internal_endpoint
	}
	return o.config.endpoint
}

// ============================================================================
// Alibaba Cloud OSS signature algorithm implementation (OSS Signature V1)
// ============================================================================

// Information required to sign the request
struct OSSSigningInfo {
	method                    string
	content_md5               string
	content_type              string
	date                      string
	canonicalized_oss_headers string
	canonicalized_resource    string
}

//Create signature information
fn (o AliyunOSS) create_signing_info(method string, bucket string, key string, headers map[string]string, query_params map[string]string) OSSSigningInfo {
	// Get Content-MD5
	content_md5 := headers['Content-MD5'] or { '' }

	// Get Content-Type
	content_type := headers['Content-Type'] or { '' }

	// Get date
	date := headers['Date'] or { '' }

	//Build a standardized OSS header
	canonicalized_oss_headers := o.build_canonicalized_oss_headers(headers)

	// Build standardized resources
	canonicalized_resource := o.build_canonicalized_resource(bucket, key, query_params)

	return OSSSigningInfo{
		method: method
		content_md5: content_md5
		content_type: content_type
		date: date
		canonicalized_oss_headers: canonicalized_oss_headers
		canonicalized_resource: canonicalized_resource
	}
}

//Build a standardized OSS header
fn (o AliyunOSS) build_canonicalized_oss_headers(headers map[string]string) string {
	// Collect all headers starting with x-oss-
	mut oss_headers := map[string]string{}
	for key, value in headers {
		lower_key := key.to_lower()
		if lower_key.starts_with('x-oss-') {
			oss_headers[lower_key] = value.trim_space()
		}
	}

	if oss_headers.len == 0 {
		return ''
	}

	// Sort by key
	mut keys := oss_headers.keys()
	keys.sort()

	//Construct a normalized string
	mut result := ''
	for key in keys {
		result += '${key}:${oss_headers[key]}\n'
	}

	return result
}


// Build standardized resources
fn (o AliyunOSS) build_canonicalized_resource(bucket string, key string, query_params map[string]string) string {
	mut resource := ''

	// add bucket
	if bucket != '' {
		resource = '/${bucket}'
	}

	// add key
	if key != '' {
		resource += '/${key}'
	} else if bucket != '' {
		resource += '/'
	} else {
		resource = '/'
	}

	//Add sub-resource parameters (needs sorting)
	sub_resources := [
		'acl', 'uploads', 'location', 'cors', 'logging', 'website', 'referer',
		'lifecycle', 'delete', 'append', 'tagging', 'objectMeta', 'uploadId',
		'partNumber', 'security-token', 'position', 'img', 'style', 'styleName',
		'replication', 'replicationProgress', 'replicationLocation', 'cname',
		'bucketInfo', 'comp', 'qos', 'live', 'status', 'vod', 'startTime',
		'endTime', 'symlink', 'x-oss-process', 'response-content-type',
		'response-content-language', 'response-expires', 'response-cache-control',
		'response-content-disposition', 'response-content-encoding',
	]

	mut sub_params := []string{}
	for param in sub_resources {
		if param in query_params {
			value := query_params[param]
			if value != '' {
				sub_params << '${param}=${value}'
			} else {
				sub_params << param
			}
		}
	}

	if sub_params.len > 0 {
		resource += '?' + sub_params.join('&')
	}

	return resource
}

//Construct the string to be signed
fn (o AliyunOSS) build_string_to_sign(info OSSSigningInfo) string {
	// If there is an OSS header, a newline needs to be added between it and the resource.
	if info.canonicalized_oss_headers != '' {
		return '${info.method}\n${info.content_md5}\n${info.content_type}\n${info.date}\n${info.canonicalized_oss_headers}${info.canonicalized_resource}'
	}

	return '${info.method}\n${info.content_md5}\n${info.content_type}\n${info.date}\n${info.canonicalized_resource}'
}

// Calculate signature
fn (o AliyunOSS) calculate_signature(string_to_sign string) string {
	// Calculate signature using HMAC-SHA1
	signature := oss_hmac_sha1(o.config.access_key_secret.bytes(), string_to_sign.bytes())
	// Base64 encoding
	return base64.encode(signature)
}

// HMAC-SHA1 implementation
fn oss_hmac_sha1(key []u8, data []u8) []u8 {
	block_size := 64
	mut k := key.clone()

	// If the key length is greater than block_size, hash first
	if k.len > block_size {
		k = sha1.sum(k)
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

	// inner hash: SHA1(i_pad || data)
	mut inner_data := i_pad.clone()
	inner_data << data
	inner_hash := sha1.sum(inner_data)

	// outer hash: SHA1(o_pad || inner_hash)
	mut outer_data := o_pad.clone()
	outer_data << inner_hash
	return sha1.sum(outer_data)
}


// Sign the request and return the complete request headers
pub fn (o AliyunOSS) sign_request(method string, bucket string, key string, mut headers map[string]string, query_params map[string]string) map[string]string {
	//Add date header
	now := time.utc()
	date := o.format_http_date(now)
	headers['Date'] = date

	//Create signature information
	info := o.create_signing_info(method, bucket, key, headers, query_params)

	//Construct the string to be signed
	string_to_sign := o.build_string_to_sign(info)

	// Calculate signature
	signature := o.calculate_signature(string_to_sign)

	//Build the Authorization header
	headers['Authorization'] = 'OSS ${o.config.access_key_id}:${signature}'

	return headers
}

// Format HTTP date
fn (o AliyunOSS) format_http_date(t time.Time) string {
	// HTTP translated comment: "Mon, 02 Jan 2006 15:04:05 GMT"
	days := ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

	day_of_week := days[int(t.day_of_week())]
	month := months[t.month - 1]

	return '${day_of_week}, ${t.day:02d} ${month} ${t.year} ${t.hour:02d}:${t.minute:02d}:${t.second:02d} GMT'
}

// ============================================================================
// HTTP request helper method
// ============================================================================

// Get the host name
fn (o AliyunOSS) get_host(bucket string) string {
	endpoint := o.get_current_endpoint()
	if bucket != '' {
		return '${bucket}.${endpoint}'
	}
	return endpoint
}

// Get the full URL
fn (o AliyunOSS) get_url(bucket string, key string, query_params map[string]string) string {
	host := o.get_host(bucket)

	mut path := ''
	if key != '' {
		// URL encode key, but keep /
		path = '/' + o.encode_key(key)
	} else {
		path = '/'
	}

	mut url := 'https://${host}${path}'

	if query_params.len > 0 {
		query_string := o.build_query_string(query_params)
		url += '?${query_string}'
	}

	return url
}

// URL encoding key (reserved /)
fn (o AliyunOSS) encode_key(key string) string {
	parts := key.split('/')
	mut encoded_parts := []string{}
	for part in parts {
		encoded_parts << urllib.query_escape(part)
	}
	return encoded_parts.join('/')
}

// Build query string
fn (o AliyunOSS) build_query_string(params map[string]string) string {
	if params.len == 0 {
		return ''
	}

	mut keys := params.keys()
	keys.sort()

	mut parts := []string{}
	for key in keys {
		value := params[key]
		if value != '' {
			parts << '${urllib.query_escape(key)}=${urllib.query_escape(value)}'
		} else {
			parts << urllib.query_escape(key)
		}
	}

	return parts.join('&')
}


//Perform HTTP request
fn (o AliyunOSS) do_request(method http.Method, bucket string, key string, query_params map[string]string, extra_headers map[string]string, payload []u8) !http.Response {
	url := o.get_url(bucket, key, query_params)

	// Prepare request headers
	mut headers := extra_headers.clone()
	headers['Host'] = o.get_host(bucket)

	// If there is a payload, calculate Content-MD5
	if payload.len > 0 {
		md5_hash := md5.sum(payload)
		headers['Content-MD5'] = base64.encode(md5_hash)
		headers['Content-Length'] = payload.len.str()
	}

	// Signature request
	signed_headers := o.sign_request(method.str(), bucket, key, mut headers, query_params)

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
		return error(new_timeout_error('aliyun_oss', method.str()).msg())
	}

	return response
}

// Parse OSS error response
fn (o AliyunOSS) parse_error_response(response http.Response, operation string) StorageError {
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
		o.extract_error_message(response.body)
	} else {
		'HTTP ${status}'
	}

	return new_storage_error_with_status(kind, message, 'aliyun_oss', operation, status)
}

//Extract the error message from the XML error response
fn (o AliyunOSS) extract_error_message(body string) string {
	// Simple XML parsing, extract <Message> tag content
	if message_start := body.index('<Message>') {
		if message_end := body.index('</Message>') {
			return body[message_start + 9..message_end]
		}
	}
	// Try to extract the <Code> tag
	if code_start := body.index('<Code>') {
		if code_end := body.index('</Code>') {
			return body[code_start + 6..code_end]
		}
	}
	return body
}

// Calculate the ETag (MD5) of the data
fn (o AliyunOSS) calculate_etag(data []u8) string {
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
pub fn (mut o AliyunOSS) upload(bucket string, key string, data []u8, content_type string) !StorageResult {
	mut headers := map[string]string{}
	if content_type != '' {
		headers['Content-Type'] = content_type
	} else {
		headers['Content-Type'] = 'application/octet-stream'
	}

	response := o.do_request(.put, bucket, key, map[string]string{}, headers, data)!

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'upload').msg())
	}

	// Get ETag from response header
	etag := response.header.get_custom('ETag') or { o.calculate_etag(data) }

	return new_storage_result(key, etag, i64(data.len))
}

// Streaming upload file
pub fn (mut o AliyunOSS) upload_stream(bucket string, key string, mut reader io.Reader, size i64, content_type string) !StorageResult {
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

	return o.upload(bucket, key, data, content_type)
}

// Download file
pub fn (o AliyunOSS) download(bucket string, key string) ![]u8 {
	response := o.do_request(.get, bucket, key, map[string]string{}, map[string]string{}, []u8{})!

	if response.status_code == 404 {
		return error(new_not_found_error('aliyun_oss', bucket, key).msg())
	}

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'download').msg())
	}

	return response.body.bytes()
}

// Streaming download file
pub fn (o AliyunOSS) download_stream(bucket string, key string, mut writer io.Writer) !i64 {
	data := o.download(bucket, key)!
	written := writer.write(data) or {
		return error(new_storage_error(.unknown, 'Failed to write to stream: ${err}', 'aliyun_oss', 'download_stream').msg())
	}
	return i64(written)
}

// delete file
pub fn (o AliyunOSS) delete(bucket string, key string) ! {
	response := o.do_request(.delete, bucket, key, map[string]string{}, map[string]string{}, []u8{})!

	// OSS returns 204 or 200 to indicate successful deletion
	if response.status_code != 204 && response.status_code != 200 {
		if response.status_code == 404 {
			return error(new_not_found_error('aliyun_oss', bucket, key).msg())
		}
		return error(o.parse_error_response(response, 'delete').msg())
	}
}

// Check if the file exists
pub fn (o AliyunOSS) exists(bucket string, key string) !bool {
	response := o.do_request(.head, bucket, key, map[string]string{}, map[string]string{}, []u8{})!

	if response.status_code == 200 {
		return true
	}
	if response.status_code == 404 {
		return false
	}

	return error(o.parse_error_response(response, 'exists').msg())
}


// ============================================================================
// StorageProvider interface implementation - metadata operation
// ============================================================================

// Get file metadata
pub fn (o AliyunOSS) head(bucket string, key string) !ObjectInfo {
	response := o.do_request(.head, bucket, key, map[string]string{}, map[string]string{}, []u8{})!

	if response.status_code == 404 {
		return error(new_not_found_error('aliyun_oss', bucket, key).msg())
	}

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'head').msg())
	}

	// Parse response headers
	content_length := response.header.get_custom('Content-Length') or { '0' }
	etag := response.header.get_custom('ETag') or { '' }
	content_type := response.header.get_custom('Content-Type') or { 'application/octet-stream' }
	last_modified_str := response.header.get_custom('Last-Modified') or { '' }

	// Parse Last-Modified time
	last_modified := parse_oss_http_date(last_modified_str)

	return new_object_info(key, content_length.i64(), etag, content_type, last_modified)
}

// copy file
pub fn (mut o AliyunOSS) copy(src_bucket string, src_key string, dst_bucket string, dst_key string) !StorageResult {
	mut headers := map[string]string{}
	// OSS copy source format
	copy_source := '/${src_bucket}/${src_key}'
	headers['x-oss-copy-source'] = copy_source

	response := o.do_request(.put, dst_bucket, dst_key, map[string]string{}, headers, []u8{})!

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'copy').msg())
	}

	// Parse ETag from response
	etag := o.extract_copy_result_etag(response.body)

	// Get the size of the copied file
	head_info := o.head(dst_bucket, dst_key) or {
		return new_storage_result(dst_key, etag, 0)
	}

	return new_storage_result(dst_key, etag, head_info.size)
}

// Extract ETag from copy result XML
fn (o AliyunOSS) extract_copy_result_etag(body string) string {
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
pub fn (o AliyunOSS) list(bucket string, options ListOptions) !ListResult {
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

	response := o.do_request(.get, bucket, '', query_params, map[string]string{}, []u8{})!

	if response.status_code == 404 {
		return error(new_bucket_not_found_error('aliyun_oss', bucket).msg())
	}

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'list').msg())
	}

	// Parse the XML response
	return o.parse_list_objects_response(response.body)
}


// Parse ListObjectsV2 response
fn (o AliyunOSS) parse_list_objects_response(body string) !ListResult {
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

		obj := o.parse_object_from_xml(content_xml)
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
fn (o AliyunOSS) parse_object_from_xml(xml string) ObjectInfo {
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
			last_modified = parse_oss_iso8601_date(lm_str)
		}
	}

	content_type := infer_content_type(key)

	return new_object_info(key, size, etag, content_type, last_modified)
}


// ============================================================================
//StorageProvider interface implementation - Bucket operation
// ============================================================================

//Create bucket
pub fn (o AliyunOSS) create_bucket(bucket string) ! {
	mut headers := map[string]string{}
	headers['Content-Type'] = 'application/xml'

	//Construct the XML that creates the bucket
	// Note: OSS needs to specify the storage type and data redundancy type
	payload := '<?xml version="1.0" encoding="UTF-8"?><CreateBucketConfiguration><StorageClass>Standard</StorageClass></CreateBucketConfiguration>'

	response := o.do_request(.put, bucket, '', map[string]string{}, headers, payload.bytes())!

	// 200 or 409 (BucketAlreadyExists) is considered successful
	if response.status_code != 200 && response.status_code != 409 {
		return error(o.parse_error_response(response, 'create_bucket').msg())
	}
}

// delete bucket
pub fn (o AliyunOSS) delete_bucket(bucket string) ! {
	response := o.do_request(.delete, bucket, '', map[string]string{}, map[string]string{}, []u8{})!

	if response.status_code != 204 && response.status_code != 200 {
		if response.status_code == 404 {
			return error(new_bucket_not_found_error('aliyun_oss', bucket).msg())
		}
		return error(o.parse_error_response(response, 'delete_bucket').msg())
	}
}

// Check if bucket exists
pub fn (o AliyunOSS) bucket_exists(bucket string) !bool {
	response := o.do_request(.head, bucket, '', map[string]string{}, map[string]string{}, []u8{})!

	if response.status_code == 200 {
		return true
	}
	if response.status_code == 404 {
		return false
	}

	return error(o.parse_error_response(response, 'bucket_exists').msg())
}

// Get provider name
pub fn (o AliyunOSS) provider_name() string {
	return 'aliyun_oss'
}

// ============================================================================
//StorageProvider interface implementation - multipart upload
// ============================================================================

//Initialize multipart upload
pub fn (mut o AliyunOSS) init_multipart(bucket string, key string, content_type string) !string {
	mut query_params := map[string]string{}
	query_params['uploads'] = ''

	mut headers := map[string]string{}
	if content_type != '' {
		headers['Content-Type'] = content_type
	}

	response := o.do_request(.post, bucket, key, query_params, headers, []u8{})!

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'init_multipart').msg())
	}

	//Extract the UploadId from the XML response
	upload_id := o.extract_upload_id(response.body)
	if upload_id == '' {
		return error(new_storage_error(.unknown, 'Failed to parse UploadId from response', 'aliyun_oss', 'init_multipart').msg())
	}

	//Record upload status
	o.multipart_uploads[upload_id] = OSSMultipartUploadState{
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
fn (o AliyunOSS) extract_upload_id(body string) string {
	if id_start := body.index('<UploadId>') {
		if id_end := body.index('</UploadId>') {
			return body[id_start + 10..id_end]
		}
	}
	return ''
}


//Upload fragments
pub fn (mut o AliyunOSS) upload_part(bucket string, key string, upload_id string, part_number int, data []u8) !string {
	mut query_params := map[string]string{}
	query_params['partNumber'] = part_number.str()
	query_params['uploadId'] = upload_id

	mut headers := map[string]string{}
	headers['Content-Length'] = data.len.str()

	response := o.do_request(.put, bucket, key, query_params, headers, data)!

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'upload_part').msg())
	}

	// Get ETag from response header
	etag := response.header.get_custom('ETag') or { o.calculate_etag(data) }

	//Update upload status
	if upload_id in o.multipart_uploads {
		mut upload_state := o.multipart_uploads[upload_id]
		upload_state.parts[part_number] = new_part_info(part_number, etag, i64(data.len))
		o.multipart_uploads[upload_id] = upload_state
	}

	return etag
}

//Complete multipart upload
pub fn (mut o AliyunOSS) complete_multipart(bucket string, key string, upload_id string, parts []PartInfo) !StorageResult {
	mut query_params := map[string]string{}
	query_params['uploadId'] = upload_id

	// Build CompleteMultipartUpload XML
	mut xml_parts := '<?xml version="1.0" encoding="UTF-8"?><CompleteMultipartUpload>'
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
	response := o.do_request(.post, bucket, key, query_params, headers, payload)!

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'complete_multipart').msg())
	}

	// Parse ETag from response
	etag := o.extract_complete_multipart_etag(response.body)

	// Calculate total size
	mut total_size := i64(0)
	for part in parts {
		total_size += part.size
	}

	// Clear upload status
	o.multipart_uploads.delete(upload_id)

	return new_storage_result(key, etag, total_size)
}

// Extract ETag from CompleteMultipartUploadResult XML
fn (o AliyunOSS) extract_complete_multipart_etag(body string) string {
	if etag_start := body.index('<ETag>') {
		if etag_end := body.index('</ETag>') {
			return body[etag_start + 6..etag_end]
		}
	}
	return ''
}

//Cancel multipart upload
pub fn (mut o AliyunOSS) abort_multipart(bucket string, key string, upload_id string) ! {
	mut query_params := map[string]string{}
	query_params['uploadId'] = upload_id

	response := o.do_request(.delete, bucket, key, query_params, map[string]string{}, []u8{})!

	if response.status_code != 204 && response.status_code != 200 {
		return error(o.parse_error_response(response, 'abort_multipart').msg())
	}

	// Clear upload status
	o.multipart_uploads.delete(upload_id)
}


// ============================================================================
// StorageProvider interface implementation - pre-signed URL
// ============================================================================

// Generate pre-signed URL
pub fn (o AliyunOSS) presign_url(bucket string, key string, options PresignOptions) !string {
	// Calculate expiration timestamp
	now := time.utc()
	expires := now.unix() + i64(options.expires_in)

	//Construct the string to be signed
	// Format: METHOD\n\nContent-Type\nExpires\nCanonicalizedOSSHeaders\nCanonicalizedResource
	mut content_type := ''
	if options.content_type != '' {
		content_type = options.content_type
	}

	canonicalized_resource := o.build_canonicalized_resource(bucket, key, map[string]string{})

	string_to_sign := '${options.method}\n\n${content_type}\n${expires}\n${canonicalized_resource}'

	// Calculate signature
	signature := o.calculate_signature(string_to_sign)

	// Build URL
	host := o.get_host(bucket)
	encoded_key := o.encode_key(key)

	mut url := 'https://${host}/${encoded_key}'
	url += '?OSSAccessKeyId=${urllib.query_escape(o.config.access_key_id)}'
	url += '&Expires=${expires}'
	url += '&Signature=${urllib.query_escape(signature)}'

	return url
}

// ============================================================================
// helper function
// ============================================================================

// Parse OSS HTTP date format
fn parse_oss_http_date(date_str string) i64 {
	if date_str == '' {
		return 0
	}
	// HTTP translated comment: "Mon, 02 Jan 2006 15:04:05 GMT"
	// Simplify processing and return the current time
	return time.now().unix()
}

// Parse OSS ISO8601 date format
fn parse_oss_iso8601_date(date_str string) i64 {
	if date_str == '' {
		return 0
	}
	// ISO8601 format: "2006-01-02T15:04:05.000Z"
	// Simplify processing and return the current time
	return time.now().unix()
}
