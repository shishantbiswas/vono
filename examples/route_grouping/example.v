// Route grouping example for vono web framework
module main

import net.http
import meiseayoung.vono

fn main() {
	mut app := vono.Vono.new()

	// Create API sub-application
	mut api := vono.Vono.new()
	
	api.get('/users', fn (mut c vono.Context) http.Response {
		return c.json('[{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]')
	})

	api.get('/users/:id', fn (mut c vono.Context) http.Response {
		user_id := c.params['id'] or { 'unknown' }
		return c.json('{"id": ${user_id}, "name": "User ${user_id}"}')
	})

	api.post('/users', fn (mut c vono.Context) http.Response {
		return c.json('{"message": "User created"}')
	})

	// Mount API routes under /api prefix
	app.route('/api', mut api)

	// Root route
	app.get('/', fn (mut c vono.Context) http.Response {
		return c.html('<h1>Welcome to vono!</h1><p>API available at /api</p>')
	})

	println('Server starting on http://127.0.0.1:3000')
	println('Routes:')
	println('  GET  /           - Welcome page')
	println('  GET  /api/users  - List users')
	println('  GET  /api/users/:id - Get user by ID')
	println('  POST /api/users  - Create user')
	app.listen(':3000')
}
