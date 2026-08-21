import meiseayoung.vono
import os
import time

fn test_logger_creation() {
	println('=== 测试日志器创建 ===')
	
	config := vono.LoggerConfig{
		level: vono.LogLevel.debug
		output: vono.LogOutput.console
		enable_colors: true
	}
	
	logger := vono.new_logger(config)
	assert logger.config.level == vono.LogLevel.debug
	assert logger.config.output == vono.LogOutput.console
	
	println('✅ 日志器创建测试通过')
}

fn test_log_levels() {
	println('=== 测试日志级别 ===')
	
	// Convert test string to log level
	assert vono.parse_log_level('debug') == vono.LogLevel.debug
	assert vono.parse_log_level('info') == vono.LogLevel.info
	assert vono.parse_log_level('warn') == vono.LogLevel.warn
	assert vono.parse_log_level('error') == vono.LogLevel.error
	assert vono.parse_log_level('invalid') == vono.LogLevel.info  // default value
	
	//Test log level to string
	assert vono.log_level_to_string(vono.LogLevel.debug) == 'DEBUG'
	assert vono.log_level_to_string(vono.LogLevel.info) == 'INFO'
	assert vono.log_level_to_string(vono.LogLevel.warn) == 'WARN'
	assert vono.log_level_to_string(vono.LogLevel.error) == 'ERROR'
	
	println('✅ 日志级别测试通过')
}

fn test_console_logging() {
	println('=== 测试控制台日志输出 ===')
	
	config := vono.LoggerConfig{
		level: vono.LogLevel.debug
		output: vono.LogOutput.console
		enable_colors: true
	}
	
	mut logger := vono.new_logger(config)
	
	//Test basic logging method
	logger.debug('这是一条调试消息')
	logger.info('这是一条信息消息')
	logger.warn('这是一条警告消息')
	logger.error('这是一条错误消息')
	
	//Test the log with module
	logger.info_with_module('模块信息消息', 'TEST')
	
	//Test logs with fields
	fields := {
		'user_id': '12345'
		'action': 'login'
		'ip': '192.168.1.1'
	}
	logger.info_with_fields('用户登录', fields)
	
	//Test the log with request ID
	logger.info_with_request('处理请求', 'req-123456')
	
	println('✅ 控制台日志输出测试通过')
}

fn test_file_logging() {
	println('=== 测试文件日志输出 ===')
	
	log_file := './test_log.log'
	
	// Clean up any test files that may exist
	if os.exists(log_file) {
		os.rm(log_file) or {}
	}
	
	config := vono.LoggerConfig{
		level: vono.LogLevel.info
		output: vono.LogOutput.file
		file_path: log_file
		enable_colors: false  //File output does not require color
	}
	
	mut logger := vono.new_logger(config)
	
	//Write some logs
	logger.info('测试文件日志 1')
	logger.warn('测试文件日志 2')
	logger.error('测试文件日志 3')
	
	// Wait to make sure the file is written to completion
	time.sleep(100 * time.millisecond)
	
	// Verify that the file exists and has content
	assert os.exists(log_file)
	
	content := os.read_file(log_file) or {
		panic('无法读取日志文件: ${err}')
	}
	
	assert content.contains('测试文件日志 1')
	assert content.contains('测试文件日志 2')
	assert content.contains('测试文件日志 3')
	assert content.contains('INFO')
	assert content.contains('WARN')
	assert content.contains('ERROR')
	
	// Clean test files
	os.rm(log_file) or {}
	
	println('✅ 文件日志输出测试通过')
}

fn test_json_logging() {
	println('=== 测试JSON格式日志 ===')
	
	log_file := './test_json_log.log'
	
	// Clean up any test files that may exist
	if os.exists(log_file) {
		os.rm(log_file) or {}
	}
	
	config := vono.LoggerConfig{
		level: vono.LogLevel.info
		output: vono.LogOutput.file
		file_path: log_file
		enable_json: true
	}
	
	mut logger := vono.new_logger(config)
	
	//Write log in JSON format
	fields := {
		'user_id': '12345'
		'action': 'test'
	}
	logger.info_with_fields('JSON日志测试', fields)
	
	// Wait for file to be written
	time.sleep(100 * time.millisecond)
	
	//Verify JSON format
	assert os.exists(log_file)
	content := os.read_file(log_file) or {
		panic('无法读取JSON日志文件: ${err}')
	}
	
	assert content.contains('"level":"INFO"')
	assert content.contains('"message":"JSON日志测试"')
	assert content.contains('"user_id":"12345"')
	
	// Clean test files
	os.rm(log_file) or {}
	
	println('✅ JSON格式日志测试通过')
}

fn test_global_logger() {
	println('=== 测试全局日志器 ===')
	
	config := vono.LoggerConfig{
		level: vono.LogLevel.info
		output: vono.LogOutput.console
		enable_colors: true
	}
	
	//Create a logger instance
	mut logger := vono.new_logger(config)
	
	//Use logger method
	logger.info('日志器信息消息')
	logger.warn('日志器警告消息')
	logger.error('日志器错误消息')
	
	println('✅ 全局日志器测试通过')
}

fn test_request_logging() {
	println('=== 测试HTTP请求日志 ===')
	
	config := vono.LoggerConfig{
		level: vono.LogLevel.info
		output: vono.LogOutput.console
		enable_colors: true
	}
	
	mut logger := vono.new_logger(config)
	
	req_log := vono.RequestLog{
		method: 'GET'
		path: '/api/users'
		status_code: 200
		response_time: 45.67
		user_agent: 'Mozilla/5.0'
		remote_addr: '192.168.1.100'
		request_size: 1024
		response_size: 2048
		request_id: 'req-789'
	}
	
	vono.log_request(mut logger, req_log)
	
	println('✅ HTTP请求日志测试通过')
}

fn test_performance_logging() {
	println('=== 测试性能监控日志 ===')
	
	config := vono.LoggerConfig{
		level: vono.LogLevel.info
		output: vono.LogOutput.console
		enable_colors: true
	}
	
	mut logger := vono.new_logger(config)
	
	details := {
		'cache_hit': 'true'
		'db_queries': '3'
		'memory_usage': '45MB'
	}
	
	vono.log_performance(mut logger, '数据库查询', 123.45, details)
	
	println('✅ 性能监控日志测试通过')
}

fn test_error_logging() {
	println('=== 测试错误日志 ===')
	
	config := vono.LoggerConfig{
		level: vono.LogLevel.error
		output: vono.LogOutput.console
		enable_colors: true
	}
	
	mut logger := vono.new_logger(config)
	
	vono.log_error_with_stack(mut logger, '数据库连接失败', '连接超时: 5秒', 'DATABASE')
	
	println('✅ 错误日志测试通过')
}

fn main() {
	println('开始日志系统测试...\n')
	
	test_logger_creation()
	println('')
	
	test_log_levels()
	println('')
	
	test_console_logging()
	println('')
	
	test_file_logging()
	println('')
	
	test_json_logging()
	println('')
	
	test_global_logger()
	println('')
	
	test_request_logging()
	println('')
	
	test_performance_logging()
	println('')
	
	test_error_logging()
	println('')
	
	println('🎉 所有日志系统测试通过！')
}