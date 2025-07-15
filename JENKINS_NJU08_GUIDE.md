# Jenkins Pipeline 配置说明 (nju08版本)

## 🔄 Pipeline 概述

这个Jenkins Pipeline是专门为nju08小组定制的，基于Harbor私有镜像仓库和Kubernetes集群的完整CI/CD流程。

## 📋 主要配置

### 环境变量
```groovy
environment {
    HARBOR_REGISTRY = '172.22.83.19:30003'    // Harbor镜像仓库地址
    IMAGE_NAME = 'nju08/yys-app'               // 镜像名称 (nju08项目)
    GIT_REPO = 'https://gitee.com/nju231220075_1/yys.git'  // Git仓库地址
    NAMESPACE = 'nju08'                        // Kubernetes命名空间
    MONITOR_NAMESPACE = 'nju08'                // 监控命名空间
    HARBOR_USER = 'nju08'                      // Harbor用户名
}
```

### 参数化构建
- `HARBOR_PASS`: Harbor登录密码（构建时输入）

## 🔧 Pipeline 阶段详解

### 1. Clone Code (主节点)
- 从Gitee克隆源代码
- 使用master标签的Jenkins节点

### 2. Unit Test (主节点)
- 使用Docker容器运行Maven单元测试
- 容器: `maven:3.9.4-openjdk-17`
- 生成测试报告并发布到Jenkins

### 3. Image Build (主节点)
- 使用Dockerfile多阶段构建
- 构建两个标签: `BUILD_NUMBER` 和 `latest`
- 利用缓存提高构建速度

### 4. Push (主节点)
- 登录Harbor私有仓库
- 推送Docker镜像到Harbor

### 5. Deploy to Kubernetes (从节点)
使用`jnlp-kubectl`容器执行以下子阶段：

#### 5.1 Clone YAML
- 在slave节点克隆YAML配置文件

#### 5.2 Config YAML
- 动态替换YAML文件中的变量:
  - 镜像地址和版本号
  - 命名空间配置
  - 监控命名空间

#### 5.3 Deploy YYS Application
- 创建nju08命名空间
- 部署Deployment和Service

#### 5.4 Deploy ServiceMonitor
- 部署Prometheus监控配置
- 支持监控指标采集

#### 5.5 Deploy HPA
- 部署水平自动扩容器
- 部署metrics-server

#### 5.6 Health Check
- 等待Pod就绪
- 验证部署状态
- 检查各项服务

## 🐳 Docker配置要求

### Dockerfile要求
确保项目根目录存在Dockerfile，支持多阶段构建：
```dockerfile
# 第一阶段：Maven构建
FROM maven:3.9.4-openjdk-17 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# 第二阶段：运行环境
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
```

## 📁 Kubernetes配置

确保以下YAML文件存在并正确配置：

### 必需文件
- `k8s/deployment.yaml` - 应用部署配置
- `k8s/service.yaml` - 服务配置
- `k8s/servicemonitor.yaml` - Prometheus监控配置
- `k8s/hpa.yaml` - 水平自动扩容配置
- `hpa/metrics-server.yaml` - 指标服务器配置

### YAML模板变量
Pipeline会自动替换以下变量：
- `yys-app:latest` → `172.22.83.19:30003/nju08/yys-app:${BUILD_NUMBER}`
- `namespace: default` → `namespace: nju08`

## 🔐 Jenkins配置要求

### 节点标签
- **master**: 执行Git克隆、构建、推送
- **slave**: 执行Kubernetes部署

### 容器配置
- slave节点需要配置`jnlp-kubectl`容器
- 容器需要kubectl工具和Kubernetes集群访问权限

### 凭据配置
- Harbor仓库访问权限
- Kubernetes集群访问权限

## 🎯 使用方法

### 1. 创建Jenkins Pipeline Job
1. 新建Pipeline项目
2. 配置Git仓库: `https://gitee.com/nju231220075_1/yys.git`
3. 指定Jenkinsfile路径

### 2. 运行Pipeline
1. 点击"Build with Parameters"
2. 输入Harbor密码
3. 启动构建

### 3. 监控构建过程
- 查看各阶段执行状态
- 检查测试报告
- 验证部署结果

## 📊 构建结果

### 成功输出示例
```
✅ Deployment Summary:
   - Image: 172.22.83.19:30003/nju08/yys-app:123
   - Namespace: nju08
   - Monitor Namespace: nju08
   - Services: Deployment, Service, ServiceMonitor, HPA
```

### 部署验证
```bash
# 检查部署状态
kubectl get pods -n nju08
kubectl get svc -n nju08
kubectl get hpa -n nju08

# 检查应用健康
kubectl logs -l app=yys-app -n nju08
```

## 🔍 故障排除

### 常见问题

1. **Harbor登录失败**
   - 检查用户名密码
   - 确认Harbor服务可访问

2. **Kubernetes部署失败**
   - 检查kubectl配置
   - 验证集群连接
   - 确认命名空间权限

3. **Docker构建失败**
   - 检查Dockerfile语法
   - 确认基础镜像可用
   - 验证构建上下文

4. **测试失败**
   - 检查Maven配置
   - 验证测试代码
   - 查看详细错误日志

## 🚀 优化建议

1. **缓存优化**: 使用Docker构建缓存
2. **并行执行**: 可以并行执行独立的测试
3. **资源限制**: 为容器设置资源限制
4. **通知机制**: 配置邮件或即时通讯通知
5. **版本管理**: 使用Git标签进行版本管理

这个Pipeline提供了完整的从代码到部署的自动化流程，适合nju08小组的开发和部署需求。
