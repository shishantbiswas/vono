// test_openapi_serialization.v - Test OpenAPI serialization and deserialization
// **Feature: swagger-ui, Property 1: OpenAPI Document Round-Trip Serialization**
// **Validates: Requirements 3.1, 3.2, 3.4**
module main

import vono
import x.json2

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
	println('\n=== OpenAPI 序列化测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

// Test 1: OpenAPIDocument to_json_str basic function
fn test_document_to_json_str() bool {
	doc := vono.OpenAPIDocument{
		openapi: '3.0.0'
		info: vono.OpenAPIInfo{
			title: 'Test API'
			version: '1.0.0'
		}
		paths: {
			'/users': vono.OpenAPIPathItem{
				get: vono.OpenAPIOperation{
					summary: 'Get users'
					responses: {
						'200': vono.OpenAPIResponse{
							description: 'Success'
						}
					}
				}
			}
		}
	}
	
	json_str := doc.to_json_str()
	has_openapi := json_str.contains('"openapi":"3.0.0"')
	has_title := json_str.contains('"title":"Test API"')
	has_users := json_str.contains('"/users"')
	return has_openapi && has_title && has_users
}

// Test 2: Field name mapping (schema_type -> type, in_location -> in)
fn test_field_name_mapping() bool {
	param := vono.OpenAPIParameter{
		name: 'id'
		in_location: 'path'
		schema: vono.OpenAPISchema{
			schema_type: 'integer'
		}
	}
	
	json_any := param.to_json()
	json_str := json_any.str()
	
	// Should use 'in' not 'in_location', 'type' not 'schema_type'
	has_in := json_str.contains('"in":"path"')
	has_type := json_str.contains('"type":"integer"')
	no_in_location := !json_str.contains('in_location')
	no_schema_type := !json_str.contains('schema_type')
	return has_in && has_type && no_in_location && no_schema_type
}

//Test 3: ref field mapping
fn test_ref_field_mapping() bool {
	schema := vono.OpenAPISchema{
		ref: '#/components/schemas/User'
	}
	
	json_any := schema.to_json()
	json_str := json_any.str()
	
	return json_str.contains(r'"$ref":"#/components/schemas/User"')
}

// Test 4: Optional fields omitted - empty string should not be present
fn test_optional_fields_omission_strings() bool {
	info := vono.OpenAPIInfo{
		title: 'Test'
		version: '1.0.0'
		// description is empty, should be omitted
	}
	
	json_any := info.to_json()
	json_str := json_any.str()
	
	no_desc := !json_str.contains('"description"')
	has_title := json_str.contains('"title":"Test"')
	has_version := json_str.contains('"version":"1.0.0"')
	return no_desc && has_title && has_version
}

// Test 5: Optional fields omitted - empty array should not be present
fn test_optional_fields_omission_arrays() bool {
	doc := vono.OpenAPIDocument{
		openapi: '3.0.0'
		info: vono.OpenAPIInfo{
			title: 'Test'
			version: '1.0.0'
		}
		paths: {}
		// servers is empty, should be omitted
		// tags is empty, should be omitted
	}
	
	json_str := doc.to_json_str()
	
	no_servers := !json_str.contains('"servers"')
	no_tags := !json_str.contains('"tags"')
	return no_servers && no_tags
}

// Test 6: Optional fields omitted - empty map should not appear
fn test_optional_fields_omission_maps() bool {
	doc := vono.OpenAPIDocument{
		openapi: '3.0.0'
		info: vono.OpenAPIInfo{
			title: 'Test'
			version: '1.0.0'
		}
		paths: {}
		// components is empty, should be omitted
	}
	
	json_str := doc.to_json_str()
	
	return !json_str.contains('"components"')
}

// Test 7: boolean false should not appear (unless required)
fn test_optional_boolean_omission() bool {
	param := vono.OpenAPIParameter{
		name: 'test'
		in_location: 'query'
		required: false  // should be omitted
		deprecated: false  // should be omitted
	}
	
	json_any := param.to_json()
	json_str := json_any.str()
	
	no_required := !json_str.contains('"required"')
	no_deprecated := !json_str.contains('"deprecated"')
	return no_required && no_deprecated
}

// Test 8: boolean true should appear
fn test_boolean_true_included() bool {
	param := vono.OpenAPIParameter{
		name: 'test'
		in_location: 'query'
		required: true
		deprecated: true
	}
	
	json_any := param.to_json()
	json_str := json_any.str()
	
	has_required := json_str.contains('"required":true')
	has_deprecated := json_str.contains('"deprecated":true')
	return has_required && has_deprecated
}

// Test 9: Nested structure serialization
fn test_nested_structure_serialization() bool {
	doc := vono.OpenAPIDocument{
		openapi: '3.0.0'
		info: vono.OpenAPIInfo{
			title: 'Test API'
			version: '1.0.0'
			contact: vono.OpenAPIContact{
				name: 'Support'
				email: 'support@example.com'
			}
		}
		paths: {
			'/users': vono.OpenAPIPathItem{
				get: vono.OpenAPIOperation{
					summary: 'Get users'
					parameters: [
						vono.OpenAPIParameter{
							name: 'limit'
							in_location: 'query'
							schema: vono.OpenAPISchema{
								schema_type: 'integer'
							}
						}
					]
					responses: {
						'200': vono.OpenAPIResponse{
							description: 'Success'
							content: {
								'application/json': vono.OpenAPIMediaType{
									schema: vono.OpenAPISchema{
										schema_type: 'array'
									}
								}
							}
						}
					}
				}
			}
		}
	}
	
	json_str := doc.to_json_str()
	
	has_contact := json_str.contains('"contact"')
	has_email := json_str.contains('"email":"support@example.com"')
	has_params := json_str.contains('"parameters"')
	has_content := json_str.contains('"content"')
	has_json := json_str.contains('"application/json"')
	return has_contact && has_email && has_params && has_content && has_json
}

//Test 10: to_json_pretty formatted output
fn test_to_json_pretty() bool {
	doc := vono.OpenAPIDocument{
		openapi: '3.0.0'
		info: vono.OpenAPIInfo{
			title: 'Test'
			version: '1.0.0'
		}
		paths: {}
	}
	
	pretty_json := doc.to_json_pretty()
	
	// Pretty JSON should contain newlines and indentation
	has_newline := pretty_json.contains('\n')
	has_indent := pretty_json.contains('  ')
	return has_newline && has_indent
}

// Test 11: Deserialization basic functionality
fn test_from_json_basic() bool {
	json_str := '{"openapi":"3.0.0","info":{"title":"Test API","version":"1.0.0"},"paths":{}}'
	
	doc := vono.OpenAPIDocument.from_json_str(json_str) or {
		println('Error: ${err}')
		return false
	}
	
	ok_openapi := doc.openapi == '3.0.0'
	ok_title := doc.info.title == 'Test API'
	ok_version := doc.info.version == '1.0.0'
	return ok_openapi && ok_title && ok_version
}

// Test 12: Deserialize nested structure
fn test_from_json_nested() bool {
	json_str := '{"openapi":"3.0.0","info":{"title":"Test","version":"1.0.0","contact":{"name":"Support","email":"test@example.com"}},"paths":{"/users":{"get":{"summary":"Get users","responses":{"200":{"description":"OK"}}}}}}'
	
	doc := vono.OpenAPIDocument.from_json_str(json_str) or {
		println('Error: ${err}')
		return false
	}
	
	ok_contact_name := doc.info.contact.name == 'Support'
	ok_contact_email := doc.info.contact.email == 'test@example.com'
	ok_has_users := '/users' in doc.paths
	users_path := doc.paths['/users'] or { return false }
	ok_summary := users_path.get.summary == 'Get users'
	return ok_contact_name && ok_contact_email && ok_has_users && ok_summary
}

// Test 13: Deserialize field name mapping (in -> in_location, type -> schema_type)
fn test_from_json_field_mapping() bool {
	json_str := '{"name":"id","in":"path","schema":{"type":"integer"}}'
	
	parsed := json2.decode[json2.Any](json_str) or {
		return false
	}
	
	param := vono.OpenAPIParameter.from_json(parsed)
	
	ok_name := param.name == 'id'
	ok_in := param.in_location == 'path'
	ok_type := param.schema.schema_type == 'integer'
	return ok_name && ok_in && ok_type
}

// Test 14: Round trip serialization - simple documentation
fn test_round_trip_simple() bool {
	original := vono.OpenAPIDocument{
		openapi: '3.0.0'
		info: vono.OpenAPIInfo{
			title: 'Test API'
			version: '1.0.0'
			description: 'A test API'
		}
		paths: {
			'/health': vono.OpenAPIPathItem{
				get: vono.OpenAPIOperation{
					summary: 'Health check'
					responses: {
						'200': vono.OpenAPIResponse{
							description: 'OK'
						}
					}
				}
			}
		}
	}
	
	// Serialize
	json_str := original.to_json_str()
	
	// Deserialize
	restored := vono.OpenAPIDocument.from_json_str(json_str) or {
		println('Error: ${err}')
		return false
	}
	
	// Compare
	ok_openapi := restored.openapi == original.openapi
	ok_title := restored.info.title == original.info.title
	ok_version := restored.info.version == original.info.version
	ok_desc := restored.info.description == original.info.description
	ok_has_health := '/health' in restored.paths
	restored_health := restored.paths['/health'] or { return false }
	original_health := original.paths['/health'] or { return false }
	ok_summary := restored_health.get.summary == original_health.get.summary
	return ok_openapi && ok_title && ok_version && ok_desc && ok_has_health && ok_summary
}

// Test 15: Round trip serialization - complex documents
fn test_round_trip_complex() bool {
	original := vono.OpenAPIDocument{
		openapi: '3.1.0'
		info: vono.OpenAPIInfo{
			title: 'Complex API'
			version: '2.0.0'
			description: 'A complex test API'
			contact: vono.OpenAPIContact{
				name: 'API Support'
				email: 'support@example.com'
				url: 'https://example.com/support'
			}
			license: vono.OpenAPILicense{
				name: 'MIT'
				url: 'https://opensource.org/licenses/MIT'
			}
		}
		servers: [
			vono.OpenAPIServer{
				url: 'https://api.example.com'
				description: 'Production'
			}
		]
		paths: {
			'/users': vono.OpenAPIPathItem{
				get: vono.OpenAPIOperation{
					summary: 'List users'
					operation_id: 'listUsers'
					tags: ['users']
					parameters: [
						vono.OpenAPIParameter{
							name: 'limit'
							in_location: 'query'
							required: false
							schema: vono.OpenAPISchema{
								schema_type: 'integer'
								minimum: 1
								maximum: 100
							}
						}
					]
					responses: {
						'200': vono.OpenAPIResponse{
							description: 'Success'
							content: {
								'application/json': vono.OpenAPIMediaType{
									schema: vono.OpenAPISchema{
										schema_type: 'array'
									}
								}
							}
						}
					}
				}
				post: vono.OpenAPIOperation{
					summary: 'Create user'
					operation_id: 'createUser'
					tags: ['users']
					request_body: vono.OpenAPIRequestBody{
						required: true
						content: {
							'application/json': vono.OpenAPIMediaType{
								schema: vono.OpenAPISchema{
									schema_type: 'object'
									required: ['name', 'email']
									properties: {
										'name': vono.OpenAPISchema{
											schema_type: 'string'
										}
										'email': vono.OpenAPISchema{
											schema_type: 'string'
											format: 'email'
										}
									}
								}
							}
						}
					}
					responses: {
						'201': vono.OpenAPIResponse{
							description: 'Created'
						}
					}
				}
			}
		}
		tags: [
			vono.OpenAPITag{
				name: 'users'
				description: 'User operations'
			}
		]
	}
	
	// Serialize
	json_str := original.to_json_str()
	
	// Deserialize
	restored := vono.OpenAPIDocument.from_json_str(json_str) or {
		println('Error: ${err}')
		return false
	}
	
	// Compare key fields
	ok_openapi := restored.openapi == original.openapi
	ok_title := restored.info.title == original.info.title
	ok_contact := restored.info.contact.name == original.info.contact.name
	ok_license := restored.info.license.name == original.info.license.name
	ok_servers_len := restored.servers.len == original.servers.len
	ok_server_url := restored.servers[0].url == original.servers[0].url
	ok_has_users := '/users' in restored.paths
	restored_users := restored.paths['/users'] or { return false }
	ok_get_op := restored_users.get.operation_id == 'listUsers'
	ok_post_op := restored_users.post.operation_id == 'createUser'
	ok_tags_len := restored.tags.len == original.tags.len
	ok_tag_name := restored.tags[0].name == 'users'
	
	return ok_openapi && ok_title && ok_contact && ok_license && ok_servers_len && ok_server_url && ok_has_users && ok_get_op && ok_post_op && ok_tags_len && ok_tag_name
}

fn main() {
	println('🚀 开始 OpenAPI 序列化测试...\n')

	mut stats := TestStats{}

	// Serialization test
	stats.run_test('to_json_str 基本功能', test_document_to_json_str)
	stats.run_test('字段名映射 (schema_type->type, in_location->in)', test_field_name_mapping)
	stats.run_test('ref 字段映射', test_ref_field_mapping)
	stats.run_test('可选字段省略 - 空字符串', test_optional_fields_omission_strings)
	stats.run_test('可选字段省略 - 空数组', test_optional_fields_omission_arrays)
	stats.run_test('可选字段省略 - 空 map', test_optional_fields_omission_maps)
	stats.run_test('布尔值 false 省略', test_optional_boolean_omission)
	stats.run_test('布尔值 true 包含', test_boolean_true_included)
	stats.run_test('嵌套结构序列化', test_nested_structure_serialization)
	stats.run_test('to_json_pretty 格式化', test_to_json_pretty)
	
	//Deserialization test
	stats.run_test('from_json 基本功能', test_from_json_basic)
	stats.run_test('from_json 嵌套结构', test_from_json_nested)
	stats.run_test('from_json 字段名映射', test_from_json_field_mapping)
	
	// round trip test
	stats.run_test('往返序列化 - 简单文档', test_round_trip_simple)
	stats.run_test('往返序列化 - 复杂文档', test_round_trip_complex)

	//Print test summary
	stats.print_summary()
}
