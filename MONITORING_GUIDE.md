# YYS 监控与弹性扩展实践指南

## 概述

本文档提供了 YYS Spring Boot 应用的完整监控和自动扩容解决方案，包括 Prometheus 指标采集、Grafana 可视化监控、压力测试验证和 HPA 自动扩容配置。

## 1.3.1 采集 Prometheus 指标 ✅

### ServiceMonitor 配置

已通过 ServiceMonitor 实现 Prometheus 对 Kubernetes 中 Spring Boot 应用的指标采集：

```yaml
# k8s/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: yys-app-monitor
spec:
  selector:
    matchLabels:
      app: yys-app
  endpoints:
  - port: http
    path: /actuator/prometheus
    interval: 30s
    scrapeTimeout: 10s
```

### 可采集的指标类别

1. **Spring Boot Actuator 指标**:
   - JVM 内存使用 (`jvm_memory_used_bytes`)
   - GC 统计 (`jvm_gc_collection_seconds_count`)
   - HTTP 请求统计 (`http_server_requests_seconds_count`)
   - 线程池状态 (`executor_pool_size_threads`)

2. **自定义业务指标**:
   - 限流触发次数 (`http_server_requests_rate_limited_total`)
   - API 调用计数器
   - 业务操作统计

3. **系统资源指标**:
   - CPU 使用率 (`process_cpu_seconds_total`)
   - 内存使用情况
   - 磁盘空间状态

### 验证指标采集

```bash
# 检查 Prometheus 指标端点
curl http://localhost:8080/actuator/prometheus

# 验证特定指标
curl -s http://localhost:8080/actuator/prometheus | grep "jvm_memory_used_bytes"
```

## 1.3.2 配置 Grafana 监控面板 ✅

### Dashboard 配置

已创建完整的 Grafana Dashboard 配置文件 `monitoring/yys-dashboard.json`，包含以下监控面板：

#### 1. **资源监控面板**
- **CPU 使用率**: 实时 CPU 使用百分比，阈值告警
- **内存使用率**: JVM 堆内存使用率监控

#### 2. **JVM 监控面板**
- **堆内存使用情况**: 已用vs最大堆内存趋势图
- **GC 次数统计**: 垃圾回收频率和类型统计

#### 3. **应用性能面板**
- **HTTP 请求 QPS**: 每秒请求数统计
- **平均响应时间**: 接口响应时间趋势

### Dashboard 特性

1. **多维度监控**:
   ```
   - 系统资源: CPU、内存使用率
   - JVM 状态: 堆内存、GC 统计
   - 应用性能: QPS、响应时间
   ```

2. **告警阈值配置**:
   ```
   - CPU 使用率: 50%(黄色), 80%(红色)
   - 内存使用率: 70%(黄色), 90%(红色)
   ```

3. **时间范围**: 支持最近1小时到自定义时间范围

### 导入 Dashboard

1. 打开 Grafana Web 界面
2. 进入 "+" → "Import"
3. 上传 `monitoring/yys-dashboard.json` 文件
4. 配置数据源为 Prometheus
5. 保存并查看监控面板

## 1.3.3 压测验证监控效果 ✅

### 压力测试工具

提供了两个压测脚本来验证监控系统：

#### 1. **完整压测脚本** (`monitoring/load-test.sh`)
- 多阶段压力测试
- 自动生成测试报告
- 监控指标对比分析

#### 2. **简化压测脚本** (`monitoring/simple-load-test.sh`)
- 快速验证基本功能
- 并发请求测试
- 实时指标监控

### 执行压力测试

```bash
# 启动应用
mvn spring-boot:run &

# 执行简化压测
./monitoring/simple-load-test.sh

# 执行完整压测
./monitoring/load-test.sh
```

### 测试验证内容

1. **HTTP 请求统计验证**:
   - 请求计数增加
   - QPS 峰值测量
   - 响应时间变化

2. **JVM 性能验证**:
   - 内存使用率变化
   - GC 触发频率
   - 线程池状态

3. **业务指标验证**:
   - 限流机制触发
   - 自定义计数器更新

### 预期监控效果

在 Grafana 面板中应观察到：
- CPU 使用率曲线上升
- 内存使用率波动增加
- HTTP QPS 出现明显峰值
- 平均响应时间可能略有增加
- GC 频率可能增加

## 1.3.4 加分项：配置自动扩容 (+10分) ✅

### HPA 配置特性

已实现基于多重指标的智能自动扩容：

#### 1. **多重触发条件**
```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 50    # CPU 50% 触发扩容
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 70    # 内存 70% 触发扩容
- type: Pods
  pods:
    metric:
      name: http_requests_per_second
    target:
      type: AverageValue
      averageValue: "10"        # QPS 10 触发扩容
```

