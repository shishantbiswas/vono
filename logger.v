module hono

import os
import time
import x.json2

// Log level enumeration
pub enum LogLevel {
	debug = 0
	info  = 1
	warn  = 2
	error = 3
}

// Log level string mapping
const log_level_strings = {
	LogLevel.debug: 'DEBUG'
	LogLevel.info:  'INFO'
	LogLevel.warn:  'WARN'
	LogLevel.error: 'ERROR'
}

//Log output type
pub enum LogOutput {
	console
	file
	both
}

// Log entry structure
pub struct LogEntry {
pub mut:
	timestamp string
	level     string
	message   string
	module    string
	function  string
	file      string
	line      int
	fields    map[string]string
	request_id string
}

//Log configuration
pub struct LoggerConfig {
pub mut:
	level            LogLevel = LogLevel.info
	output           LogOutput = LogOutput.console
	file_path        string = './logs/app.log'
	max_file_size    u64 = 10 * 1024 * 1024  // 10MB
	max_backup_files int = 5
	enable_colors    bool = true
	enable_json      bool
	time_format      string = '2006-01-02 15:04:05'
}

// Logger structure
pub struct Logger {
pub mut:
	config LoggerConfig
	current_file_size u64
}

//Create a new logger instance
pub fn new_logger(config LoggerConfig) &Logger {
	return &Logger{
		config: config
	}
}

//Convert string to log level
pub fn parse_log_level(level_str string) LogLevel {
	match level_str.to_lower() {
		'debug' { return LogLevel.debug }
		'info' { return LogLevel.info }
		'warn' { return LogLevel.warn }
		'error' { return LogLevel.error }
		else { return LogLevel.info }
	}
}

// Convert log level to string
pub fn log_level_to_string(level LogLevel) string {
	return log_level_strings[level] or { 'INFO' }
}

// Check if the log level should be output
fn (l &Logger) should_log(level LogLevel) bool {
	return int(level) >= int(l.config.level)
}

//Format timestamp
fn format_timestamp() string {
	now := time.now()
	return now.format_ss()
}

// Get ANSI color code
fn get_color_code(level LogLevel) string {
	match level {
		.debug { return '\033[36m' }  // cyan
		.info { return '\033[32m' }   // green
		.warn { return '\033[33m' }   // yellow
		.error { return '\033[31m' }  // red
	}
}

//Reset ANSI colors
const color_reset = '\033[0m'

//Format log message (text format)
fn (l &Logger) format_text_log(entry LogEntry) string {
	mut parts := []string{}
	
	// timestamp
	parts << '[${entry.timestamp}]'
	
	//Log level (with color)
	if l.config.enable_colors {
		color := get_color_code(parse_log_level(entry.level))
		parts << '${color}${entry.level}${color_reset}'
	} else {
		parts << entry.level
	}
	
	//Module information
	if entry.module != '' {
		parts << '[${entry.module}]'
	}
	
	// information
	parts << entry.message
	
	// additional fields
	if entry.fields.len > 0 {
		mut field_parts := []string{}
		for key, value in entry.fields {
			field_parts << '${key}=${value}'
		}
		parts << '{${field_parts.join(', ')}}'
	}
	
	// Request ID
	if entry.request_id != '' {
		parts << '[req:${entry.request_id}]'
	}
	
	return parts.join(' ')
}

//Format log message (JSON format)
fn (l &Logger) format_json_log(entry LogEntry) string {
	return json2.encode[LogEntry](entry)
}

//Write log to file
fn (mut l Logger) write_to_file(content string) {
	// Make sure the log directory exists
	log_dir := os.dir(l.config.file_path)
	if !os.exists(log_dir) {
		os.mkdir_all(log_dir) or {
			eprintln('无法创建日志目录: ${err}')
			return
		}
	}
	
	// Check file size, rotate if necessary
	if l.config.max_file_size > 0 {
		if os.exists(l.config.file_path) {
			file_size := os.file_size(l.config.file_path)
			if file_size >= l.config.max_file_size {
				l.rotate_log_file()
			}
		}
	}
	
	//Write to log
	mut file := os.open_append(l.config.file_path) or {
		eprintln('无法打开日志文件: ${err}')
		return
	}
	defer {
		file.close()
	}
	
	file.writeln(content) or {
		eprintln('无法写入日志文件: ${err}')
	}
}

//Rotate log files
fn (l &Logger) rotate_log_file() {
	// Delete the oldest backup file
	oldest_backup := '${l.config.file_path}.${l.config.max_backup_files}'
	if os.exists(oldest_backup) {
		os.rm(oldest_backup) or {}
	}
	
	//Move existing backup files
	for i := l.config.max_backup_files - 1; i >= 1; i-- {
		old_file := '${l.config.file_path}.${i}'
		new_file := '${l.config.file_path}.${i + 1}'
		if os.exists(old_file) {
			os.mv(old_file, new_file) or {}
		}
	}
	
	//Move the current log file to the first backup
	if os.exists(l.config.file_path) {
		backup_file := '${l.config.file_path}.1'
		os.mv(l.config.file_path, backup_file) or {}
	}
}

