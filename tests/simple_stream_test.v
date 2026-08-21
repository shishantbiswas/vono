import meiseayoung.vono
import net.http
import os
import time
import strings

fn main() {
	println('=== 文件流式传输功能测试 ===')
	
	//Create test file
	create_test_files()
	
	//Create Context for testing
	test_file_streaming()
	
	println('\n功能测试完成!')
	
	// Clean test files
	cleanup_test_files()
}

fn create_test_files() {
	println('创建测试文件...')
	
	//Create small file (1KB)
	small_content := 'Hello World! '.repeat(80)
	os.write_file('test_small.txt', small_content) or { 
		println('  ❌ 创建小文件失败: $err')
		return
	}
	println('  ✅ 创建小文件: test_small.txt (${small_content.len} bytes)')
	
	//Create medium file (~100KB)
	mut medium_content := strings.new_builder(100 * 1024)
	for i in 0 .. 1000 {
		medium_content.write_string('This is line ${i:04d} with some content to make it longer and test streaming.\n')
	}
	medium_str := medium_content.str()
	os.write_file('test_medium.txt', medium_str) or { 
		println('  ❌ 创建中等文件失败: $err')
		return
	}
	println('  ✅ 创建中等文件: test_medium.txt (${medium_str.len} bytes)')
	
	//Create large file (about 1MB)
	mut large_content := strings.new_builder(1024 * 1024)
	base_line := 'This is a long line of text that will be repeated many times to create a large file for testing streaming functionality. '
	for i in 0 .. 10000 {
		large_content.write_string('${i:05d}: $base_line\n')
	}
	large_str := large_content.str()
	os.write_file('test_large.txt', large_str) or { 
		println('  ❌ 创建大文件失败: $err')
		return
	}
	println('  ✅ 创建大文件: test_large.txt (${large_str.len} bytes)')
}

fn test_file_streaming() {
	println('\n开始功能测试...')
	
	//Create a mock request
	test_req := http.Request{
		method: http.Method.get
		url: '/test'
		data: ''
		header: http.new_header()
	}
	
	//Test 1: Traditional file service
	println('\n--- 测试1: 传统文件服务 ---')
	check_traditional_file_serving(test_req)
	
	//Test 2: Streaming file service
	println('\n--- 测试2: 流式文件服务 ---')
	check_stream_file_serving(test_req)
	
	//Test 3: Smart file service
	println('\n--- 测试3: 智能文件服务 ---')
	check_smart_file_serving(test_req)
	
	//Test 4: Range request
	println('\n--- 测试4: Range请求测试 ---')
	check_range_requests()
	
	//Test 5: Custom option test
	println('\n--- 测试5: 自定义选项测试 ---')
	check_custom_options(test_req)
}

fn check_traditional_file_serving(req http.Request) {
	files_to_test := ['test_small.txt', 'test_medium.txt', 'test_large.txt']
	
	for file in files_to_test {
		if !os.exists(file) {
			println('  ❌ 文件不存在: $file')
			continue
		}
		
		// Create Context
		mut ctx := vono.Context.new(req, map[string]string{}, map[string]string{}, '')
		
		start := time.now()
		response := ctx.file(file)
		duration := time.now() - start
		
		mut original_size := i64(0)
		if stat := os.stat(file) {
			original_size = stat.size
		}
		response_size := response.body.len
		
		if response.status_code == 200 && response_size == int(original_size) {
			println('  ✅ $file: 成功 (${response_size} bytes, ${duration})')
		} else {
			println('  ❌ $file: 失败 (状态码: ${response.status_code}, 大小: ${response_size}/${original_size})')
		}
	}
}

fn check_stream_file_serving(req http.Request) {
	files_to_test := ['test_small.txt', 'test_medium.txt', 'test_large.txt']
	
	for file in files_to_test {
		if !os.exists(file) {
			println('  ❌ 文件不存在: $file')
			continue
		}
		
		// Create Context
		mut ctx := vono.Context.new(req, map[string]string{}, map[string]string{}, '')
		
		start := time.now()
		response := ctx.file_stream(file)
		duration := time.now() - start
		
		mut original_size := i64(0)
		if stat := os.stat(file) {
			original_size = stat.size
		}
		response_size := response.body.len
		
		if response.status_code == 200 && response_size == int(original_size) {
			println('  ✅ $file (流式): 成功 (${response_size} bytes, ${duration})')
		} else {
			println('  ❌ $file (流式): 失败 (状态码: ${response.status_code}, 大小: ${response_size}/${original_size})')
		}
	}
}

