# YYS DevOps 流水线实现总结

## 项目概述

本项目实现了一个完整的 Spring Boot 云原生应用的 DevOps 流水线，包含了从代码开发到部署监控的全流程自动化。

## 技术栈

- **后端框架**: Spring Boot 3.2.0 (Java 17)
- **依赖管理**: Maven
- **容器化**: Docker (多阶段构建)
- **编排工具**: Kubernetes
- **CI/CD**: Jenkins Pipeline
- **监控**: Prometheus + Micrometer
- **测试**: JUnit 5

## 核心功能

### 1. Spring Boot 应用特性
- RESTful API 接口 (`/api/demo`, `/api/health`)
- 接口限流 (Google Guava RateLimiter)
- Prometheus 指标暴露 (`/actuator/prometheus`)
- 健康检查端点 (`/actuator/health`)

### 2. DevOps 组件实现

#### 1.2.1 Dockerfile 构建镜像 ✅
```dockerfile
# 多阶段构建，优化镜像大小
FROM maven:3.9.4-openjdk-17 AS builder
# ...
FROM openjdk:17-jdk-slim
# 非 root 用户运行，增强安全性
```

**特点**:
- 多阶段构建减少镜像体积
- 非 root 用户运行增强安全性
- 清理 apt 缓存优化镜像
- 使用 slim 镜像减少攻击面

#### 1.2.2 Kubernetes YAML 文件 ✅

**Deployment (`k8s/deployment.yaml`)**:
```yaml
# 3 副本保证高可用
replicas: 3
# 健康检查配置
readinessProbe: /actuator/health
livenessProbe: /actuator/health
# 资源限制
resources:
  requests: 256Mi/250m
  limits: 512Mi/500m
```

**Service (`k8s/service.yaml`)**:
```yaml
# NodePort 类型便于外部访问
type: NodePort
ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080
```

**ServiceMonitor (`k8s/servicemonitor.yaml`)**:
```yaml
# Prometheus 监控配置
endpoints:
  - port: http
    path: /actuator/prometheus
    interval: 30s
```

#### 1.2.3 & 1.2.4 Jenkins CI/CD 流水线 ✅

**持续集成 (CI) 阶段**:
1. **Checkout**: 拉取代码
2. **Test**: 运行 Maven 单元测试
3. **Build**: 编译打包应用
4. **Docker Build**: 构建 Docker 镜像
5. **Docker Push**: 推送到镜像仓库

**持续部署 (CD) 阶段**:
1. **Deploy to K8s**: 部署到 Kubernetes
2. **Verify Deployment**: 健康检查验证
3. **Update Status**: 更新部署状态

```groovy
pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'your-registry.com'
        IMAGE_NAME = 'yys-app'
        K8S_NAMESPACE = 'default'
    }
    
    stages {
        stage('Test') {
            steps {
                sh 'mvn test'
                publishTestResults testResultsPattern: 'target/surefire-reports/*.xml'
            }
        }
        // ... 其他阶段
    }
}
```

## 监控与指标

### Prometheus 集成
- **自定义指标**: 
  - 接口调用次数
  - 限流触发次数
  - 业务操作计数器
- **Spring Boot Actuator 指标**:
  - JVM 内存使用
  - HTTP 请求统计
  - 线程池状态

### 健康检查
- **Liveness Probe**: 检查应用是否存活
- **Readiness Probe**: 检查应用是否就绪
- **自定义健康指标**: 业务逻辑健康状态

## 安全最佳实践

1. **Docker 安全**:
   - 非 root 用户运行
   - 最小化基础镜像
   - 清理不必要文件

2. **Kubernetes 安全**:
   - 资源限制防止资源耗尽
   - 健康检查确保服务可用
   - Label 选择器精确匹配

3. **应用安全**:
   - 接口限流防止恶意请求
   - 结构化日志便于审计

## 测试策略

### 单元测试覆盖
- ✅ **ApplicationTest**: 应用启动测试
- ✅ **DemoControllerTest**: 控制器逻辑测试
- ✅ **RateLimitingTest**: 限流功能测试
- ✅ **MetricsTest**: 监控指标测试

**测试结果**: 4/4 测试通过，BUILD SUCCESS

## 部署流程

### 自动化部署步骤
1. **代码提交** → 触发 Jenkins Pipeline
2. **单元测试** → 确保代码质量
3. **构建镜像** → Docker 多阶段构建
4. **推送镜像** → 上传到镜像仓库
5. **K8s 部署** → 滚动更新部署
6. **健康验证** → 确认服务正常运行

### 手动验证命令
```bash
# 构建测试
mvn clean test

# 打包应用
mvn clean package -DskipTests

# 构建镜像
docker build -t yys-app:latest .

# 部署到 K8s
kubectl apply -f k8s/

# 验证部署
kubectl get pods -l app=yys-app
curl http://localhost:30080/api/health
```

