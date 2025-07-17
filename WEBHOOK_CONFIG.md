# Webhook 自动触发配置说明

## 1. Jenkins 配置

### 1.1 安装插件
确保 Jenkins 安装了以下插件：
- Git Plugin
- Gitee Plugin（如果使用 Gitee）
- GitHub Plugin（如果使用 GitHub）

### 1.2 Pipeline 配置
在 Jenkinsfile 顶部添加触发器配置：

```groovy
pipeline {
    agent none
    
    triggers {
        // Git 仓库变更触发（每分钟检查一次）
        pollSCM('H/1 * * * *')
        
        // 或者使用 Webhook 触发
        githubPush()  // 如果使用 GitHub
        // giteeHttpPush()  // 如果使用 Gitee
    }
    
    // ...existing code...
}
```

## 2. Git 仓库 Webhook 配置

### 2.1 Gitee Webhook 配置
1. 进入 Gitee 仓库设置 → Webhook
2. 添加 Webhook URL：`http://your-jenkins-url/gitee-project/your-project-name`
3. 选择触发事件：Push events
4. 设置密钥（可选）

### 2.2 GitHub Webhook 配置
1. 进入 GitHub 仓库 Settings → Webhooks
2. 添加 Webhook URL：`http://your-jenkins-url/github-webhook/`
3. Content type: `application/json`
4. 选择触发事件：Just the push event

## 3. Jenkins Job 配置

### 3.1 源码管理配置
- Repository URL: 您的 Git 仓库地址
- Credentials: 配置 Git 访问凭据
- Branch: `*/hpa` 或 `*/main`

### 3.2 构建触发器
勾选以下选项之一：
- "GitHub hook trigger for GITScm polling"（GitHub）
- "Gitee webhook trigger"（Gitee）
- "Poll SCM"（轮询方式，作为备选）

## 4. 测试自动触发

1. 提交代码到指定分支：
```bash
git add .
git commit -m "Trigger Jenkins Pipeline"
git push origin hpa
```

2. 查看 Jenkins 是否自动触发构建

3. 检查 Jenkins 日志确认 Webhook 接收

## 5. 故障排除

### 5.1 常见问题
- Jenkins 无法访问：检查网络和防火墙
- Webhook 失败：检查 URL 和认证配置
- 权限问题：确保 Jenkins 有足够权限访问 Git 仓库

### 5.2 调试方法
- 查看 Jenkins 系统日志
- 检查 Git 仓库 Webhook 日志
- 使用 curl 手动测试 Webhook URL

## 6. 安全考虑

- 使用 HTTPS 连接
- 配置 Webhook 密钥验证
- 限制 Jenkins 访问权限
- 定期更新访问令牌
