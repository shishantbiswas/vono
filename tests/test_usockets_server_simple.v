// uSockets simplified test server - consistent with the outer main.v configuration
module main

import meiseayoung.hono
import net.http
import x.json2

// JSON response structure
struct JsonResponse {
	message string
}

struct UserResponse {
	user_id string
}

fn main() {
	mut app := hono.Hono.new()

	// Routing configuration exactly the same as outer main.v (no middleware)
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.text('Hello, World!')
	})

	app.get('/json', fn (mut c hono.Context) http.Response {
		data := JsonResponse{message: 'Hello, JSON!'}
		json_str := json2.encode(data)
		return c.json(json_str)
	})

	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id'] or { 'unknown' }
		data := UserResponse{user_id: user_id}
		json_str := json2.encode(data)
		return c.json(json_str)
	})

	app.get('/health', fn (mut c hono.Context) http.Response {
		return c.text('OK')
	})

	println('[usockets-simple] Starting on port 9999 (uSockets)...')
	app.listen_usockets(9999)
}