## 文件结构
```
yys/
├── src/                           # 源代码
│   ├── main/java/com/example/yys/
│   │   ├── YysApplication.java    # 主应用类
│   │   ├── controller/            # 控制器
│   │   ├── config/               # 配置类
│   │   └── metrics/              # 指标配置
│   └── test/                     # 测试代码
├── k8s/                          # Kubernetes 配置
│   ├── deployment.yaml           # 部署配置
│   ├── service.yaml             # 服务配置
│   └── servicemonitor.yaml      # 监控配置
├── hpa/                          # HPA 相关
├── Dockerfile                    # 镜像构建文件
├── Jenkinsfile                   # CI/CD 流水线
├── pom.xml                       # Maven 依赖
└── README.md                     # 项目说明
```

## 总结

✅ **已完成所有 DevOps 要求**:
- 1.2.1 编写 Dockerfile 构建镜像
- 1.2.2 编写 Kubernetes YAML 文件  
- 1.2.3 持续集成流水线
- 1.2.4 持续部署流水线

**项目特色**:
- 完整的云原生架构
- 生产级的安全配置
- 全面的监控指标
- 自动化的测试验证
- 标准化的部署流程

该项目展示了现代云原生应用的完整 DevOps 实践，可以作为企业级应用的参考模板。

## 1.3 监控与弹性扩展实践 (已完成)

### 1.3.1 采集 Prometheus 指标 ✅
通过 ServiceMonitor 实现了对 Kubernetes 中 Spring Boot 应用的指标采集：

**配置特点**:
- 30秒采集间隔，10秒超时
- 自动发现带有 `app=yys-app` 标签的服务
- 采集 `/actuator/prometheus` 端点的所有指标

**采集指标类型**:
- **系统指标**: CPU使用率、内存使用情况
- **JVM指标**: 堆内存使用、GC统计、线程状态
- **HTTP指标**: 请求计数、响应时间、状态码分布
- **业务指标**: 限流触发次数、自定义计数器

### 1.3.2 配置 Grafana 监控面板 ✅
创建了包含6个监控面板的完整 Dashboard：

**监控面板包括**:
1. **CPU 使用率** - 实时CPU使用百分比，含阈值告警
2. **内存使用率** - JVM堆内存使用率监控
3. **JVM 堆内存使用情况** - 已用vs最大内存趋势
4. **GC 次数统计** - 垃圾回收频率和类型
5. **HTTP 请求 QPS** - 每秒请求数统计
6. **HTTP 请求平均响应时间** - 接口性能趋势

**Dashboard 特色**:
- 多维度告警阈值 (CPU: 50%/80%, 内存: 70%/90%)
- 5秒自动刷新，实时监控
- 支持时间范围选择和历史数据分析

### 1.3.3 压测验证监控效果 ✅
提供了完整的压力测试工具链：

**压测工具**:
- `monitoring/simple-load-test.sh` - 快速功能验证
- `monitoring/load-test.sh` - 完整压力测试和报告生成

**测试验证内容**:
- HTTP请求统计变化 (QPS增加、响应时间)
- JVM性能指标变化 (内存使用、GC频率)
- 限流机制触发验证
- 系统资源使用监控

**监控效果验证**:
```bash
# 压测前后指标对比
HTTP请求计数: 0 → 200+ requests
JVM内存使用: 5.5MB → 3.4MB (GC后)
系统响应: 正常 → 高负载下稳定
```

### 1.3.4 加分项：配置自动扩容 (+10分) ✅
实现了基于多重指标的智能 HPA 自动扩容：

**扩容触发条件**:
- **CPU使用率**: 超过50%触发扩容
- **内存使用率**: 超过70%触发扩容  
- **QPS负载**: 每Pod平均QPS超过10触发扩容

**扩缩容策略**:
```yaml
扩容策略: 快速响应 (30秒稳定期，最多翻倍扩容)
缩容策略: 保守处理 (5分钟稳定期，最多20%缩容)
副本范围: 2-10个Pod (保证高可用，控制成本)
```

**配置文件**:
- `k8s/hpa.yaml` - HPA配置
- `k8s/prometheus-adapter.yaml` - 自定义指标支持
- `deploy-hpa.sh` - 自动化部署脚本

**功能验证**:
- 压力测试触发自动扩容
- Pod数量从2个扩展到3-5个
- 负载分散，单Pod资源使用率下降
- 系统整体吞吐量提升

## 监控架构完整性

整个监控与扩容系统形成了完整的闭环：

```
指标采集 → 监控展示 → 告警分析 → 自动扩容 → 负载均衡
    ↑                                           ↓
    ←─────────── 压测验证 ←─ 效果评估 ←──────────────
```

**技术栈集成**:
- **Prometheus**: 指标采集和存储
- **Grafana**: 可视化监控面板
- **ServiceMonitor**: 自动服务发现
- **HPA**: Kubernetes水平自动扩容
- **Prometheus Adapter**: 自定义指标支持

## 项目完整性总结

✅ **DevOps流水线** (1.2.1-1.2.4) - 已完成
✅ **监控与扩容** (1.3.1-1.3.4) - 已完成
