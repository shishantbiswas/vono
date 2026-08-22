#  Bearer Auth Middleware
Simple Bearer token authentication.

```v
import vono
import net.http

fn main() {
    mut app := vono.Vono.new()

    // Single token authentication
    app.use('/api/*', vono.bearer_auth(vono.BearerAuthOptions{
        token: 'my-api-token'
        realm: 'Protected API'
    }))

    // Multiple tokens
    app.use('/admin/*', vono.bearer_auth(vono.BearerAuthOptions{
        token: vono.BearerToken(['token1', 'token2', 'token3'])
    }))

    // Custom verification
    app.use('/custom/*', vono.bearer_auth(vono.BearerAuthOptions{
        verify_token: fn (token string, c vono.Context) bool {
            // Custom validation logic
            return token.len > 10 && token.starts_with('valid_')
        }
    }))

    app.get('/api/data', fn (mut c vono.Context) http.Response {
        token := vono.get_bearer_token(c) or { 'unknown' }
        return c.json('{"message": "Protected data", "token": "${token}"}')
    })

    app.listen(':3000')
}
```