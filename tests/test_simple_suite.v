import meiseayoung.vono
import os

// Simplified test statistics
struct TestStats {
mut:
	total_tests int
	passed_tests int
	failed_tests int
}

fn (mut stats TestStats) run_test(test_name string, test_func fn() bool) {
	stats.total_tests++
	print('🧪 ${test_name}... ')
	
	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats TestStats) print_summary() {
	println('\n=== 测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')
	
	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

// 1. Test configuration management
fn test_config_management() bool {
	//Test default configuration
	config := vono.default_config()
	
	if config.server.host != '127.0.0.1' {
		return false
	}
	
	if config.server.port != 8080 {
		return false
	}
	
	//Test configuration verification
	vono.validate_config(config) or {
		return false
	}
	
	return true
}

// 2. Test log system
fn test_logging_system() bool {
	//Create test logger
	config := vono.LoggerConfig{
		level: vono.LogLevel.debug
		output: vono.LogOutput.console
		enable_colors: false
	}
	
	mut logger := vono.new_logger(config)
	
	//Test basic logging method
	logger.info('测试信息日志')
	logger.warn('测试警告日志')
	logger.error('测试错误日志')
	
	//Test log level conversion
	if vono.parse_log_level('info') != vono.LogLevel.info {
		return false
	}
	
	if vono.log_level_to_string(vono.LogLevel.error) != 'ERROR' {
		return false
	}
	
	return true
}

// 3. Test security verification
fn test_security_validation() bool {
	// Test dangerous paths
	dangerous_paths := [
		'../../../etc/passwd',
		'..\\..\\windows\\system32',
		'/etc/passwd',
		'C:\\Windows\\System32'
	]
	
	options := vono.PathValidationOptions{}
	
	for path in dangerous_paths {
		vono.validate_file_path(path, options) or {
			// Validation failure is the expected result
			continue
		}
		// If no error is returned, it means that the dangerous path has passed the verification, which is incorrect.
		return false
	}
	
	//Test safe path
	safe_path := 'documents/file.txt'
	vono.validate_file_path(safe_path, options) or {
		return false  // The safe path should pass verification
	}
	
	return true
}

// 4. Test error handling structure
fn test_error_handling() bool {
	//Test error type
	error_types := [
		vono.ErrorType.bad_request,
		vono.ErrorType.unauthorized,
		vono.ErrorType.forbidden,
		vono.ErrorType.not_found,
		vono.ErrorType.internal_server_error
	]
	
	//Verify error code
	expected_codes := [400, 401, 403, 404, 500]
	
	for i, error_type in error_types {
		if int(error_type) != expected_codes[i] {
			return false
		}
	}
	
	return true
}

// 5. Test configuration file operation
fn test_config_file_operations() bool {
	config_path := './test_config.json'
	
	// Clean up any test files that may exist
	if os.exists(config_path) {
		os.rm(config_path) or { return false }
	}
	
	//Create and save configuration
	config := vono.default_config()
	vono.save_config(config, config_path) or {
		return false
	}
	
	//Load configuration
	loaded_config := vono.load_config(config_path) or {
		return false
	}
	
	//Verify configuration content
	success := loaded_config.server.host == config.server.host &&
			   loaded_config.server.port == config.server.port
	
	// Clean test files
	os.rm(config_path) or {}
	
	return success
}

// 6. Test environment variable configuration
fn test_env_config() bool {
	//Set environment variables
	os.setenv('HONO_HOST', '0.0.0.0', true)
	os.setenv('HONO_PORT', '9090', true)
	os.setenv('HONO_ENV', 'production', true)
	
	config := vono.load_config_from_env()
	
	//Verify environment variable configuration
	success := config.server.host == '0.0.0.0' &&
			   config.server.port == 9090 &&
			   config.env == 'production'
	
	// Clean up environment variables
	os.unsetenv('HONO_HOST')
	os.unsetenv('HONO_PORT')
	os.unsetenv('HONO_ENV')
	
	return success
}

// 7. Test configuration summary
fn test_config_summary() bool {
	config := vono.default_config()
	summary := vono.get_config_summary(config)
	
	// Verification summary contains key information
	return summary.contains('应用配置摘要') &&
		   summary.contains('127.0.0.1:8080') &&
		   summary.contains('development') &&
		   summary.contains('静态文件') &&
		   summary.contains('文件上传')
}

// 8. Test configuration merge
fn test_config_merge() bool {
	base_config := vono.default_config()
	mut override_config := vono.AppConfig{}
	override_config.server.host = '0.0.0.0'
	override_config.server.port = 9000
	override_config.env = 'production'
	
	merged_config := vono.merge_config(base_config, override_config)
	
	//Verify merge results
	return merged_config.server.host == '0.0.0.0' &&
		   merged_config.server.port == 9000 &&
		   merged_config.env == 'production' &&
		   merged_config.static.enabled == true  // Other values ​​should remain default
}

// 9. Test the upload configuration structure
fn test_upload_config_struct() bool {
	config := vono.ChunkUploadConfig{
		chunk_size: 1024 * 1024
		max_file_size: 100 * 1024 * 1024
		temp_dir: './test_uploads/chunks'
		upload_dir: './test_uploads/files'
	}
	
	//Verify configuration structure
	return config.chunk_size == 1024 * 1024 &&
		   config.max_file_size == 100 * 1024 * 1024 &&
		   config.temp_dir == './test_uploads/chunks' &&
		   config.upload_dir == './test_uploads/files'
}

// 10. Test cache configuration
fn test_cache_config() bool {
	//Test cache configuration structure
	cache_config := vono.CacheConfig{
		enabled: true
		max_size: 1000
		default_ttl: 300
		cleanup_interval: 60
	}
	
	return cache_config.enabled == true &&
		   cache_config.max_size == 1000 &&
		   cache_config.default_ttl == 300 &&
		   cache_config.cleanup_interval == 60
}

fn main() {
	println('🚀 开始vono简化测试套件...\n')
	
	mut stats := TestStats{}
	
	//Run all tests
	stats.run_test('配置管理', test_config_management)
	stats.run_test('日志系统', test_logging_system)
	stats.run_test('安全验证', test_security_validation)
	stats.run_test('错误处理', test_error_handling)
	stats.run_test('配置文件操作', test_config_file_operations)
	stats.run_test('环境变量配置', test_env_config)
	stats.run_test('配置摘要', test_config_summary)
	stats.run_test('配置合并', test_config_merge)
	stats.run_test('上传配置结构', test_upload_config_struct)
	stats.run_test('缓存配置', test_cache_config)
	
	//Print test summary
	stats.print_summary()
}