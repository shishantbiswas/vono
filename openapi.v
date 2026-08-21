// openapi.v - OpenAPI 3.0/3.1 specification data structure
// This module provides the data structure definition of OpenAPI documents and supports OpenAPI 3.0.x and 3.1.x specifications.
module vono

import x.json2

// ============================================================================
// OpenAPI basic structure (Task 1.1)
// ============================================================================

// OpenAPIContact - contact information
pub struct OpenAPIContact {
pub mut:
	name  string
	url   string
	email string
}

// OpenAPILicense - License information
pub struct OpenAPILicense {
pub mut:
	name string  // required
	url  string
}

// OpenAPIInfo - API basic information
pub struct OpenAPIInfo {
pub mut:
	title            string  // required
	version          string  // required
	description      string
	terms_of_service string
	contact          OpenAPIContact
	license          OpenAPILicense
}

// OpenAPIServer - server information
pub struct OpenAPIServer {
pub mut:
	url         string  // required
	description string
}

// OpenAPIExternalDocs - external documentation
pub struct OpenAPIExternalDocs {
pub mut:
	url         string  // required
	description string
}

// OpenAPITag - tag definition
pub struct OpenAPITag {
pub mut:
	name          string  // required
	description   string
	external_docs OpenAPIExternalDocs
}


// ============================================================================
// OpenAPI path and operation structure (Task 1.2)
// ============================================================================

// OpenAPIMediaType - media type
pub struct OpenAPIMediaType {
pub mut:
	schema  OpenAPISchema
	example string
}

// OpenAPIHeader - response header
pub struct OpenAPIHeader {
pub mut:
	description string
	required    bool
	schema      OpenAPISchema
}

// OpenAPIResponse - response definition
pub struct OpenAPIResponse {
pub mut:
	description string  // required
	headers     map[string]OpenAPIHeader
	content     map[string]OpenAPIMediaType
}

// OpenAPIRequestBody - request body definition
pub struct OpenAPIRequestBody {
pub mut:
	description string
	content     map[string]OpenAPIMediaType  // required
	required    bool
}

// OpenAPIParameter - parameter definition
pub struct OpenAPIParameter {
pub mut:
	name        string  // required
	in_location string  // Required: "path", "query", "header", "cookie"
	description string
	required    bool
	deprecated  bool
	schema      OpenAPISchema
	example     string
}

// OpenAPIOperation - operation definition
pub struct OpenAPIOperation {
pub mut:
	summary      string
	description  string
	operation_id string
	tags         []string
	parameters   []OpenAPIParameter
	request_body OpenAPIRequestBody
	responses    map[string]OpenAPIResponse  // required
	deprecated   bool
	security     []map[string][]string
}

// OpenAPIPathItem - path item
pub struct OpenAPIPathItem {
pub mut:
	get         OpenAPIOperation
	post        OpenAPIOperation
	put         OpenAPIOperation
	delete      OpenAPIOperation
	patch       OpenAPIOperation
	head        OpenAPIOperation
	options     OpenAPIOperation
	summary     string
	description string
	parameters  []OpenAPIParameter
}


// ============================================================================
// OpenAPI Schema and Components structure (Task 1.3)
// ============================================================================

// OpenAPISchema - JSON Schema definition
pub struct OpenAPISchema {
pub mut:
	schema_type  string  // "string", "integer", "number", "boolean", "array", "object"
	format       string  // "int32", "int64", "float", "double", "date", "date-time", etc.
	title        string
	description  string
	default_val  string
	example      string
	enum_values  []string
	required     []string
	properties   map[string]OpenAPISchema
	items        &OpenAPISchema = unsafe { nil }  // for array type
	minimum      f64
	maximum      f64
	min_length   int
	max_length   int
	pattern      string
	nullable     bool
	read_only    bool
	write_only   bool
	ref          string  // $ref reference
}

// OpenAPISecurityScheme - security scheme
pub struct OpenAPISecurityScheme {
pub mut:
	scheme_type   string  // "apiKey", "http", "oauth2", "openIdConnect"
	description   string
	name          string  // for apiKey
	in_location   string  // for apiKey: "query", "header", "cookie"
	scheme        string  // for http: "bearer", "basic"
	bearer_format string  // for http bearer
}

// OpenAPIComponents - reusable components
pub struct OpenAPIComponents {
pub mut:
	schemas          map[string]OpenAPISchema
	responses        map[string]OpenAPIResponse
	parameters       map[string]OpenAPIParameter
	request_bodies   map[string]OpenAPIRequestBody
	headers          map[string]OpenAPIHeader
	security_schemes map[string]OpenAPISecurityScheme
}

// OpenAPIDocument - OpenAPI document main structure
pub struct OpenAPIDocument {
pub mut:
	openapi       string                       // Required: "3.0.0" or "3.1.0"
	info          OpenAPIInfo                  // required
	servers       []OpenAPIServer
	paths         map[string]OpenAPIPathItem   // required
	components    OpenAPIComponents
	security      []map[string][]string
	tags          []OpenAPITag
	external_docs OpenAPIExternalDocs
}


// ============================================================================
// OpenAPI document serialization (Task 2.1)
// ============================================================================

// Helper function to check if a string is empty
fn is_empty(s string) bool {
	return s.len == 0
}

// Helper function to check if a map is empty
fn is_map_empty[K, V](m map[K]V) bool {
	return m.len == 0
}

// Helper function to check if an array is empty
fn is_array_empty[T](arr []T) bool {
	return arr.len == 0
}

