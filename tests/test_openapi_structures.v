// test_openapi_structures.v - Test OpenAPI data structures
import meiseayoung.vono

// OpenAPI data structure test
// Test the data structure definition of OpenAPI 3.0/3.1 specification

struct TestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats TestStats) run_test(test_name string, test_func fn () bool) {
	stats.total_tests++
	print('🧪 ${test_name}... ')

	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats TestStats) print_summary() {
	println('\n=== OpenAPI 数据结构测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

//Test 1: OpenAPIContact structure
fn test_openapi_contact() bool {
	contact := vono.OpenAPIContact{
		name: 'API Support'
		url: 'https://example.com/support'
		email: 'support@example.com'
	}
	return contact.name == 'API Support' && 
		contact.url == 'https://example.com/support' && 
		contact.email == 'support@example.com'
}

//Test 2: OpenAPILicense structure
fn test_openapi_license() bool {
	license := vono.OpenAPILicense{
		name: 'MIT'
		url: 'https://opensource.org/licenses/MIT'
	}
	return license.name == 'MIT' && 
		license.url == 'https://opensource.org/licenses/MIT'
}

//Test 3: OpenAPIInfo structure
fn test_openapi_info() bool {
	info := vono.OpenAPIInfo{
		title: 'My API'
		version: '1.0.0'
		description: 'A sample API'
		terms_of_service: 'https://example.com/tos'
		contact: vono.OpenAPIContact{
			name: 'Support'
		}
		license: vono.OpenAPILicense{
			name: 'MIT'
		}
	}
	return info.title == 'My API' && 
		info.version == '1.0.0' && 
		info.description == 'A sample API'
}

//Test 4: OpenAPIServer structure
fn test_openapi_server() bool {
	server := vono.OpenAPIServer{
		url: 'https://api.example.com'
		description: 'Production server'
	}
	return server.url == 'https://api.example.com' && 
		server.description == 'Production server'
}

//Test 5: OpenAPITag structure
fn test_openapi_tag() bool {
	tag := vono.OpenAPITag{
		name: 'users'
		description: 'User operations'
		external_docs: vono.OpenAPIExternalDocs{
			url: 'https://docs.example.com/users'
			description: 'User documentation'
		}
	}
	return tag.name == 'users' && 
		tag.description == 'User operations'
}

//Test 6: OpenAPIParameter structure
fn test_openapi_parameter() bool {
	param := vono.OpenAPIParameter{
		name: 'id'
		in_location: 'path'
		description: 'User ID'
		required: true
		deprecated: false
		schema: vono.OpenAPISchema{
			schema_type: 'integer'
			format: 'int64'
		}
	}
	return param.name == 'id' && 
		param.in_location == 'path' && 
		param.required == true
}

//Test 7: OpenAPIResponse structure
fn test_openapi_response() bool {
	response := vono.OpenAPIResponse{
		description: 'Successful response'
		content: {
			'application/json': vono.OpenAPIMediaType{
				schema: vono.OpenAPISchema{
					schema_type: 'object'
				}
			}
		}
	}
	return response.description == 'Successful response' && 
		'application/json' in response.content
}

//Test 8: OpenAPIOperation structure
fn test_openapi_operation() bool {
	op := vono.OpenAPIOperation{
		summary: 'Get user'
		description: 'Get user by ID'
		operation_id: 'getUser'
		tags: ['users']
		responses: {
			'200': vono.OpenAPIResponse{
				description: 'Success'
			}
		}
	}
	return op.summary == 'Get user' && 
		op.operation_id == 'getUser' && 
		'users' in op.tags
}

//Test 9: OpenAPIPathItem structure
fn test_openapi_path_item() bool {
	path_item := vono.OpenAPIPathItem{
		summary: 'User operations'
		get: vono.OpenAPIOperation{
			summary: 'Get user'
			responses: {
				'200': vono.OpenAPIResponse{
					description: 'Success'
				}
			}
		}
		post: vono.OpenAPIOperation{
			summary: 'Create user'
			responses: {
				'201': vono.OpenAPIResponse{
					description: 'Created'
				}
			}
		}
	}
	return path_item.summary == 'User operations' && 
		path_item.get.summary == 'Get user' && 
		path_item.post.summary == 'Create user'
}

//Test 10: OpenAPISchema structure
fn test_openapi_schema() bool {
	schema := vono.OpenAPISchema{
		schema_type: 'object'
		title: 'User'
		description: 'User object'
		required: ['id', 'name']
		properties: {
			'id': vono.OpenAPISchema{
				schema_type: 'integer'
				format: 'int64'
			}
			'name': vono.OpenAPISchema{
				schema_type: 'string'
			}
		}
	}
	return schema.schema_type == 'object' && 
		schema.title == 'User' && 
		'id' in schema.required && 
		'name' in schema.properties
}

//Test 11: OpenAPISecurityScheme structure
fn test_openapi_security_scheme() bool {
	scheme := vono.OpenAPISecurityScheme{
		scheme_type: 'http'
		description: 'Bearer token authentication'
		scheme: 'bearer'
		bearer_format: 'JWT'
	}
	return scheme.scheme_type == 'http' && 
		scheme.scheme == 'bearer' && 
		scheme.bearer_format == 'JWT'
}

// Test 12: OpenAPIComponents structure
fn test_openapi_components() bool {
	components := vono.OpenAPIComponents{
		schemas: {
			'User': vono.OpenAPISchema{
				schema_type: 'object'
			}
		}
		security_schemes: {
			'bearerAuth': vono.OpenAPISecurityScheme{
				scheme_type: 'http'
				scheme: 'bearer'
			}
		}
	}
	return 'User' in components.schemas && 
		'bearerAuth' in components.security_schemes
}

//Test 13: OpenAPIDocument structure
fn test_openapi_document() bool {
	doc := vono.OpenAPIDocument{
		openapi: '3.0.0'
		info: vono.OpenAPIInfo{
			title: 'My API'
			version: '1.0.0'
		}
		servers: [
			vono.OpenAPIServer{
				url: 'https://api.example.com'
			}
		]
		paths: {
			'/users': vono.OpenAPIPathItem{
				get: vono.OpenAPIOperation{
					summary: 'List users'
					responses: {
						'200': vono.OpenAPIResponse{
							description: 'Success'
						}
					}
				}
			}
		}
		tags: [
			vono.OpenAPITag{
				name: 'users'
			}
		]
	}
	return doc.openapi == '3.0.0' && 
		doc.info.title == 'My API' && 
		'/users' in doc.paths
}

// Test 14: Parameter position support (path, query, header, cookie)
fn test_parameter_locations() bool {
	locations := ['path', 'query', 'header', 'cookie']
	for loc in locations {
		param := vono.OpenAPIParameter{
			name: 'test'
			in_location: loc
		}
		if param.in_location != loc {
			return false
		}
	}
	return true
}

// Test 15: HTTP method support
fn test_http_methods() bool {
	path_item := vono.OpenAPIPathItem{
		get: vono.OpenAPIOperation{
			summary: 'GET'
			responses: {'200': vono.OpenAPIResponse{description: 'OK'}}
		}
		post: vono.OpenAPIOperation{
			summary: 'POST'
			responses: {'201': vono.OpenAPIResponse{description: 'Created'}}
		}
		put: vono.OpenAPIOperation{
			summary: 'PUT'
			responses: {'200': vono.OpenAPIResponse{description: 'OK'}}
		}
		delete: vono.OpenAPIOperation{
			summary: 'DELETE'
			responses: {'204': vono.OpenAPIResponse{description: 'No Content'}}
		}
		patch: vono.OpenAPIOperation{
			summary: 'PATCH'
			responses: {'200': vono.OpenAPIResponse{description: 'OK'}}
		}
		head: vono.OpenAPIOperation{
			summary: 'HEAD'
			responses: {'200': vono.OpenAPIResponse{description: 'OK'}}
		}
		options: vono.OpenAPIOperation{
			summary: 'OPTIONS'
			responses: {'200': vono.OpenAPIResponse{description: 'OK'}}
		}
	}
	return path_item.get.summary == 'GET' && 
		path_item.post.summary == 'POST' && 
		path_item.put.summary == 'PUT' && 
		path_item.delete.summary == 'DELETE' && 
		path_item.patch.summary == 'PATCH' && 
		path_item.head.summary == 'HEAD' && 
		path_item.options.summary == 'OPTIONS'
}

fn main() {
	println('🚀 开始 OpenAPI 数据结构测试...\n')

	mut stats := TestStats{}

	//Run all tests
	stats.run_test('OpenAPIContact 结构体', test_openapi_contact)
	stats.run_test('OpenAPILicense 结构体', test_openapi_license)
	stats.run_test('OpenAPIInfo 结构体', test_openapi_info)
	stats.run_test('OpenAPIServer 结构体', test_openapi_server)
	stats.run_test('OpenAPITag 结构体', test_openapi_tag)
	stats.run_test('OpenAPIParameter 结构体', test_openapi_parameter)
	stats.run_test('OpenAPIResponse 结构体', test_openapi_response)
	stats.run_test('OpenAPIOperation 结构体', test_openapi_operation)
	stats.run_test('OpenAPIPathItem 结构体', test_openapi_path_item)
	stats.run_test('OpenAPISchema 结构体', test_openapi_schema)
	stats.run_test('OpenAPISecurityScheme 结构体', test_openapi_security_scheme)
	stats.run_test('OpenAPIComponents 结构体', test_openapi_components)
	stats.run_test('OpenAPIDocument 结构体', test_openapi_document)
	stats.run_test('参数位置支持', test_parameter_locations)
	stats.run_test('HTTP 方法支持', test_http_methods)

	//Print test summary
	stats.print_summary()
}
