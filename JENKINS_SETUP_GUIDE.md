# Jenkins 环境配置指南

## 问题分析

从构建日志可以看出，Jenkins构建失败的主要原因：

1. **`mvn: not found`** - Jenkins环境中没有安装Maven
2. **测试报告文件不存在** - 因为Maven命令失败，导致没有生成测试报告

## 解决方案

### 方案1: 配置Jenkins工具 (推荐)

#### 1.1 配置Maven工具
1. 进入Jenkins管理界面: `Manage Jenkins` → `Global Tool Configuration`
2. 找到 `Maven` 部分，点击 `Add Maven`
3. 配置Maven:
   - **Name**: `Maven-3.9.0`
   - **Install automatically**: 勾选
   - **Version**: 选择 `3.9.0` 或更高版本

#### 1.2 配置JDK工具
1. 在同一页面找到 `JDK` 部分，点击 `Add JDK`
2. 配置JDK:
   - **Name**: `JDK-17`
   - **Install automatically**: 勾选
   - **Version**: 选择 `OpenJDK 17`

#### 1.3 使用修复后的Jenkinsfile
使用已修复的 `Jenkinsfile`，它包含了错误处理和工具配置。

### 方案2: 使用Docker容器运行Maven (备选)

如果无法配置Jenkins工具，可以使用 `Jenkinsfile-robust`，它会自动检测环境并使用Docker容器运行Maven。

## Jenkinsfile 优化说明

### 主要改进

1. **工具配置**:
   ```groovy
   tools {
       maven 'Maven-3.9.0'
       jdk 'JDK-17'
   }
   ```

2. **错误处理**:
   ```groovy
   try {
       sh 'mvn clean test'
   } catch (Exception e) {
       echo "Tests failed: ${e.getMessage()}"
       currentBuild.result = 'UNSTABLE'
   }
   ```

3. **文件存在性检查**:
   ```groovy
   script {
       if (fileExists('target/surefire-reports/*.xml')) {
           junit 'target/surefire-reports/*.xml'
       } else {
           echo 'No test reports found'
       }
   }
   ```

4. **条件执行**:
   ```groovy
   when {
       not { 
           equals expected: 'FAILURE', actual: currentBuild.result 
       }
   }
   ```

5. **Docker备选方案**:
   ```groovy
   def mavenCommand = '''
       if command -v mvn &> /dev/null; then
           mvn clean test
       else
           docker run --rm -v "$PWD":/usr/src/app maven:3.9.4-openjdk-17 mvn clean test
       fi
   '''
   ```

## 部署选项

### 选项1: 使用修复后的Jenkinsfile
```bash
# 替换当前的Jenkinsfile
cp Jenkinsfile-robust Jenkinsfile
git add Jenkinsfile
git commit -m "Fix Jenkins Maven configuration"
git push
```

### 选项2: 保持当前结构，配置Jenkins环境
1. 按照上述步骤配置Maven和JDK工具
2. 确保工具名称与Jenkinsfile中的配置一致
3. 重新运行Pipeline

## 验证步骤

### 1. 本地验证
```bash
# 确保本地构建正常
mvn clean test
mvn clean package -DskipTests

# 确保Docker构建正常
docker build -t yys-app:test .
```

### 2. Jenkins验证
1. 创建新的Pipeline任务
2. 配置Git仓库地址
3. 运行Pipeline并观察日志

## 常见问题解决

### Q1: Maven工具配置后仍然找不到
**解决**: 
- 检查Jenkins节点配置
- 确保工具名称拼写正确
- 重启Jenkins服务

### Q2: Docker权限问题
**解决**:
```bash
# 将jenkins用户添加到docker组
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Q3: Kubernetes部署失败
**解决**:
- 配置kubectl工具
- 设置Kubernetes集群访问凭证
- 确保Jenkins有cluster-admin权限

## 推荐的Jenkins插件

确保安装以下插件：
- **Pipeline**: 流水线支持
- **Docker Pipeline**: Docker集成
- **Kubernetes**: K8s部署支持
- **JUnit**: 测试报告
- **HTML Publisher**: HTML报告发布

## 最佳实践

1. **分阶段部署**: 先在测试环境验证，再部署到生产
2. **并行执行**: 将独立的任务并行执行以节省时间
3. **错误恢复**: 实现优雅的错误处理和恢复机制
4. **通知机制**: 配置构建状态通知（邮件、Slack等）
5. **资源清理**: 及时清理构建产物和临时文件

## 下一步行动

1. ✅ 使用修复后的Jenkinsfile
2. ⚙️ 配置Jenkins工具（Maven + JDK）
3. 🔧 测试Pipeline执行
4. 📊 监控构建结果
5. 🚀 优化构建性能
