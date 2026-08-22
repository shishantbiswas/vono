# Rate Limiting Middleware
Request rate limiting to protect against abuse.

```v
import vono
import net.http

fn main() {
    mut app := vono.Vono.new()

    // Create memory store for rate limiting
    store := vono.MemoryStore.new()

    // Default: 100 requests per minute
    app.use(vono.rate_limit(vono.RateLimitOptions{
        store: store
        window_ms: 60000   // 1 minute
        limit: 100         // Max 100 requests
        headers: true      // Add X-RateLimit-* headers
    }))

    // Custom key generator (e.g., by user ID)
    app.use('/api/*', vono.rate_limit(vono.RateLimitOptions{
        store: store
        window_ms: 60000
        limit: 50
        key_generator: fn (c vono.Context) string {
            if user_id := c.get('user_id') {
                return user_id
            }
            return c.get_client_ip()
        }
    }))

    // Skip rate limiting for certain requests
    app.use(vono.rate_limit(vono.RateLimitOptions{
        store: store
        limit: 100
        skip: fn (c vono.Context) bool {
            // Skip for health check endpoints
            return c.path == '/health'
        }
    }))

    app.get('/', fn (mut c vono.Context) http.Response {
        return c.text('Hello!')
    })

    app.listen(':3000')
}
```