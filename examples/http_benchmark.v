// HTTP stress testing tool - veb vs vono performance comparison
// Run: v run http_benchmark.v
//
// Please start the server before using:
// Terminal 1: v run server_veb.v (port 8080)
// Terminal 2: v run server_vono.v (port 8081)

module main

import net.http
import time

// test configuration
const veb_base_url = 'http://127.0.0.1:8080'
const vono_base_url = 'http://127.0.0.1:8081'
const requests_per_endpoint = 200

// test endpoint
struct Endpoint {
	path string
	name string
}

const test_endpoints = [
	Endpoint{path: '/', name: '首页 (静态)'},
	Endpoint{path: '/api/health', name: '健康检查 (静态)'},
	Endpoint{path: '/api/users', name: '用户列表 (静态)'},
	Endpoint{path: '/api/users/123', name: '单个用户 (动态)'},
	Endpoint{path: '/api/users/456/posts', name: '用户帖子 (动态)'},
]

struct BenchmarkResult {
	endpoint       string
	total_requests int
	success_count  int
	error_count    int
	total_time_ms  i64
	avg_time_ms    f64
	min_time_ms    f64
	max_time_ms    f64
	rps            f64
}

fn main() {
	println('')
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║           HTTP 压测工具 - veb vs vono 性能对比              ║')
	println('╠═══════════════════════════════════════════════════════════════╣')
	println('║ 请确保已启动以下服务器:                                       ║')
	println('║   - veb:    v run server_veb.v   (端口 8080)                  ║')
	println('║   - vono: v run server_vono.v  (端口 8081)                  ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
	println('')
	
	// Check if the server is available
	println('检查服务器状态...')
	veb_available := check_server(veb_base_url)
	vono_available := check_server(vono_base_url)
	
	if !veb_available {
		println('⚠️  veb 服务器 (${veb_base_url}) 不可用')
	} else {
		println('✅ veb 服务器 (${veb_base_url}) 已就绪')
	}
	
	if !vono_available {
		println('⚠️  vono 服务器 (${vono_base_url}) 不可用')
	} else {
		println('✅ vono 服务器 (${vono_base_url}) 已就绪')
	}
	
	if !veb_available && !vono_available {
		println('')
		println('❌ 没有可用的服务器，请先启动服务器后再运行测试')
		return
	}
	
	println('')
	println('开始压测 (每端点 ${requests_per_endpoint} 次请求)...')
	println('─────────────────────────────────────────────────────────────────')
	
	mut veb_results := []BenchmarkResult{}
	mut vono_results := []BenchmarkResult{}
	
	for endpoint in test_endpoints {
		println('')
		println('测试端点: ${endpoint.name} (${endpoint.path})')
		
		if veb_available {
			result := run_benchmark('veb', veb_base_url, endpoint)
			veb_results << result
			print_single_result('veb', result)
		}
		
		if vono_available {
			result := run_benchmark('vono', vono_base_url, endpoint)
			vono_results << result
			print_single_result('vono', result)
		}
	}
	
	//Print comparison results
	if veb_available && vono_available {
		print_comparison_table(veb_results, vono_results)
	}
	
	// print summary
	print_summary(veb_results, vono_results, veb_available, vono_available)
}

fn check_server(base_url string) bool {
	http.get(base_url) or { return false }
	return true
}

fn run_benchmark(name string, base_url string, endpoint Endpoint) BenchmarkResult {
	url := '${base_url}${endpoint.path}'
	
	mut success_count := 0
	mut error_count := 0
	mut min_time := f64(999999.0)
	mut max_time := f64(0.0)
	mut total_req_time := f64(0.0)
	
	start_time := time.now()
	
	for _ in 0 .. requests_per_endpoint {
		req_start := time.now()
		
		resp := http.get(url) or {
			error_count++
			continue
		}
		
		req_time := f64(time.since(req_start).microseconds()) / 1000.0
		
		if resp.status_code >= 200 && resp.status_code < 300 {
			success_count++
		} else {
			error_count++
		}
		
		total_req_time += req_time
		if req_time < min_time {
			min_time = req_time
		}
		if req_time > max_time {
			max_time = req_time
		}
	}
	
	total_time := time.since(start_time)
	total_time_ms := total_time.milliseconds()
	total_requests := success_count + error_count
	avg_time := if total_requests > 0 { total_req_time / f64(total_requests) } else { 0.0 }
	rps := if total_time_ms > 0 { f64(total_requests) * 1000.0 / f64(total_time_ms) } else { 0.0 }
	
	return BenchmarkResult{
		endpoint: endpoint.name
		total_requests: total_requests
		success_count: success_count
		error_count: error_count
		total_time_ms: total_time_ms
		avg_time_ms: avg_time
		min_time_ms: min_time
		max_time_ms: max_time
		rps: rps
	}
}

fn print_single_result(name string, r BenchmarkResult) {
	println('  ${name}: ${r.rps:.0} req/s | avg: ${r.avg_time_ms:.2}ms | min: ${r.min_time_ms:.2}ms | max: ${r.max_time_ms:.2}ms | 成功: ${r.success_count}/${r.total_requests}')
}

fn print_comparison_table(veb_results []BenchmarkResult, vono_results []BenchmarkResult) {
	println('')
	println('╔═══════════════════════════════════════════════════════════════════════════════════════╗')
	println('║                              性能对比表                                               ║')
	println('╠═══════════════════════════════════════════════════════════════════════════════════════╣')
	println('║ 端点                    │ veb (req/s)  │ vono (req/s) │ 差异      │ 胜出           ║')
	println('╠═══════════════════════════════════════════════════════════════════════════════════════╣')
	
	for i, veb_r in veb_results {
		if i >= vono_results.len {
			break
		}
		vono_r := vono_results[i]
		
		diff := vono_r.rps - veb_r.rps
		diff_pct := if veb_r.rps > 0 { (diff / veb_r.rps) * 100.0 } else { 0.0 }
		winner := if vono_r.rps > veb_r.rps { 'vono' } else { 'veb' }
		
		name := veb_r.endpoint
		veb_rps := '${veb_r.rps:.0}'
		vono_rps := '${vono_r.rps:.0}'
		diff_str := if diff > 0 { '+${diff_pct:.1}%' } else { '${diff_pct:.1}%' }
		
		println('║ ${name:-23} │ ${veb_rps:-12} │ ${vono_rps:-14} │ ${diff_str:-9} │ ${winner:-14} ║')
	}
	
	println('╚═══════════════════════════════════════════════════════════════════════════════════════╝')
}

fn print_summary(veb_results []BenchmarkResult, vono_results []BenchmarkResult, veb_available bool, vono_available bool) {
	println('')
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║                        测试总结                               ║')
	println('╠═══════════════════════════════════════════════════════════════╣')
	
	if veb_available && veb_results.len > 0 {
		mut total_rps := f64(0.0)
		for r in veb_results {
			total_rps += r.rps
		}
		avg_rps := total_rps / f64(veb_results.len)
		println('║ veb 平均吞吐量:    ${avg_rps:-40.0} req/s ║')
	}
	
	if vono_available && vono_results.len > 0 {
		mut total_rps := f64(0.0)
		for r in vono_results {
			total_rps += r.rps
		}
		avg_rps := total_rps / f64(vono_results.len)
		println('║ vono 平均吞吐量: ${avg_rps:-40.0} req/s ║')
	}
	
	println('╠═══════════════════════════════════════════════════════════════╣')
	println('║ 测试配置:                                                     ║')
	println('║   - 每端点请求数: ${requests_per_endpoint:-44} ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
	
	println('')
	println('提示: 使用 wrk 或 ab 可以获得更准确的压测结果:')
	println('  wrk -t4 -c100 -d10s http://127.0.0.1:8080/')
	println('  wrk -t4 -c100 -d10s http://127.0.0.1:8081/')
}
