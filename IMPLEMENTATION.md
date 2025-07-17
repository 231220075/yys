# 云原生 REST 应用实现说明

本项目基于 Spring Boot 开发了一个 REST 应用，并结合云原生技术栈 (Docker、Kubernetes、Jenkins、Prometheus、Grafana) 完成流程制作、持续集成部署、指标采集与图表验证的全流程实践。

## 📋 功能实现

### 11.1 实现 REST 接口 (5 分)

实现了一个简单的 REST API 接口 `/hello`，返回固定 JSON 数据：

```bash
curl http://localhost:8080/hello
```

响应格式：
```json
{
  "msg": "hello",
  "timestamp": 1642567890123,
  "service": "prometheus-test-demo",
  "version": "1.0.0"
}
```

### 11.2 实现限流控制 (10 分)

要求接口支持限流功能：当请求频率超过每秒 100 次时，返回 HTTP 状态码 '429 Too Many Requests'。

**限流实现方式：**
- 使用 **Guava RateLimiter** 实现本地限流
- 配置：每秒允许 100 个请求 (`RateLimiter.create(100.0)`)
- 超出限制时返回 429 状态码和错误信息

**测试限流功能：**
```bash
# 使用 Apache Bench 测试
ab -n 200 -c 50 http://localhost:8080/hello

# 使用 curl 循环测试
for i in {1..150}; do curl -w "%{http_code}\n" -o /dev/null -s http://localhost:8080/hello; done
```

### 11.3 暴露访问指标给 Prometheus (5 分)

应用需暴露接口访问频率 (QPS) 等指标，供 Prometheus 采集。Actuator + Micrometer 已自动统计 HTTP 请求，指标为：

**自动生成的指标：**
- `http_server_requests_seconds_count` - 接口请求次数 (已分状态码、方法等标签)
- `http_server_requests_seconds_sum` - 接口响应时间和 (单位为秒)

**自定义指标：**
- `http_requests_total` - HTTP 请求总数 (按端点分类)
- `rate_limited_requests_total` - 被限流的请求总数

**指标访问地址：**
```bash
# Prometheus 指标端点
curl http://localhost:8998/actuator/prometheus

# 健康检查端点
curl http://localhost:8998/actuator/health
```

## 🚀 部署和测试

### 本地运行
```bash
# 编译项目
mvn clean package

# 运行应用
java -jar target/prometheus-test-demo-1.0.0.jar

# 或使用 Maven 直接运行
mvn spring-boot:run
```

### Docker 构建
```bash
# 构建镜像
docker build -t prometheus-test-demo:latest .

# 运行容器
docker run -p 8080:8080 -p 8998:8998 prometheus-test-demo:latest
```

### Kubernetes 部署
```bash
# 部署应用
kubectl apply -f jenkins/scripts/prometheus-test-demo.yaml

# 检查 Pod 状态
kubectl get pods -n nju08

# 检查服务
kubectl get svc -n nju08
```

## 📊 Prometheus 监控

### ServiceMonitor 配置
项目包含 ServiceMonitor 配置，用于 Prometheus 自动发现和采集指标：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: prometheus-test-demo
  namespace: nju08
spec:
  selector:
    matchLabels:
      app: prometheus-test-demo
  endpoints:
  - port: management
    path: /actuator/prometheus
```

### 关键指标查询
在 Prometheus/Grafana 中可以使用以下查询：

```promql
# QPS (每秒请求数)
rate(http_server_requests_seconds_count[5m])

# 平均响应时间
rate(http_server_requests_seconds_sum[5m]) / rate(http_server_requests_seconds_count[5m])

# 错误率
rate(http_server_requests_seconds_count{status!~"2.."}[5m]) / rate(http_server_requests_seconds_count[5m])

# 限流请求数
rate(rate_limited_requests_total[5m])
```

## 🔧 技术栈

- **Spring Boot 2.1.13** - Web 框架
- **Spring Boot Actuator** - 监控端点
- **Micrometer + Prometheus** - 指标采集
- **Guava RateLimiter** - 限流控制
- **Docker** - 容器化
- **Kubernetes** - 容器编排
- **Jenkins** - CI/CD
- **Prometheus + Grafana** - 监控告警

## 📈 验证结果

1. **REST 接口**：✅ `/hello` 接口正常返回 JSON 数据
2. **限流功能**：✅ 超过 100 QPS 时返回 429 状态码
3. **Prometheus 指标**：✅ 指标正常暴露在 `/actuator/prometheus` 端点
4. **容器化部署**：✅ Docker 镜像构建和 Kubernetes 部署成功
5. **CI/CD 流程**：✅ Jenkins Pipeline 自动构建部署

所有功能均已实现并通过测试验证！