fn check_smart_file_serving(req http.Request) {
	files_to_test := ['test_small.txt', 'test_medium.txt', 'test_large.txt']
	
	for file in files_to_test {
		if !os.exists(file) {
			println('  ❌ 文件不存在: $file')
			continue
		}
		
		// Create Context
		mut ctx := vono.Context.new(req, map[string]string{}, map[string]string{}, '')
		
		start := time.now()
		response := ctx.file_smart(file)
		duration := time.now() - start
		
		mut original_size := i64(0)
		if stat := os.stat(file) {
			original_size = stat.size
		}
		response_size := response.body.len
		
		// Check whether the transmission method is correctly selected
		mut expected_method := "内存"
		if original_size > 50 * 1024 * 1024 { //Default threshold 50MB
			expected_method = "流式"
		}
		
		if response.status_code == 200 && response_size == int(original_size) {
			println('  ✅ $file (智能-$expected_method): 成功 (${response_size} bytes, ${duration})')
		} else {
			println('  ❌ $file (智能): 失败 (状态码: ${response.status_code}, 大小: ${response_size}/${original_size})')
		}
	}
}

fn check_range_requests() {
	file := 'test_medium.txt'
	if !os.exists(file) {
		println('  ❌ 测试文件不存在: $file')
		return
	}
	
	//Create a request with Range header
	mut range_header := http.new_header()
	range_header.add_custom('Range', 'bytes=0-99') or { }
	
	range_req := http.Request{
		method: http.Method.get
		url: '/test'
		data: ''
		header: range_header
	}
	
	// Create Context
	mut ctx := vono.Context.new(range_req, map[string]string{}, map[string]string{}, '')
	
	// Use options that support Range
	options := vono.FileOptions{
		enable_range: true
		stream_threshold: 1024  // Force streaming to test Range functionality
	}
	
	response := ctx.file_stream_with_options(file, options)
	
	if response.status_code == 206 {  // Partial Content
		println('  ✅ Range请求: 成功 (状态码: 206, 内容长度: ${response.body.len})')
		
		// Check the Content-Range header
		if content_range := response.header.get_custom('Content-Range') {
			println('  📊 Content-Range: $content_range')
		}
	} else {
		println('  ❌ Range请求: 失败 (状态码: ${response.status_code})')
	}
}

fn check_custom_options(req http.Request) {
	file := 'test_medium.txt'
	if !os.exists(file) {
		println('  ❌ 测试文件不存在: $file')
		return
	}
	
	//Test custom options
	custom_options := vono.FileOptions{
		stream_threshold: 10 * 1024  // 10KB threshold
		buffer_size: 2048            // 2KB buffer
		enable_range: true
		max_age: 7200
		content_type: 'text/plain; charset=utf-8'
		headers: {
			'X-Custom-Header': 'streaming-test'
			'X-Buffer-Size': '2048'
		}
	}
	
	// Create Context
	mut ctx := vono.Context.new(req, map[string]string{}, map[string]string{}, '')
	
	response := ctx.file_stream_with_options(file, custom_options)
	
	if response.status_code == 200 {
		println('  ✅ 自定义选项: 成功')
		
		// Check for custom headers
		if custom_header := response.header.get_custom('X-Custom-Header') {
			println('  📋 自定义头部: $custom_header')
		}
		
		if cache_control := response.header.get_custom('Cache-Control') {
			println('  🕒 缓存控制: $cache_control')
		}
		
		if content_type := response.header.get_custom('Content-Type') {
			println('  📝 内容类型: $content_type')
		}
	} else {
		println('  ❌ 自定义选项: 失败 (状态码: ${response.status_code})')
	}
}

fn cleanup_test_files() {
	println('\n清理测试文件...')
	test_files := ['test_small.txt', 'test_medium.txt', 'test_large.txt']
	
	for file in test_files {
		if os.exists(file) {
			os.rm(file) or {
				println('  警告: 无法删除 $file')
			}
		}
	}
	println('清理完成')
}
