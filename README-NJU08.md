# NJU08 团队云原生应用部署指南

## 概述
本项目为NJU08团队提供完整的云原生应用解决方案，包括Spring Boot应用、Docker容器化、Kubernetes部署、Jenkins CI/CD流水线、Prometheus监控和HPA自动扩容。

## 🏗️ 架构组件

### 1. 应用层
- **Spring Boot 3.2.0**: REST API服务
- **Prometheus集成**: /actuator/prometheus指标端点
- **健康检查**: /actuator/health端点
- **限流保护**: Bucket4j实现的API限流

### 2. 容器层
- **Harbor私有镜像仓库**: 172.22.83.19:30003/nju08/yys-app
- **多阶段Docker构建**: Maven + OpenJDK运行时
- **镜像安全**: 非root用户运行

### 3. 编排层
- **命名空间**: nju08 (团队隔离)
- **部署策略**: 滚动更新
- **服务发现**: ClusterIP + NodePort (30008)
- **资源限制**: CPU/内存配额

### 4. CI/CD层
- **Jenkins Pipeline**: 多Agent架构
- **自动化流程**: 代码检查 → 构建 → 测试 → 部署
- **Harbor集成**: 私有镜像推送和拉取

### 5. 监控层
- **Prometheus**: 指标采集
- **Grafana**: 可视化面板
- **ServiceMonitor**: 自动服务发现

### 6. 扩容层
- **HPA**: CPU/内存基础的自动扩容
- **副本范围**: 2-10个Pod
- **扩容策略**: 渐进式扩容/缩容

## 🚀 快速部署

### 前置条件
```bash
# 1. 确保kubectl已配置
kubectl cluster-info

# 2. 确保有Harbor访问权限
# 联系管理员获取 172.22.83.19:30003 的访问凭据

# 3. 创建Harbor访问秘钥
kubectl create secret docker-registry harbor-secret \
  --docker-server=172.22.83.19:30003 \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  --namespace=nju08
```

### 一键部署
```bash
# 执行nju08专用部署脚本
./deploy-nju08.sh
```

### 手动部署
```bash
# 1. 创建命名空间
kubectl create namespace nju08
kubectl label namespace nju08 team=nju08

# 2. 部署应用
kubectl apply -f k8s/deployment-nju08.yaml
kubectl apply -f k8s/service-nju08.yaml

# 3. 部署监控和HPA
kubectl apply -f hpa/hpa-nju08.yaml

# 4. 检查部署状态
kubectl get all -n nju08
```

## 📊 监控和运维

### 查看应用状态
```bash
# Pod状态
kubectl get pods -n nju08 -l app=yys-app

# 服务状态
kubectl get svc -n nju08

# HPA状态
kubectl get hpa yys-app-hpa -n nju08 -w
```

### 应用访问
- **内部访问**: `http://yys-app-service.nju08.svc.cluster.local:8080`
- **外部访问**: `http://<NODE_IP>:30008`
- **健康检查**: `http://<NODE_IP>:30008/actuator/health`
- **Prometheus指标**: `http://<NODE_IP>:30008/actuator/prometheus`

### 日志查看
```bash
# 实时日志
kubectl logs -f deployment/yys-app -n nju08

# 历史日志
kubectl logs deployment/yys-app -n nju08 --previous
```

### 压力测试
```bash
# 使用Apache Bench进行压测
ab -n 1000 -c 10 http://<NODE_IP>:30008/api/hello

# 观察HPA响应
kubectl get hpa yys-app-hpa -n nju08 -w
```

## 🔧 Jenkins CI/CD

### Pipeline配置
Jenkins流水线已配置为多Agent架构：
- **主节点**: 代码检出和协调
- **构建节点**: Maven构建和Docker构建
- **部署节点**: Kubernetes部署

### 流水线阶段
1. **代码检查**: Git检出和Maven验证
2. **单元测试**: Maven test execution
3. **构建镜像**: Docker build with Harbor push
4. **部署应用**: Kubernetes rolling update
5. **健康检查**: 应用启动验证

### 环境变量
```groovy
HARBOR_REGISTRY = '172.22.83.19:30003'
IMAGE_NAME = 'nju08/yys-app'
NAMESPACE = 'nju08'
SERVICE_NAME = 'yys-app'
```

## 📈 扩容策略

### HPA配置
- **最小副本**: 2
- **最大副本**: 10
- **CPU阈值**: 70%
- **内存阈值**: 80%

### 扩容行为
- **扩容速度**: 每60秒最多扩容100%
- **缩容速度**: 每60秒最多缩容10%
- **稳定窗口**: 扩容60秒，缩容300秒

## 🛡️ 安全配置

### 网络安全
- **命名空间隔离**: nju08专用命名空间
- **NodePort端口**: 30008 (nju08专用)
- **镜像拉取**: Harbor私有仓库

### 容器安全
- **非root运行**: 用户ID 1001
- **资源限制**: CPU 500m/1000m, 内存 512Mi/1Gi
- **健康检查**: 存活性和就绪性探针

## 🔍 故障排查

### 常见问题

#### 1. Pod无法启动
```bash
# 检查Pod状态
kubectl describe pod <pod-name> -n nju08

# 检查镜像拉取
kubectl get events -n nju08 --sort-by='.lastTimestamp'
```

#### 2. Harbor镜像拉取失败
```bash
# 检查秘钥
kubectl get secret harbor-secret -n nju08

# 重新创建秘钥
kubectl delete secret harbor-secret -n nju08
kubectl create secret docker-registry harbor-secret \
  --docker-server=172.22.83.19:30003 \
  --docker-username=<username> \
  --docker-password=<password> \
  --namespace=nju08
```

#### 3. HPA不工作
```bash
# 检查metrics-server
kubectl top nodes
kubectl top pods -n nju08

# 检查HPA状态
kubectl describe hpa yys-app-hpa -n nju08
```

#### 4. 服务无法访问
```bash
# 检查Service和Endpoints
kubectl get svc,ep -n nju08

# 检查防火墙
sudo ufw status
```

## 📚 相关文档

- [Spring Boot Actuator指南](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Kubernetes HPA文档](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Prometheus监控最佳实践](https://prometheus.io/docs/practices/)
- [Harbor镜像仓库文档](https://goharbor.io/docs/)

## 🤝 团队信息

- **团队**: NJU08
- **命名空间**: nju08
- **NodePort**: 30008
- **镜像仓库**: 172.22.83.19:30003/nju08/*

---
*本文档由云原生DevOps团队维护，如有问题请联系项目负责人。*
