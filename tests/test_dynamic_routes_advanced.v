import meiseayoung.vono
import net.http

fn main() {
	println('=== 高级动态路由测试用例 ===')
	
	//Test 1: Complex nested parameter routing
	test_complex_nested_routes()
	
	//Test 2: RESTful API routing mode
	test_restful_api_patterns()
	
	//Test 3: Versioned API routing
	test_versioned_api_routes()
	
	//Test 4: File path routing
	test_file_path_routes()
	
	//Test 5: Multi-language routing
	test_multilingual_routes()
	
	//Test 6: Subdomain name routing simulation
	test_subdomain_simulation()
	
	//Test 7: Dynamic middleware routing
	test_dynamic_middleware_routes()
	
	println('✅ 高级动态路由测试完成')
}

fn test_complex_nested_routes() {
	println('\n📊 复杂嵌套参数路由测试...')
	
	mut app := vono.Vono.new()
	
	// Complex nested route definition
	complex_routes := [
		// E-commerce platform routing
		'/shop/:region/:city/stores/:store_id/products/:category/:product_id',
		'/shop/:region/:city/stores/:store_id/orders/:order_id/items/:item_id',
		'/shop/:region/:city/stores/:store_id/reviews/:review_id/replies/:reply_id',
		
		// social media routing
		'/social/:platform/users/:user_id/posts/:post_id/comments/:comment_id/likes',
		'/social/:platform/groups/:group_id/events/:event_id/attendees/:user_id',
		'/social/:platform/pages/:page_id/posts/:post_id/shares/:share_id',
		
		//Enterprise management routing
		'/enterprise/:org_id/departments/:dept_id/teams/:team_id/members/:member_id',
		'/enterprise/:org_id/projects/:project_id/tasks/:task_id/subtasks/:subtask_id',
		'/enterprise/:org_id/budgets/:budget_id/categories/:category_id/items/:item_id'
	]
	
	//Add route
	for route in complex_routes {
		app.get(route, fn (mut c vono.Context) http.Response {
			return c.text('Complex route response')
		})
	}
	
	// test path
	test_cases := [
		{
			'route': '/shop/:region/:city/stores/:store_id/products/:category/:product_id'
			'path': '/shop/asia/beijing/stores/store123/products/electronics/phone456'
			'expected_params': 'region:asia,city:beijing,store_id:store123,category:electronics,product_id:phone456'
		},
		{
			'route': '/social/:platform/users/:user_id/posts/:post_id/comments/:comment_id/likes'
			'path': '/social/twitter/users/user789/posts/post101/comments/comment202/likes'
			'expected_params': 'platform:twitter,user_id:user789,post_id:post101,comment_id:comment202'
		},
		{
			'route': '/enterprise/:org_id/departments/:dept_id/teams/:team_id/members/:member_id'
			'path': '/enterprise/org999/departments/dept888/teams/team777/members/member666'
			'expected_params': 'org_id:org999,dept_id:dept888,team_id:team777,member_id:member666'
		}
	]
	
	mut success_count := 0
	for test_case in test_cases {
		if match_result := app.fast_router.match_route('GET', test_case['path']) {
			// Verify parameter extraction
			mut param_check_passed := true
			expected_params := test_case['expected_params'].split(',')
			
			for expected_param in expected_params {
				parts := expected_param.split(':')
				if parts.len == 2 {
					param_name := parts[0].trim_space()
					expected_value := parts[1].trim_space()
					
					if actual_value := match_result.params[param_name] {
						if actual_value != expected_value {
							param_check_passed = false
							break
						}
					} else {
						param_check_passed = false
						break
					}
				}
			}
			
			if param_check_passed {
				success_count++
				println('  ✅ ${test_case['path']} - 参数提取正确')
			} else {
				println('  ❌ ${test_case['path']} - 参数提取错误')
			}
		} else {
			println('  ❌ ${test_case['path']} - 路由匹配失败')
		}
	}
	
	println('  复杂嵌套路由测试: ${success_count}/${test_cases.len} 通过')
}

