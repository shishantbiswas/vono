module vono

import time

// Context LRU cache node
@[heap]
struct ContextLRUCacheNode {
pub mut:
	key        string
	value      ContextRouteMatch
	prev       &ContextLRUCacheNode = unsafe { nil }
	next       &ContextLRUCacheNode = unsafe { nil }
	created_at i64  //Add creation timestamp
	last_access i64 //Add last access time
}

// Context LRU cache
pub struct ContextLRUCache {
mut:
	capacity        int
	size           int
	cache          map[string]&ContextLRUCacheNode
	head           &ContextLRUCacheNode = unsafe { nil }
	tail           &ContextLRUCacheNode = unsafe { nil }
	ttl_seconds    i64 = 3600  // TTL: 1 hour, 0 means no expiration
	last_cleanup   i64         // The time when expired entries were last cleaned
	cleanup_interval i64 = 300 // Cleanup interval: 5 minutes
}

//ContextLRUCache constructor
pub fn ContextLRUCache.new(capacity int) ContextLRUCache {
	return ContextLRUCache{
		capacity: capacity
		size: 0
		cache: map[string]&ContextLRUCacheNode{}
		ttl_seconds: 3600
		last_cleanup: time.now().unix()
		cleanup_interval: 300
	}
}

//Create cache with custom TTL
pub fn ContextLRUCache.new_with_ttl(capacity int, ttl_seconds i64) ContextLRUCache {
	return ContextLRUCache{
		capacity: capacity
		size: 0
		cache: map[string]&ContextLRUCacheNode{}
		ttl_seconds: ttl_seconds
		last_cleanup: time.now().unix()
		cleanup_interval: 300
	}
}

// Get cached value
pub fn (mut cache ContextLRUCache) get(key string) ?ContextRouteMatch {
	// Periodically clean up expired entries
	cache.cleanup_expired_if_needed()
	
	if mut node := cache.cache[key] {
		// Check if it has expired
		if cache.is_expired(node) {
			cache.remove_node(mut node)
			return none
		}
		
		//Update access time
		node.last_access = time.now().unix()
		cache.move_to_front(mut node)
		return node.value
	}
	return none
}

//Set cache value
pub fn (mut cache ContextLRUCache) put(key string, value ContextRouteMatch) {
	// Periodically clean up expired entries
	cache.cleanup_expired_if_needed()
	
	if mut node := cache.cache[key] {
		// Update existing node
		node.value = value
		node.last_access = time.now().unix()
		cache.move_to_front(mut node)
		return
	}
	
	// If capacity is exceeded, remove the node that has not been used for the longest time first
	if cache.size >= cache.capacity {
		cache.remove_tail()
	}
	
	//Create new node
	now := time.now().unix()
	mut new_node := &ContextLRUCacheNode{
		key: key
		value: value
		created_at: now
		last_access: now
	}
	
	cache.cache[key] = new_node
	cache.add_to_front(mut new_node)
	cache.size++
}

//Move to the head of the linked list
fn (mut cache ContextLRUCache) move_to_front(mut node ContextLRUCacheNode) {
	// If it is already the head node, return directly
	if unsafe { voidptr(node) == voidptr(cache.head) } {
		return
	}
	
	// Safely remove from current location
	if node.prev != unsafe { nil } {
		mut prev := node.prev
		prev.next = node.next
	}
	if node.next != unsafe { nil } {
		mut next := node.next
		next.prev = node.prev
	}
	
	// If it is a tail node, update the tail pointer
	if unsafe { voidptr(node) == voidptr(cache.tail) } {
		cache.tail = node.prev
	}
	
	//Add to header
	cache.add_to_front(mut node)
}

//Add to the head of the linked list
fn (mut cache ContextLRUCache) add_to_front(mut node ContextLRUCacheNode) {
	node.next = cache.head
	node.prev = unsafe { nil }
	
	if cache.head != unsafe { nil } {
		mut head := cache.head
		head.prev = node
	}
	
	cache.head = node
	
	if cache.tail == unsafe { nil } {
		cache.tail = node
	}
}

// Remove the tail of the linked list (memory safe version)
fn (mut cache ContextLRUCache) remove_tail() {
	if cache.tail == unsafe { nil } {
		return
	}
	
	// Use common node removal methods
	mut tail_node := cache.tail
	cache.remove_node(mut tail_node)
}

// Safely remove the specified node
fn (mut cache ContextLRUCache) remove_node(mut node ContextLRUCacheNode) {
	if node.key == '' {
		return // Avoid removing nodes that have been cleaned
	}
	
	// Remove from the hash table first to avoid dangling pointers
	cache.cache.delete(node.key)
	
	// Safely update linked list pointers
	if node.prev != unsafe { nil } {
		mut prev := node.prev
		prev.next = node.next
	} else {
		// This is the head node
		cache.head = node.next
	}
	
	if node.next != unsafe { nil } {
		mut next := node.next
		next.prev = node.prev
	} else {
		// This is the tail node
		cache.tail = node.prev
	}
	
	// Completely clean up node references to prevent memory leaks
	node.prev = unsafe { nil }
	node.next = unsafe { nil }
	node.key = '' // Clear key as cleared mark
	
	//Update size count
	if cache.size > 0 {
		cache.size--
	}
}

// Get cache statistics
pub fn (cache ContextLRUCache) get_stats() (int, int) {
	return cache.size, cache.capacity
}

