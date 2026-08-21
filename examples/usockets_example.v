module main

import net.http
import meiseayoung.vono

fn main() {
    mut app := vono.Vono.new()

    app.get('/', fn (mut c vono.Context) http.Response {
        return c.text('Hello from vono + uSockets!')
    })

    app.get('/json', fn (mut c vono.Context) http.Response {
        return c.json('{"message": "Hello, JSON!"}')
    })

    app.get('/users/:id', fn (mut c vono.Context) http.Response {
        user_id := c.params['id'] or { 'unknown' }
        return c.json('{"user_id": "${user_id}"}')
    })

    //Use uSockets backend
    app.listen_usockets(3008)
}