fn test_restful_api_patterns() {
	println('\n📊 RESTful API 路由模式测试...')
	
	mut app := vono.Vono.new()
	
	// RESTful resource routing
	restful_patterns := [
		//User resources
		'/api/users',                           // GET: list, POST: create
		'/api/users/:id',                       // GET: details, PUT: update, DELETE: delete
		'/api/users/:id/profile',               // GET: User information
		'/api/users/:id/settings',              // GET/PUT: User settings
		
		// Nested resources
		'/api/users/:user_id/posts',            // GET: User article list, POST: Create article
		'/api/users/:user_id/posts/:post_id',   // GET: article details, PUT: update, DELETE: delete
		'/api/users/:user_id/posts/:post_id/comments',  // GET: comment list, POST: add comment
		'/api/users/:user_id/posts/:post_id/comments/:comment_id',  // GET/PUT/DELETE: comment operation
		
		//Relationship resources
		'/api/users/:user_id/followers',        // GET: Follower list
		'/api/users/:user_id/following',        // GET: Watchlist
		'/api/users/:user_id/follow/:target_id', // POST: Follow, DELETE: Unfollow
		
		//Search and filter
		'/api/search/users/:query',             // GET: Search for users
		'/api/search/posts/:query',             // GET: Search for articles
		'/api/filter/posts/:category/:tag',     // GET: Filter by category and tag
	]
	
	//Add all RESTful routes
	for pattern in restful_patterns {
		// Simulate different HTTP methods
		app.get(pattern, fn (mut c vono.Context) http.Response {
			return c.text('GET response')
		})
		app.post(pattern, fn (mut c vono.Context) http.Response {
			return c.text('POST response')
		})
		app.put(pattern, fn (mut c vono.Context) http.Response {
			return c.text('PUT response')
		})
		app.delete(pattern, fn (mut c vono.Context) http.Response {
			return c.text('DELETE response')
		})
	}
	
	// Test RESTful operations
	restful_tests := [
		{
			'method': 'GET'
			'path': '/api/users/123'
			'description': '获取用户详情'
		},
		{
			'method': 'POST'
			'path': '/api/users/123/posts'
			'description': '创建用户文章'
		},
		{
			'method': 'PUT'
			'path': '/api/users/123/posts/456'
			'description': '更新文章'
		},
		{
			'method': 'DELETE'
			'path': '/api/users/123/posts/456/comments/789'
			'description': '删除评论'
		},
		{
			'method': 'GET'
			'path': '/api/search/users/john'
			'description': '搜索用户'
		},
		{
			'method': 'GET'
			'path': '/api/filter/posts/tech/javascript'
			'description': '过滤文章'
		}
	]
	
	mut restful_success := 0
	for test in restful_tests {
		if _ := app.fast_router.match_route(test['method'], test['path']) {
			restful_success++
			println('  ✅ ${test['method']} ${test['path']} - ${test['description']}')
		} else {
			println('  ❌ ${test['method']} ${test['path']} - ${test['description']}')
		}
	}
	
	println('  RESTful API测试: ${restful_success}/${restful_tests.len} 通过')
}

fn test_versioned_api_routes() {
	println('\n📊 版本化API路由测试...')
	
	mut app := vono.Vono.new()
	
	// Versioned API routing
	versioned_routes := [
		// Version 1 API
		'/api/v1/users/:id',
		'/api/v1/posts/:id',
		'/api/v1/auth/login',
		
		// Version 2 API (backwards compatible)
		'/api/v2/users/:id',
		'/api/v2/users/:id/profile',
		'/api/v2/posts/:id',
		'/api/v2/posts/:id/analytics',
		'/api/v2/auth/oauth/:provider',
		
		// Version 3 API (latest)
		'/api/v3/users/:id',
		'/api/v3/users/:id/preferences',
		'/api/v3/posts/:id',
		'/api/v3/posts/:id/engagement',
		'/api/v3/auth/sso/:provider/:tenant',
		
		//Universal version routing
		'/api/:version/health',
		'/api/:version/status',
		'/api/:version/metrics/:metric_type'
	]
	
	for route in versioned_routes {
		app.get(route, fn (mut c vono.Context) http.Response {
			return c.text('Versioned API response')
		})
	}
	
	//Version compatibility testing
	version_tests := [
		{
			'path': '/api/v1/users/123'
			'expected_version': 'v1'
		},
		{
			'path': '/api/v2/users/456/profile'
			'expected_version': 'v2'
		},
		{
			'path': '/api/v3/auth/sso/google/tenant789'
			'expected_version': 'v3'
		},
		{
			'path': '/api/v2/health'
			'expected_version': 'v2'
		},
		{
			'path': '/api/v3/metrics/performance'
			'expected_version': 'v3'
		}
	]
	
	mut version_success := 0
	for test in version_tests {
		if match_result := app.fast_router.match_route('GET', test['path']) {
			// Check version parameters
			if version := match_result.params['version'] {
				if version == test['expected_version'] {
					version_success++
					println('  ✅ ${test['path']} - 版本${version}')
				} else {
					println('  ❌ ${test['path']} - 版本不匹配: 期望${test['expected_version']}, 实际${version}')
				}
			} else {
				// Fixed version routing
				if test['path'].contains(test['expected_version']) {
					version_success++
					println('  ✅ ${test['path']} - 固定版本${test['expected_version']}')
				}
			}
		} else {
			println('  ❌ ${test['path']} - 路由匹配失败')
		}
	}
	
	println('  版本化API测试: ${version_success}/${version_tests.len} 通过')
}

