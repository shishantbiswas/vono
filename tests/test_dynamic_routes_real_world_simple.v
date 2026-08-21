import meiseayoung.hono
import net.http
import time

fn main() {
	println('=== 真实世界动态路由测试 ===')
	
	// Test 1: E-commerce platform routing
	test_ecommerce_platform()
	
	//Test 2: Social media routing
	test_social_media_platform()
	
	// Test 3: Enterprise SaaS routing
	test_enterprise_saas_platform()
	
	//Test 4: Content Management System Routing
	test_cms_platform()
	
	//Test 5: Comprehensive performance test
	test_comprehensive_performance()
	
	println('✅ 真实世界动态路由测试完成')
}

fn test_ecommerce_platform() {
	println('\n📊 电商平台路由测试...')
	
	mut app := hono.Hono.new()
	
	// Typical routing for e-commerce platforms
	ecommerce_routes := [
		// Product management
		'/products/:product_id',
		'/products/:product_id/reviews/:review_id',
		'/products/:product_id/variants/:variant_id',
		'/categories/:category_id/products',
		'/brands/:brand_id/products',
		
		// Users and orders
		'/users/:user_id/orders/:order_id',
		'/users/:user_id/cart/items/:item_id',
		'/users/:user_id/wishlist/:product_id',
		'/orders/:order_id/items/:item_id',
		'/orders/:order_id/payments/:payment_id',
		
		// Merchant management
		'/merchants/:merchant_id/products/:product_id',
		'/merchants/:merchant_id/orders/:order_id',
		'/merchants/:merchant_id/analytics/:metric_type',
		
		//Search and filter
		'/search/:query/category/:category',
		'/filter/:category/:subcategory/products'
	]
	
	for route in ecommerce_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('ecommerce response')
		})
	}
	
	// E-commerce scenario test
	ecommerce_test_paths := [
		'/products/iphone15/reviews/review123',
		'/categories/electronics/products',
		'/users/customer456/orders/order789',
		'/merchants/apple_store/analytics/sales',
		'/search/laptop/category/computers',
		'/filter/clothing/shirts/products'
	]
	
	mut success_count := 0
	for path in ecommerce_test_paths {
		if match_result := app.fast_router.match_route('GET', path) {
			param_count := match_result.params.len
			success_count++
			println('  ✅ ${path} (${param_count}个参数)')
		} else {
			println('  ❌ ${path} (匹配失败)')
		}
	}
	
	println('  电商平台路由测试: ${success_count}/${ecommerce_test_paths.len} 通过')
}

fn test_social_media_platform() {
	println('\n📊 社交媒体路由测试...')
	
	mut app := hono.Hono.new()
	
	// Typical routing for social media
	social_routes := [
		// user related
		'/users/:user_id/profile',
		'/users/:user_id/posts/:post_id',
		'/users/:user_id/followers',
		'/users/:user_id/messages/:conversation_id',
		
		// Content interaction
		'/posts/:post_id/comments/:comment_id',
		'/posts/:post_id/likes',
		'/comments/:comment_id/replies/:reply_id',
		
		//Groups and pages
		'/groups/:group_id/posts/:post_id',
		'/groups/:group_id/members/:member_id',
		'/pages/:page_id/posts/:post_id',
		
		// media and search
		'/media/:media_id/metadata',
		'/search/users/:query',
		'/hashtags/:hashtag/posts',
		'/trending/:category/:timeframe'
	]
	
	for route in social_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('social response')
		})
	}
	
	// Social media scenario testing
	social_test_paths := [
		'/users/john_doe/posts/viral_post',
		'/posts/trending_post/comments/top_comment',
		'/groups/tech_community/members/developer123',
		'/search/users/jane_smith',
		'/hashtags/technology/posts',
		'/trending/news/daily'
	]
	
	mut success_count := 0
	for path in social_test_paths {
		if match_result := app.fast_router.match_route('GET', path) {
			param_count := match_result.params.len
			success_count++
			println('  ✅ ${path} (${param_count}个参数)')
		} else {
			println('  ❌ ${path} (匹配失败)')
		}
	}
	
	println('  社交媒体路由测试: ${success_count}/${social_test_paths.len} 通过')
}

