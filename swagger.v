// swagger.v - Swagger UI middleware
// This module provides the Swagger UI document interface function, similar to the @hono/swagger-ui middleware of Hono.js
// Support OpenAPI 3.0/3.1 specification
module hono

import net.http

// ============================================================================
// Swagger UI configuration options (Task 7.1)
// ============================================================================

// SwaggerUIOptions - Swagger UI configuration options
// Usage example:
//   app.get('/ui', hono.swagger_ui(hono.SwaggerUIOptions{ url: '/doc' }))
pub struct SwaggerUIOptions {
pub mut:
	url                         string = '/doc'  // OpenAPI documentation URL
	title                       string = 'API Documentation'  // Page title
	deep_linking                bool   = true   // Enable deep linking
	display_request_duration    bool   = true   // Display the request time
	default_models_expand_depth int    = 1      //Model expansion depth
	doc_expansion               string = 'list' //Document expansion method: 'list', 'full', 'none'
	filter                      bool            // enable filtering
	show_extensions             bool            // show extension
	show_common_extensions      bool   = true   //Show commonly used extensions
	try_it_out_enabled          bool   = true   // Enable Try it out
	custom_css                  string          // Custom CSS
	custom_js                   string          // Custom JavaScript
	custom_css_url              string          // Custom CSS URL
	custom_js_url               string          // Custom JavaScript URL
}


// ============================================================================
// Swagger UI HTML generation (Task 7.2)
// ============================================================================

// generate_swagger_html - Generate Swagger UI HTML page
// Use CDN link to load Swagger UI resources
//Apply configuration options to SwaggerUIBundle configuration
fn generate_swagger_html(options SwaggerUIOptions) string {
	// Build custom CSS URL tags
	custom_css_url_tag := if options.custom_css_url.len > 0 {
		'<link rel="stylesheet" href="${options.custom_css_url}">'
	} else {
		''
	}

	// Build a custom JS URL tag
	custom_js_url_tag := if options.custom_js_url.len > 0 {
		'<script src="${options.custom_js_url}"></script>'
	} else {
		''
	}

	// Build custom CSS inline styles
	custom_css_inline := if options.custom_css.len > 0 {
		options.custom_css
	} else {
		''
	}

	// Build custom JS inline script
	custom_js_inline := if options.custom_js.len > 0 {
		options.custom_js
	} else {
		''
	}

	// Convert Boolean value to JavaScript string
	deep_linking_str := if options.deep_linking { 'true' } else { 'false' }
	display_request_duration_str := if options.display_request_duration { 'true' } else { 'false' }
	filter_str := if options.filter { 'true' } else { 'false' }
	show_extensions_str := if options.show_extensions { 'true' } else { 'false' }
	show_common_extensions_str := if options.show_common_extensions { 'true' } else { 'false' }
	try_it_out_enabled_str := if options.try_it_out_enabled { 'true' } else { 'false' }

	return '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${options.title}</title>
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
    ${custom_css_url_tag}
    <style>
        html { box-sizing: border-box; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin: 0; background: #fafafa; }
        ${custom_css_inline}
    </style>
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
    ${custom_js_url_tag}
    <script>
        window.onload = function() {
            const ui = SwaggerUIBundle({
                url: "${options.url}",
                dom_id: \'#swagger-ui\',
                deepLinking: ${deep_linking_str},
                displayRequestDuration: ${display_request_duration_str},
                defaultModelsExpandDepth: ${options.default_models_expand_depth},
                docExpansion: "${options.doc_expansion}",
                filter: ${filter_str},
                showExtensions: ${show_extensions_str},
                showCommonExtensions: ${show_common_extensions_str},
                tryItOutEnabled: ${try_it_out_enabled_str},
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout"
            });
            window.ui = ui;
        };
        ${custom_js_inline}
    </script>
</body>
</html>'
}


// ============================================================================
// Swagger UI middleware function (Task 7.3)
// ============================================================================

// swagger_ui - Create a Swagger UI handler
// Return the processor function, set the correct Content-Type, and return the generated HTML
// Usage example:
//   app.get('/ui', hono.swagger_ui(hono.SwaggerUIOptions{ url: '/doc' }))
// app.get('/docs', hono.swagger_ui()) // Use default options
pub fn swagger_ui(options ...SwaggerUIOptions) fn (mut Context) http.Response {
	// Get options, use default values ​​if not provided
	opts := if options.len > 0 {
		options[0]
	} else {
		SwaggerUIOptions{}
	}

	// Pregenerate HTML content
	html_content := generate_swagger_html(opts)

	return fn [html_content] (mut c Context) http.Response {
		return http.Response{
			status_code: 200
			header:      http.new_header(key: .content_type, value: 'text/html; charset=utf-8')
			body:        html_content
		}
	}
}

// swagger_ui_handler - alias function of swagger_ui
// Usage example:
//   app.get('/swagger', hono.swagger_ui_handler(hono.SwaggerUIOptions{ url: '/api/doc' }))
pub fn swagger_ui_handler(options ...SwaggerUIOptions) fn (mut Context) http.Response {
	return swagger_ui(...options)
}