fn test_file_path_routes() {
	println('\n📊 文件路径路由测试...')
	
	mut app := vono.Vono.new()
	
	//File system routing
	file_routes := [
		//Basic file routing
		'/files/:filename',
		'/files/:category/:filename',
		'/files/:year/:month/:filename',
		'/files/:year/:month/:day/:filename',
		
		// User file routing
		'/users/:user_id/files/:filename',
		'/users/:user_id/files/:folder/:filename',
		'/users/:user_id/files/:folder/:subfolder/:filename',
		
		//Project file routing
		'/projects/:project_id/files/:path/:filename',
		'/projects/:project_id/versions/:version/files/:filename',
		'/projects/:project_id/branches/:branch/files/:path/:filename',
		
		//Media file routing
		'/media/:type/:resolution/:filename',
		'/media/:type/:year/:month/:day/:filename',
		'/media/thumbnails/:size/:filename',
		
		// Document routing
		'/docs/:language/:category/:filename',
		'/docs/:version/:language/:section/:filename'
	]
	
	for route in file_routes {
		app.get(route, fn (mut c vono.Context) http.Response {
			return c.text('File response')
		})
	}
	
	//File path test case
	file_tests := [
		{
			'path': '/files/document.pdf'
			'expected_params': 'filename:document.pdf'
		},
		{
			'path': '/files/images/photo.jpg'
			'expected_params': 'category:images,filename:photo.jpg'
		},
		{
			'path': '/files/2023/12/report.xlsx'
			'expected_params': 'year:2023,month:12,filename:report.xlsx'
		},
		{
			'path': '/users/user123/files/documents/contract.pdf'
			'expected_params': 'user_id:user123,folder:documents,filename:contract.pdf'
		},
		{
			'path': '/projects/proj456/versions/v1.2.3/files/readme.md'
			'expected_params': 'project_id:proj456,version:v1.2.3,filename:readme.md'
		},
		{
			'path': '/media/video/1080p/movie.mp4'
			'expected_params': 'type:video,resolution:1080p,filename:movie.mp4'
		},
		{
			'path': '/docs/en/api/authentication.md'
			'expected_params': 'language:en,category:api,filename:authentication.md'
		}
	]
	
	mut file_success := 0
	for test in file_tests {
		if match_result := app.fast_router.match_route('GET', test['path']) {
			mut params_correct := true
			expected_params := test['expected_params'].split(',')
			
			for expected_param in expected_params {
				parts := expected_param.split(':')
				if parts.len == 2 {
					param_name := parts[0]
					expected_value := parts[1]
					
					if actual_value := match_result.params[param_name] {
						if actual_value != expected_value {
							params_correct = false
							break
						}
					} else {
						params_correct = false
						break
					}
				}
			}
			
			if params_correct {
				file_success++
				println('  ✅ ${test['path']} - 参数正确')
			} else {
				println('  ❌ ${test['path']} - 参数错误')
			}
		} else {
			println('  ❌ ${test['path']} - 路由匹配失败')
		}
	}
	
	println('  文件路径路由测试: ${file_success}/${file_tests.len} 通过')
}

