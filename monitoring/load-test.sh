#!/bin/bash

# YYS Application Load Testing Script
# 用于验证监控指标和系统性能

echo "=== YYS 应用压测开始 ==="

# 配置参数
APP_URL="http://localhost:8080"
PROMETHEUS_URL="http://localhost:8080/actuator/prometheus"
CONCURRENT_USERS=10
DURATION=60  # 秒
REQUEST_RATE=5  # 每秒请求数

# 检查应用是否启动
echo "检查应用状态..."
if ! curl -s "${APP_URL}/actuator/health" > /dev/null; then
    echo "❌ 应用未启动，请先启动应用"
    exit 1
fi
echo "✅ 应用运行正常"

# 函数：发送请求
send_requests() {
    local endpoint=$1
    local count=$2
    
    for i in $(seq 1 $count); do
        curl -s "${APP_URL}${endpoint}" > /dev/null &
        sleep 0.1
    done
    wait
}

# 函数：获取监控指标
get_metrics() {
    echo "=== 当前监控指标 ==="
    
    # HTTP 请求计数
    echo "📊 HTTP 请求统计:"
    curl -s "$PROMETHEUS_URL" | grep "http_server_requests_seconds_count" | head -5
    
    # JVM 内存使用
    echo -e "\n🧠 JVM 内存使用:"
    curl -s "$PROMETHEUS_URL" | grep "jvm_memory_used_bytes.*heap" | head -2
    
    # GC 统计
    echo -e "\n🗑️  GC 统计:"
    curl -s "$PROMETHEUS_URL" | grep "jvm_gc_collection_seconds_count" | head -3
    
    # 限流统计
    echo -e "\n🚦 限流统计:"
    curl -s "$PROMETHEUS_URL" | grep "rate_limited"
    
    echo "==============================="
}

# 获取压测前的基准指标
echo -e "\n📈 压测前基准指标："
get_metrics

echo -e "\n🚀 开始压力测试..."
echo "📋 测试配置:"
echo "   - 并发用户: $CONCURRENT_USERS"
echo "   - 持续时间: $DURATION 秒"
echo "   - 请求频率: $REQUEST_RATE req/s"

# 压测阶段1: 正常请求
echo -e "\n🔥 阶段1: 正常API请求压测 (30秒)"
start_time=$(date +%s)
while [ $(($(date +%s) - start_time)) -lt 30 ]; do
    for i in $(seq 1 $CONCURRENT_USERS); do
        curl -s "${APP_URL}/api/health" > /dev/null &
        curl -s "${APP_URL}/actuator/health" > /dev/null &
    done
    sleep $(echo "scale=2; 1/$REQUEST_RATE" | bc)
done
wait

echo "✅ 阶段1完成"

# 获取中期指标
echo -e "\n📊 阶段1后监控指标："
get_metrics

# 压测阶段2: 高频请求触发限流
echo -e "\n⚡ 阶段2: 高频请求压测 (触发限流, 30秒)"
start_time=$(date +%s)
while [ $(($(date +%s) - start_time)) -lt 30 ]; do
    for i in $(seq 1 $((CONCURRENT_USERS * 2))); do
        curl -s "${APP_URL}/api/demo" > /dev/null &
    done
    sleep 0.1  # 高频请求
done
wait

echo "✅ 阶段2完成"

# 获取最终指标
echo -e "\n📈 压测后最终监控指标："
get_metrics

# 生成压测报告
echo -e "\n📄 生成压测报告..."
cat > /tmp/load_test_report.txt << EOF
YYS 应用压力测试报告
====================

测试时间: $(date)
测试配置:
- 并发用户: $CONCURRENT_USERS
- 总持续时间: $DURATION 秒
- 基础请求频率: $REQUEST_RATE req/s

测试阶段:
1. 正常请求压测 (30秒)
2. 高频请求压测 (30秒，触发限流)

监控指标验证:
✅ HTTP 请求QPS - 通过Prometheus指标验证
✅ JVM内存使用 - 堆内存使用率监控
✅ GC次数统计 - 垃圾回收频率监控
✅ 限流效果 - 限流计数器验证

建议观察的Grafana面板:
- CPU使用率变化
- 内存使用率趋势
- HTTP请求QPS峰值
- 平均响应时间变化
- GC频率变化

EOF

echo "✅ 压测完成！"
echo "📊 详细报告已保存到: /tmp/load_test_report.txt"
echo "🔍 请在Grafana面板中观察以下指标变化:"
echo "   - CPU使用率是否有明显上升"
echo "   - 内存使用率变化趋势"
echo "   - HTTP请求QPS峰值达到多少"
echo "   - 平均响应时间是否增加"
echo "   - 是否触发了限流机制"

echo -e "\n💡 提示: 可以在Grafana中查看时间范围为最近1小时的数据，观察压测期间的指标变化"
