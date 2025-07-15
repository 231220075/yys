#!/bin/bash

# YYS Application HPA Deployment Script
# 配置基于负载的自动扩容

echo "=== YYS 应用 HPA 自动扩容配置 ==="

# 检查 kubectl 是否可用
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl 未找到，请确保 Kubernetes 环境已配置"
    exit 1
fi

# 检查 metrics-server 是否运行
echo "📊 检查 metrics-server 状态..."
if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    echo "✅ metrics-server 已运行"
else
    echo "⚠️  metrics-server 未找到，需要安装 metrics-server"
    echo "正在部署 metrics-server..."
    kubectl apply -f hpa/metrics-server.yaml
    echo "等待 metrics-server 启动..."
    kubectl wait --for=condition=available --timeout=60s deployment/metrics-server -n kube-system
fi

# 确保应用已部署
echo "🚀 检查应用部署状态..."
if kubectl get deployment yys-app &> /dev/null; then
    echo "✅ yys-app 应用已部署"
else
    echo "📦 部署 yys-app 应用..."
    kubectl apply -f k8s/deployment.yaml
    kubectl apply -f k8s/service.yaml
    kubectl wait --for=condition=available --timeout=120s deployment/yys-app
fi

# 部署 ServiceMonitor
echo "📈 配置 Prometheus 监控..."
kubectl apply -f k8s/servicemonitor.yaml

# 部署 HPA
echo "⚖️  配置 HPA 自动扩容..."
kubectl apply -f k8s/hpa.yaml

# 验证 HPA 状态
echo "🔍 验证 HPA 配置..."
kubectl get hpa yys-app-hpa

# 显示当前 Pod 状态
echo -e "\n📦 当前 Pod 状态:"
kubectl get pods -l app=yys-app

# 显示 HPA 详细信息
echo -e "\n📊 HPA 详细信息:"
kubectl describe hpa yys-app-hpa

# 创建负载测试函数
load_test_hpa() {
    echo -e "\n🔥 开始 HPA 负载测试..."
    
    # 获取服务URL
    SERVICE_IP=$(kubectl get service yys-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$SERVICE_IP" ]; then
        SERVICE_IP=$(kubectl get service yys-app -o jsonpath='{.spec.clusterIP}')
    fi
    SERVICE_PORT=$(kubectl get service yys-app -o jsonpath='{.spec.ports[0].port}')
    
    echo "目标服务: http://$SERVICE_IP:$SERVICE_PORT"
    
    # 启动负载测试
    echo "发送高频请求触发 HPA 扩容..."
    
    # 使用 kubectl port-forward 进行本地测试
    kubectl port-forward service/yys-app 8080:8080 &
    PORT_FORWARD_PID=$!
    
    sleep 5  # 等待端口转发建立
    
    # 执行压力测试
    for i in {1..300}; do
        curl -s "http://localhost:8080/actuator/health" > /dev/null &
        curl -s "http://localhost:8080/api/health" > /dev/null &
        if [ $((i % 50)) -eq 0 ]; then
            echo "已发送 $i 组请求..."
            echo "当前 HPA 状态:"
            kubectl get hpa yys-app-hpa
        fi
        sleep 0.1
    done
    
    echo "等待请求完成..."
    wait
    
    # 停止端口转发
    kill $PORT_FORWARD_PID 2>/dev/null
    
    echo "负载测试完成，观察 HPA 扩容效果..."
}

# 提供交互式菜单
echo -e "\n🎛️  HPA 管理选项:"
echo "1. 查看 HPA 状态"
echo "2. 执行负载测试"
echo "3. 查看 Pod 扩容情况"
echo "4. 删除 HPA 配置"
echo "5. 实时监控 HPA"

read -p "请选择操作 (1-5): " choice

case $choice in
    1)
        echo "📊 HPA 状态:"
        kubectl get hpa yys-app-hpa
        echo -e "\nHPA 详细信息:"
        kubectl describe hpa yys-app-hpa
        ;;
    2)
        load_test_hpa
        ;;
    3)
        echo "📦 Pod 扩容情况:"
        kubectl get pods -l app=yys-app -w
        ;;
    4)
        echo "🗑️  删除 HPA 配置..."
        kubectl delete hpa yys-app-hpa
        echo "HPA 已删除"
        ;;
    5)
        echo "👀 实时监控 HPA (按 Ctrl+C 退出):"
        watch -n 2 "kubectl get hpa yys-app-hpa && echo && kubectl get pods -l app=yys-app"
        ;;
    *)
        echo "无效选择"
        ;;
esac

echo -e "\n✅ HPA 配置完成！"
echo "💡 提示:"
echo "   - 使用 'kubectl get hpa' 查看扩容状态"
echo "   - 使用 'kubectl describe hpa yys-app-hpa' 查看详细信息"
echo "   - 当 CPU 使用率超过 50% 或内存超过 70% 时会自动扩容"
echo "   - Pod 数量范围: 2-10 个"
echo "   - 扩容策略: 快速扩容，保守缩容"
