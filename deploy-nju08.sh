#!/bin/bash

# NJU08团队专用部署脚本
# 部署完整的云原生应用到nju08命名空间

set -e

echo "=== NJU08 云原生应用部署脚本 ==="
echo "部署目标: nju08 命名空间"
echo "镜像仓库: Harbor Registry (172.22.83.19:30003)"
echo "==============================================="

# 检查kubectl连接
echo "检查Kubernetes集群连接..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "❌ 无法连接到Kubernetes集群，请检查kubectl配置"
    exit 1
fi
echo "✅ Kubernetes集群连接正常"

# 检查命名空间
echo "检查nju08命名空间..."
if ! kubectl get namespace nju08 > /dev/null 2>&1; then
    echo "创建nju08命名空间..."
    kubectl create namespace nju08
    kubectl label namespace nju08 team=nju08
fi
echo "✅ nju08命名空间准备就绪"

# 检查Harbor镜像拉取秘钥
echo "检查Harbor镜像拉取秘钥..."
if ! kubectl get secret harbor-secret -n nju08 > /dev/null 2>&1; then
    echo "⚠️  Harbor秘钥不存在，请手动创建:"
    echo "kubectl create secret docker-registry harbor-secret \\"
    echo "  --docker-server=172.22.83.19:30003 \\"
    echo "  --docker-username=<your-username> \\"
    echo "  --docker-password=<your-password> \\"
    echo "  --namespace=nju08"
    echo ""
    read -p "是否继续部署(y/N)? " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Harbor镜像拉取秘钥存在"
fi

# 部署应用
echo "部署应用到nju08命名空间..."
kubectl apply -f k8s/deployment-nju08.yaml
kubectl apply -f k8s/service-nju08.yaml

echo "等待应用启动..."
kubectl rollout status deployment/yys-app -n nju08 --timeout=300s

# 部署监控和HPA
echo "部署监控和自动扩容..."
kubectl apply -f hpa/hpa-nju08.yaml

# 检查部署状态
echo ""
echo "=== 部署状态检查 ==="
echo "Pods状态:"
kubectl get pods -n nju08 -l app=yys-app

echo ""
echo "Service状态:"
kubectl get svc -n nju08 -l app=yys-app

echo ""
echo "HPA状态:"
kubectl get hpa -n nju08

echo ""
echo "=== 访问信息 ==="
NODEPORT=$(kubectl get svc yys-app-nodeport -n nju08 -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "应用访问地址:"
echo "  集群内部: http://yys-app-service.nju08.svc.cluster.local:8080"
echo "  NodePort: http://${NODE_IP}:${NODEPORT}"
echo ""
echo "健康检查:"
echo "  健康状态: http://${NODE_IP}:${NODEPORT}/actuator/health"
echo "  Prometheus指标: http://${NODE_IP}:${NODEPORT}/actuator/prometheus"
echo ""
echo "✅ NJU08应用部署完成!"

# 提供快速测试命令
echo ""
echo "=== 快速测试命令 ==="
echo "测试API:"
echo "  curl http://${NODE_IP}:${NODEPORT}/api/hello"
echo ""
echo "查看日志:"
echo "  kubectl logs -f deployment/yys-app -n nju08"
echo ""
echo "查看HPA状态:"
echo "  kubectl get hpa yys-app-hpa -n nju08 -w"
