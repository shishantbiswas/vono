module hono

import os
import x.json2

// Server configuration structure
pub struct ServerConfig {
pub mut:
	host              string = '127.0.0.1'
	port              int    = 8080
	read_timeout      int    = 30  // Second
	write_timeout     int    = 30  // Second
	max_request_size  u64    = 10 * 1024 * 1024  // 10MB
	enable_cors       bool   = true
	enable_gzip       bool   = true
}

// Static file configuration
pub struct StaticConfig {
pub mut:
	enabled           bool   = true
	root_dir          string = './static'
	index_files       []string = ['index.html', 'index.htm']
	cache_max_age     int    = 3600  // Second
	enable_directory_listing bool
	allowed_extensions []string = ['.html', '.css', '.js', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.txt', '.pdf']
}

//Upload configuration
pub struct UploadConfig {
pub mut:
	enabled           bool   = true
	upload_dir        string = './uploads'
	max_file_size     u64    = 100 * 1024 * 1024  // 100MB
	max_chunk_size    u64    = 5 * 1024 * 1024    // 5MB
	merge_buffer_size int    = 8192  // 8KB
	allowed_types     []string = ['.txt', '.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png', '.gif']
	cleanup_timeout   int    = 3600  //Seconds, timeout for cleaning up unfinished uploads
}

// cache configuration
pub struct CacheConfig {
pub mut:
	enabled           bool = true
	max_size          int  = 1000
	default_ttl       int  = 300   // Second
	cleanup_interval  int  = 60    // Second
}

//security configuration
pub struct SecurityConfig {
pub mut:
	enable_path_validation    bool = true
	enable_file_type_check    bool = true
	enable_size_limits        bool = true
	max_path_length          int  = 255
	blocked_extensions       []string = ['.exe', '.bat', '.cmd', '.sh', '.php', '.asp', '.jsp']
	enable_xss_protection    bool = true
	enable_csrf_protection   bool
}

//Log configuration
pub struct LogConfig {
pub mut:
	enabled           bool   = true
	level             string = 'info'  // debug, info, warn, error
	output            string = 'console'  // console, file, both
	file_path         string = './logs/app.log'
	max_file_size     u64    = 10 * 1024 * 1024  // 10MB
	max_backup_files  int    = 5
	enable_request_log bool  = true
}

// Application configuration main structure
pub struct AppConfig {
pub mut:
	server   ServerConfig
	static   StaticConfig
	upload   UploadConfig
	cache    CacheConfig
	security SecurityConfig
	log      LogConfig
	debug    bool
	env      string = 'development'  // development, production, test
}

//Default configuration
pub fn default_config() AppConfig {
	return AppConfig{
		server: ServerConfig{}
		static: StaticConfig{}
		upload: UploadConfig{}
		cache: CacheConfig{}
		security: SecurityConfig{}
		log: LogConfig{}
	}
}

//Load configuration from file
pub fn load_config(config_path string) !AppConfig {
	if !os.exists(config_path) {
		println('配置文件不存在: ${config_path}，使用默认配置')
		return default_config()
	}
	
	config_content := os.read_file(config_path) or {
		return error('无法读取配置文件: ${err}')
	}
	
	config := json2.decode[AppConfig](config_content) or {
		return error('配置文件格式错误: ${err}')
	}
	
	//Verify configuration
	validate_config(config) or {
		return error('配置验证失败: ${err}')
	}
	
	println('成功加载配置文件: ${config_path}')
	return config
}

//Save configuration to file
pub fn save_config(config AppConfig, config_path string) ! {
	config_json := json2.encode[AppConfig](config, prettify: true)
	
	// Make sure the directory exists
	config_dir := os.dir(config_path)
	if !os.exists(config_dir) {
		os.mkdir_all(config_dir) or {
			return error('无法创建配置目录: ${err}')
		}
	}
	
	os.write_file(config_path, config_json) or {
		return error('无法保存配置文件: ${err}')
	}
	
	println('配置已保存到: ${config_path}')
}

//Load configuration from environment variables
pub fn load_config_from_env() AppConfig {
	mut config := default_config()
	
	// Server configuration
	host := os.getenv('HONO_HOST')
	if host != '' {
		config.server.host = host
	}
	
	port_str := os.getenv('HONO_PORT')
	if port_str != '' {
		config.server.port = port_str.int()
	}
	
	env := os.getenv('HONO_ENV')
	if env != '' {
		config.env = env
	}
	
	debug_str := os.getenv('HONO_DEBUG')
	if debug_str != '' {
		config.debug = debug_str.to_lower() in ['true', '1', 'yes']
	}
	
	//Upload configuration
	upload_dir := os.getenv('HONO_UPLOAD_DIR')
	if upload_dir != '' {
		config.upload.upload_dir = upload_dir
	}
	
	static_dir := os.getenv('HONO_STATIC_DIR')
	if static_dir != '' {
		config.static.root_dir = static_dir
	}
	
	//Log configuration
	log_level := os.getenv('HONO_LOG_LEVEL')
	if log_level != '' {
		config.log.level = log_level
	}
	
	log_file := os.getenv('HONO_LOG_FILE')
	if log_file != '' {
		config.log.file_path = log_file
	}
	
	return config
}

//Verify configuration
pub fn validate_config(config AppConfig) ! {
	// Verify port range
	if config.server.port < 1 || config.server.port > 65535 {
		return error('端口号必须在 1-65535 范围内')
	}
	
	// Verification timeout settings
	if config.server.read_timeout < 1 || config.server.write_timeout < 1 {
		return error('超时时间必须大于0')
	}
	
	// Verify file size limit
	if config.server.max_request_size < 1024 {
		return error('最大请求大小不能小于1KB')
	}
	
	if config.upload.max_file_size < 1024 {
		return error('最大文件大小不能小于1KB')
	}
	
	if config.upload.max_chunk_size < 1024 {
		return error('最大分片大小不能小于1KB')
	}
	
	//Verify cache configuration
	if config.cache.max_size < 1 {
		return error('缓存最大大小必须大于0')
	}
	
	// Verify log level
	if config.log.level !in ['debug', 'info', 'warn', 'error'] {
		return error('日志级别必须是: debug, info, warn, error 之一')
	}
	
	// Verify environment
	if config.env !in ['development', 'production', 'test'] {
		return error('环境必须是: development, production, test 之一')
	}
	
	//Verify directory path
	if config.static.enabled && config.static.root_dir == '' {
		return error('静态文件目录不能为空')
	}
	
	if config.upload.enabled && config.upload.upload_dir == '' {
		return error('上传目录不能为空')
	}
}

//Create a sample configuration file
pub fn create_example_config(config_path string) ! {
	config := default_config()
	save_config(config, config_path) or {
		return error('无法创建示例配置文件: ${err}')
	}
	println('示例配置文件已创建: ${config_path}')
}

// Get configuration summary information
pub fn get_config_summary(config AppConfig) string {
	mut summary := []string{}
	
	summary << '=== 应用配置摘要 ==='
	summary << '环境: ${config.env}'
	summary << '调试模式: ${config.debug}'
	summary << ''
	summary << '服务器:'
	summary << '  地址: ${config.server.host}:${config.server.port}'
	summary << '  最大请求大小: ${config.server.max_request_size / 1024 / 1024}MB'
	summary << '  CORS: ${config.server.enable_cors}'
	summary << '  GZIP: ${config.server.enable_gzip}'
	summary << ''
	summary << '静态文件:'
	summary << '  启用: ${config.static.enabled}'
	summary << '  目录: ${config.static.root_dir}'
	summary << '  缓存时间: ${config.static.cache_max_age}秒'
	summary << ''
	summary << '文件上传:'
	summary << '  启用: ${config.upload.enabled}'
	summary << '  目录: ${config.upload.upload_dir}'
	summary << '  最大文件大小: ${config.upload.max_file_size / 1024 / 1024}MB'
	summary << '  最大分片大小: ${config.upload.max_chunk_size / 1024 / 1024}MB'
	summary << ''
	summary << '缓存:'
	summary << '  启用: ${config.cache.enabled}'
	summary << '  最大条目: ${config.cache.max_size}'
	summary << '  默认TTL: ${config.cache.default_ttl}秒'
	summary << ''
	summary << '安全:'
	summary << '  路径验证: ${config.security.enable_path_validation}'
	summary << '  文件类型检查: ${config.security.enable_file_type_check}'
	summary << '  XSS保护: ${config.security.enable_xss_protection}'
	summary << ''
	summary << '日志:'
	summary << '  启用: ${config.log.enabled}'
	summary << '  级别: ${config.log.level}'
	summary << '  输出: ${config.log.output}'
	summary << '  请求日志: ${config.log.enable_request_log}'
	
	return summary.join('\n')
}

// Merge configuration (for configuration override)
pub fn merge_config(base AppConfig, override AppConfig) AppConfig {
	mut merged := base
	
	// More complex merge logic can be implemented here
	// Currently simply use override to cover the non-zero value of base
	if override.server.host != '' {
		merged.server.host = override.server.host
	}
	if override.server.port != 0 {
		merged.server.port = override.server.port
	}
	if override.env != '' {
		merged.env = override.env
	}
	
	return merged
}