//Test server - for high concurrency testing
module main

import meiseayoung.vono
import net.http

fn main() {
	mut app := vono.Vono.new()
	
	// Simple test routing
	app.get('/', fn (mut c vono.Context) http.Response {
		return c.text('OK')
	})
	
	app.get('/delay', fn (mut c vono.Context) http.Response {
		// Simulate some processing delays
		return c.text('OK with delay')
	})
	
	println('测试服务器启动中...')
	println('配置: timeout_secs=120, keepalive_timeout=30, max_keepalive_req=10000')
	
	app.listen(':8888')
}