// Core logging method
fn (mut l Logger) log(level LogLevel, message string, mod_name string, fields map[string]string, request_id string) {
	if !l.should_log(level) {
		return
	}
	
	entry := LogEntry{
		timestamp: format_timestamp()
		level: log_level_to_string(level)
		message: message
		module: mod_name
		fields: fields
		request_id: request_id
	}
	
	//Format log content
	content := if l.config.enable_json {
		l.format_json_log(entry)
	} else {
		l.format_text_log(entry)
	}
	
	//output log
	match l.config.output {
		.console {
			println(content)
		}
		.file {
			l.write_to_file(content)
		}
		.both {
			println(content)
			l.write_to_file(content)
		}
	}
}

//Public log method
pub fn (mut l Logger) debug(message string) {
	l.log(LogLevel.debug, message, '', {}, '')
}

pub fn (mut l Logger) info(message string) {
	l.log(LogLevel.info, message, '', {}, '')
}

pub fn (mut l Logger) warn(message string) {
	l.log(LogLevel.warn, message, '', {}, '')
}

pub fn (mut l Logger) error(message string) {
	l.log(LogLevel.error, message, '', {}, '')
}

// Log method with module
pub fn (mut l Logger) debug_with_module(message string, mod_name string) {
	l.log(LogLevel.debug, message, mod_name, {}, '')
}

pub fn (mut l Logger) info_with_module(message string, mod_name string) {
	l.log(LogLevel.info, message, mod_name, {}, '')
}

pub fn (mut l Logger) warn_with_module(message string, mod_name string) {
	l.log(LogLevel.warn, message, mod_name, {}, '')
}

pub fn (mut l Logger) error_with_module(message string, mod_name string) {
	l.log(LogLevel.error, message, mod_name, {}, '')
}

// Log method with fields
pub fn (mut l Logger) debug_with_fields(message string, fields map[string]string) {
	l.log(LogLevel.debug, message, '', fields, '')
}

pub fn (mut l Logger) info_with_fields(message string, fields map[string]string) {
	l.log(LogLevel.info, message, '', fields, '')
}

pub fn (mut l Logger) warn_with_fields(message string, fields map[string]string) {
	l.log(LogLevel.warn, message, '', fields, '')
}

pub fn (mut l Logger) error_with_fields(message string, fields map[string]string) {
	l.log(LogLevel.error, message, '', fields, '')
}

// Log method with request ID
pub fn (mut l Logger) debug_with_request(message string, request_id string) {
	l.log(LogLevel.debug, message, '', {}, request_id)
}

pub fn (mut l Logger) info_with_request(message string, request_id string) {
	l.log(LogLevel.info, message, '', {}, request_id)
}

pub fn (mut l Logger) warn_with_request(message string, request_id string) {
	l.log(LogLevel.warn, message, '', {}, request_id)
}

pub fn (mut l Logger) error_with_request(message string, request_id string) {
	l.log(LogLevel.error, message, '', {}, request_id)
}

// Complete logging method
pub fn (mut l Logger) log_full(level LogLevel, message string, mod_name string, fields map[string]string, request_id string) {
	l.log(level, message, mod_name, fields, request_id)
}

//HTTP request log structure
pub struct RequestLog {
pub mut:
	method        string
	path          string
	status_code   int
	response_time f64  // milliseconds
	user_agent    string
	remote_addr   string
	request_size  u64
	response_size u64
	request_id    string
}

// Record HTTP request log
pub fn log_request(mut logger Logger, req_log RequestLog) {
	fields := {
		'method': req_log.method
		'path': req_log.path
		'status': req_log.status_code.str()
		'response_time': '${req_log.response_time:.2f}ms'
		'user_agent': req_log.user_agent
		'remote_addr': req_log.remote_addr
		'request_size': req_log.request_size.str()
		'response_size': req_log.response_size.str()
	}
	
	message := '${req_log.method} ${req_log.path} ${req_log.status_code} ${req_log.response_time:.2f}ms'
	logger.log_full(LogLevel.info, message, 'HTTP', fields, req_log.request_id)
}

//Performance monitoring log
pub fn log_performance(mut logger Logger, operation string, duration f64, details map[string]string) {
	mut fields := {
		'operation': operation
		'duration': '${duration:.2f}ms'
	}
	
	//Merge details
	for key, value in details {
		fields[key] = value
	}
	
	message := '性能监控: ${operation} 耗时 ${duration:.2f}ms'
	logger.log_full(LogLevel.info, message, 'PERF', fields, '')
}

// Error log (with stack information)
pub fn log_error_with_stack(mut logger Logger, message string, err_details string, mod_name string) {
	fields := {
		'error_details': err_details
		'stack_trace': 'V语言暂不支持堆栈跟踪'
	}
	
	logger.log_full(LogLevel.error, message, mod_name, fields, '')
}