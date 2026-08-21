import meiseayoung.hono
import os

fn test_default_config() {
	println('=== 测试默认配置 ===')
	
	config := hono.default_config()
	
	//Verify default value
	assert config.server.host == '127.0.0.1'
	assert config.server.port == 8080
	assert config.static.enabled == true
	assert config.upload.enabled == true
	assert config.cache.enabled == true
	assert config.log.enabled == true
	assert config.env == 'development'
	
	println('✅ 默认配置测试通过')
}

fn test_config_validation() {
	println('=== 测试配置验证 ===')
	
	mut config := hono.default_config()
	
	//Test valid configuration
	hono.validate_config(config) or {
		panic('有效配置验证失败: ${err}')
	}
	println('✅ 有效配置验证通过')
	
	//Test invalid port
	config.server.port = 0
	hono.validate_config(config) or {
		println('✅ 无效端口验证通过: ${err}')
		config.server.port = 8080  // recover
	}
	
	//Test invalid log level
	config.log.level = 'invalid'
	hono.validate_config(config) or {
		println('✅ 无效日志级别验证通过: ${err}')
		config.log.level = 'info'  // recover
	}
	
	//Test invalid environment
	config.env = 'invalid'
	hono.validate_config(config) or {
		println('✅ 无效环境验证通过: ${err}')
		config.env = 'development'  // recover
	}
}

fn test_config_file_operations() {
	println('=== 测试配置文件操作 ===')
	
	config_path := './test_config.json'
	
	// Clean up any test files that may exist
	if os.exists(config_path) {
		os.rm(config_path) or {}
	}
	
	//Create default configuration
	config := hono.default_config()
	
	//Save configuration
	hono.save_config(config, config_path) or {
		panic('保存配置失败: ${err}')
	}
	println('✅ 配置保存成功')
	
	//Load configuration
	loaded_config := hono.load_config(config_path) or {
		panic('加载配置失败: ${err}')
	}
	println('✅ 配置加载成功')
	
	//Verify configuration content
	assert loaded_config.server.host == config.server.host
	assert loaded_config.server.port == config.server.port
	assert loaded_config.env == config.env
	println('✅ 配置内容验证通过')
	
	// Clean test files
	os.rm(config_path) or {}
}

fn test_env_config_loading() {
	println('=== 测试环境变量配置 ===')
	
	//Set environment variables
	os.setenv('HONO_HOST', '0.0.0.0', true)
	os.setenv('HONO_PORT', '9090', true)
	os.setenv('HONO_ENV', 'production', true)
	os.setenv('HONO_DEBUG', 'true', true)
	
	config := hono.load_config_from_env()
	
	//Verify environment variable configuration
	assert config.server.host == '0.0.0.0'
	assert config.server.port == 9090
	assert config.env == 'production'
	assert config.debug == true
	
	println('✅ 环境变量配置测试通过')
	
	// Clean up environment variables
	os.unsetenv('HONO_HOST')
	os.unsetenv('HONO_PORT')
	os.unsetenv('HONO_ENV')
	os.unsetenv('HONO_DEBUG')
}

fn test_config_summary() {
	println('=== 测试配置摘要 ===')
	
	config := hono.default_config()
	summary := hono.get_config_summary(config)
	
	// Verification summary contains key information
	assert summary.contains('应用配置摘要')
	assert summary.contains('127.0.0.1:8080')
	assert summary.contains('development')
	assert summary.contains('静态文件')
	assert summary.contains('文件上传')
	
	println('配置摘要:')
	println(summary)
	println('✅ 配置摘要测试通过')
}

fn test_config_merge() {
	println('=== 测试配置合并 ===')
	
	base_config := hono.default_config()
	mut override_config := hono.AppConfig{}
	override_config.server.host = '0.0.0.0'
	override_config.server.port = 9000
	override_config.env = 'production'
	
	merged_config := hono.merge_config(base_config, override_config)
	
	//Verify merge results
	assert merged_config.server.host == '0.0.0.0'
	assert merged_config.server.port == 9000
	assert merged_config.env == 'production'
	// Other values ​​should remain default
	assert merged_config.static.enabled == true
	assert merged_config.upload.enabled == true
	
	println('✅ 配置合并测试通过')
}

fn main() {
	println('开始配置管理系统测试...\n')
	
	test_default_config()
	println('')
	
	test_config_validation()
	println('')
	
	test_config_file_operations()
	println('')
	
	test_env_config_loading()
	println('')
	
	test_config_summary()
	println('')
	
	test_config_merge()
	println('')
	
	println('🎉 所有配置管理测试通过！')
}