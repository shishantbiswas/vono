module vono

// Trie routing node type
enum TrieNodeType {
	static
	param
	wildcard
}

// Context Trie routing node
@[heap]
pub struct ContextTrieNode {
pub mut:
	segment     string
	node_type   TrieNodeType
	param_name  string
	handler     ?ContextHandler
	children    map[string]&ContextTrieNode
	param_child &ContextTrieNode = unsafe { nil }
	wildcard_child &ContextTrieNode = unsafe { nil }
}

//ContextTrieNode constructor
pub fn ContextTrieNode.new(segment string, node_type TrieNodeType, param_name string) &ContextTrieNode {
	return &ContextTrieNode{
		segment: segment
		node_type: node_type
		param_name: param_name
		children: map[string]&ContextTrieNode{}
	}
}

// Context Trie router
pub struct ContextTrieRouter {
mut:
	method_trees map[string]&ContextTrieNode
	cache        ContextLRUCache
}

//ContextTrieRouter constructor
pub fn ContextTrieRouter.new() ContextTrieRouter {
	return ContextTrieRouter{
		method_trees: map[string]&ContextTrieNode{}
		cache: ContextLRUCache.new(1000)
	}
}

//Add route to Trie tree
pub fn (mut tr ContextTrieRouter) add_route(method string, path string, handler ContextHandler) {
	if method !in tr.method_trees {
		tr.method_trees[method] = ContextTrieNode.new('', TrieNodeType.static, '')
	}
	
	segments := path.split('/').filter(it != '')
	mut current := tr.method_trees[method] or { return }
	
	for i, seg in segments {
		if seg.starts_with(':') {
			//parameter node
			if current.param_child == unsafe { nil } {
				current.param_child = ContextTrieNode.new(seg, TrieNodeType.param, seg[1..])
			}
			current = current.param_child
		} else if seg == '*' {
			// wildcard node
			if current.wildcard_child == unsafe { nil } {
				current.wildcard_child = ContextTrieNode.new(seg, TrieNodeType.wildcard, seg[1..])
			}
			current = current.wildcard_child
		} else {
			// static node
			if seg !in current.children {
				current.children[seg] = ContextTrieNode.new(seg, TrieNodeType.static, '')
			}
			current = current.children[seg] or { return }
		}
		
		// Set the processor on the last node
		if i == segments.len - 1 {
			current.handler = handler
		}
	}
}

// Match routes in Trie tree
pub fn (mut tr ContextTrieRouter) match_route(method string, path string) ?ContextRouteMatch {
	//Check cache first
	if cached := tr.cache.get(path) {
		return cached
	}
	
	if method !in tr.method_trees {
		return none
	}
	
	segments := path.split('/').filter(it != '')
	mut current := tr.method_trees[method] or { return none }
	mut params := map[string]string{}
	
	for seg in segments {
		// Try static matching first
		if seg in current.children {
			current = current.children[seg] or { return none }
		} else if current.param_child != unsafe { nil } {
			//Parameter matching
			params[current.param_child.param_name] = seg
			current = current.param_child
		} else if current.wildcard_child != unsafe { nil } {
			// wildcard matching
			current = current.wildcard_child
			break
		} else {
			return none
		}
	}
	
	if handler := current.handler {
		result := ContextRouteMatch{
			handler: handler
			params: params
		}
		tr.cache.put(path, result)
		return result
	}
	
	return none
}

// Get all routes
pub fn (tr ContextTrieRouter) get_all_routes() []string {
	mut routes := []string{}
	
	for _, root in tr.method_trees {
		tr.collect_routes(root, '', mut routes)
	}
	
	return routes
}

// Recursively collect routes
fn (tr ContextTrieRouter) collect_routes(node &ContextTrieNode, current_path string, mut routes []string) {
	if node.handler != none {
		routes << current_path
	}
	
	//Collect static child nodes
	for segment, child in node.children {
		tr.collect_routes(child, '${current_path}/${segment}', mut routes)
	}
	
	// Collect parameter sub-nodes
	if node.param_child != unsafe { nil } {
		tr.collect_routes(node.param_child, '${current_path}/:${node.param_child.param_name}', mut routes)
	}
	
	//Collect wildcard child nodes
	if node.wildcard_child != unsafe { nil } {
		tr.collect_routes(node.wildcard_child, '${current_path}/*', mut routes)
	}
} 