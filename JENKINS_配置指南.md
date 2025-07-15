# Jenkins Pipeline 配置指南 - NJU08团队

## 🚨 问题解决

### 刚才遇到的问题及解决方案

#### 问题1: Git分支配置错误
**错误信息**: `Couldn't find any revision to build. Verify the repository and branch configuration for this job.`

**原因**: Jenkinsfile中使用了`git url: "${env.GIT_REPO}"`，试图检出master分支，但代码在hpa分支

**解决方案**: 使用`checkout scm`替代硬编码的git URL

#### 问题2: Post Actions执行错误  
**错误信息**: `Required context class hudson.FilePath is missing`

**原因**: 在post actions中直接执行sh命令，缺少node上下文

**解决方案**: 在post actions的sh命令外包装`node('master')`

#### 问题3: Docker镜像拉取超时
**错误信息**: `Get "https://registry-1.docker.io/v2/": context deadline exceeded`

**原因**: Jenkins环境无法访问Docker Hub，网络连接超时

**解决方案**: 使用多镜像源智能选择策略

#### 问题4: 镜像仓库访问被拒绝
**错误信息**: `pull access denied for registry.cn-hangzhou.aliyuncs.com/library/maven`

**原因**: 镜像仓库路径错误或需要认证

**解决方案**: 使用公开可访问的镜像源（腾讯云、网易等）

## ⚙️ Jenkins Job 配置

### 1. 创建Pipeline Job
```
1. 登录Jenkins
2. 新建Item → Pipeline
3. 名称: yys-nju08-pipeline
4. 配置Pipeline
```

### 2. Pipeline配置
#### Source Code Management
- **Repository URL**: `https://gitee.com/nju231220075_1/yys.git`
- **Credentials**: 添加Gitee访问凭据
- **Branch Specifier**: `*/hpa` (指定hpa分支)

#### Build Triggers
- ☑️ GitHub hook trigger for GITScm polling
- ☑️ Poll SCM: `H/5 * * * *` (每5分钟检查一次)

#### Pipeline Definition
- **Definition**: Pipeline script from SCM
- **SCM**: Git
- **Repository URL**: `https://gitee.com/nju231220075_1/yys.git`  
- **Branch**: `*/hpa`
- **Script Path**: `Jenkinsfile`

### 3. 环境准备

#### Master节点要求
```bash
# Docker环境
docker --version
docker-compose --version

# Maven缓存目录
mkdir -p /var/jenkins_home/.m2
```

#### Slave节点要求
```yaml
# jnlp-kubectl容器需要包含:
- kubectl客户端
- Kubernetes集群访问权限
- nju08命名空间的操作权限
```

## 🔧 参数配置

### 必需参数
| 参数名 | 说明 | 示例值 |
|--------|------|--------|
| HARBOR_PASS | Harbor密码 | `your-harbor-password` |

### 环境变量
| 变量名 | 值 | 说明 |
|--------|-----|------|
| HARBOR_REGISTRY | 172.22.83.19:30003 | Harbor仓库地址 |
| IMAGE_NAME | nju08/yys-app | 镜像名称 |
| NAMESPACE | nju08 | K8s命名空间 |
| HARBOR_USER | nju08 | Harbor用户名 |

## 🚀 执行流程

### Pipeline阶段说明
1. **Clone Code**: 检出hpa分支代码
2. **Unit Test**: Docker容器中执行Maven测试
3. **Image Build**: 多阶段Docker构建
4. **Push**: 推送到Harbor仓库
5. **Deploy to Kubernetes**: 部署到nju08命名空间

### 手动触发
```bash
# 方式1: Jenkins Web界面
构建 → Build with Parameters → 输入HARBOR_PASS → 构建

# 方式2: API触发
curl -X POST "http://jenkins-url/job/yys-nju08-pipeline/buildWithParameters" \
  --data-urlencode "HARBOR_PASS=your-password"
```

## 🔍 故障排查

### 常见问题

#### 1. Git Clone失败
```bash
# 检查分支是否存在
git ls-remote --heads https://gitee.com/nju231220075_1/yys.git

# 确认Jenkins有Gitee访问权限
# 添加Credentials: Username/Password 或 SSH Key
```

#### 2. Maven测试失败
```bash
# 本地测试
docker run --rm -v $PWD:/usr/src/app -w /usr/src/app maven:3.9.4-openjdk-17 mvn clean test

# 检查测试报告
cat target/surefire-reports/*.xml
```

#### 3. Docker构建失败
```bash
# 检查Dockerfile语法
docker build --no-cache -t test-image .

# 查看构建日志
docker build -t test-image . --progress=plain

# 测试网络连接
curl -s --max-time 10 https://registry-1.docker.io/v2/
curl -s --max-time 10 https://registry.cn-hangzhou.aliyuncs.com/v2/

# 使用阿里云镜像源
docker build -f Dockerfile.stable -t test-image .
```

#### 4. 网络连接问题
```bash
# 测试各种镜像源连接
curl -s --max-time 10 https://registry-1.docker.io/v2/           # Docker Hub
curl -s --max-time 10 https://ccr.ccs.tencentyun.com/v2/        # 腾讯云
curl -s --max-time 10 https://hub-mirror.c.163.com/v2/          # 网易

# 配置Docker镜像加速器
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://ccr.ccs.tencentyun.com",
    "https://hub-mirror.c.163.com",
    "https://registry.cn-hangzhou.aliyuncs.com"
  ]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker

# 测试镜像拉取
docker pull ccr.ccs.tencentyun.com/library/maven:3.9.4-openjdk-17
docker pull hub-mirror.c.163.com/library/maven:3.9.4-openjdk-17
```

#### 5. Harbor推送失败
```bash
# 测试Harbor连接
docker login 172.22.83.19:30003

# 检查网络连通性
ping 172.22.83.19
telnet 172.22.83.19 30003
```

#### 6. Kubernetes部署失败
```bash
# 检查kubectl配置
kubectl cluster-info
kubectl auth can-i create pods --namespace=nju08

# 检查命名空间
kubectl get namespace nju08
kubectl describe namespace nju08
```

### 调试技巧

#### 1. 启用详细日志
```groovy
// 在Jenkinsfile中添加
options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '10'))
}
```

#### 2. 保留构建产物
```groovy
// 在post actions中添加
archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: true
```

#### 3. 并行执行优化
```groovy
// 并行执行测试和代码检查
parallel {
    stage('Unit Test') { /* ... */ }
    stage('Code Quality') { /* ... */ }
}
```

## 📊 监控和通知

### 构建状态监控
```bash
# 检查最近构建状态
curl "http://jenkins-url/job/yys-nju08-pipeline/lastBuild/api/json"

# 构建历史
curl "http://jenkins-url/job/yys-nju08-pipeline/api/json?tree=builds[number,status,timestamp]"
```

### 部署验证
```bash
# 检查应用健康状态
kubectl get pods -n nju08 -l app=yys-app
kubectl get svc -n nju08 -l app=yys-app

# 应用访问测试
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
curl http://${NODE_IP}:30008/actuator/health
```

## 🔐 安全最佳实践

### 1. 凭据管理
- 使用Jenkins Credentials存储敏感信息
- 定期轮换Harbor密码
- 限制Pipeline访问权限

### 2. 镜像安全
- 定期扫描Harbor镜像漏洞
- 使用最小权限运行容器
- 启用镜像签名验证

### 3. 集群安全
- 限制nju08命名空间权限
- 启用RBAC访问控制
- 监控异常API调用

---
*本文档持续更新，如有问题请联系NJU08团队负责人*
