#!/bin/bash

# 构建和部署脚本

set -e

echo "=== YYS 应用构建和部署脚本 ==="

# 配置
APP_NAME="yys-app"
IMAGE_TAG=${1:-"latest"}
REGISTRY=${2:-""}
NAMESPACE=${3:-"default"}

echo "应用名称: $APP_NAME"
echo "镜像标签: $IMAGE_TAG"
echo "镜像仓库: $REGISTRY"
echo "命名空间: $NAMESPACE"

# 1. 编译应用
echo -e "\n=== 1. 编译Spring Boot应用 ==="
if [ -f "pom.xml" ]; then
    mvn clean package -DskipTests
    echo "✅ Maven构建完成"
else
    echo "❌ 未找到pom.xml文件"
    exit 1
fi

# 2. 构建Docker镜像
echo -e "\n=== 2. 构建Docker镜像 ==="
if [ -f "Dockerfile" ]; then
    if [ -n "$REGISTRY" ]; then
        FULL_IMAGE_NAME="$REGISTRY/$APP_NAME:$IMAGE_TAG"
    else
        FULL_IMAGE_NAME="$APP_NAME:$IMAGE_TAG"
    fi
    
    docker build -t "$FULL_IMAGE_NAME" .
    echo "✅ Docker镜像构建完成: $FULL_IMAGE_NAME"
    
    # 推送到仓库（如果指定了仓库）
    if [ -n "$REGISTRY" ]; then
        echo "推送镜像到仓库..."
        docker push "$FULL_IMAGE_NAME"
        echo "✅ 镜像推送完成"
    fi
else
    echo "❌ 未找到Dockerfile"
    exit 1
fi

# 3. 检查Kubernetes连接
echo -e "\n=== 3. 检查Kubernetes连接 ==="
if command -v kubectl >/dev/null 2>&1; then
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ Kubernetes集群连接正常"
    else
        echo "⚠️  无法连接到Kubernetes集群，跳过部署步骤"
        echo "请确保kubectl配置正确或手动部署"
        exit 0
    fi
else
    echo "⚠️  kubectl未安装，跳过部署步骤"
    echo "请安装kubectl后再执行部署"
    exit 0
fi

# 4. 部署应用
echo -e "\n=== 4. 部署到Kubernetes ==="

# 更新deployment.yaml中的镜像
if [ -f "k8s/deployment.yaml" ]; then
    cp k8s/deployment.yaml k8s/deployment.yaml.backup
    sed -i.tmp "s|image: yys-app:.*|image: $FULL_IMAGE_NAME|g" k8s/deployment.yaml
    
    kubectl apply -f k8s/deployment.yaml -n "$NAMESPACE"
    echo "✅ 应用部署完成"
    
    # 部署ServiceMonitor
    if [ -f "k8s/servicemonitor.yaml" ]; then
        kubectl apply -f k8s/servicemonitor.yaml -n "$NAMESPACE"
        echo "✅ ServiceMonitor部署完成"
    fi
    
    # 恢复原文件
    mv k8s/deployment.yaml.backup k8s/deployment.yaml
    rm -f k8s/deployment.yaml.tmp
else
    echo "❌ 未找到k8s/deployment.yaml"
    exit 1
fi

# 5. 部署HPA
echo -e "\n=== 5. 部署HPA ==="
if [ -f "hpa/metrics-server.yaml" ]; then
    kubectl apply -f hpa/metrics-server.yaml
    echo "✅ Metrics Server部署完成"
fi

if [ -f "hpa/service-hpa.yaml" ]; then
    kubectl apply -f hpa/service-hpa.yaml -n "$NAMESPACE"
    echo "✅ HPA配置部署完成"
fi

# 6. 验证部署
echo -e "\n=== 6. 验证部署状态 ==="
echo "等待Pod就绪..."
kubectl rollout status deployment/$APP_NAME -n "$NAMESPACE" --timeout=300s

echo -e "\n当前Pod状态:"
kubectl get pods -l app=$APP_NAME -n "$NAMESPACE"

echo -e "\nHPA状态:"
kubectl get hpa -n "$NAMESPACE"

echo -e "\n服务状态:"
kubectl get svc -l app=$APP_NAME -n "$NAMESPACE"

# 7. 获取访问地址
echo -e "\n=== 7. 访问信息 ==="
SERVICE_TYPE=$(kubectl get svc yys-app-service -n "$NAMESPACE" -o jsonpath='{.spec.type}' 2>/dev/null || echo "")

if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
    echo "等待LoadBalancer分配外部IP..."
    kubectl get svc yys-app-service -n "$NAMESPACE" -w &
    WATCH_PID=$!
    sleep 30
    kill $WATCH_PID 2>/dev/null || true
    
    EXTERNAL_IP=$(kubectl get svc yys-app-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$EXTERNAL_IP" ]; then
        echo "应用访问地址: http://$EXTERNAL_IP/api/hello"
    else
        echo "LoadBalancer外部IP尚未分配，请稍后查看"
    fi
elif [ "$SERVICE_TYPE" = "NodePort" ]; then
    NODE_PORT=$(kubectl get svc yys-app-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    if [ -z "$NODE_IP" ]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    fi
    echo "应用访问地址: http://$NODE_IP:$NODE_PORT/api/hello"
else
    echo "使用ClusterIP服务，可通过端口转发访问:"
    echo "kubectl port-forward svc/yys-app-service 8080:80 -n $NAMESPACE"
    echo "然后访问: http://localhost:8080/api/hello"
fi

echo -e "\n=== 部署完成 ==="
echo "可以运行以下命令进行测试:"
echo "1. 功能测试: curl http://your-service-url/api/hello"
echo "2. 健康检查: curl http://your-service-url/actuator/health"
echo "3. 压力测试: ./scripts/load-test.sh http://your-service-url"
echo "4. 监控HPA: kubectl get hpa -n $NAMESPACE -w"
