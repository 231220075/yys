# Docker 镜像加速配置说明

## 1. 配置 Docker 镜像加速器

### 1.1 在 Jenkins 节点上配置（需要管理员权限）

创建或编辑 `/etc/docker/daemon.json`：

```json
{
  "registry-mirrors": [
    "https://registry.docker-cn.com",
    "https://mirror.aliyuncs.com",
    "https://dockerhub.azk8s.cn",
    "https://reg-mirror.qiniu.com"
  ],
  "insecure-registries": ["172.22.83.19:30003"],
  "dns": ["8.8.8.8", "114.114.114.114"]
}
```

重启 Docker 服务：
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 1.2 在 Dockerfile 中使用国内镜像源

```dockerfile
# 使用阿里云镜像
FROM registry.cn-hangzhou.aliyuncs.com/library/maven:3.8.5-openjdk-17 AS builder
FROM registry.cn-hangzhou.aliyuncs.com/library/openjdk:17-jre-slim

# 或使用腾讯云镜像
FROM ccr.ccs.tencentyun.com/library/maven:3.8.5-openjdk-17 AS builder
FROM ccr.ccs.tencentyun.com/library/openjdk:17-jre-slim
```

## 2. Jenkins 构建超时配置

### 2.1 在 Jenkinsfile 中增加超时设置

```groovy
stage('Image Build') {
    steps {
        timeout(time: 20, unit: 'MINUTES') {
            script {
                try {
                    sh "docker build --cache-from ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:latest -t ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER} -t ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:latest ."
                } catch (Exception e) {
                    error "Docker build failed: ${e.getMessage()}"
                }
            }
        }
    }
}
```

### 2.2 Docker build 参数优化

```bash
# 使用缓存和多线程构建
docker build \
  --cache-from ${HARBOR_REGISTRY}/${IMAGE_NAME}:latest \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --progress=plain \
  -t ${HARBOR_REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} \
  -t ${HARBOR_REGISTRY}/${IMAGE_NAME}:latest .
```

## 3. 网络问题排查

### 3.1 测试网络连接

```bash
# 测试 Docker Hub 连接
curl -I https://registry-1.docker.io/v2/

# 测试 DNS 解析
nslookup registry-1.docker.io

# 测试镜像拉取
docker pull hello-world
```

### 3.2 常见解决方案

1. **代理设置**：如果在企业网络环境中
2. **防火墙规则**：检查是否被防火墙阻止
3. **DNS 配置**：使用稳定的 DNS 服务器
4. **重试机制**：在 Pipeline 中添加重试逻辑
