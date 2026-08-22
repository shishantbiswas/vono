# Cookie Helper

Utilities for managing HTTP cookies, including signed cookies.

```v
import vono

fn main() {
    mut app := vono.Vono.new()

    app.get('/cookie/set', fn (mut c vono.Context) http.Response {
        // Set a cookie
        vono.set_cookie(mut c, 'session_id', 'abc123', vono.CookieOptions{
            http_only: true
            secure: true
            max_age: 3600
            path: '/'
        })
        return c.json('{"message": "Cookie set"}')
    })

    app.get('/cookie/get', fn (mut c vono.Context) http.Response {
        // Get a cookie
        if session := vono.get_cookie(c, 'session_id') {
            return c.json('{"session": "${session}"}')
        }
        return c.json('{"error": "Cookie not found"}')
    })

    app.get('/cookie/delete', fn (mut c vono.Context) http.Response {
        vono.delete_cookie(mut c, 'session_id')
        return c.json('{"message": "Cookie deleted"}')
    })

    // Signed cookies (tamper-proof)
    app.get('/signed/set', fn (mut c vono.Context) http.Response {
        secret := 'my-secret-key'
        vono.set_signed_cookie(mut c, 'key', 'value', secret) or {
            return c.json('{"error": "Failed to set signed cookie"}')
        }
        return c.json('{"message": "Signed cookie set"}')
    })

    app.get('/signed/get', fn (mut c vono.Context) http.Response {
        secret := 'my-secret-key'
        user_data := vono.get_signed_cookie(c, 'key', secret) or {
            return c.json('{"error": "Invalid or missing signed cookie"}')
        }
        return c.json('{"user_data": "${user_data}"}')
    })

    app.listen(':3000')
}
```