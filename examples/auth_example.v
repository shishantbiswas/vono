module main

import meiseayoung.hono
import net.http
import x.json2

// response structure
struct ErrorResponse {
	error string
}

struct ProtectedUserResponse {
	message  string
	user_id  string
	username string
	email    string
	role     string
}

struct ProtectedAdminResponse {
	message  string
	user_id  string
	username string
	email    string
	role     string
}

fn main() {
	//Create database manager
	db_manager := hono.new_database_manager('auth_system.db') or {
		eprintln('Failed to create database manager: $err')
		return
	}

	//Create authentication manager
	mut auth_manager := hono.new_auth_manager(db_manager)
	
	//Initialize authentication related table
	auth_manager.init_tables() or {
		eprintln('Failed to initialize auth tables: $err')
		return
	}

	//Create Hono application
	mut app := hono.Hono{}

	//Register authentication route
	hono.register_auth_routes(mut app, mut auth_manager)

	//Add some example menu items
	create_sample_menus(mut auth_manager)

	//Add some example users
	create_sample_users(mut auth_manager)

	//Add some protected routing examples
	app.get('/api/protected/user', fn [auth_manager] (mut c hono.Context) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		user := auth_manager.verify_token(token) or {
			c.status(401)
			return c.json(json2.encode[ErrorResponse](ErrorResponse{
				error: 'User not found'
			}))
		}
		return c.json(json2.encode[ProtectedUserResponse](ProtectedUserResponse{
			message: 'This is a protected user route'
			user_id: user.id.str()
			username: user.username
			email: user.email
			role: user.role.str()
		}))
	})

	app.get('/api/protected/admin', fn [auth_manager] (mut c hono.Context) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		user := auth_manager.verify_token(token) or {
			c.status(401)
			return c.json(json2.encode[ErrorResponse](ErrorResponse{
				error: 'User not found'
			}))
		}
		if !auth_manager.check_permission(user, 'manage') {
			c.status(403)
			return c.json(json2.encode[ErrorResponse](ErrorResponse{
				error: 'Admin access required'
			}))
		}
		return c.json(json2.encode[ProtectedAdminResponse](ProtectedAdminResponse{
			message: 'This is a protected admin route'
			user_id: user.id.str()
			username: user.username
			email: user.email
			role: user.role.str()
		}))
	})

	//Add static file service
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.file('public/auth.html')
	})

	println('🚀 用户角色菜单管理系统已启动')
	println('📱 访问地址: http://127.0.0.1:3000')
	println('')
	println('📋 示例用户:')
	println('   用户名: admin, 密码: admin123, 角色: admin')
	println('   用户名: manager, 密码: manager123, 角色: manager')
	println('   用户名: user, 密码: user123, 角色: user')
	println('   用户名: guest, 密码: guest123, 角色: guest')
	println('')

	// Start the server
	app.listen(':3000')
}

//Create a sample menu
fn create_sample_menus(mut auth_manager hono.AuthManager) {
	//Create root menu
	auth_manager.create_menu_item('仪表板', '/dashboard', '📊', 0, 1, ['read']) or { println('仪表板插入失败') }
	auth_manager.create_menu_item('用户管理', '/users', '👥', 0, 2, ['read', 'write', 'manage']) or { println('用户管理插入失败') }
	auth_manager.create_menu_item('系统设置', '/settings', '⚙️', 0, 3, ['manage']) or { println('系统设置插入失败') }
	auth_manager.create_menu_item('文件管理', '/files', '📁', 0, 4, ['read', 'write']) or { println('文件管理插入失败') }

	// Get the user management menu ID (dynamically obtained)
	user_menu_id := auth_manager.get_menu_id_by_path('/users')

	//Create submenu
	auth_manager.create_menu_item('用户列表', '/users/list', '📋', user_menu_id, 1, ['read']) or { println('用户列表插入失败') }
	auth_manager.create_menu_item('添加用户', '/users/add', '➕', user_menu_id, 2, ['write']) or { println('添加用户插入失败') }
	auth_manager.create_menu_item('编辑用户', '/users/edit', '✏️', user_menu_id, 3, ['write']) or { println('编辑用户插入失败') }
	auth_manager.create_menu_item('删除用户', '/users/delete', '🗑️', user_menu_id, 4, ['manage']) or { println('删除用户插入失败') }

	// More test menus
	auth_manager.create_menu_item('报表中心', '/reports', '📈', 0, 5, ['read', 'write']) or { println('报表中心插入失败') }
	reports_menu_id := auth_manager.get_menu_id_by_path('/reports')
	auth_manager.create_menu_item('销售报表', '/reports/sales', '💹', reports_menu_id, 1, ['read']) or { println('销售报表插入失败') }
	auth_manager.create_menu_item('财务报表', '/reports/finance', '💰', reports_menu_id, 2, ['read']) or { println('财务报表插入失败') }
	auth_manager.create_menu_item('消息中心', '/messages', '📨', 0, 6, ['read']) or { println('消息中心插入失败') }
	auth_manager.create_menu_item('个人中心', '/profile', '👤', 0, 7, ['read', 'write']) or { println('个人中心插入失败') }
	auth_manager.create_menu_item('测试菜单A', '/test/a', '🅰️', 0, 8, ['read']) or { println('测试菜单A插入失败') }
	auth_manager.create_menu_item('测试菜单B', '/test/b', '🅱️', 0, 9, ['read']) or { println('测试菜单B插入失败') }
	auth_manager.create_menu_item('测试菜单C', '/test/c', '🆑', 0, 10, ['read']) or { println('测试菜单C插入失败') }
	test_a_id := auth_manager.get_menu_id_by_path('/test/a')
	auth_manager.create_menu_item('A-子菜单1', '/test/a/1', '1️⃣', test_a_id, 1, ['read']) or { println('A-子菜单1插入失败') }
	auth_manager.create_menu_item('A-子菜单2', '/test/a/2', '2️⃣', test_a_id, 2, ['read']) or { println('A-子菜单2插入失败') }

	println('✅ 示例菜单已创建')
	println('✅ 更多测试菜单已创建')
}

//Create sample user
fn create_sample_users(mut auth_manager hono.AuthManager) {
	//Create admin user
	auth_manager.create_user('admin', 'admin@example.com', 'admin123', hono.UserRole.admin) or { return }
	
	//Create manager user
	auth_manager.create_user('manager', 'manager@example.com', 'manager123', hono.UserRole.manager) or { return }
	
	//Create a normal user
	auth_manager.create_user('user', 'user@example.com', 'user123', hono.UserRole.user) or { return }
	
	//Create guest user
	auth_manager.create_user('guest', 'guest@example.com', 'guest123', hono.UserRole.guest) or { return }

	println('✅ 示例用户已创建')
} 
