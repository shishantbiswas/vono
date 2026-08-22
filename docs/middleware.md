# Middleware

Middlewares are wrapper function that allow you to run it for all or selective routes for additional functionality that you may want. Out of the box, Vono provides middleware helpers for:

## Build-in Middlewares

[CORS Middleware](/)

[Cookie Helper](/)

[JWT Middleware](/)

[Bearer Auth Middleware](/)

[Compression Middleware](/)

[Rate Limiting Middleware](/)

[Request Validator](/)


## Custom Middleware Expample 
```v
import net.http
import time
import vono

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

    app.get('/', fn (mut c vono.Context) http.Response {
        return c.text('Hello with middleware!')
    })

    app.listen(':3000')
}
```