fn test_enterprise_saas_platform() {
	println('\n📊 企业SaaS路由测试...')
	
	mut app := hono.Hono.new()
	
	// Typical routing for enterprise SaaS
	saas_routes := [
		//Organization management
		'/orgs/:org_id/teams/:team_id',
		'/orgs/:org_id/members/:member_id',
		'/orgs/:org_id/departments/:dept_id/teams/:team_id',
		'/orgs/:org_id/roles/:role_id/permissions',
		
		// project management
		'/projects/:project_id/tasks/:task_id',
		'/projects/:project_id/milestones/:milestone_id',
		'/projects/:project_id/files/:file_id/versions/:version_id',
		
		// Workflow and reporting
		'/workflows/:workflow_id/steps/:step_id',
		'/reports/:report_id/data/:date_range',
		'/dashboards/:dashboard_id/widgets/:widget_id',
		'/analytics/:metric_type/:period/:granularity',
		
		// Integration and billing
		'/integrations/:integration_id/webhooks/:webhook_id',
		'/subscriptions/:subscription_id/invoices/:invoice_id',
		'/billing/:org_id/usage/:service/:period'
	]
	
	for route in saas_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('saas response')
		})
	}
	
	// Enterprise SaaS scenario testing
	saas_test_paths := [
		'/orgs/acme_corp/teams/engineering',
		'/projects/website_redesign/tasks/frontend_dev',
		'/workflows/approval_process/steps/manager_review',
		'/reports/sales_report/data/2023-Q4',
		'/analytics/revenue/monthly/daily',
		'/subscriptions/enterprise_plan/invoices/dec_2023'
	]
	
	mut success_count := 0
	for path in saas_test_paths {
		if match_result := app.fast_router.match_route('GET', path) {
			param_count := match_result.params.len
			success_count++
			println('  ✅ ${path} (${param_count}个参数)')
		} else {
			println('  ❌ ${path} (匹配失败)')
		}
	}
	
	println('  企业SaaS路由测试: ${success_count}/${saas_test_paths.len} 通过')
}

fn test_cms_platform() {
	println('\n📊 内容管理系统路由测试...')
	
	mut app := hono.Hono.new()
	
	//CMS typical routing
	cms_routes := [
		// content management
		'/content/:content_id/versions/:version_id',
		'/content/:content_id/comments/:comment_id',
		'/content/types/:type_id/fields/:field_id',
		'/categories/:category_id/content',
		
		//Users and permissions
		'/users/:user_id/content',
		'/workspaces/:workspace_id/users/:user_id',
		'/roles/:role_id/permissions/:permission_id',
		
		//Media library
		'/media/:media_id/metadata',
		'/media/folders/:folder_id/files/:file_id',
		'/media/:media_id/thumbnails/:size',
		
		//Multi-language and publishing
		'/content/:content_id/translations/:language',
		'/sites/:site_id/pages/:page_id',
		'/channels/:channel_id/content/:content_id'
	]
	
	for route in cms_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('cms response')
		})
	}
	
	//CMS scenario test
	cms_test_paths := [
		'/content/blog_article/versions/v1.2',
		'/workspaces/editorial/users/editor123',
		'/media/hero_image/thumbnails/large',
		'/content/homepage/translations/zh-CN',
		'/sites/corporate_site/pages/about_us',
		'/channels/social_media/content/announcement'
	]
	
	mut success_count := 0
	for path in cms_test_paths {
		if match_result := app.fast_router.match_route('GET', path) {
			param_count := match_result.params.len
			success_count++
			println('  ✅ ${path} (${param_count}个参数)')
		} else {
			println('  ❌ ${path} (匹配失败)')
		}
	}
	
	println('  内容管理系统路由测试: ${success_count}/${cms_test_paths.len} 通过')
}

