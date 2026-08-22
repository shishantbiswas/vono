# CORS Middleware

Cross-Origin Resource Sharing (CORS) is a browser seecurity mechanism used to check it the request made from the frontend is allowed to make it to a different server. Read more about it on [MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS)

```v
import vono
import net.http

fn main() {
    mut app := vono.Vono.new()

    // Allow all origins
    app.use(vono.cors())

    // Custom configuration
    app.use(vono.cors(vono.CorsOptions{
        origin: 'https://example.com'
        credentials: true
        max_age: 600
        allow_methods: ['GET', 'POST', 'PUT', 'DELETE']
        allow_headers: ['Content-Type', 'Authorization']
    }))

    app.listen(':3000')
}
```