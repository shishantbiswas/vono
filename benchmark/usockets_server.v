// uSockets test server
// Used for integration testing to verify uSockets backend functionality
//
//Compile and run:
//   v -enable-globals -cc gcc -ldflags "-ldbghelp" benchmark/usockets_test_server.v -o usockets_test.exe
//   .\usockets_test.exe

module main

import meiseayoung.vono
import net.http

fn main() {
	mut app := vono.Vono.new()

	// Global middleware - add custom response headers
	app.use(fn (mut c vono.Context, next fn (mut vono.Context) http.Response) http.Response {
		mut resp := next(mut c)
		c.headers['X-Middleware'] = 'applied'
		return resp
	})

	// ==================== Basic routing ====================

	app.get('/', fn (mut c vono.Context) http.Response {
		return c.text('Hello World')
	})

	app.get('/health', fn (mut c vono.Context) http.Response {
		return c.text('OK')
	})

	app.get('/api/health', fn (mut c vono.Context) http.Response {
		return c.text('OK')
	})

	// ==================== CRUD routing ====================

	app.get('/api/users', fn (mut c vono.Context) http.Response {
		return c.json('{"users": []}')
	})

	app.post('/api/users', fn (mut c vono.Context) http.Response {
		c.status(201)
		return c.json('{"created": true}')
	})

	app.get('/api/users/:id', fn (mut c vono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"id": "${id}"}')
	})

	app.put('/api/users/:id', fn (mut c vono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"id": "${id}", "updated": true}')
	})

	app.delete('/api/users/:id', fn (mut c vono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"id": "${id}", "deleted": true}')
	})

	app.patch('/api/users/:id', fn (mut c vono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"id": "${id}", "patched": true}')
	})

	// ==================== Multi-parameter routing ====================

	app.get('/api/users/:user_id/posts/:post_id', fn (mut c vono.Context) http.Response {
		user_id := c.params['user_id'] or { '' }
		post_id := c.params['post_id'] or { '' }
		return c.json('{"user_id": "${user_id}", "post_id": "${post_id}"}')
	})

	app.get('/api/categories/:category/items/:item', fn (mut c vono.Context) http.Response {
		category := c.params['category'] or { '' }
		item := c.params['item'] or { '' }
		return c.json('{"category": "${category}", "item": "${item}"}')
	})

	// ==================== Query parameter routing ====================

	app.get('/api/search', fn (mut c vono.Context) http.Response {
		q := c.query['q'] or { '' }
		limit := c.query['limit'] or { '10' }
		page := c.query['page'] or { '1' }
		return c.json('{"query": "${q}", "limit": ${limit}, "page": ${page}}')
	})

	// ==================== Response format routing ====================

	app.get('/api/json', fn (mut c vono.Context) http.Response {
		return c.json('{"message": "JSON response"}')
	})

	app.get('/api/html', fn (mut c vono.Context) http.Response {
		return c.html('<html><body><h1>HTML Response</h1></body></html>')
	})

	app.get('/api/created', fn (mut c vono.Context) http.Response {
		c.status(201)
		return c.json('{"created": true}')
	})

	app.get('/api/custom-header', fn (mut c vono.Context) http.Response {
		c.headers['X-Custom-Header'] = 'custom-value'
		return c.text('OK')
	})

	// ==================== Custom 404 ====================

	app.not_found(fn (mut c vono.Context) http.Response {
		c.status(404)
		return c.json('{"error": "Not Found", "path": "${c.path}"}')
	})

	// Start uSockets server
	println('[usockets-test-server] Starting on port 9998...')
	app.listen_usockets(9998)
}
