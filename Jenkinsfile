pipeline {
    agent none
    
    // 环境变量管理
    environment {
        HARBOR_REGISTRY = '172.22.83.19:30003'
        IMAGE_NAME = 'nju08/yys-app'
        NAMESPACE = 'nju08'
        MONITOR_NAMESPACE = 'nju08'
        HARBOR_USER = 'nju08'
        MAVEN_OPTS = '-Dmaven.test.failure.ignore=false'
    }
    
    parameters {
        string(name: 'HARBOR_PASS', defaultValue: '', description: 'Harbor login password')
    }
    
    stages {
        stage('Clone Code') {
            agent {
                label 'master'
            }
            steps {
                echo "1.Git Clone Code"
                script {
                    try {
                        // 使用 checkout scm 来检出当前分支的代码
                        checkout scm
                        echo "Successfully checked out code from current branch"
                    } catch (Exception e) {
                        error "Git checkout failed: ${e.getMessage()}"
                    }
                }
            }
        }
        
        stage('Unit Test') {
            agent {
                label 'master'
            }
            steps {
                echo "2.Unit Test Stage"
                script {
                    try {
                        // 使用Docker运行Maven测试
                        sh '''
                            docker run --rm \
                                -v $PWD:/usr/src/app \
                                -v $HOME/.m2:/root/.m2 \
                                -w /usr/src/app \
                                maven:3.9.4-openjdk-17 \
                                mvn clean test
                        '''
                        echo 'Unit tests completed successfully'
                    } catch (Exception e) {
                        echo "Tests failed: ${e.getMessage()}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
            post {
                always {
                    script {
                        // 发布测试结果
                        try {
                            if (fileExists('target/surefire-reports/*.xml')) {
                                junit 'target/surefire-reports/*.xml'
                            } else {
                                echo 'No test reports found'
                            }
                        } catch (Exception e) {
                            echo "Test report publishing failed: ${e.getMessage()}"
                        }
                    }
                }
            }
        }
        
        stage('Image Build') {
            agent {
                label 'master'
            }
            steps {
                echo "3.Image Build Stage (包含 Maven 构建)"
                script {
                    try {
                        // 测试多个镜像源的可用性并选择最佳Dockerfile
                        def dockerFile = "Dockerfile"
                        def buildStrategy = "官方镜像"
                        
                        // 测试Docker Hub连接
                        def dockerHubTest = sh(script: "timeout 10 curl -s https://registry-1.docker.io/v2/ || echo 'FAILED'", returnStdout: true).trim()
                        
                        // 测试腾讯云镜像源连接
                        def tencentTest = sh(script: "timeout 10 curl -s https://ccr.ccs.tencentyun.com/v2/ || echo 'FAILED'", returnStdout: true).trim()
                        
                        // 测试网易镜像源连接
                        def neteaseTest = sh(script: "timeout 10 curl -s https://hub-mirror.c.163.com/v2/ || echo 'FAILED'", returnStdout: true).trim()
                        
                        // 智能选择构建策略
                        if (dockerHubTest != 'FAILED') {
                            dockerFile = "Dockerfile.local"
                            buildStrategy = "官方镜像+国内Maven源"
                            echo "✅ Docker Hub可达，使用官方镜像"
                        } else if (tencentTest != 'FAILED') {
                            dockerFile = "Dockerfile.stable"
                            buildStrategy = "腾讯云镜像源"
                            echo "✅ 腾讯云镜像源可达，使用腾讯云镜像"
                        } else if (neteaseTest != 'FAILED') {
                            dockerFile = "Dockerfile.mirror"
                            buildStrategy = "网易镜像源"
                            echo "✅ 网易镜像源可达，使用网易镜像"
                        } else {
                            dockerFile = "Dockerfile"
                            buildStrategy = "标准镜像"
                            echo "⚠️ 所有镜像源测试失败，使用标准Dockerfile"
                        }
                        
                        echo "📋 构建策略: ${buildStrategy}"
                        echo "📄 使用Dockerfile: ${dockerFile}"
                        
                        // 构建Docker镜像，增加超时和重试
                        retry(3) {
                            sh """
                                docker build \
                                    --file ${dockerFile} \
                                    --cache-from ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:latest \
                                    --build-arg BUILDKIT_INLINE_CACHE=1 \
                                    --network=host \
                                    -t ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER} \
                                    -t ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:latest \
                                    .
                            """
                        }
                        echo "✅ Docker镜像构建成功: ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER}"
                        echo "🎯 构建策略: ${buildStrategy}"
                    } catch (Exception e) {
                        error "Docker构建失败: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Push') {
            agent {
                label 'master'
            }
            steps {
                echo "4.Push Docker Image Stage"
                script {
                    try {
                        sh "echo '${HARBOR_PASS}' | docker login --username=${HARBOR_USER} --password-stdin ${env.HARBOR_REGISTRY}"
                        sh "docker push ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER}"
                        sh "docker push ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:latest"
                        echo "Docker images pushed successfully"
                    } catch (Exception e) {
                        error "Docker push failed: ${e.getMessage()}"
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            agent {
                label 'slave'
            }
            steps {
                container('jnlp-kubectl') {
                    script {
                        stage('Clone YAML') {
                            echo "5. Git Clone YAML To Slave"
                            try {
                                // 使用 checkout scm 获取当前流水线的源代码
                                checkout scm
                            } catch (Exception e) {
                                error "Git clone on slave failed: ${e.getMessage()}"
                            }
                        }
                        
                        stage('Config YAML') {
                            echo "6. Change YAML File Stage"
                            // 更新部署文件中的镜像和命名空间
                            sh """
                                # 更新 deployment.yaml
                                sed -i 's|yys-app:latest|${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER}|g' k8s/deployment.yaml
                                sed -i 's|namespace: default|namespace: ${NAMESPACE}|g' k8s/deployment.yaml
                                
                                # 更新 service.yaml
                                sed -i 's|namespace: default|namespace: ${NAMESPACE}|g' k8s/service.yaml
                                
                                # 更新 servicemonitor.yaml
                                sed -i 's|namespace: default|namespace: ${MONITOR_NAMESPACE}|g' k8s/servicemonitor.yaml
                                
                                # 更新 hpa.yaml
                                sed -i 's|namespace: default|namespace: ${NAMESPACE}|g' k8s/hpa.yaml
                                
                                echo "=== Updated Deployment YAML ==="
                                cat k8s/deployment.yaml
                                echo "=== Updated ServiceMonitor YAML ==="
                                cat k8s/servicemonitor.yaml
                            """
                        }
                        
                        stage('Deploy YYS Application') {
                            echo "7. Deploy YYS App To K8s Stage"
                            sh '''
                                # 创建命名空间（如果不存在）
                                kubectl create namespace ${NAMESPACE} || true
                                
                                # 部署应用
                                kubectl apply -f k8s/deployment.yaml
                                kubectl apply -f k8s/service.yaml
                            '''
                        }
                        
                        stage('Deploy ServiceMonitor') {
                            echo "8. Deploy ServiceMonitor To K8s Stage"
                            try {
                                sh '''
                                    # 创建监控命名空间（如果不存在）
                                    kubectl create namespace ${MONITOR_NAMESPACE} || true
                                    
                                    # 部署 ServiceMonitor
                                    kubectl apply -f k8s/servicemonitor.yaml
                                '''
                            } catch (Exception e) {
                                echo "ServiceMonitor deployment failed: ${e.getMessage()}"
                                echo "This might be expected if Prometheus Operator is not installed"
                            }
                        }
                        
                        stage('Deploy HPA') {
                            echo "9. Deploy HPA To K8s Stage"
                            try {
                                sh '''
                                    # 部署 HPA
                                    kubectl apply -f k8s/hpa.yaml
                                    
                                    # 部署 metrics-server（如果需要）
                                    kubectl apply -f hpa/metrics-server.yaml || true
                                '''
                            } catch (Exception e) {
                                echo "HPA deployment failed: ${e.getMessage()}"
                                echo "This might be expected if metrics-server is not available"
                            }
                        }
                        
                        stage('Health Check') {
                            echo "10. Health Check Stage"
                            try {
                                sh """
                                    echo "等待部署完成..."
                                    kubectl wait --for=condition=ready pod -l app=yys-app -n ${NAMESPACE} --timeout=300s
                                    
                                    echo "检查部署状态..."
                                    kubectl get pods -l app=yys-app -n ${NAMESPACE}
                                    kubectl get svc -l app=yys-app -n ${NAMESPACE}
                                    kubectl get hpa -n ${NAMESPACE} || true
                                    
                                    echo "Application is healthy and ready!"
                                """
                            } catch (Exception e) {
                                echo "Health check failed: ${e.getMessage()}"
                                currentBuild.result = 'UNSTABLE'
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 通知机制和清理
    post {
        success {
            echo '🎉 Pipeline succeeded! YYS Application deployed successfully.'
            script {
                echo "✅ Deployment Summary:"
                echo "   - Image: ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER}"
                echo "   - Namespace: ${NAMESPACE}"
                echo "   - Monitor Namespace: ${MONITOR_NAMESPACE}"
                echo "   - Services: Deployment, Service, ServiceMonitor, HPA"
            }
        }
        failure {
            echo '❌ Pipeline failed! Please check the logs for details.'
        }
        unstable {
            echo '⚠️ Pipeline completed with warnings. Some non-critical steps failed.'
        }
        always {
            echo '🔄 Pipeline execution completed.'
            // 清理本地镜像以节省磁盘空间
            node('master') {
                script {
                    try {
                        sh "docker rmi ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER} || true"
                        sh "docker rmi ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:latest || true"
                        sh "docker system prune -f || true"
                    } catch (Exception e) {
                        echo "Image cleanup failed: ${e.getMessage()}"
                    }
                }
            }
        }
    }
}
