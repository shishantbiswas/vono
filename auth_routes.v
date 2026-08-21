module vono

import x.json2
import net.http

//Login request structure
pub struct LoginRequest {
pub:
	username string
	password string
}

//Register request structure
pub struct RegisterRequest {
pub:
	username string
	email    string
	password string
	role     string
}

//Menu creation request structure
pub struct MenuCreateRequest {
pub:
	name        string
	path        string
	icon        string
	parent_id   int
	sort_order  int
	permissions []string
}

// response structure
struct ErrorResponseBody {
	error string
}

struct LoginResponseBody {
	token      string
	expires_at string
}

struct RegisterResponseBody {
	user_id  string
	username string
	email    string
	role     string
}

struct MessageResponseBody {
	message string
}

struct ProfileResponseBody {
	user_id  string
	username string
	email    string
	role     string
	active   string
}

struct MenusResponseBody {
	menus []MenuItem
}

struct MenuCreateResponseBody {
	menu_id     string
	name        string
	path        string
	icon        string
	parent_id   string
	sort_order  string
	permissions string
	active      string
}

// Authentication middleware (only verification, no user injection)
pub fn auth_middleware(auth_manager AuthManager) ContextMiddleware {
	return fn [auth_manager] (mut c Context, next fn (mut Context) http.Response) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		if token == '' {
			c.status(401)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: 'Authorization token required'
			}))
		}
		_ := auth_manager.verify_token(token) or {
			c.status(401)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: 'Invalid or expired token'
			}))
		}
		return next(mut c)
	}
}

// Permission checking middleware (directly verify token permissions)
pub fn permission_middleware(auth_manager AuthManager, required_permission string) ContextMiddleware {
	return fn [auth_manager, required_permission] (mut c Context, next fn (mut Context) http.Response) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		user := auth_manager.verify_token(token) or {
			c.status(401)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: 'Invalid or expired token'
			}))
		}
		if !auth_manager.check_permission(user, required_permission) {
			c.status(403)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: 'Insufficient permissions'
			}))
		}
		return next(mut c)
	}
}

//Register authentication route
pub fn register_auth_routes(mut app Vono, mut auth_manager AuthManager) {
	//Login route
	app.post('/api/auth/login', fn [mut auth_manager] (mut c Context) http.Response {
		body := c.body
		login_req := json2.decode[LoginRequest](body) or {
			c.status(400)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: 'Invalid request body'
			}))
		}
		session := auth_manager.login(login_req.username, login_req.password) or {
			c.status(401)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: err.msg()
			}))
		}
		return c.json(json2.encode[LoginResponseBody](LoginResponseBody{
			token: session.token.str()
			expires_at: session.expires_at.str()
		}))
	})

	//Register route
	app.post('/api/auth/register', fn [mut auth_manager] (mut c Context) http.Response {
		body := c.body
		register_req := json2.decode[RegisterRequest](body) or {
			c.status(400)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: 'Invalid request body'
			}))
		}
		role := match register_req.role {
			'admin' { UserRole.admin }
			'manager' { UserRole.manager }
			'user' { UserRole.user }
			'guest' { UserRole.guest }
			else { UserRole.user }
		}
		user := auth_manager.create_user(register_req.username, register_req.email, register_req.password, role) or {
			c.status(400)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: err.msg()
			}))
		}
		return c.json(json2.encode[RegisterResponseBody](RegisterResponseBody{
			user_id: user.id.str()
			username: user.username
			email: user.email
			role: user.role.str()
		}))
	})

	//Logout routing
	app.post('/api/auth/logout', fn [mut auth_manager] (mut c Context) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		if token == '' {
			c.status(401)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: 'Authorization token required'
			}))
		}
		auth_manager.logout(token) or {
			c.status(500)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: err.msg()
			}))
		}
		return c.json(json2.encode[MessageResponseBody](MessageResponseBody{
			message: 'Logged out successfully'
		}))
	})

	// Get user information routing
	app.get('/api/auth/profile', fn [auth_manager] (mut c Context) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		user := auth_manager.verify_token(token) or {
			c.status(401)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: 'Invalid or expired token'
			}))
		}
		return c.json(json2.encode[ProfileResponseBody](ProfileResponseBody{
			user_id: user.id.str()
			username: user.username
			email: user.email
			role: user.role.str()
			active: user.status.str()
		}))
	})

	// Get user menu route
	app.get('/api/auth/menus', fn [auth_manager] (mut c Context) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		user := auth_manager.verify_token(token) or {
			c.status(401)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: 'Invalid or expired token'
			}))
		}
		menus := auth_manager.get_user_menus(user) or {
			c.status(500)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: err.msg()
			}))
		}
		return c.json(json2.encode[MenusResponseBody](MenusResponseBody{
			menus: menus
		}))
	})

	//Create menu item routing (requires administrator privileges)
	app.post('/api/auth/menus', fn [mut auth_manager] (mut c Context) http.Response {
		body := c.body
		menu_req := json2.decode[MenuCreateRequest](body) or {
			c.status(400)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: 'Invalid request body'
			}))
		}
		menu := auth_manager.create_menu_item(menu_req.name, menu_req.path, menu_req.icon, menu_req.parent_id, menu_req.sort_order, menu_req.permissions) or {
			c.status(400)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: err.msg()
			}))
		}
		return c.json(json2.encode[MenuCreateResponseBody](MenuCreateResponseBody{
			menu_id: menu.id.str()
			name: menu.name
			path: menu.path
			icon: menu.icon
			parent_id: menu.parent_id.str()
			sort_order: menu.sort_order.str()
			permissions: json2.encode[[]string](menu.permissions)
			active: menu.status.str()
		}))
	})

	// Get all menu item routes (requires administrator privileges)
	app.get('/api/auth/menus/all', fn [auth_manager] (mut c Context) http.Response {
		menus := auth_manager.get_all_menu_items() or {
			c.status(500)
			return c.json(json2.encode[ErrorResponseBody](ErrorResponseBody{
				error: err.msg()
			}))
		}
		return c.json(json2.encode[MenusResponseBody](MenusResponseBody{
			menus: menus
		}))
	})
} 
