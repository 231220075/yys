# NJU08 Prometheus Test Demo

基于 Spring Boot 3.x 和 Java 17 的云原生微服务演示项目，集成限流和监控功能。

## 项目特性

- ✅ **Spring Boot 3.2.0** + **Java 17**
- ✅ **限流功能** - Google Guava RateLimiter（每秒100请求）
- ✅ **健康检查** - Spring Boot Actuator
- ✅ **容器化** - Docker 多阶段构建
- ✅ **云原生** - Kubernetes 部署支持
- ✅ **CI/CD** - Jenkins 流水线
- ✅ **监控** - Prometheus ServiceMonitor

## 快速开始

### 本地运行
```bash
# 编译项目
mvn clean package

# 运行应用
java -jar target/nju08-0.0.1-SNAPSHOT.jar

# 测试接口
curl http://localhost:8080/hello
curl http://localhost:8080/actuator/health
```

### Docker 部署
```bash
# 构建镜像
docker build -t nju08:latest .

# 运行容器
docker run -p 8080:8080 nju08:latest
```

### Kubernetes 部署
```bash
# 部署到 K8s
kubectl apply -f k8s/

# 查看状态
kubectl get pods,svc -l app=nju08
```

## API 接口

| 端点 | 方法 | 描述 |
|------|------|------|
| `/hello` | GET | 主业务接口（带限流保护） |
| `/actuator/health` | GET | 应用健康检查 |
| `/actuator/metrics` | GET | 应用指标信息 |

## 限流策略

- **限流算法**: Google Guava RateLimiter
- **限流阈值**: 100 请求/秒
- **超限响应**: HTTP 429 Too Many Requests

## 小组信息

- **小组编号**: NJU08
- **项目名称**: prometheus-test-demo
- **技术栈**: Spring Boot + Kubernetes + Prometheus
