# Gettings started

Vono is a high-performance [V language](https://vlang.io) web framework inspired by [Hono](https://hono.dev) and [Express](https://expressjs.com), it aims to bring high level TS/JS syntax but with all the benefits of a compiled language, it features hybrid routing, LRU cache, middleware support, multi-cloud storage, chunked file upload, and more.

It uses [uSockets](https://github.com/uNetworking/uSockets), [Libuv](https://libuv.org) and [Picoev](https://github.com/kazuho/picoev) to compile your code in a high concurrency http/websocket server capable of handling millions of requests.  

This project is forked from [meiseayoung](https://github.com/meiseayoung) at [vono](https://github.com/meiseayoung/vono)

## Installation

````sh
v install --git https://github.com/shishantbiswas/vono
````

## Quick Start
Start by creating a new project by `v new`, open it in a text editor and add the demo code below to `main.v`

```v
import vono
import net.http

fn main() {
    mut app := hono.Hono.new()
    
    app.get('/', fn (mut c hono.Context) http.Response {
        return c.text('Hello, World!')
    })
    
    // Use uSockets backend (high concurrency optimized)
    app.listen_usockets(3000)
    
    // Or use default picoev backend
    // app.listen(':3000')
}
```

Now compile it with 
``` sh
v -prod .
```

::: info
At the root of our project you'll have you binary with the name of the project you have chosen at the `v new` step,
that's your server all contained within that binary 
:::
