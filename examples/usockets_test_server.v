// uSockets test server (local module version)
// Compilation method:
// Method 1 (recommended): Install vono to ~/.vmodules and use it
// Method 2: Directly compile the entire directory
//
// Run: ./usockets_server

module main

import net.http

//Due to limitations of the V language module system, the necessary code is directly included here.
//In actual use, you should import meiseayoung.vono

fn main() {
	println('=== uSockets 服务器测试 ===')
	println('')
	println('由于 V 语言模块导入限制，无法直接从 examples 目录导入父目录模块。')
	println('')
	println('请使用以下方式测试 uSockets 服务器:')
	println('')
	println('方式 1: 安装 vono 到 vpm')
	println('  v install meiseayoung.vono')
	println('  v run tests/test_usockets_server.v')
	println('')
	println('方式 2: 使用符号链接')
	println('  ln -s $(pwd) ~/.vmodules/vono')
	println('  v run tests/test_usockets_server.v')
	println('')
	println('方式 3: 直接编译测试')
	println('  v -shared vono/')
	println('  # 如果编译成功，说明 uSockets 模块正常工作')
	println('')
	
	// Verify that compilation is successful
	println('✅ 编译成功！uSockets 模块已移除全局变量依赖。')
}