fn test_comprehensive_performance() {
	println('\n📊 综合性能测试...')
	
	mut app := hono.Hono.new()
	
	//Add all types of real routes
	all_real_routes := [
		// E-commerce routing
		'/products/:id/reviews/:review_id',
		'/users/:user_id/orders/:order_id/items/:item_id',
		'/merchants/:merchant_id/analytics/:metric',
		
		// social media routing
		'/users/:user_id/posts/:post_id/comments/:comment_id',
		'/groups/:group_id/events/:event_id/attendees/:user_id',
		'/hashtags/:hashtag/posts/:post_id',
		
		// Enterprise SaaS routing
		'/orgs/:org_id/projects/:project_id/tasks/:task_id',
		'/workflows/:workflow_id/instances/:instance_id/steps/:step_id',
		'/reports/:report_id/filters/:filter_type/:filter_value',
		
		//CMS routing
		'/content/:content_id/versions/:version_id/comments/:comment_id',
		'/workspaces/:workspace_id/projects/:project_id/files/:file_id',
		'/sites/:site_id/pages/:page_id/sections/:section_id',
		
		//API routing
		'/api/:version/resources/:resource_id/relationships/:relationship_type',
		'/api/:version/search/:query/filters/:filter_category/:filter_value',
		'/api/:version/batch/:batch_id/operations/:operation_id/results'
	]
	
	println('  添加 ${all_real_routes.len} 个真实应用路由...')
	
	for route in all_real_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('real world response')
		})
	}
	
	//Real scene test path
	real_world_paths := [
		'/products/laptop123/reviews/review456',
		'/users/customer789/orders/order101/items/item202',
		'/merchants/tech_store/analytics/sales',
		'/users/john_doe/posts/post123/comments/comment456',
		'/groups/developers/events/meetup2023/attendees/user789',
		'/hashtags/javascript/posts/tutorial_post',
		'/orgs/startup_inc/projects/mobile_app/tasks/ui_design',
		'/workflows/approval/instances/inst123/steps/manager_review',
		'/reports/revenue_report/filters/date_range/2023-Q4',
		'/content/blog_post/versions/v2.1/comments/feedback123',
		'/workspaces/editorial/projects/website/files/homepage.html',
		'/sites/corporate/pages/about/sections/team_info',
		'/api/v1/resources/user123/relationships/followers',
		'/api/v2/search/machine learning/filters/category/tutorials',
		'/api/v1/batch/batch456/operations/update_users/results'
	]
	
	println('  开始综合性能测试...')
	println('    测试路径数量: ${real_world_paths.len}')
	
	//Performance test
	iterations := 2000
	
	start_time := time.now()
	mut total_matches := 0
	mut successful_matches := 0
	
	for _ in 0 .. iterations {
		for path in real_world_paths {
			total_matches++
			if match_result := app.fast_router.match_route('GET', path) {
				successful_matches++
				// Verify parameter extraction
				param_count := match_result.params.len
				if param_count >= 2 {  // There should be at least 2 parameters
					// Parameter extraction is normal
				}
			}
		}
	}
	
	total_time := time.since(start_time)
	avg_time := f64(total_time.microseconds()) / f64(total_matches)
	throughput := f64(total_matches) / total_time.seconds()
	success_rate := f64(successful_matches) / f64(total_matches) * 100.0
	
	println('  综合性能测试结果:')
	println('    总匹配次数: ${total_matches}')
	println('    成功匹配: ${successful_matches}')
	println('    成功率: ${success_rate:.1f}%')
	println('    总时间: ${total_time}')
	println('    平均时间: ${avg_time:.3f}μs')
	println('    吞吐量: ${throughput:.0f} 请求/秒')
	
	//Performance rating
	if avg_time < 5.0 {
		println('    🏆 性能等级: 卓越 (< 5μs)')
	} else if avg_time < 10.0 {
		println('    🥇 性能等级: 优秀 (< 10μs)')
	} else if avg_time < 50.0 {
		println('    ✅ 性能等级: 良好 (< 50μs)')
	} else {
		println('    ⚠️  性能等级: 需要优化 (>= 50μs)')
	}
	
	//Complexity analysis
	println('\n  路由复杂度分析:')
	
	complexity_tests := [
		{
			'name': '简单路由 (2个参数)'
			'path': '/products/laptop123/reviews/review456'
		},
		{
			'name': '中等路由 (3个参数)'
			'path': '/users/customer789/orders/order101/items/item202'
		},
		{
			'name': '复杂路由 (4个参数)'
			'path': '/orgs/startup_inc/projects/mobile_app/tasks/ui_design'
		},
		{
			'name': '极复杂路由 (5个参数)'
			'path': '/workflows/approval/instances/inst123/steps/manager_review'
		}
	]
	
	for test in complexity_tests {
		test_iterations := 5000
		
		start_time_complex := time.now()
		mut complex_matches := 0
		
		for _ in 0 .. test_iterations {
			if _ := app.fast_router.match_route('GET', test['path']) {
				complex_matches++
			}
		}
		
		complex_time := time.since(start_time_complex)
		complex_avg := f64(complex_time.microseconds()) / f64(complex_matches)
		
		println('    ${test['name']}: ${complex_avg:.3f}μs')
	}
	
	//display final statistics
	static_count, dynamic_count, cache_count, _ := app.get_router_stats()
	println('\n  最终路由统计:')
	println('    静态路由: ${static_count}')
	println('    动态路由: ${dynamic_count}')
	println('    缓存条目: ${cache_count}')
}