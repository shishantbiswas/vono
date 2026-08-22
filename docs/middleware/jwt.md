# JWT Middleware
JSON Web Token authentication middleware.

```v
import vono
import time
import net.http

fn main() {
    mut app := vono.Vono.new()
    secret := 'my-jwt-secret-key'

    // Generate JWT token
    app.post('/auth/login', fn [secret] (mut c vono.Context) http.Response {
        payload := vono.JwtPayload{
            sub: 'user123'
            iss: 'my-app'
            exp: time.now().unix() + 3600  // 1 hour
            iat: time.now().unix()
            claims: {
                'role': 'admin'
                'name': 'John Doe'
            }
        }

        token := vono.sign_jwt(payload, secret, .hs256) or {
            c.status(500)
            return c.json('{"error": "Failed to generate token"}')
        }

        return c.json('{"token": "${token}"}')
    })

    // Protect routes with JWT middleware
    app.use('/api/*', vono.jwt_middleware(vono.JwtOptions{
        secret: secret
        alg: .hs256
    }))

    app.get('/api/profile', fn (mut c vono.Context) http.Response {
        // Access JWT payload from context
        if payload := vono.get_jwt_payload(c) {
            return c.json('{"user": "${payload.sub}"}')
        }
        return c.json('{"error": "No payload"}')
    })

    app.listen(':3000')
}
```