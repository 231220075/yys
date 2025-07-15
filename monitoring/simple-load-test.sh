#!/bin/bash

echo "=== YYS 应用压测验证 ==="

# 检查应用状态
echo "检查应用状态..."
if curl -s "http://localhost:8080/actuator/health" | grep "UP" > /dev/null; then
    echo "✅ 应用运行正常"
else
    echo "❌ 应用未正常运行"
    exit 1
fi

# 获取压测前指标
echo -e "\n📊 压测前基准指标："
echo "HTTP请求计数:"
curl -s "http://localhost:8080/actuator/prometheus" | grep "http_server_requests_seconds_count" | head -2

echo -e "\nJVM内存使用:"
curl -s "http://localhost:8080/actuator/prometheus" | grep "jvm_memory_used_bytes.*heap" | head -1

# 执行压测
echo -e "\n🚀 开始压力测试 (30秒)..."

# 发送100个并发请求
for i in {1..100}; do
    curl -s "http://localhost:8080/actuator/health" > /dev/null &
    curl -s "http://localhost:8080/api/health" > /dev/null &
    if [ $((i % 10)) -eq 0 ]; then
        echo "已发送 $i 组请求..."
    fi
    sleep 0.1
done

echo "等待所有请求完成..."
wait

# 获取压测后指标
echo -e "\n📈 压测后监控指标："
echo "HTTP请求计数:"
curl -s "http://localhost:8080/actuator/prometheus" | grep "http_server_requests_seconds_count" | head -2

echo -e "\nJVM内存使用:"
curl -s "http://localhost:8080/actuator/prometheus" | grep "jvm_memory_used_bytes.*heap" | head -1

echo -e "\n✅ 压测完成！"
echo "💡 建议在Grafana中观察以下指标的变化："
echo "   - HTTP请求QPS增加"
echo "   - JVM内存使用率变化"
echo "   - CPU使用率上升"