// Get detailed cache statistics
pub fn (mut cache ContextLRUCache) get_detailed_stats() map[string]i64 {
	// Clean up expired entries first and then count them
	cache.cleanup_expired_if_needed()
	
	mut expired_count := i64(0)
	
	// Count the number of expired entries
	if cache.ttl_seconds > 0 {
		for _, node in cache.cache {
			if cache.is_expired(node) {
				expired_count++
			}
		}
	}
	
	return {
		'size': i64(cache.size)
		'capacity': i64(cache.capacity)
		'expired_count': expired_count
		'ttl_seconds': cache.ttl_seconds
		'last_cleanup': cache.last_cleanup
		'cleanup_interval': cache.cleanup_interval
		'memory_usage_estimate': i64(cache.size * 200) // Rough estimate, each node is about 200 bytes
	}
}

//Set TTL
pub fn (mut cache ContextLRUCache) set_ttl(ttl_seconds i64) {
	cache.ttl_seconds = ttl_seconds
}

//Set the cleaning interval
pub fn (mut cache ContextLRUCache) set_cleanup_interval(interval_seconds i64) {
	cache.cleanup_interval = interval_seconds
}

// Check if the cache is healthy
pub fn (mut cache ContextLRUCache) is_healthy() bool {
	// Check basic status
	if cache.size == 0 {
		return cache.head == unsafe { nil } && cache.tail == unsafe { nil } && cache.cache.len == 0
	}
	
	// Check the head and tail pointers
	if cache.head == unsafe { nil } || cache.tail == unsafe { nil } {
		return false
	}
	
	// Check that the size of the hash table and linked list are consistent
	if cache.cache.len != cache.size {
		return false
	}
	
	// Check the integrity of the linked list
	mut count := 0
	mut current := cache.head
	for current != unsafe { nil } {
		count++
		if count > cache.size {
			return false // Circular reference detected
		}
		current = current.next
	}
	
	return count == cache.size
}

// Check if the node is expired
fn (cache ContextLRUCache) is_expired(node &ContextLRUCacheNode) bool {
	if cache.ttl_seconds <= 0 {
		return false // TTL of 0 means no expiration
	}
	now := time.now().unix()
	return (now - node.last_access) > cache.ttl_seconds
}

// Clean up expired entries if necessary
fn (mut cache ContextLRUCache) cleanup_expired_if_needed() {
	now := time.now().unix()
	if (now - cache.last_cleanup) > cache.cleanup_interval {
		cache.cleanup_expired_entries()
		cache.last_cleanup = now
	}
}

// Clean up all expired entries
fn (mut cache ContextLRUCache) cleanup_expired_entries() {
	if cache.ttl_seconds <= 0 {
		return // TTL of 0 means no expiration
	}
	
	mut expired_keys := []string{}
	
	//Collect expired keys
	for key, node in cache.cache {
		if cache.is_expired(node) {
			expired_keys << key
		}
	}
	
	//Remove expired nodes
	for key in expired_keys {
		if mut node := cache.cache[key] {
			cache.remove_node(mut node)
		}
	}
}

// Force cleanup of all expired entries (public method)
pub fn (mut cache ContextLRUCache) force_cleanup_expired() {
	cache.cleanup_expired_entries()
}

// Safely clear all caches (memory safe version)
pub fn (mut cache ContextLRUCache) clear() {
	// Safely clean up node references one by one
	mut current := cache.head
	for current != unsafe { nil } {
		mut next := current.next
		
		// Completely clean up all references to the current node
		current.prev = unsafe { nil }
		current.next = unsafe { nil }
		current.key = ''
		// Clear the data in value (if necessary)
		
		current = next
	}
	
	// Clear the hash table and pointers
	cache.cache.clear()
	cache.head = unsafe { nil }
	cache.tail = unsafe { nil }
	cache.size = 0
	cache.last_cleanup = time.now().unix()
}


// ============================================================================
// High-performance route cache - optimized for route matching
// ============================================================================
// Features:
// 1. No TTL check (route will not expire)
// 2. No LRU movement (simple map lookup)
// 3. Fixed size, empty and rebuild when full.
// 4. Zero-overhead get operation

pub struct FastRouteCache {
mut:
	cache    map[string]ContextRouteMatch
	capacity int
	enabled  bool = true
}

pub fn FastRouteCache.new(capacity int) FastRouteCache {
	return FastRouteCache{
		cache: map[string]ContextRouteMatch{}
		capacity: capacity
		enabled: true
	}
}

// Fast retrieval - zero overhead
@[inline]
pub fn (cache &FastRouteCache) get(key string) ?ContextRouteMatch {
	if !cache.enabled {
		return none
	}
	if result := cache.cache[key] {
		return result
	}
	return none
}

//Quick settings
@[inline]
pub fn (mut cache FastRouteCache) put(key string, value ContextRouteMatch) {
	if !cache.enabled {
		return
	}
	// If full, flush and rebuild (faster than LRU eviction)
	if cache.cache.len >= cache.capacity {
		cache.cache.clear()
	}
	cache.cache[key] = value
}

// Get statistics
pub fn (cache &FastRouteCache) get_stats() (int, int) {
	return cache.cache.len, cache.capacity
}

// clear cache
pub fn (mut cache FastRouteCache) clear() {
	cache.cache.clear()
}

// enable/disable
pub fn (mut cache FastRouteCache) set_enabled(enabled bool) {
	cache.enabled = enabled
	if !enabled {
		cache.clear()
	}
}
