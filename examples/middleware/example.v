// Middleware example for vono web framework
module main

import net.http
import time
import meiseayoung.vono

fn main() {
	mut app := vono.Vono.new()

	// Logger middleware
	app.use(fn (mut c vono.Context, next fn (mut vono.Context) http.Response) http.Response {
		start := time.now()
		response := next(mut c)
		duration := time.since(start)
		println('[${c.req.method}] ${c.path} - ${duration}')
		return response
	})

	// CORS middleware
	app.use(fn (mut c vono.Context, next fn (mut vono.Context) http.Response) http.Response {
		c.headers['Access-Control-Allow-Origin'] = '*'
		c.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
		c.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
		return next(mut c)
	})

	// Routes
	app.get('/', fn (mut c vono.Context) http.Response {
		return c.text('Hello with middleware!')
	})

	app.get('/api/data', fn (mut c vono.Context) http.Response {
		return c.json('{"data": "some data"}')
	})

	println('Server starting on http://127.0.0.1:3000')
	app.listen(':3000')
}
