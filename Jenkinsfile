pipeline {
    agent none
    
    // 环境变量管理
    environment {
        HARBOR_REGISTRY = '172.22.83.19:30003'
        IMAGE_NAME = 'nju08/yys-app'
        GIT_REPO = 'https://gitee.com/nju231220075_1/yys.git'
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
                        git url: "${env.GIT_REPO}"
                    } catch (Exception e) {
                        error "Git clone failed: ${e.getMessage()}"
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
                        // 使用 Dockerfile 多阶段构建，包含 Maven 构建和镜像构建
                        sh "docker build --cache-from ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:latest -t ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER} -t ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:latest ."
                        echo "Docker image built successfully: ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER}"
                    } catch (Exception e) {
                        error "Docker build failed: ${e.getMessage()}"
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
