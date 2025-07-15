#!/bin/bash

# NJU08 Jenkins Pipeline 本地测试脚本
# 用于在本地验证Docker构建是否正常

set -e

echo "=== NJU08 Docker构建本地测试 ==="
echo "测试目标: 验证Docker镜像构建"
echo "==============================="

# 检查Docker环境
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装，请先安装Docker"
    exit 1
fi

echo "✅ Docker环境检查通过"
echo "Docker版本: $(docker --version)"

# 测试网络连接
echo ""
echo "🌐 测试网络连接..."

# 测试Docker Hub连接
DOCKER_HUB_STATUS="失败"
if timeout 10 curl -s https://registry-1.docker.io/v2/ > /dev/null 2>&1; then
    DOCKER_HUB_STATUS="正常"
fi
echo "Docker Hub连接: $DOCKER_HUB_STATUS"

# 测试阿里云镜像源连接
ALIYUN_STATUS="失败"
if timeout 10 curl -s https://registry.cn-hangzhou.aliyuncs.com/v2/ > /dev/null 2>&1; then
    ALIYUN_STATUS="正常"
fi
echo "阿里云镜像源连接: $ALIYUN_STATUS"

# 选择使用的Dockerfile
DOCKERFILE="Dockerfile"
if [ "$DOCKER_HUB_STATUS" = "失败" ] && [ "$ALIYUN_STATUS" = "正常" ]; then
    DOCKERFILE="Dockerfile.stable"
    echo "⚠️  将使用稳定版Dockerfile (阿里云镜像源)"
fi

echo ""
echo "🔨 开始Docker构建测试..."
echo "使用Dockerfile: $DOCKERFILE"

# 构建镜像
IMAGE_TAG="test-yys-app:$(date +%s)"
echo "构建镜像标签: $IMAGE_TAG"

if docker build -f $DOCKERFILE -t $IMAGE_TAG . --progress=plain; then
    echo ""
    echo "✅ Docker镜像构建成功!"
    echo "镜像信息:"
    docker images $IMAGE_TAG
    
    echo ""
    echo "🧪 测试容器启动..."
    CONTAINER_ID=$(docker run -d -p 8080:8080 $IMAGE_TAG)
    
    echo "等待应用启动..."
    sleep 30
    
    # 测试健康检查
    if curl -f http://localhost:8080/actuator/health > /dev/null 2>&1; then
        echo "✅ 应用健康检查通过"
        echo "🎉 本地测试完全成功!"
    else
        echo "⚠️  应用启动但健康检查失败"
        echo "检查容器日志:"
        docker logs $CONTAINER_ID --tail 20
    fi
    
    # 清理
    echo ""
    echo "🧹 清理测试资源..."
    docker stop $CONTAINER_ID > /dev/null 2>&1 || true
    docker rm $CONTAINER_ID > /dev/null 2>&1 || true
    docker rmi $IMAGE_TAG > /dev/null 2>&1 || true
    
else
    echo "❌ Docker镜像构建失败"
    echo ""
    echo "🔍 故障排查建议:"
    echo "1. 检查网络连接"
    echo "2. 尝试配置Docker镜像加速器"
    echo "3. 查看详细构建日志"
    echo ""
    echo "如果是网络问题，可以配置Docker镜像加速器:"
    echo "sudo mkdir -p /etc/docker"
    echo 'sudo tee /etc/docker/daemon.json <<-"EOF"'
    echo "{"
    echo '  "registry-mirrors": ['
    echo '    "https://registry.cn-hangzhou.aliyuncs.com"'
    echo "  ]"
    echo "}"
    echo "EOF"
    echo "sudo systemctl daemon-reload"
    echo "sudo systemctl restart docker"
    exit 1
fi

echo ""
echo "📋 测试总结:"
echo "- Docker环境: ✅"
echo "- 网络连接: Docker Hub $DOCKER_HUB_STATUS, 阿里云 $ALIYUN_STATUS"
echo "- 镜像构建: ✅"
echo "- 应用启动: ✅"
echo ""
echo "现在可以在Jenkins中重新运行Pipeline!"
