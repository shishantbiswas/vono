# Motivation

### List of Hono-like Frameowrk in other languages

Rust has [Axum](https://github.com/tokio-rs/axum), [Salvo](https://github.com/salvo-rs/salvo) and [Peom](https://github.com/poem-web/poem). 

Go has [Fiber](https://github.com/gofiber/fiber), [Echo](https://github.com/labstack/echo), [Gin](https://github.com/gin-gonic/gin) and [Chi](https://github.com/go-chi/chi).

JS/TS has [Hono](https://github.com/honojs/hono), [Fastify](https://github.com/fastify/fastify), [Elysia](https://github.com/elysiajs/elysia) and the OG [Express](https://github.com/expressjs/express).

All the languages above have multiple Hono-like web frameworks which are simple and blazingly fast similar to what Hono is in context of JS/TS, out of all these languages V was the only one where a hono-like framework wasn't popular or well known, the only one I found was [v-hono](https://github.com/meiseayoung/v-hono) but it's wasn't working at first, so after I fixed all the errors I decided that I'll maintain a fork of it which I call [vono](https://github.com/shishantbiswas/vono)

## Why V
V is overall a expectional language surrounded with it's controversial past but I don't mind, this isn't my fisrt attempt at a high performance server but my prior attempts of using libuv with a coroutine lib for maximum performance was a disaster and required a bunch of "mental context switching" which was something I was not capable of handling nor I had the years of experience to tackle it , not to mention manually memory managing this whole thing was a nightmare it never stopped leaking memory