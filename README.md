# YYS 云原生应用项目

基于 Spring Boot 开发的 REST 应用，结合云原生技术栈完成限流控制、持续集成部署、指标采集和扩容验证的全流程实践。

## 项目结构

```
yys/
├── src/main/java/com/example/yys/
│   ├── YysApplication.java           # 应用主类
│   ├── controller/
│   │   └── HelloController.java     # REST控制器
│   ├── service/
│   │   └── RateLimitService.java    # 限流服务
│   └── config/
│       └── MetricsConfig.java       # 指标配置
├── src/main/resources/
│   └── application.yml              # 应用配置
├── k8s/
│   └── deployment.yaml              # Kubernetes部署文件
├── hpa/                             # HPA相关配置
├── scripts/
│   └── load-test.sh                 # 压力测试脚本
├── Dockerfile                       # Docker镜像构建文件
├── Jenkinsfile                      # CI/CD流水线配置
└── pom.xml                          # Maven依赖配置
```

## 功能特性

### 1.1.1 REST 接口实现 ✅

- **GET /api/hello**: 返回固定JSON数据 `{"msg": "hello"}`
- **GET /api/health**: 健康检查接口
- **GET /api/info**: 应用信息和限流状态
- **GET /actuator/prometheus**: Prometheus指标端点

### 1.1.2 限流控制 ✅

支持多种限流实现方式：

- **Google Guava RateLimiter**: 每秒100个请求
- **Bucket4j**: 备选方案，支持突发流量
- **自定义限流器**: 基于原子计数器
- **Spring Cloud Gateway**: 高级限流功能

当请求频率超过每秒100次时，返回HTTP状态码 `429 Too Many Requests`。

### 1.1.3 Prometheus指标暴露 ✅

应用自动暴露以下指标给Prometheus采集：

```
# 接口请求次数（已分状态码、方法等标签）
http_server_requests_seconds_count

# 接口响应时间总和（单位为秒）
http_server_requests_seconds_sum

# 活跃连接数
http_server_active_connections
```

## 快速开始

### 本地开发

1. **编译并运行应用**:
```bash
mvn clean package
java -jar target/yys-app-1.0.0.jar
```

2. **测试接口**:
```bash
# 基本功能测试
curl http://localhost:8080/api/hello

# 健康检查
curl http://localhost:8080/actuator/health

# 查看指标
curl http://localhost:8080/actuator/prometheus
```

3. **限流测试**:
```bash
# 运行压力测试脚本
./scripts/load-test.sh http://localhost:8080 50 60
```

### Docker部署

1. **构建镜像**:
```bash
docker build -t yys-app:latest .
```

2. **运行容器**:
```bash
docker run -p 8080:8080 yys-app:latest
```

### Kubernetes部署

1. **部署应用**:
```bash
kubectl apply -f k8s/deployment.yaml
```

2. **部署HPA**:
```bash
kubectl apply -f hpa/metrics-server.yaml
kubectl apply -f hpa/service-hpa.yaml
```

3. **检查状态**:
```bash
kubectl get pods -l app=yys-app
kubectl get hpa yys-app-hpa
```

## 技术栈

- **框架**: Spring Boot 3.2.0
- **Java版本**: 17
- **限流**: Google Guava RateLimiter + Bucket4j
- **指标**: Micrometer + Prometheus
- **容器**: Docker
- **编排**: Kubernetes
- **CI/CD**: Jenkins
- **监控**: Prometheus + Grafana

## 监控与运维

### 关键指标

1. **QPS指标**: `http_server_requests_seconds_count`
2. **响应时间**: `http_server_requests_seconds_sum`
3. **限流状态**: 通过 `/api/info` 接口查看
4. **HPA状态**: `kubectl get hpa yys-app-hpa`

### 扩容验证

应用配置了HPA，当CPU使用率超过60%或内存使用率超过70%时会自动扩容：

- 最小副本数: 2
- 最大副本数: 10
- 扩容策略: 渐进式扩容，避免过度扩容

## 压力测试

使用提供的压力测试脚本：

```bash
# 基本测试（默认50并发，5分钟）
./scripts/load-test.sh

# 自定义参数测试
./scripts/load-test.sh http://your-service-url 100 300
```

测试内容：
1. 功能测试：验证各接口正常响应
2. 限流测试：验证每秒100请求的限制
3. 压力测试：模拟高并发场景
4. HPA监控：观察自动扩容行为

## 开发说明

### 添加新接口

在 `HelloController` 中添加新的REST端点，参考现有实现模式。

### 修改限流策略

在 `RateLimitService` 中调整限流参数：
- 修改 `RateLimiter.create(100.0)` 中的数值
- 调整Bucket4j的容量和补充速率

### 自定义指标

在 `MetricsConfig` 中添加新的自定义指标。

## 故障排查

### 常见问题

1. **限流不生效**: 检查 `RateLimitService` 配置
2. **指标不显示**: 确认Actuator端点已暴露
3. **HPA不扩容**: 检查metrics-server和资源使用率
4. **容器启动失败**: 查看Docker日志和健康检查

### 日志查看

```bash
# 应用日志
kubectl logs -f deployment/yys-app

# HPA事件
kubectl describe hpa yys-app-hpa
```

## DevOps 流水线构建与部署

### 1.2.1 Dockerfile构建镜像 ✅

项目使用多阶段构建的Dockerfile：

```dockerfile
# 构建阶段
FROM maven:3.9.4-openjdk-17 AS builder
# 运行时阶段  
FROM openjdk:17-jre-slim
```

**特性：**
- 多阶段构建，减少镜像大小
- 非root用户运行，提高安全性
- 健康检查配置
- 生产就绪的镜像配置

### 1.2.2 Kubernetes YAML文件 ✅

准备以下资源对象的YAML文件：

- **Deployment** (包含多个副本): `k8s/deployment.yaml`
- **Service** (暴露服务): `k8s/deployment.yaml`  
- **ServiceMonitor** 配置: `k8s/servicemonitor.yaml`
- **ImagePullPolicy** 配置: 设置为 `Always`

```bash
# 部署所有资源
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/servicemonitor.yaml
kubectl apply -f hpa/service-hpa.yaml
```

### 1.2.3 持续集成流水线 ✅

Jenkins CI流水线 (`Jenkinsfile`) 实现以下功能：

- **拉取代码**: 从Git仓库检出代码
- **构建项目**: 使用Maven进行编译构建
- **运行单元测试**: 执行JUnit测试并生成报告
- **构建并推送Docker镜像**: 自动标记并推送到镜像仓库

```bash
# 手动触发构建流程
mvn clean test                    # 运行测试
mvn clean package               # 构建项目
docker build -t yys-app:latest   # 构建镜像
```

### 1.2.4 持续部署流水线 ✅

Jenkins CD流水线实现Kubernetes部署过程：

- **拉取镜像**: 从镜像仓库拉取最新镜像
- **执行kubectl apply**: 部署服务到Kubernetes
- **检查部署是否成功**: 验证Pod状态和健康检查

```bash
# 手动部署命令
kubectl apply -f k8s/deployment.yaml
kubectl rollout status deployment/yys-app
kubectl get pods -l app=yys-app
```

### CI/CD 流水线特性

**集成流水线 (CI):**
- 自动代码质量检查
- 单元测试覆盖率报告
- Docker镜像安全扫描
- 构建状态通知

**部署流水线 (CD):**
- 蓝绿部署支持
- 滚动更新策略
- 自动回滚机制
- 部署状态监控
