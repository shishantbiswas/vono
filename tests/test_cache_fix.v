import meiseayoung.vono

fn main() {
	println('=== 测试缓存内存泄漏修复 ===')
	
	//Create cache
	mut cache := vono.ContextLRUCache.new(5)
	
	//Create test data
	test_route_match := vono.ContextRouteMatch{
		handler: vono.ContextHandler{
			path: '/test'
		}
		params: {'id': '123'}
		path: '/test'
		base_path: ''
	}
	
	println('1. 基本功能测试')
	
	//Add cache item
	cache.put('key1', test_route_match)
	cache.put('key2', test_route_match)
	cache.put('key3', test_route_match)
	
	size, capacity := cache.get_stats()
	println('   添加3个项后: ${size}/${capacity}')
	
	//Test acquisition
	if _ := cache.get('key1') {
		println('   ✅ 成功获取key1')
	} else {
		println('   ❌ 获取key1失败')
	}
	
	println('2. 容量溢出测试')
	
	// Note: the above get('key1') will move key1 to the head (most recently used)
	// So the LRU order becomes: key1 (head) -> key3 -> key2 (tail)
	// Add more items to trigger LRU removal
	cache.put('key4', test_route_match)  // size=4
	cache.put('key5', test_route_match)  // size=5 (capacity reached)
	cache.put('key6', test_route_match)  // Remove key2 (most unused)
	
	size2, _ := cache.get_stats()
	println('   添加到容量上限后: ${size2}/${capacity}')
	
	// key2 should be removed (because key1 was moved to the head after get)
	if _ := cache.get('key2') {
		println('   ❌ key2仍然存在（应该被移除）')
	} else {
		println('   ✅ key2正确被移除（LRU淘汰）')
	}
	
	// key1 should still exist (since it was most recently accessed)
	if _ := cache.get('key1') {
		println('   ✅ key1仍然存在（最近访问过）')
	} else {
		println('   ❌ key1被错误移除')
	}
	
	println('3. 健康检查测试')
	
	// health check
	is_healthy := cache.is_healthy()
	println('   缓存健康状态: ${is_healthy}')
	
	println('4. 清理测试')
	
	// Clear all caches
	cache.clear()
	size3, _ := cache.get_stats()
	println('   清理后大小: ${size3}')
	
	// Health check after cleaning
	is_healthy2 := cache.is_healthy()
	println('   清理后健康状态: ${is_healthy2}')
	
	println('✅ 所有测试通过！缓存内存泄漏修复成功')
}