// High concurrency test (5000-10000 concurrency)
//
// How to use:
// 1. Start the server (ulimit must be set): ulimit -n 65535 && ./bench_server_usockets
// 2. Run the test: ulimit -n 65535 && go run vono/tests/test_high_concurrency.go
// 3. Test a certain level individually: ulimit -n 65535 && go run vono/tests/test_high_concurrency.go 8000
//
// IMPORTANT NOTE:
// - Both server and client need to set ulimit -n 65535
// - When testing multiple concurrency levels continuously, it is recommended to restart the server before each test
// - TIME_WAIT connection will affect subsequent tests. It is recommended to wait 10 seconds before testing the next level.
//
// System requirements (macOS):
//   sudo sysctl -w kern.ipc.somaxconn=8192
//   ulimit -n 65535

package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

type BenchResult struct {
	Concurrency int
	TotalReqs   int64
	SuccessReqs int64
	RPS         float64
	AvgLatency  float64
	P99Latency  float64
	SuccessRate float64
}

func main() {
	baseURL := "http://127.0.0.1:8080/"
	duration := 10 * time.Second

	//Default test levels: 5000, 6000, 7000, 8000, 9000, 10000
	concurrencyLevels := []int{5000, 6000, 7000, 8000, 9000, 10000}

	// Support command line parameters to specify a single concurrency level
	if len(os.Args) > 1 {
		level, err := strconv.Atoi(os.Args[1])
		if err == nil {
			concurrencyLevels = []int{level}
		}
	}

	fmt.Println("╔═══════════════════════════════════════════════════════════════════════════╗")
	fmt.Println("║              vono 高并发测试 (5000-10000 并发)                          ║")
	fmt.Println("╚═══════════════════════════════════════════════════════════════════════════╝")
	fmt.Println()

	// Check if the server is running
	if !checkServer(baseURL) {
		fmt.Println("❌ 服务器未运行")
		fmt.Println("   请先启动: ./bench_server_usockets")
		fmt.Println()
		fmt.Println("   系统配置要求:")
		fmt.Println("   - macOS: sudo sysctl -w kern.ipc.somaxconn=8192")
		fmt.Println("   - ulimit -n 65535")
		return
	}
	fmt.Println("✅ 服务器已就绪")
	fmt.Println()

	results := make([]BenchResult, 0, len(concurrencyLevels))

	for _, conns := range concurrencyLevels {
		result := runBenchmark(baseURL, conns, duration)
		results = append(results, result)

		// Test interval to allow the system to recover (TIME_WAIT connection takes time to release)
		// macOS TIME_WAIT defaults to 15-30 seconds, it is recommended to wait 60 seconds
		if len(concurrencyLevels) > 1 {
			fmt.Println("   ⏳ 等待 60 秒让系统恢复 (TIME_WAIT 连接释放)...")
			time.Sleep(60 * time.Second)
		}
	}

	// Output summary report
	printSummary(results)
}

func checkServer(baseURL string) bool {
	client := &http.Client{Timeout: 2 * time.Second}
	for i := 0; i < 5; i++ {
		resp, err := client.Get(baseURL)
		if err == nil && resp.StatusCode < 400 {
			resp.Body.Close()
			return true
		}
		time.Sleep(200 * time.Millisecond)
	}
	return false
}

func runBenchmark(baseURL string, conns int, duration time.Duration) BenchResult {
	fmt.Printf("🔥 测试 %d 并发连接 (持续 %v)\n", conns, duration)

	var total, success int64
	var totalLatencyNs int64
	latencies := make([]int64, 0, 1000000)
	var mu sync.Mutex

	client := &http.Client{
		Timeout: 60 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        conns * 2,
			MaxIdleConnsPerHost: conns * 2,
			MaxConnsPerHost:     0,
			IdleConnTimeout:     120 * time.Second,
			DisableKeepAlives:   false,
			ForceAttemptHTTP2:   false,
		},
	}

	var wg sync.WaitGroup
	stop := make(chan struct{})
	start := time.Now()

	// Start all connections at the same time
	for i := 0; i < conns; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				select {
				case <-stop:
					return
				default:
					t0 := time.Now()
					resp, err := client.Get(baseURL)
					lat := time.Since(t0).Nanoseconds()

					atomic.AddInt64(&total, 1)
					atomic.AddInt64(&totalLatencyNs, lat)

					mu.Lock()
					latencies = append(latencies, lat)
					mu.Unlock()

					if err != nil {
						continue
					}
					io.Copy(io.Discard, resp.Body)
					resp.Body.Close()
					if resp.StatusCode < 400 {
						atomic.AddInt64(&success, 1)
					}
				}
			}
		}()
	}

	time.Sleep(duration)
	close(stop)
	wg.Wait()

	elapsed := time.Since(start)

	// Calculate P99
	sort.Slice(latencies, func(i, j int) bool { return latencies[i] < latencies[j] })
	p99 := int64(0)
	if len(latencies) > 0 {
		idx := len(latencies) * 99 / 100
		p99 = latencies[idx]
	}

	avgLat := float64(totalLatencyNs) / float64(total) / 1e6
	rps := float64(total) / elapsed.Seconds()
	successRate := float64(success) / float64(total) * 100

	// Determine test results
	status := "✅"
	if successRate < 99.0 {
		status = "⚠️"
	}
	if successRate < 90.0 {
		status = "❌"
	}

	fmt.Printf("   %s RPS: %8.0f  Avg: %6.2fms  P99: %6.2fms  Success: %.1f%%\n",
		status, rps, avgLat, float64(p99)/1e6, successRate)
	fmt.Println()

	return BenchResult{
		Concurrency: conns,
		TotalReqs:   total,
		SuccessReqs: success,
		RPS:         rps,
		AvgLatency:  avgLat,
		P99Latency:  float64(p99) / 1e6,
		SuccessRate: successRate,
	}
}

func printSummary(results []BenchResult) {
	if len(results) <= 1 {
		return
	}

	fmt.Println("═══════════════════════════════════════════════════════════════════════════")
	fmt.Println("                           📊 测试结果汇总")
	fmt.Println("═══════════════════════════════════════════════════════════════════════════")
	fmt.Println()
	fmt.Println("┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐")
	fmt.Println("│   并发数     │     RPS      │   平均延迟   │   P99延迟    │   成功率     │")
	fmt.Println("├──────────────┼──────────────┼──────────────┼──────────────┼──────────────┤")

	allPassed := true
	for _, r := range results {
		status := "✅"
		if r.SuccessRate < 99.0 {
			status = "⚠️"
			allPassed = false
		}
		if r.SuccessRate < 90.0 {
			status = "❌"
			allPassed = false
		}

		fmt.Printf("│ %s %6d    │ %10.0f   │ %8.2fms   │ %8.2fms   │ %8.1f%%   │\n",
			status, r.Concurrency, r.RPS, r.AvgLatency, r.P99Latency, r.SuccessRate)
	}

	fmt.Println("└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┘")
	fmt.Println()

	if allPassed {
		fmt.Println("🎉 所有高并发测试通过！vono uSockets 后端表现优秀！")
	} else {
		fmt.Println("⚠️  部分测试未达到 99% 成功率，请检查系统配置")
		fmt.Println("   - macOS: sudo sysctl -w kern.ipc.somaxconn=8192")
		fmt.Println("   - ulimit -n 65535")
	}
	fmt.Println()
}