#### 2. **智能扩缩容策略**
```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 30     # 快速扩容
    policies:
    - type: Percent
      value: 100                       # 最多翻倍扩容
    - type: Pods
      value: 3                         # 最多增加3个Pod
  scaleDown:
    stabilizationWindowSeconds: 300    # 保守缩容
    policies:
    - type: Percent
      value: 20                        # 最多缩容20%
    - type: Pods
      value: 1                         # 最多减少1个Pod
```

#### 3. **副本数范围**
- **最小副本**: 2 个（保证高可用）
- **最大副本**: 10 个（防止资源耗尽）

### 部署 HPA 自动扩容

```bash
# 使用自动化脚本部署
./deploy-hpa.sh

# 手动部署方式
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/prometheus-adapter.yaml  # 自定义指标支持
```

### HPA 功能验证

#### 1. **查看 HPA 状态**
```bash
kubectl get hpa yys-app-hpa
kubectl describe hpa yys-app-hpa
```

#### 2. **触发自动扩容测试**
```bash
# 使用脚本执行负载测试
./deploy-hpa.sh
# 选择选项 2: 执行负载测试

# 手动触发高负载
kubectl port-forward service/yys-app 8080:8080 &
./monitoring/load-test.sh
```

#### 3. **观察扩容过程**
```bash
# 实时监控 Pod 数量变化
kubectl get pods -l app=yys-app -w

# 实时监控 HPA 状态
watch -n 2 "kubectl get hpa yys-app-hpa"
```

### 扩容触发条件

1. **CPU 负载触发**:
   - 当平均 CPU 使用率超过 50% 时触发扩容
   - 适用于 CPU 密集型请求处理

2. **内存压力触发**:
   - 当平均内存使用率超过 70% 时触发扩容
   - 防止内存溢出和性能下降

3. **QPS 负载触发**:
   - 当每个 Pod 平均 QPS 超过 10 时触发扩容
   - 基于业务负载的智能扩容

### 扩容效果验证

执行压力测试后，应观察到：

1. **HPA 状态变化**:
   ```
   NAME          REFERENCE           TARGETS         MINPODS   MAXPODS   REPLICAS
   yys-app-hpa   Deployment/yys-app  45%/50%, 35%/70%   2         10        3
   ```

2. **Pod 数量增加**:
   ```
   NAME                       READY   STATUS    RESTARTS
   yys-app-xxx-yyy           1/1     Running   0
   yys-app-xxx-zzz           1/1     Running   0
   yys-app-xxx-aaa           1/1     Running   0  # 新扩容的Pod
   ```

3. **负载分散效果**:
   - 单个 Pod 的 CPU/内存使用率下降
   - 整体系统吞吐量提升
   - 响应时间保持稳定

## 监控架构总览

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   YYS App       │    │   Prometheus     │    │   Grafana       │
│                 │    │                  │    │                 │
│ /actuator/      ├────► ServiceMonitor   ├────► Dashboard       │
│ prometheus      │    │                  │    │                 │
│                 │    │ Custom Metrics   │    │ Alerting        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Kubernetes    │    │ Prometheus       │    │   Alert         │
│   HPA           │    │ Adapter          │    │   Manager       │
│                 │    │                  │    │                 │
│ Auto Scaling    ◄────┤ Custom Metrics   │    │ Notifications   │
│                 │    │ API              │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 最佳实践建议

### 1. **监控指标优化**
- 根据业务特性调整采集频率
- 设置合理的告警阈值
- 定期清理历史数据

### 2. **扩容策略调优**
- 根据应用启动时间调整扩容速度
- 考虑成本因素设置最大副本数
- 监控扩容效果并调整阈值

### 3. **性能测试建议**
- 定期执行压力测试验证扩容效果
- 模拟真实业务场景的负载模式
- 测试极端情况下的系统行为

### 4. **故障处理**
- 配置告警通知机制
- 准备故障恢复预案
- 记录和分析扩容事件

## 总结

✅ **已完成的监控与扩容功能**:

1. **1.3.1 Prometheus 指标采集** - ServiceMonitor 配置完成
2. **1.3.2 Grafana 监控面板** - 6个监控面板配置完成
3. **1.3.3 压测验证** - 多种压测工具和验证脚本
4. **1.3.4 HPA 自动扩容** - 基于多重指标的智能扩容

该监控和扩容方案提供了：
- 📊 **全面监控**: CPU、内存、JVM、HTTP等多维度指标
- 📈 **可视化面板**: Grafana Dashboard 实时展示
- 🔥 **压力测试**: 自动化测试验证监控效果
- ⚖️ **智能扩容**: 基于负载的自动水平扩容
- 🛡️ **高可用保障**: 最小2副本，最大10副本保护

系统已具备生产级的监控和弹性伸缩能力！
