#!/bin/bash

# Docker镜像源连通性测试脚本
# 测试各种国内外镜像源的可用性

echo "=== Docker镜像源连通性测试 ==="
echo "测试时间: $(date)"
echo "================================"

# 定义镜像源列表
declare -A REGISTRIES=(
    ["Docker Hub"]="https://registry-1.docker.io/v2/"
    ["腾讯云"]="https://ccr.ccs.tencentyun.com/v2/"
    ["网易"]="https://hub-mirror.c.163.com/v2/"
    ["阿里云"]="https://registry.cn-hangzhou.aliyuncs.com/v2/"
    ["华为云"]="https://swr.cn-north-4.myhuaweicloud.com/v2/"
    ["Azure中国"]="https://dockerhub.azk8s.cn/v2/"
)

# 测试函数
test_registry() {
    local name="$1"
    local url="$2"
    local status="❌ 失败"
    local latency=""
    
    echo -n "测试 $name ... "
    
    # 测试连通性和延迟
    if timeout 10 curl -s "$url" > /dev/null 2>&1; then
        # 测量延迟
        local start_time=$(date +%s%3N)
        curl -s "$url" > /dev/null 2>&1
        local end_time=$(date +%s%3N)
        latency=$((end_time - start_time))
        status="✅ 正常 (${latency}ms)"
    fi
    
    echo "$status"
    return $([ "$status" != "❌ 失败" ] && echo 0 || echo 1)
}

echo "🌐 开始测试镜像源连通性..."
echo ""

# 存储可用的镜像源
available_registries=()

# 遍历测试所有镜像源
for registry_name in "${!REGISTRIES[@]}"; do
    registry_url="${REGISTRIES[$registry_name]}"
    if test_registry "$registry_name" "$registry_url"; then
        available_registries+=("$registry_name")
    fi
done

echo ""
echo "📊 测试结果汇总:"
echo "=================="

if [ ${#available_registries[@]} -eq 0 ]; then
    echo "❌ 所有镜像源都不可用!"
    echo ""
    echo "🔧 建议解决方案:"
    echo "1. 检查网络连接"
    echo "2. 检查防火墙设置"
    echo "3. 配置HTTP代理"
    echo "4. 联系网络管理员"
else
    echo "✅ 可用的镜像源 (${#available_registries[@]}/$(echo ${!REGISTRIES[@]} | wc -w)):"
    for registry in "${available_registries[@]}"; do
        echo "   - $registry"
    done
    
    echo ""
    echo "🚀 推荐配置 Docker 镜像加速器:"
    echo "sudo mkdir -p /etc/docker"
    echo "sudo tee /etc/docker/daemon.json <<-'EOF'"
    echo "{"
    echo '  "registry-mirrors": ['
    
    # 根据可用性推荐镜像源
    if [[ " ${available_registries[@]} " =~ " 腾讯云 " ]]; then
        echo '    "https://ccr.ccs.tencentyun.com",'
    fi
    if [[ " ${available_registries[@]} " =~ " 网易 " ]]; then
        echo '    "https://hub-mirror.c.163.com",'
    fi
    if [[ " ${available_registries[@]} " =~ " 阿里云 " ]]; then
        echo '    "https://registry.cn-hangzhou.aliyuncs.com",'
    fi
    if [[ " ${available_registries[@]} " =~ " 华为云 " ]]; then
        echo '    "https://swr.cn-north-4.myhuaweicloud.com",'
    fi
    if [[ " ${available_registries[@]} " =~ " Azure中国 " ]]; then
        echo '    "https://dockerhub.azk8s.cn"'
    fi
    
    echo "  ]"
    echo "}"
    echo "EOF"
    echo "sudo systemctl daemon-reload"
    echo "sudo systemctl restart docker"
fi

echo ""
echo "🐳 Dockerfile 推荐策略:"
echo "======================="

if [[ " ${available_registries[@]} " =~ " Docker Hub " ]]; then
    echo "✅ 推荐使用: Dockerfile.local (官方镜像+国内Maven源)"
elif [[ " ${available_registries[@]} " =~ " 腾讯云 " ]]; then
    echo "✅ 推荐使用: Dockerfile.stable (腾讯云镜像源)"
elif [[ " ${available_registries[@]} " =~ " 网易 " ]]; then
    echo "✅ 推荐使用: Dockerfile.mirror (网易镜像源)"
else
    echo "⚠️  推荐使用: Dockerfile (标准版本，可能较慢)"
fi

echo ""
echo "测试完成! $(date)"
