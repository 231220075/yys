#!/bin/bash

# 压力测试脚本 - 测试限流和HPA功能

echo "开始压力测试..."

# 配置
SERVICE_URL=${1:-"http://localhost:8080"}
CONCURRENT_USERS=${2:-50}
DURATION=${3:-300}

echo "目标URL: $SERVICE_URL"
echo "并发用户数: $CONCURRENT_USERS"
echo "测试持续时间: $DURATION 秒"

# 检查依赖
command -v curl >/dev/null 2>&1 || { echo "curl 未安装" >&2; exit 1; }
command -v ab >/dev/null 2>&1 || { echo "apache-bench 未安装，尝试安装..." >&2; }

# 功能测试
echo "=== 1. 功能测试 ==="
echo "测试 /api/hello 接口:"
curl -s "$SERVICE_URL/api/hello" | jq .

echo -e "\n测试健康检查:"
curl -s "$SERVICE_URL/actuator/health" | jq .

echo -e "\n测试应用信息:"
curl -s "$SERVICE_URL/api/info" | jq .

echo -e "\n测试Prometheus指标:"
curl -s "$SERVICE_URL/actuator/prometheus" | head -20

# 限流测试
echo -e "\n=== 2. 限流测试 ==="
echo "快速发送请求测试限流 (每秒超过100个请求):"

success_count=0
rate_limited_count=0

for i in {1..150}; do
    response=$(curl -s -w "%{http_code}" "$SERVICE_URL/api/hello" -o /dev/null)
    if [ "$response" = "200" ]; then
        ((success_count++))
    elif [ "$response" = "429" ]; then
        ((rate_limited_count++))
    fi
    # 短暂延迟以模拟高频请求
    sleep 0.01
done

echo "成功请求: $success_count"
echo "被限流请求: $rate_limited_count"

# 压力测试
echo -e "\n=== 3. 压力测试 ==="

# 使用Apache Bench进行压力测试
if command -v ab >/dev/null 2>&1; then
    echo "使用Apache Bench进行压力测试..."
    ab -n 10000 -c $CONCURRENT_USERS -t $DURATION "$SERVICE_URL/api/hello"
else
    echo "使用curl进行简单压力测试..."
    
    # 创建后台任务模拟并发请求
    for ((i=1; i<=CONCURRENT_USERS; i++)); do
        {
            end_time=$((SECONDS + DURATION))
            while [ $SECONDS -lt $end_time ]; do
                curl -s "$SERVICE_URL/api/hello" > /dev/null 2>&1
                sleep 0.1
            done
        } &
    done
    
    echo "已启动 $CONCURRENT_USERS 个并发客户端，持续 $DURATION 秒..."
    
    # 监控过程
    for ((i=1; i<=DURATION; i++)); do
        echo -n "."
        sleep 1
        if [ $((i % 30)) -eq 0 ]; then
            echo " ${i}s"
        fi
    done
    
    # 等待所有后台任务完成
    wait
fi

echo -e "\n=== 4. 监控HPA状态 ==="
if command -v kubectl >/dev/null 2>&1; then
    echo "HPA状态:"
    kubectl get hpa yys-app-hpa 2>/dev/null || echo "HPA未部署或kubectl未配置"
    
    echo -e "\nPod状态:"
    kubectl get pods -l app=yys-app 2>/dev/null || echo "Pod未部署或kubectl未配置"
else
    echo "kubectl未安装，跳过Kubernetes监控"
fi

echo -e "\n=== 压力测试完成 ==="
