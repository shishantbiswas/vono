module main

import net.http
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    app.get('/', fn (mut c hono.Context) http.Response {
        return c.text('Hello from vono + uSockets!')
    })

    app.get('/json', fn (mut c hono.Context) http.Response {
        return c.json('{"message": "Hello, JSON!"}')
    })

    app.get('/users/:id', fn (mut c hono.Context) http.Response {
        user_id := c.params['id'] or { 'unknown' }
        return c.json('{"user_id": "${user_id}"}')
    })

    //Use uSockets backend
    app.listen_usockets(3008)
}
