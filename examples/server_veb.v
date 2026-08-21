// veb server example - for performance comparison testing
// veb is the official new version of the V language web framework (replacing the old vweb)
// 
// Run: v run server_veb.v
//Test: curl http://127.0.0.1:8080/
//
// Stress test command:
//   wrk -t4 -c100 -d10s http://127.0.0.1:8080/
//   wrk -t4 -c100 -d10s http://127.0.0.1:8080/api/users/123

module main

import veb
import time

// application status
pub struct App {
pub:
	start_time time.Time = time.now()
}

//Context type
pub struct Context {
	veb.Context
}

fn main() {
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║              veb 服务器 - 性能对比测试                        ║')
	println('╠═══════════════════════════════════════════════════════════════╣')
	println('║ 端口: 8080                                                    ║')
	println('║ 测试端点:                                                     ║')
	println('║   GET  /                    - Hello World                     ║')
	println('║   GET  /api/health          - 健康检查                        ║')
	println('║   GET  /api/users           - 获取用户列表                    ║')
	println('║   POST /api/users           - 创建用户                        ║')
	println('║   GET  /api/users/:id       - 获取单个用户                    ║')
	println('║   GET  /api/users/:id/posts - 获取用户帖子                    ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
	println('')
	println('启动 veb 服务器在端口 8080...')
	
	mut app := &App{}
	veb.run[App, Context](mut app, 8080)
}

// ============================================
// static routing
// ============================================

// front page
@['/']
pub fn (app &App) index(mut ctx Context) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.text('Hello World')
}

// health check
@['/api/health']
pub fn (app &App) health(mut ctx Context) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.text('OK')
}

// Get user list
@['/api/users'; get]
pub fn (app &App) get_users(mut ctx Context) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[[]User]([
		User{id: '1', name: 'Alice', email: 'alice@example.com'},
		User{id: '2', name: 'Bob', email: 'bob@example.com'},
	])
}

//Create user
@['/api/users'; post]
pub fn (app &App) create_user(mut ctx Context) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[CreateResponse](CreateResponse{created: true, id: '3'})
}

// ============================================
// dynamic routing
// ============================================

// Get a single user
@['/api/users/:id']
pub fn (app &App) get_user(mut ctx Context, id string) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[User](User{id: id, name: 'User ${id}', email: 'user${id}@example.com'})
}

// Get the user's posts
@['/api/users/:id/posts']
pub fn (app &App) get_user_posts(mut ctx Context, id string) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[PostsResponse](PostsResponse{
		user_id: id
		posts: [
			Post{id: '1', title: 'First Post', content: 'Hello World'},
			Post{id: '2', title: 'Second Post', content: 'V is awesome'},
		]
	})
}

// Get specific posts
@['/api/users/:user_id/posts/:post_id']
pub fn (app &App) get_user_post(mut ctx Context, user_id string, post_id string) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[PostResponse](PostResponse{
		user_id: user_id
		post_id: post_id
		post: Post{id: post_id, title: 'Post ${post_id}', content: 'Content of post ${post_id}'}
	})
}

// Get classified products
@['/api/categories/:cat/items/:item']
pub fn (app &App) get_category_item(mut ctx Context, cat string, item string) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[ItemResponse](ItemResponse{
		category: cat
		item: item
		price: 99.99
	})
}

// ============================================
//data structure
// ============================================

struct User {
	id    string
	name  string
	email string
}

struct Post {
	id      string
	title   string
	content string
}

struct CreateResponse {
	created bool
	id      string
}

struct PostsResponse {
	user_id string
	posts   []Post
}

struct PostResponse {
	user_id string
	post_id string
	post    Post
}

struct ItemResponse {
	category string
	item     string
	price    f64
}