// to_json - Serialize OpenAPIContact to JSON
pub fn (c OpenAPIContact) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_empty(c.name) {
		obj['name'] = json2.Any(c.name)
	}
	if !is_empty(c.url) {
		obj['url'] = json2.Any(c.url)
	}
	if !is_empty(c.email) {
		obj['email'] = json2.Any(c.email)
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPILicense to JSON
pub fn (l OpenAPILicense) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// name is required
	obj['name'] = json2.Any(l.name)
	if !is_empty(l.url) {
		obj['url'] = json2.Any(l.url)
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPIInfo to JSON
pub fn (i OpenAPIInfo) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// title and version are required
	obj['title'] = json2.Any(i.title)
	obj['version'] = json2.Any(i.version)
	if !is_empty(i.description) {
		obj['description'] = json2.Any(i.description)
	}
	if !is_empty(i.terms_of_service) {
		obj['termsOfService'] = json2.Any(i.terms_of_service)
	}
	// Only include contact if it has any non-empty fields
	if !is_empty(i.contact.name) || !is_empty(i.contact.url) || !is_empty(i.contact.email) {
		obj['contact'] = i.contact.to_json()
	}
	// Only include license if name is set (required field)
	if !is_empty(i.license.name) {
		obj['license'] = i.license.to_json()
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPIServer to JSON
pub fn (s OpenAPIServer) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// url is required
	obj['url'] = json2.Any(s.url)
	if !is_empty(s.description) {
		obj['description'] = json2.Any(s.description)
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPIExternalDocs to JSON
pub fn (e OpenAPIExternalDocs) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// url is required
	obj['url'] = json2.Any(e.url)
	if !is_empty(e.description) {
		obj['description'] = json2.Any(e.description)
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPITag to JSON
pub fn (t OpenAPITag) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// name is required
	obj['name'] = json2.Any(t.name)
	if !is_empty(t.description) {
		obj['description'] = json2.Any(t.description)
	}
	if !is_empty(t.external_docs.url) {
		obj['externalDocs'] = t.external_docs.to_json()
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPISchema to JSON
pub fn (s OpenAPISchema) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	
	// Handle $ref - if ref is set, only output $ref
	if !is_empty(s.ref) {
		obj[r'$ref'] = json2.Any(s.ref)
		return json2.Any(obj)
	}
	
	// schema_type -> type
	if !is_empty(s.schema_type) {
		obj['type'] = json2.Any(s.schema_type)
	}
	if !is_empty(s.format) {
		obj['format'] = json2.Any(s.format)
	}
	if !is_empty(s.title) {
		obj['title'] = json2.Any(s.title)
	}
	if !is_empty(s.description) {
		obj['description'] = json2.Any(s.description)
	}
	if !is_empty(s.default_val) {
		obj['default'] = json2.Any(s.default_val)
	}
	if !is_empty(s.example) {
		obj['example'] = json2.Any(s.example)
	}
	// enum_values -> enum
	if !is_array_empty(s.enum_values) {
		mut enum_arr := []json2.Any{}
		for v in s.enum_values {
			enum_arr << json2.Any(v)
		}
		obj['enum'] = json2.Any(enum_arr)
	}
	if !is_array_empty(s.required) {
		mut req_arr := []json2.Any{}
		for r in s.required {
			req_arr << json2.Any(r)
		}
		obj['required'] = json2.Any(req_arr)
	}
	if !is_map_empty(s.properties) {
		mut props := map[string]json2.Any{}
		for key, val in s.properties {
			props[key] = val.to_json()
		}
		obj['properties'] = json2.Any(props)
	}
	// items for array type
	if s.items != unsafe { nil } {
		obj['items'] = s.items.to_json()
	}
	if s.minimum != 0 {
		obj['minimum'] = json2.Any(s.minimum)
	}
	if s.maximum != 0 {
		obj['maximum'] = json2.Any(s.maximum)
	}
	if s.min_length != 0 {
		obj['minLength'] = json2.Any(s.min_length)
	}
	if s.max_length != 0 {
		obj['maxLength'] = json2.Any(s.max_length)
	}
	if !is_empty(s.pattern) {
		obj['pattern'] = json2.Any(s.pattern)
	}
	if s.nullable {
		obj['nullable'] = json2.Any(s.nullable)
	}
	if s.read_only {
		obj['readOnly'] = json2.Any(s.read_only)
	}
	if s.write_only {
		obj['writeOnly'] = json2.Any(s.write_only)
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPIHeader to JSON
pub fn (h OpenAPIHeader) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_empty(h.description) {
		obj['description'] = json2.Any(h.description)
	}
	if h.required {
		obj['required'] = json2.Any(h.required)
	}
	// Only include schema if it has content
	if !is_empty(h.schema.schema_type) || !is_empty(h.schema.ref) {
		obj['schema'] = h.schema.to_json()
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPIMediaType to JSON
pub fn (m OpenAPIMediaType) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// Only include schema if it has content
	if !is_empty(m.schema.schema_type) || !is_empty(m.schema.ref) || !is_map_empty(m.schema.properties) {
		obj['schema'] = m.schema.to_json()
	}
	if !is_empty(m.example) {
		obj['example'] = json2.Any(m.example)
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPIResponse to JSON
pub fn (r OpenAPIResponse) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// description is required
	obj['description'] = json2.Any(r.description)
	if !is_map_empty(r.headers) {
		mut headers := map[string]json2.Any{}
		for key, val in r.headers {
			headers[key] = val.to_json()
		}
		obj['headers'] = json2.Any(headers)
	}
	if !is_map_empty(r.content) {
		mut content := map[string]json2.Any{}
		for key, val in r.content {
			content[key] = val.to_json()
		}
		obj['content'] = json2.Any(content)
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPIRequestBody to JSON
pub fn (rb OpenAPIRequestBody) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_empty(rb.description) {
		obj['description'] = json2.Any(rb.description)
	}
	// content is required
	if !is_map_empty(rb.content) {
		mut content := map[string]json2.Any{}
		for key, val in rb.content {
			content[key] = val.to_json()
		}
		obj['content'] = json2.Any(content)
	}
	if rb.required {
		obj['required'] = json2.Any(rb.required)
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPIParameter to JSON
pub fn (p OpenAPIParameter) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// name is required
	obj['name'] = json2.Any(p.name)
	// in_location -> in (required)
	obj['in'] = json2.Any(p.in_location)
	if !is_empty(p.description) {
		obj['description'] = json2.Any(p.description)
	}
	if p.required {
		obj['required'] = json2.Any(p.required)
	}
	if p.deprecated {
		obj['deprecated'] = json2.Any(p.deprecated)
	}
	// Only include schema if it has content
	if !is_empty(p.schema.schema_type) || !is_empty(p.schema.ref) {
		obj['schema'] = p.schema.to_json()
	}
	if !is_empty(p.example) {
		obj['example'] = json2.Any(p.example)
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPIOperation to JSON
pub fn (op OpenAPIOperation) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_empty(op.summary) {
		obj['summary'] = json2.Any(op.summary)
	}
	if !is_empty(op.description) {
		obj['description'] = json2.Any(op.description)
	}
	if !is_empty(op.operation_id) {
		obj['operationId'] = json2.Any(op.operation_id)
	}
	if !is_array_empty(op.tags) {
		mut tags_arr := []json2.Any{}
		for t in op.tags {
			tags_arr << json2.Any(t)
		}
		obj['tags'] = json2.Any(tags_arr)
	}
	if !is_array_empty(op.parameters) {
		mut params_arr := []json2.Any{}
		for p in op.parameters {
			params_arr << p.to_json()
		}
		obj['parameters'] = json2.Any(params_arr)
	}
	// Only include request_body if it has content
	if !is_map_empty(op.request_body.content) {
		obj['requestBody'] = op.request_body.to_json()
	}
	// responses is required
	if !is_map_empty(op.responses) {
		mut responses := map[string]json2.Any{}
		for key, val in op.responses {
			responses[key] = val.to_json()
		}
		obj['responses'] = json2.Any(responses)
	}
	if op.deprecated {
		obj['deprecated'] = json2.Any(op.deprecated)
	}
	if !is_array_empty(op.security) {
		mut sec_arr := []json2.Any{}
		for sec in op.security {
			mut sec_obj := map[string]json2.Any{}
			for key, val in sec {
				mut scopes := []json2.Any{}
				for scope in val {
					scopes << json2.Any(scope)
				}
				sec_obj[key] = json2.Any(scopes)
			}
			sec_arr << json2.Any(sec_obj)
		}
		obj['security'] = json2.Any(sec_arr)
	}
	return json2.Any(obj)
}

// Helper to check if an operation is empty (has no responses)
fn is_operation_empty(op OpenAPIOperation) bool {
	return is_map_empty(op.responses)
}

// to_json - Serialize OpenAPIPathItem to JSON
pub fn (pi OpenAPIPathItem) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_empty(pi.summary) {
		obj['summary'] = json2.Any(pi.summary)
	}
	if !is_empty(pi.description) {
		obj['description'] = json2.Any(pi.description)
	}
	if !is_array_empty(pi.parameters) {
		mut params_arr := []json2.Any{}
		for p in pi.parameters {
			params_arr << p.to_json()
		}
		obj['parameters'] = json2.Any(params_arr)
	}
	// HTTP methods - only include if they have responses
	if !is_operation_empty(pi.get) {
		obj['get'] = pi.get.to_json()
	}
	if !is_operation_empty(pi.post) {
		obj['post'] = pi.post.to_json()
	}
	if !is_operation_empty(pi.put) {
		obj['put'] = pi.put.to_json()
	}
	if !is_operation_empty(pi.delete) {
		obj['delete'] = pi.delete.to_json()
	}
	if !is_operation_empty(pi.patch) {
		obj['patch'] = pi.patch.to_json()
	}
	if !is_operation_empty(pi.head) {
		obj['head'] = pi.head.to_json()
	}
	if !is_operation_empty(pi.options) {
		obj['options'] = pi.options.to_json()
	}
	return json2.Any(obj)
}

// to_json - Serialize OpenAPISecurityScheme to JSON
pub fn (ss OpenAPISecurityScheme) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// scheme_type -> type
	if !is_empty(ss.scheme_type) {
		obj['type'] = json2.Any(ss.scheme_type)
	}
	if !is_empty(ss.description) {
		obj['description'] = json2.Any(ss.description)
	}
	if !is_empty(ss.name) {
		obj['name'] = json2.Any(ss.name)
	}
	// in_location -> in
	if !is_empty(ss.in_location) {
		obj['in'] = json2.Any(ss.in_location)
	}
	if !is_empty(ss.scheme) {
		obj['scheme'] = json2.Any(ss.scheme)
	}
	if !is_empty(ss.bearer_format) {
		obj['bearerFormat'] = json2.Any(ss.bearer_format)
	}
	return json2.Any(obj)
}

// Helper to check if components is empty
fn is_components_empty(c OpenAPIComponents) bool {
	return is_map_empty(c.schemas) && is_map_empty(c.responses) && 
		is_map_empty(c.parameters) && is_map_empty(c.request_bodies) && 
		is_map_empty(c.headers) && is_map_empty(c.security_schemes)
}

// to_json - Serialize OpenAPIComponents to JSON
pub fn (c OpenAPIComponents) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_map_empty(c.schemas) {
		mut schemas := map[string]json2.Any{}
		for key, val in c.schemas {
			schemas[key] = val.to_json()
		}
		obj['schemas'] = json2.Any(schemas)
	}
	if !is_map_empty(c.responses) {
		mut responses := map[string]json2.Any{}
		for key, val in c.responses {
			responses[key] = val.to_json()
		}
		obj['responses'] = json2.Any(responses)
	}
	if !is_map_empty(c.parameters) {
		mut parameters := map[string]json2.Any{}
		for key, val in c.parameters {
			parameters[key] = val.to_json()
		}
		obj['parameters'] = json2.Any(parameters)
	}
	if !is_map_empty(c.request_bodies) {
		mut request_bodies := map[string]json2.Any{}
		for key, val in c.request_bodies {
			request_bodies[key] = val.to_json()
		}
		obj['requestBodies'] = json2.Any(request_bodies)
	}
	if !is_map_empty(c.headers) {
		mut headers := map[string]json2.Any{}
		for key, val in c.headers {
			headers[key] = val.to_json()
		}
		obj['headers'] = json2.Any(headers)
	}
	if !is_map_empty(c.security_schemes) {
		mut security_schemes := map[string]json2.Any{}
		for key, val in c.security_schemes {
			security_schemes[key] = val.to_json()
		}
		obj['securitySchemes'] = json2.Any(security_schemes)
	}
	return json2.Any(obj)
}

// to_json - Serialize an OpenAPIDocument to a JSON Any object
pub fn (doc OpenAPIDocument) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// openapi is required
	obj['openapi'] = json2.Any(doc.openapi)
	// info is required
	obj['info'] = doc.info.to_json()
	// servers (optional)
	if !is_array_empty(doc.servers) {
		mut servers_arr := []json2.Any{}
		for s in doc.servers {
			servers_arr << s.to_json()
		}
		obj['servers'] = json2.Any(servers_arr)
	}
	// paths is required
	mut paths := map[string]json2.Any{}
	for key, val in doc.paths {
		paths[key] = val.to_json()
	}
	obj['paths'] = json2.Any(paths)
	// components (optional)
	if !is_components_empty(doc.components) {
		obj['components'] = doc.components.to_json()
	}
	// security (optional)
	if !is_array_empty(doc.security) {
		mut sec_arr := []json2.Any{}
		for sec in doc.security {
			mut sec_obj := map[string]json2.Any{}
			for key, val in sec {
				mut scopes := []json2.Any{}
				for scope in val {
					scopes << json2.Any(scope)
				}
				sec_obj[key] = json2.Any(scopes)
			}
			sec_arr << json2.Any(sec_obj)
		}
		obj['security'] = json2.Any(sec_arr)
	}
	// tags (optional)
	if !is_array_empty(doc.tags) {
		mut tags_arr := []json2.Any{}
		for t in doc.tags {
			tags_arr << t.to_json()
		}
		obj['tags'] = json2.Any(tags_arr)
	}
	// external_docs (optional)
	if !is_empty(doc.external_docs.url) {
		obj['externalDocs'] = doc.external_docs.to_json()
	}
	return json2.Any(obj)
}

// to_json_str - Serialize an OpenAPIDocument to a JSON string
pub fn (doc OpenAPIDocument) to_json_str() string {
	return doc.to_json().str()
}

// to_json_pretty - Serializes an OpenAPIDocument into a formatted JSON string
pub fn (doc OpenAPIDocument) to_json_pretty() string {
	return json2.encode(doc.to_json(), prettify: true)
}


// ============================================================================
// OpenAPI document deserialization (Task 2.3)
// ============================================================================

// from_json - Deserialize OpenAPIContact from a JSON Any object
pub fn OpenAPIContact.from_json(j json2.Any) OpenAPIContact {
	obj := j.as_map()
	return OpenAPIContact{
		name: if 'name' in obj { obj['name'] or { json2.Any('') }.str() } else { '' }
		url: if 'url' in obj { obj['url'] or { json2.Any('') }.str() } else { '' }
		email: if 'email' in obj { obj['email'] or { json2.Any('') }.str() } else { '' }
	}
}

// from_json - Deserialize OpenAPILicense from a JSON Any object
pub fn OpenAPILicense.from_json(j json2.Any) OpenAPILicense {
	obj := j.as_map()
	return OpenAPILicense{
		name: if 'name' in obj { obj['name'] or { json2.Any('') }.str() } else { '' }
		url: if 'url' in obj { obj['url'] or { json2.Any('') }.str() } else { '' }
	}
}

// from_json - Deserialize OpenAPIInfo from a JSON Any object
pub fn OpenAPIInfo.from_json(j json2.Any) OpenAPIInfo {
	obj := j.as_map()
	return OpenAPIInfo{
		title: if 'title' in obj { obj['title'] or { json2.Any('') }.str() } else { '' }
		version: if 'version' in obj { obj['version'] or { json2.Any('') }.str() } else { '' }
		description: if 'description' in obj { obj['description'] or { json2.Any('') }.str() } else { '' }
		terms_of_service: if 'termsOfService' in obj { obj['termsOfService'] or { json2.Any('') }.str() } else { '' }
		contact: if 'contact' in obj { OpenAPIContact.from_json(obj['contact'] or { json2.Any('') }) } else { OpenAPIContact{} }
		license: if 'license' in obj { OpenAPILicense.from_json(obj['license'] or { json2.Any('') }) } else { OpenAPILicense{} }
	}
}

// from_json - Deserialize OpenAPIServer from JSON Any object
pub fn OpenAPIServer.from_json(j json2.Any) OpenAPIServer {
	obj := j.as_map()
	return OpenAPIServer{
		url: if 'url' in obj { obj['url'] or { json2.Any('') }.str() } else { '' }
		description: if 'description' in obj { obj['description'] or { json2.Any('') }.str() } else { '' }
	}
}

// from_json - Deserialize OpenAPIExternalDocs from a JSON Any object
pub fn OpenAPIExternalDocs.from_json(j json2.Any) OpenAPIExternalDocs {
	obj := j.as_map()
	return OpenAPIExternalDocs{
		url: if 'url' in obj { obj['url'] or { json2.Any('') }.str() } else { '' }
		description: if 'description' in obj { obj['description'] or { json2.Any('') }.str() } else { '' }
	}
}

// from_json - Deserialize OpenAPITag from JSON Any object
pub fn OpenAPITag.from_json(j json2.Any) OpenAPITag {
	obj := j.as_map()
	return OpenAPITag{
		name: if 'name' in obj { obj['name'] or { json2.Any('') }.str() } else { '' }
		description: if 'description' in obj { obj['description'] or { json2.Any('') }.str() } else { '' }
		external_docs: if 'externalDocs' in obj { OpenAPIExternalDocs.from_json(obj['externalDocs'] or { json2.Any('') }) } else { OpenAPIExternalDocs{} }
	}
}

// from_json - Deserialize OpenAPISchema from a JSON Any object
pub fn OpenAPISchema.from_json(j json2.Any) OpenAPISchema {
	return openapi_schema_from_json_impl(j)
}

// Helper function to parse OpenAPISchema from JSON
fn openapi_schema_from_json_impl(j json2.Any) OpenAPISchema {
	obj := j.as_map()
	
	// Parse properties map
	mut props := map[string]OpenAPISchema{}
	if 'properties' in obj {
		props_obj := (obj['properties'] or { json2.Any('') }).as_map()
		for key, val in props_obj {
			props[key] = openapi_schema_from_json_impl(val)
		}
	}
	
	// Parse enum values
	mut enum_vals := []string{}
	if 'enum' in obj {
		for e in (obj['enum'] or { json2.Any('') }).as_array() {
			enum_vals << e.str()
		}
	}
	
	// Parse required array
	mut required := []string{}
	if 'required' in obj {
		for r in (obj['required'] or { json2.Any('') }).as_array() {
			required << r.str()
		}
	}
	
	mut schema := OpenAPISchema{
		schema_type: if 'type' in obj { (obj['type'] or { json2.Any('') }).str() } else { '' }
		format: if 'format' in obj { (obj['format'] or { json2.Any('') }).str() } else { '' }
		title: if 'title' in obj { (obj['title'] or { json2.Any('') }).str() } else { '' }
		description: if 'description' in obj { (obj['description'] or { json2.Any('') }).str() } else { '' }
		default_val: if 'default' in obj { (obj['default'] or { json2.Any('') }).str() } else { '' }
		example: if 'example' in obj { (obj['example'] or { json2.Any('') }).str() } else { '' }
		enum_values: enum_vals
		required: required
		properties: props
		minimum: if 'minimum' in obj { (obj['minimum'] or { json2.Any('') }).f64() } else { 0 }
		maximum: if 'maximum' in obj { (obj['maximum'] or { json2.Any('') }).f64() } else { 0 }
		min_length: if 'minLength' in obj { (obj['minLength'] or { json2.Any('') }).int() } else { 0 }
		max_length: if 'maxLength' in obj { (obj['maxLength'] or { json2.Any('') }).int() } else { 0 }
		pattern: if 'pattern' in obj { (obj['pattern'] or { json2.Any('') }).str() } else { '' }
		nullable: if 'nullable' in obj { (obj['nullable'] or { json2.Any('') }).bool() } else { false }
		read_only: if 'readOnly' in obj { (obj['readOnly'] or { json2.Any('') }).bool() } else { false }
		write_only: if 'writeOnly' in obj { (obj['writeOnly'] or { json2.Any('') }).bool() } else { false }
		ref: if r'$ref' in obj { (obj[r'$ref'] or { json2.Any('') }).str() } else { '' }
	}
	
	// Parse items (for array type) - handle pointer separately
	if 'items' in obj {
		items_schema := openapi_schema_from_json_impl(obj['items'] or { json2.Any('') })
		schema.items = &items_schema
	}
	
	return schema
}

// from_json - Deserialize OpenAPIHeader from JSON Any object
pub fn OpenAPIHeader.from_json(j json2.Any) OpenAPIHeader {
	obj := j.as_map()
	return OpenAPIHeader{
		description: if 'description' in obj { (obj['description'] or { json2.Any('') }).str() } else { '' }
		required: if 'required' in obj { (obj['required'] or { json2.Any('') }).bool() } else { false }
		schema: if 'schema' in obj { OpenAPISchema.from_json(obj['schema'] or { json2.Any('') }) } else { OpenAPISchema{} }
	}
}

// from_json - Deserialize OpenAPIMediaType from JSON Any object
pub fn OpenAPIMediaType.from_json(j json2.Any) OpenAPIMediaType {
	obj := j.as_map()
	return OpenAPIMediaType{
		schema: if 'schema' in obj { OpenAPISchema.from_json(obj['schema'] or { json2.Any('') }) } else { OpenAPISchema{} }
		example: if 'example' in obj { (obj['example'] or { json2.Any('') }).str() } else { '' }
	}
}

// from_json - Deserialize OpenAPIResponse from a JSON Any object
pub fn OpenAPIResponse.from_json(j json2.Any) OpenAPIResponse {
	obj := j.as_map()
	
	// Parse headers map
	mut headers := map[string]OpenAPIHeader{}
	if 'headers' in obj {
		headers_obj := (obj['headers'] or { json2.Any('') }).as_map()
		for key, val in headers_obj {
			headers[key] = OpenAPIHeader.from_json(val)
		}
	}
	
	// Parse content map
	mut content := map[string]OpenAPIMediaType{}
	if 'content' in obj {
		content_obj := (obj['content'] or { json2.Any('') }).as_map()
		for key, val in content_obj {
			content[key] = OpenAPIMediaType.from_json(val)
		}
	}
	
	return OpenAPIResponse{
		description: if 'description' in obj { (obj['description'] or { json2.Any('') }).str() } else { '' }
		headers: headers
		content: content
	}
}

// from_json - Deserialize OpenAPIRequestBody from JSON Any object
pub fn OpenAPIRequestBody.from_json(j json2.Any) OpenAPIRequestBody {
	obj := j.as_map()
	
	// Parse content map
	mut content := map[string]OpenAPIMediaType{}
	if 'content' in obj {
		content_obj := (obj['content'] or { json2.Any('') }).as_map()
		for key, val in content_obj {
			content[key] = OpenAPIMediaType.from_json(val)
		}
	}
	
	return OpenAPIRequestBody{
		description: if 'description' in obj { (obj['description'] or { json2.Any('') }).str() } else { '' }
		content: content
		required: if 'required' in obj { (obj['required'] or { json2.Any('') }).bool() } else { false }
	}
}

// from_json - Deserialize OpenAPIParameter from JSON Any object
pub fn OpenAPIParameter.from_json(j json2.Any) OpenAPIParameter {
	obj := j.as_map()
	return OpenAPIParameter{
		name: if 'name' in obj { (obj['name'] or { json2.Any('') }).str() } else { '' }
		in_location: if 'in' in obj { (obj['in'] or { json2.Any('') }).str() } else { '' }
		description: if 'description' in obj { (obj['description'] or { json2.Any('') }).str() } else { '' }
		required: if 'required' in obj { (obj['required'] or { json2.Any('') }).bool() } else { false }
		deprecated: if 'deprecated' in obj { (obj['deprecated'] or { json2.Any('') }).bool() } else { false }
		schema: if 'schema' in obj { OpenAPISchema.from_json(obj['schema'] or { json2.Any('') }) } else { OpenAPISchema{} }
		example: if 'example' in obj { (obj['example'] or { json2.Any('') }).str() } else { '' }
	}
}

// from_json - Deserialize OpenAPIOperation from JSON Any object
pub fn OpenAPIOperation.from_json(j json2.Any) OpenAPIOperation {
	obj := j.as_map()
	
	// Parse tags array
	mut tags := []string{}
	if 'tags' in obj {
		for t in (obj['tags'] or { json2.Any('') }).as_array() {
			tags << t.str()
		}
	}
	
	// Parse parameters array
	mut parameters := []OpenAPIParameter{}
	if 'parameters' in obj {
		for p in (obj['parameters'] or { json2.Any('') }).as_array() {
			parameters << OpenAPIParameter.from_json(p)
		}
	}
	
	// Parse responses map
	mut responses := map[string]OpenAPIResponse{}
	if 'responses' in obj {
		responses_obj := (obj['responses'] or { json2.Any('') }).as_map()
		for key, val in responses_obj {
			responses[key] = OpenAPIResponse.from_json(val)
		}
	}
	
	// Parse security array
	mut security := []map[string][]string{}
	if 'security' in obj {
		for sec in (obj['security'] or { json2.Any('') }).as_array() {
			mut sec_map := map[string][]string{}
			sec_obj := sec.as_map()
			for key, val in sec_obj {
				mut scopes := []string{}
				for scope in val.as_array() {
					scopes << scope.str()
				}
				sec_map[key] = scopes
			}
			security << sec_map
		}
	}
	
	return OpenAPIOperation{
		summary: if 'summary' in obj { (obj['summary'] or { json2.Any('') }).str() } else { '' }
		description: if 'description' in obj { (obj['description'] or { json2.Any('') }).str() } else { '' }
		operation_id: if 'operationId' in obj { (obj['operationId'] or { json2.Any('') }).str() } else { '' }
		tags: tags
		parameters: parameters
		request_body: if 'requestBody' in obj { OpenAPIRequestBody.from_json(obj['requestBody'] or { json2.Any('') }) } else { OpenAPIRequestBody{} }
		responses: responses
		deprecated: if 'deprecated' in obj { (obj['deprecated'] or { json2.Any('') }).bool() } else { false }
		security: security
	}
}

// from_json - Deserializes an OpenAPIPathItem from a JSON Any object
pub fn OpenAPIPathItem.from_json(j json2.Any) OpenAPIPathItem {
	obj := j.as_map()
	
	// Parse parameters array
	mut parameters := []OpenAPIParameter{}
	if 'parameters' in obj {
		for p in (obj['parameters'] or { json2.Any('') }).as_array() {
			parameters << OpenAPIParameter.from_json(p)
		}
	}
	
	return OpenAPIPathItem{
		summary: if 'summary' in obj { (obj['summary'] or { json2.Any('') }).str() } else { '' }
		description: if 'description' in obj { (obj['description'] or { json2.Any('') }).str() } else { '' }
		parameters: parameters
		get: if 'get' in obj { OpenAPIOperation.from_json(obj['get'] or { json2.Any('') }) } else { OpenAPIOperation{} }
		post: if 'post' in obj { OpenAPIOperation.from_json(obj['post'] or { json2.Any('') }) } else { OpenAPIOperation{} }
		put: if 'put' in obj { OpenAPIOperation.from_json(obj['put'] or { json2.Any('') }) } else { OpenAPIOperation{} }
		delete: if 'delete' in obj { OpenAPIOperation.from_json(obj['delete'] or { json2.Any('') }) } else { OpenAPIOperation{} }
		patch: if 'patch' in obj { OpenAPIOperation.from_json(obj['patch'] or { json2.Any('') }) } else { OpenAPIOperation{} }
		head: if 'head' in obj { OpenAPIOperation.from_json(obj['head'] or { json2.Any('') }) } else { OpenAPIOperation{} }
		options: if 'options' in obj { OpenAPIOperation.from_json(obj['options'] or { json2.Any('') }) } else { OpenAPIOperation{} }
	}
}

// from_json - Deserialize OpenAPISecurityScheme from JSON Any object
pub fn OpenAPISecurityScheme.from_json(j json2.Any) OpenAPISecurityScheme {
	obj := j.as_map()
	return OpenAPISecurityScheme{
		scheme_type: if 'type' in obj { (obj['type'] or { json2.Any('') }).str() } else { '' }
		description: if 'description' in obj { (obj['description'] or { json2.Any('') }).str() } else { '' }
		name: if 'name' in obj { (obj['name'] or { json2.Any('') }).str() } else { '' }
		in_location: if 'in' in obj { (obj['in'] or { json2.Any('') }).str() } else { '' }
		scheme: if 'scheme' in obj { (obj['scheme'] or { json2.Any('') }).str() } else { '' }
		bearer_format: if 'bearerFormat' in obj { (obj['bearerFormat'] or { json2.Any('') }).str() } else { '' }
	}
}

// from_json - Deserializes OpenAPIComponents from JSON Any objects
pub fn OpenAPIComponents.from_json(j json2.Any) OpenAPIComponents {
	obj := j.as_map()
	
	// Parse schemas map
	mut schemas := map[string]OpenAPISchema{}
	if 'schemas' in obj {
		schemas_obj := (obj['schemas'] or { json2.Any('') }).as_map()
		for key, val in schemas_obj {
			schemas[key] = OpenAPISchema.from_json(val)
		}
	}
	
	// Parse responses map
	mut responses := map[string]OpenAPIResponse{}
	if 'responses' in obj {
		responses_obj := (obj['responses'] or { json2.Any('') }).as_map()
		for key, val in responses_obj {
			responses[key] = OpenAPIResponse.from_json(val)
		}
	}
	
	// Parse parameters map
	mut parameters := map[string]OpenAPIParameter{}
	if 'parameters' in obj {
		parameters_obj := (obj['parameters'] or { json2.Any('') }).as_map()
		for key, val in parameters_obj {
			parameters[key] = OpenAPIParameter.from_json(val)
		}
	}
	
	// Parse request_bodies map
	mut request_bodies := map[string]OpenAPIRequestBody{}
	if 'requestBodies' in obj {
		request_bodies_obj := (obj['requestBodies'] or { json2.Any('') }).as_map()
		for key, val in request_bodies_obj {
			request_bodies[key] = OpenAPIRequestBody.from_json(val)
		}
	}
	
	// Parse headers map
	mut headers := map[string]OpenAPIHeader{}
	if 'headers' in obj {
		headers_obj := (obj['headers'] or { json2.Any('') }).as_map()
		for key, val in headers_obj {
			headers[key] = OpenAPIHeader.from_json(val)
		}
	}
	
	// Parse security_schemes map
	mut security_schemes := map[string]OpenAPISecurityScheme{}
	if 'securitySchemes' in obj {
		security_schemes_obj := (obj['securitySchemes'] or { json2.Any('') }).as_map()
		for key, val in security_schemes_obj {
			security_schemes[key] = OpenAPISecurityScheme.from_json(val)
		}
	}
	
	return OpenAPIComponents{
		schemas: schemas
		responses: responses
		parameters: parameters
		request_bodies: request_bodies
		headers: headers
		security_schemes: security_schemes
	}
}

// from_json - Deserializes an OpenAPIDocument from a JSON Any object
pub fn OpenAPIDocument.from_json(j json2.Any) OpenAPIDocument {
	obj := j.as_map()
	
	// Parse servers array
	mut servers := []OpenAPIServer{}
	if 'servers' in obj {
		for s in (obj['servers'] or { json2.Any('') }).as_array() {
			servers << OpenAPIServer.from_json(s)
		}
	}
	
	// Parse paths map
	mut paths := map[string]OpenAPIPathItem{}
	if 'paths' in obj {
		paths_obj := (obj['paths'] or { json2.Any('') }).as_map()
		for key, val in paths_obj {
			paths[key] = OpenAPIPathItem.from_json(val)
		}
	}
	
	// Parse security array
	mut security := []map[string][]string{}
	if 'security' in obj {
		for sec in (obj['security'] or { json2.Any('') }).as_array() {
			mut sec_map := map[string][]string{}
			sec_obj := sec.as_map()
			for key, val in sec_obj {
				mut scopes := []string{}
				for scope in val.as_array() {
					scopes << scope.str()
				}
				sec_map[key] = scopes
			}
			security << sec_map
		}
	}
	
	// Parse tags array
	mut tags := []OpenAPITag{}
	if 'tags' in obj {
		for t in (obj['tags'] or { json2.Any('') }).as_array() {
			tags << OpenAPITag.from_json(t)
		}
	}
	
	return OpenAPIDocument{
		openapi: if 'openapi' in obj { (obj['openapi'] or { json2.Any('') }).str() } else { '' }
		info: if 'info' in obj { OpenAPIInfo.from_json(obj['info'] or { json2.Any('') }) } else { OpenAPIInfo{} }
		servers: servers
		paths: paths
		components: if 'components' in obj { OpenAPIComponents.from_json(obj['components'] or { json2.Any('') }) } else { OpenAPIComponents{} }
		security: security
		tags: tags
		external_docs: if 'externalDocs' in obj { OpenAPIExternalDocs.from_json(obj['externalDocs'] or { json2.Any('') }) } else { OpenAPIExternalDocs{} }
	}
}

// from_json_str - Deserialize an OpenAPIDocument from a JSON string
pub fn OpenAPIDocument.from_json_str(json_str string) !OpenAPIDocument {
	parsed := json2.decode[json2.Any](json_str)!
	return OpenAPIDocument.from_json(parsed)
}


// ============================================================================
// OpenAPI document validation (Task 4.1)
// ============================================================================

// OpenAPIErrorKind - OpenAPI error type
pub enum OpenAPIErrorKind {
	missing_required_field
	invalid_version
	invalid_path
	invalid_parameter
	invalid_schema
	serialization_error
	deserialization_error
}

// OpenAPIError - OpenAPI related error
pub struct OpenAPIError {
	Error
pub:
	kind       OpenAPIErrorKind
	error_msg  string
	path       string  // Optional: problem path
	field      string  // Optional: question field
}

// msg - implements the IError interface
pub fn (e OpenAPIError) msg() string {
	return e.error_msg
}

//Supported OpenAPI versions
const supported_openapi_versions = ['3.0.0', '3.0.1', '3.0.2', '3.0.3', '3.1.0']

// validate - verify the validity of OpenAPIDocument
// Validate required fields, OpenAPI version and path format
//Return descriptive error message
pub fn (doc OpenAPIDocument) validate() ! {
	// 1. Verify required fields: openapi
	if is_empty(doc.openapi) {
		return error("Missing required field 'openapi' in OpenAPI document")
	}
	
	// 2. Verify OpenAPI version (3.0.x, 3.1.x)
	if doc.openapi !in supported_openapi_versions {
		return error("Unsupported OpenAPI version '${doc.openapi}'. Supported versions: ${supported_openapi_versions.join(', ')}")
	}
	
	// 3. Verify required fields: info
	if is_empty(doc.info.title) {
		return error("Missing required field 'info.title' in OpenAPI document")
	}
	
	if is_empty(doc.info.version) {
		return error("Missing required field 'info.version' in OpenAPI document")
	}
	
	// 4. Verify path format
	for path, _ in doc.paths {
		// The path must start with '/'
		if !path.starts_with('/') {
			return error("Invalid path '${path}': paths must start with '/'")
		}
		
		// Check the path parameter format - supports {param} and :param formats
		// Verify bracket matching in {param} format
		mut open_braces := 0
		mut last_open_idx := -1
		for i, c in path {
			if c == `{` {
				open_braces++
				last_open_idx = i
			} else if c == `}` {
				open_braces--
				if open_braces < 0 {
					return error("Invalid path '${path}': unmatched '}' at position ${i}")
				}
			}
		}
		if open_braces > 0 {
			return error("Invalid path '${path}': unmatched '{' at position ${last_open_idx}")
		}
		
		// Check for empty path parameters {} or :
		if path.contains('{}') {
			return error("Invalid path '${path}': empty path parameter '{}'")
		}
		
		// Check for consecutive slashes
		if path.contains('//') {
			return error("Invalid path '${path}': contains consecutive slashes '//'")
		}
	}
	
	//Verification passed
	return
}

// validate_with_details - validate and return all errors (not just the first one)
pub fn (doc OpenAPIDocument) validate_with_details() []OpenAPIError {
	mut errors := []OpenAPIError{}
	
	// 1. Verify required fields: openapi
	if is_empty(doc.openapi) {
		errors << OpenAPIError{
			kind: .missing_required_field
			error_msg: "Missing required field 'openapi' in OpenAPI document"
			field: 'openapi'
		}
	} else if doc.openapi !in supported_openapi_versions {
		// 2. Verify OpenAPI version
		errors << OpenAPIError{
			kind: .invalid_version
			error_msg: "Unsupported OpenAPI version '${doc.openapi}'. Supported versions: ${supported_openapi_versions.join(', ')}"
			field: 'openapi'
		}
	}
	
	// 3. Verify required fields: info
	if is_empty(doc.info.title) {
		errors << OpenAPIError{
			kind: .missing_required_field
			error_msg: "Missing required field 'info.title' in OpenAPI document"
			field: 'info.title'
		}
	}
	
	if is_empty(doc.info.version) {
		errors << OpenAPIError{
			kind: .missing_required_field
			error_msg: "Missing required field 'info.version' in OpenAPI document"
			field: 'info.version'
		}
	}
	
	// 4. Verify path format
	for path, _ in doc.paths {
		// The path must start with '/'
		if !path.starts_with('/') {
			errors << OpenAPIError{
				kind: .invalid_path
				error_msg: "Invalid path '${path}': paths must start with '/'"
				path: path
			}
			continue
		}
		
		// Check path parameter format
		mut open_braces := 0
		mut last_open_idx := -1
		mut has_brace_error := false
		for i, c in path {
			if c == `{` {
				open_braces++
				last_open_idx = i
			} else if c == `}` {
				open_braces--
				if open_braces < 0 {
					errors << OpenAPIError{
						kind: .invalid_path
						error_msg: "Invalid path '${path}': unmatched '}' at position ${i}"
						path: path
					}
					has_brace_error = true
					break
				}
			}
		}
		if !has_brace_error && open_braces > 0 {
			errors << OpenAPIError{
				kind: .invalid_path
				error_msg: "Invalid path '${path}': unmatched '{' at position ${last_open_idx}"
				path: path
			}
		}
		
		// Check for empty path parameters
		if path.contains('{}') {
			errors << OpenAPIError{
				kind: .invalid_path
				error_msg: "Invalid path '${path}': empty path parameter '{}'"
				path: path
			}
		}
		
		// Check for consecutive slashes
		if path.contains('//') {
			errors << OpenAPIError{
				kind: .invalid_path
				error_msg: "Invalid path '${path}': contains consecutive slashes '//'"
				path: path
			}
		}
	}
	
	return errors
}

// is_valid - Check if the document is valid
pub fn (doc OpenAPIDocument) is_valid() bool {
	doc.validate() or { return false }
	return true
}


// ============================================================================
// OpenAPI Document Builder (Task 5)
// ============================================================================

// OpenAPIBuilder - Streaming API builder
// Usage example:
//   doc := OpenAPIBuilder.new()
//       .openapi('3.0.0')
//       .title('My API')
//       .version('1.0.0')
//       .description('API description')
//       .server('https://api.example.com', 'Production server')
//       .tag('users', 'User operations')
//       .path('/users')
//           .get(OpenAPIOperation{ ... })
//           .post(OpenAPIOperation{ ... })
//           .done()
//       .build()!
pub struct OpenAPIBuilder {
mut:
	doc OpenAPIDocument
}

// new - Create a new OpenAPIBuilder instance
pub fn OpenAPIBuilder.new() OpenAPIBuilder {
	return OpenAPIBuilder{
		doc: OpenAPIDocument{
			paths: map[string]OpenAPIPathItem{}
		}
	}
}

// openapi - Set OpenAPI version
pub fn (mut b OpenAPIBuilder) openapi(version string) &OpenAPIBuilder {
	b.doc.openapi = version
	return unsafe { b }
}

// info - Set complete API information
pub fn (mut b OpenAPIBuilder) info(info OpenAPIInfo) &OpenAPIBuilder {
	b.doc.info = info
	return unsafe { b }
}

// title - Set the API title
pub fn (mut b OpenAPIBuilder) title(title string) &OpenAPIBuilder {
	b.doc.info.title = title
	return unsafe { b }
}

// version - set API version
pub fn (mut b OpenAPIBuilder) version(version string) &OpenAPIBuilder {
	b.doc.info.version = version
	return unsafe { b }
}

// description - Set API description
pub fn (mut b OpenAPIBuilder) description(desc string) &OpenAPIBuilder {
	b.doc.info.description = desc
	return unsafe { b }
}

// terms_of_service - Set the terms of service URL
pub fn (mut b OpenAPIBuilder) terms_of_service(url string) &OpenAPIBuilder {
	b.doc.info.terms_of_service = url
	return unsafe { b }
}

// contact - set contact information
pub fn (mut b OpenAPIBuilder) contact(contact OpenAPIContact) &OpenAPIBuilder {
	b.doc.info.contact = contact
	return unsafe { b }
}

// license - set license information
pub fn (mut b OpenAPIBuilder) license(license OpenAPILicense) &OpenAPIBuilder {
	b.doc.info.license = license
	return unsafe { b }
}

// server - add server information
pub fn (mut b OpenAPIBuilder) server(url string, description string) &OpenAPIBuilder {
	b.doc.servers << OpenAPIServer{
		url: url
		description: description
	}
	return unsafe { b }
}

// tag - add tag
pub fn (mut b OpenAPIBuilder) tag(name string, description string) &OpenAPIBuilder {
	b.doc.tags << OpenAPITag{
		name: name
		description: description
	}
	return unsafe { b }
}

// external_docs - Set external documentation
pub fn (mut b OpenAPIBuilder) external_docs(url string, description string) &OpenAPIBuilder {
	b.doc.external_docs = OpenAPIExternalDocs{
		url: url
		description: description
	}
	return unsafe { b }
}

// add_schema - Add a reusable Schema to components
pub fn (mut b OpenAPIBuilder) add_schema(name string, schema OpenAPISchema) &OpenAPIBuilder {
	b.doc.components.schemas[name] = schema
	return unsafe { b }
}

// add_response - Add a reusable Response to components
pub fn (mut b OpenAPIBuilder) add_response(name string, response OpenAPIResponse) &OpenAPIBuilder {
	b.doc.components.responses[name] = response
	return unsafe { b }
}

// add_parameter - Add a reusable Parameter to components
pub fn (mut b OpenAPIBuilder) add_parameter(name string, param OpenAPIParameter) &OpenAPIBuilder {
	b.doc.components.parameters[name] = param
	return unsafe { b }
}

// add_security_scheme - Add security scheme to components
pub fn (mut b OpenAPIBuilder) add_security_scheme(name string, scheme OpenAPISecurityScheme) &OpenAPIBuilder {
	b.doc.components.security_schemes[name] = scheme
	return unsafe { b }
}

// security - add global security requirements
pub fn (mut b OpenAPIBuilder) security(requirements map[string][]string) &OpenAPIBuilder {
	b.doc.security << requirements
	return unsafe { b }
}


// ============================================================================
// OpenAPIPathBuilder - Path builder (Task 5.2)
// ============================================================================

// OpenAPIPathBuilder - path builder
// Used to add HTTP method operations for specific paths
pub struct OpenAPIPathBuilder {
mut:
	parent    &OpenAPIBuilder = unsafe { nil }
	path      string
	path_item OpenAPIPathItem
}

// path - start building path, return OpenAPIPathBuilder
pub fn (mut b OpenAPIBuilder) path(path string) OpenAPIPathBuilder {
	// If the path already exists, get the existing path_item
	existing := b.doc.paths[path] or { OpenAPIPathItem{} }
	return OpenAPIPathBuilder{
		parent: unsafe { b }
		path: path
		path_item: existing
	}
}

// summary - Set path summary
pub fn (mut pb OpenAPIPathBuilder) summary(summary string) &OpenAPIPathBuilder {
	pb.path_item.summary = summary
	return unsafe { pb }
}

// path_description - Set path description
pub fn (mut pb OpenAPIPathBuilder) path_description(description string) &OpenAPIPathBuilder {
	pb.path_item.description = description
	return unsafe { pb }
}

// parameters - set path level parameters
pub fn (mut pb OpenAPIPathBuilder) parameters(params []OpenAPIParameter) &OpenAPIPathBuilder {
	pb.path_item.parameters = params
	return unsafe { pb }
}

// get - add GET operation
pub fn (mut pb OpenAPIPathBuilder) get(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.get = op
	return unsafe { pb }
}

// post - add POST operation
pub fn (mut pb OpenAPIPathBuilder) post(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.post = op
	return unsafe { pb }
}

// put - add PUT operation
pub fn (mut pb OpenAPIPathBuilder) put(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.put = op
	return unsafe { pb }
}

// delete - add DELETE operation
pub fn (mut pb OpenAPIPathBuilder) delete(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.delete = op
	return unsafe { pb }
}

// patch - add PATCH operation
pub fn (mut pb OpenAPIPathBuilder) patch(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.patch = op
	return unsafe { pb }
}

// head - add HEAD operation
pub fn (mut pb OpenAPIPathBuilder) head(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.head = op
	return unsafe { pb }
}

// options - add OPTIONS operation
pub fn (mut pb OpenAPIPathBuilder) options(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.options = op
	return unsafe { pb }
}

// done - Complete path construction and return to parent builder
pub fn (mut pb OpenAPIPathBuilder) done() &OpenAPIBuilder {
	if pb.parent != unsafe { nil } {
		pb.parent.doc.paths[pb.path] = pb.path_item
	}
	return unsafe { pb.parent }
}


// ============================================================================
// OpenAPIBuilder build method (Task 5.3)
// ============================================================================

// build - Build and verify OpenAPI documentation
// Call validate() to validate the document and return an error if validation fails.
pub fn (b OpenAPIBuilder) build() !OpenAPIDocument {
	// Validate document
	b.doc.validate()!
	return b.doc
}

// build_unchecked - build OpenAPI documentation (without validation)
// Used for scenarios where verification needs to be skipped
pub fn (b OpenAPIBuilder) build_unchecked() OpenAPIDocument {
	return b.doc
}

// validate - validate the currently built document
pub fn (b OpenAPIBuilder) validate() ! {
	return b.doc.validate()
}

// get_document - Get the currently built document (does not validate)
pub fn (b OpenAPIBuilder) get_document() OpenAPIDocument {
	return b.doc
}


// ============================================================================
// Routing information extraction (Task 8)
// ============================================================================

// RouteInfo - routing information structure
// Contains the route's path, HTTP method, path parameters and processor information
// Used to automatically generate OpenAPI documentation
pub struct RouteInfo {
pub:
	path        string    // Routing path, such as "/users/:id"
	method      string    // HTTP methods, such as "GET", "POST"
	path_params []string  //Path parameter list, such as ["id"]
	handler     IHandler  // route processor
}

// extract_path_params - extract path parameters from a path
// Support path parameters in :param format
// For example: "/users/:id/posts/:postId" -> ["id", "postId"]
fn extract_path_params(path string) []string {
	mut params := []string{}
	segments := path.split('/')
	for segment in segments {
		if segment.starts_with(':') && segment.len > 1 {
			//Extract parameter name (remove colon)
			param_name := segment[1..]
			params << param_name
		}
	}
	return params
}

// get_routes - Get all routing information of the application
// Traverse all registered routes, including sub-application routes
//Extract path parameters
// Return RouteInfo array
pub fn (app Vono) get_routes() []RouteInfo {
	mut routes := []RouteInfo{}
	
	// Get all routes from context_router
	// GET route
	for handler in app.context_router.handlers.get {
		routes << RouteInfo{
			path: handler.path
			method: 'GET'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// POST routing
	for handler in app.context_router.handlers.post {
		routes << RouteInfo{
			path: handler.path
			method: 'POST'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	//PUT routing
	for handler in app.context_router.handlers.put {
		routes << RouteInfo{
			path: handler.path
			method: 'PUT'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// DELETE route
	for handler in app.context_router.handlers.delete {
		routes << RouteInfo{
			path: handler.path
			method: 'DELETE'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// PATCH route
	for handler in app.context_router.handlers.patch {
		routes << RouteInfo{
			path: handler.path
			method: 'PATCH'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// HEAD route
	for handler in app.context_router.handlers.head {
		routes << RouteInfo{
			path: handler.path
			method: 'HEAD'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	//OPTIONS routing
	for handler in app.context_router.handlers.options {
		routes << RouteInfo{
			path: handler.path
			method: 'OPTIONS'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// Get the route from the sub-application (already merged into the main application in the route() method)
	// The routes of the sub-application have been added to context_router through merge_routes_for_method
	// So the above traversal already contains the routes of the sub-application
	
	return routes
}

// generate_openapi_paths - Generate OpenAPI paths from routing information
// Convert RouteInfo array to OpenAPI PathItem map
pub fn generate_openapi_paths(routes []RouteInfo) map[string]OpenAPIPathItem {
	mut paths := map[string]OpenAPIPathItem{}
	
	for route in routes {
		// Convert :param format to {param} format (OpenAPI standard)
		openapi_path := convert_path_to_openapi_format(route.path)
		
		// Get or create PathItem
		mut path_item := paths[openapi_path] or { OpenAPIPathItem{} }
		
		//Create a basic Operation
		mut operation := OpenAPIOperation{
			responses: {
				'200': OpenAPIResponse{
					description: 'Successful response'
				}
			}
		}
		
		//Add path parameters
		for param_name in route.path_params {
			operation.parameters << OpenAPIParameter{
				name: param_name
				in_location: 'path'
				required: true
				schema: OpenAPISchema{
					schema_type: 'string'
				}
			}
		}
		
		//Set the action based on the HTTP method
		match route.method {
			'GET' { path_item.get = operation }
			'POST' { path_item.post = operation }
			'PUT' { path_item.put = operation }
			'DELETE' { path_item.delete = operation }
			'PATCH' { path_item.patch = operation }
			'HEAD' { path_item.head = operation }
			'OPTIONS' { path_item.options = operation }
			else {}
		}
		
		paths[openapi_path] = path_item
	}
	
	return paths
}

// convert_path_to_openapi_format - Convert vono path format to OpenAPI format
//Convert :param to {param}
// For example: "/users/:id" -> "/users/{id}"
fn convert_path_to_openapi_format(path string) string {
	mut result := path
	segments := path.split('/')
	for segment in segments {
		if segment.starts_with(':') && segment.len > 1 {
			param_name := segment[1..]
			result = result.replace(':${param_name}', '{${param_name}}')
		}
	}
	return result
}