fn test_multilingual_routes() {
	println('\n📊 多语言路由测试...')
	
	mut app := vono.Vono.new()
	
	//Multi-language routing
	multilingual_routes := [
		//Basic multi-language routing
		'/:lang/home',
		'/:lang/about',
		'/:lang/contact',
		
		//Multi-language content routing
		'/:lang/articles/:id',
		'/:lang/articles/:category/:slug',
		'/:lang/products/:id',
		'/:lang/products/:category/:product_id',
		
		//Multi-language user routing
		'/:lang/users/:id/profile',
		'/:lang/users/:id/settings',
		'/:lang/auth/login',
		'/:lang/auth/register',
		
		//Multi-language API routing
		'/api/:lang/search/:query',
		'/api/:lang/translate/:from/:to/:text',
		
		// Regional routing
		'/:country/:lang/stores',
		'/:country/:lang/stores/:store_id',
		'/:country/:lang/checkout/:step'
	]
	
	for route in multilingual_routes {
		app.get(route, fn (mut c vono.Context) http.Response {
			return c.text('Multilingual response')
		})
	}
	
	//Multi-language test cases
	multilingual_tests := [
		{
			'path': '/en/home'
			'expected_lang': 'en'
		},
		{
			'path': '/zh/articles/tech/ai-revolution'
			'expected_lang': 'zh'
			'expected_category': 'tech'
			'expected_slug': 'ai-revolution'
		},
		{
			'path': '/fr/users/123/profile'
			'expected_lang': 'fr'
			'expected_id': '123'
		},
		{
			'path': '/api/es/search/machine learning'
			'expected_lang': 'es'
			'expected_query': 'machine learning'
		},
		{
			'path': '/us/en/stores/store456'
			'expected_country': 'us'
			'expected_lang': 'en'
			'expected_store_id': 'store456'
		},
		{
			'path': '/jp/ja/checkout/payment'
			'expected_country': 'jp'
			'expected_lang': 'ja'
			'expected_step': 'payment'
		}
	]
	
	mut multilingual_success := 0
	for test in multilingual_tests {
		if match_result := app.fast_router.match_route('GET', test['path']) {
			mut params_correct := true
			
			// Check language parameters
			if expected_lang := test['expected_lang'] {
				if actual_lang := match_result.params['lang'] {
					if actual_lang != expected_lang {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			// Check other parameters
			test_params := ['expected_category', 'expected_slug', 'expected_id', 'expected_query', 'expected_country', 'expected_store_id', 'expected_step']
			param_names := ['category', 'slug', 'id', 'query', 'country', 'store_id', 'step']
			
			for i, test_param in test_params {
				if expected_value := test[test_param] {
					param_name := param_names[i]
					if actual_value := match_result.params[param_name] {
						if actual_value != expected_value {
							params_correct = false
							break
						}
					} else {
						params_correct = false
						break
					}
				}
			}
			
			if params_correct {
				multilingual_success++
				println('  ✅ ${test['path']} - 多语言参数正确')
			} else {
				println('  ❌ ${test['path']} - 多语言参数错误')
			}
		} else {
			println('  ❌ ${test['path']} - 路由匹配失败')
		}
	}
	
	println('  多语言路由测试: ${multilingual_success}/${multilingual_tests.len} 通过')
}

fn test_subdomain_simulation() {
	println('\n📊 子域名路由模拟测试...')
	
	mut app := vono.Vono.new()
	
	// Simulate subdomain routing (via path prefix)
	subdomain_routes := [
		//API subdomain name
		'/api.example.com/v1/users/:id',
		'/api.example.com/v1/posts/:id',
		'/api.example.com/health',
		
		//Manage subdomain names
		'/admin.example.com/dashboard',
		'/admin.example.com/users/:id',
		'/admin.example.com/settings/:section',
		
		//User subdomain name
		'/:username.example.com/profile',
		'/:username.example.com/posts',
		'/:username.example.com/posts/:post_id',
		
		//Multi-tenant subdomain name
		'/:tenant.app.com/dashboard',
		'/:tenant.app.com/users/:user_id',
		'/:tenant.app.com/projects/:project_id',
		
		//Regional subdomain name
		'/:region.shop.com/products',
		'/:region.shop.com/products/:category',
		'/:region.shop.com/stores/:store_id'
	]
	
	for route in subdomain_routes {
		app.get(route, fn (mut c vono.Context) http.Response {
			return c.text('Subdomain response')
		})
	}
	
	// Subdomain name test case
	subdomain_tests := [
		{
			'path': '/api.example.com/v1/users/123'
			'description': 'API子域名用户接口'
		},
		{
			'path': '/admin.example.com/users/456'
			'description': '管理子域名用户管理'
			'expected_id': '456'
		},
		{
			'path': '/john.example.com/posts/789'
			'description': '用户子域名文章'
			'expected_username': 'john'
			'expected_post_id': '789'
		},
		{
			'path': '/company1.app.com/projects/proj123'
			'description': '多租户项目管理'
			'expected_tenant': 'company1'
			'expected_project_id': 'proj123'
		},
		{
			'path': '/us.shop.com/products/electronics'
			'description': '地区商店产品'
			'expected_region': 'us'
			'expected_category': 'electronics'
		}
	]
	
	mut subdomain_success := 0
	for test in subdomain_tests {
		if match_result := app.fast_router.match_route('GET', test['path']) {
			mut params_correct := true
			
			// Check parameters
			if expected_id := test['expected_id'] {
				if actual_id := match_result.params['id'] {
					if actual_id != expected_id {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_username := test['expected_username'] {
				if actual_username := match_result.params['username'] {
					if actual_username != expected_username {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_post_id := test['expected_post_id'] {
				if actual_post_id := match_result.params['post_id'] {
					if actual_post_id != expected_post_id {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_tenant := test['expected_tenant'] {
				if actual_tenant := match_result.params['tenant'] {
					if actual_tenant != expected_tenant {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_project_id := test['expected_project_id'] {
				if actual_project_id := match_result.params['project_id'] {
					if actual_project_id != expected_project_id {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_region := test['expected_region'] {
				if actual_region := match_result.params['region'] {
					if actual_region != expected_region {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_category := test['expected_category'] {
				if actual_category := match_result.params['category'] {
					if actual_category != expected_category {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if params_correct {
				subdomain_success++
				println('  ✅ ${test['path']} - ${test['description']}')
			} else {
				println('  ❌ ${test['path']} - ${test['description']} (参数错误)')
			}
		} else {
			println('  ❌ ${test['path']} - ${test['description']} (匹配失败)')
		}
	}
	
	println('  子域名路由测试: ${subdomain_success}/${subdomain_tests.len} 通过')
}

fn test_dynamic_middleware_routes() {
	println('\n📊 动态中间件路由测试...')
	
	mut app := vono.Vono.new()
	
	//Routes that require different middleware
	middleware_routes := [
		//Routes that require authentication
		'/auth/profile/:id',
		'/auth/settings/:section',
		'/auth/admin/:action',
		
		//Routes that require permission checking
		'/protected/users/:id/edit',
		'/protected/posts/:id/delete',
		'/protected/admin/:resource/:action',
		
		//Routes that require current limiting
		'/rate-limited/api/:endpoint',
		'/rate-limited/upload/:type',
		'/rate-limited/search/:query',
		
		//Routes that need to be cached
		'/cached/articles/:id',
		'/cached/products/:category/:id',
		'/cached/static/:resource',
		
		//Routes that require logging
		'/logged/transactions/:id',
		'/logged/audit/:action/:resource',
		'/logged/security/:event/:details'
	]
	
	for route in middleware_routes {
		app.get(route, fn (mut c vono.Context) http.Response {
			return c.text('Middleware route response')
		})
	}
	
	// Middleware routing test
	middleware_tests := [
		{
			'path': '/auth/profile/user123'
			'middleware_type': 'authentication'
			'expected_id': 'user123'
		},
		{
			'path': '/protected/users/456/edit'
			'middleware_type': 'authorization'
			'expected_id': '456'
		},
		{
			'path': '/rate-limited/api/users'
			'middleware_type': 'rate_limiting'
			'expected_endpoint': 'users'
		},
		{
			'path': '/cached/articles/789'
			'middleware_type': 'caching'
			'expected_id': '789'
		},
		{
			'path': '/logged/transactions/txn101'
			'middleware_type': 'logging'
			'expected_id': 'txn101'
		},
		{
			'path': '/logged/audit/delete/user'
			'middleware_type': 'audit_logging'
			'expected_action': 'delete'
			'expected_resource': 'user'
		}
	]
	
	mut middleware_success := 0
	for test in middleware_tests {
		if match_result := app.fast_router.match_route('GET', test['path']) {
			mut params_correct := true
			
			// Verify parameter extraction
			if expected_id := test['expected_id'] {
				if actual_id := match_result.params['id'] {
					if actual_id != expected_id {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_endpoint := test['expected_endpoint'] {
				if actual_endpoint := match_result.params['endpoint'] {
					if actual_endpoint != expected_endpoint {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_action := test['expected_action'] {
				if actual_action := match_result.params['action'] {
					if actual_action != expected_action {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_resource := test['expected_resource'] {
				if actual_resource := match_result.params['resource'] {
					if actual_resource != expected_resource {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if params_correct {
				middleware_success++
				println('  ✅ ${test['path']} - ${test['middleware_type']} 中间件路由')
			} else {
				println('  ❌ ${test['path']} - ${test['middleware_type']} 中间件路由 (参数错误)')
			}
		} else {
			println('  ❌ ${test['path']} - ${test['middleware_type']} 中间件路由 (匹配失败)')
		}
	}
	
	println('  动态中间件路由测试: ${middleware_success}/${middleware_tests.len} 通过')
}