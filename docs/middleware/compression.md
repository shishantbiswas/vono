# Compression Middleware
Response compression with gzip and deflate support.

```v
import vono
import net.http

fn main() {
    mut app := vono.Vono.new()

    // Auto-select best encoding based on Accept-Encoding header
    app.use(vono.compress())

    // Force gzip compression
    app.use(vono.gzip())

    // Custom configuration
    app.use(vono.compress(vono.CompressOptions{
        encoding: .gzip
        threshold: 2048  // Only compress responses > 2KB
        level: 6         // Compression level (1-9)
    }))

    app.get('/large-data', fn (mut c vono.Context) http.Response {
        // Large response will be automatically compressed
        return c.json('{"data": "...large content..."}')
    })

    app.listen(':3000')
}
```