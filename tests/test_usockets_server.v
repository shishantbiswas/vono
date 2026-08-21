// uSockets test server
module main

import net.http
import meiseayoung.hono

fn main() {
	mut app := hono.Hono.new()
	
	//Basic routing
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.text('Hello from uSockets!')
	})
	
	app.get('/health', fn (mut c hono.Context) http.Response {
		return c.text('OK')
	})
	
	// JSON response
	app.get('/api/json', fn (mut c hono.Context) http.Response {
		return c.json('{"message": "Hello JSON"}')
	})
	
	// dynamic routing
	app.get('/api/users/:id', fn (mut c hono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"id": "${id}"}')
	})
	
	app.get('/api/users/:user_id/posts/:post_id', fn (mut c hono.Context) http.Response {
		user_id := c.params['user_id'] or { '' }
		post_id := c.params['post_id'] or { '' }
		return c.json('{"user_id": "${user_id}", "post_id": "${post_id}"}')
	})
	
	// Query parameters
	app.get('/api/search', fn (mut c hono.Context) http.Response {
		q := c.query['q'] or { '' }
		return c.json('{"query": "${q}"}')
	})
	
	// 404 processing
	app.not_found(fn (mut c hono.Context) http.Response {
		c.status(404)
		return c.json('{"error": "Not Found"}')
	})
	
	println('[usockets-test-server] Starting on port 9998...')
	app.listen_usockets(9998)
}
