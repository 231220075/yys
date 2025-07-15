pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = 'yys-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        K8S_NAMESPACE = 'default'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running unit tests...'
                sh 'mvn clean test'
                echo 'Unit tests completed successfully'
            }
            post {
                always {
                    // 发布测试结果
                    junit 'target/surefire-reports/*.xml'
                    // 发布测试覆盖率报告（如果有）
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'target/site/jacoco',
                        reportFiles: 'index.html',
                        reportName: 'JaCoCo Coverage Report'
                    ])
                }
                success {
                    echo 'All tests passed!'
                }
                failure {
                    echo 'Some tests failed!'
                }
            }
        }
        
        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    def image = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    docker.withRegistry('', 'docker-hub-credentials') {
                        image.push()
                        image.push('latest')
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo 'Deploying to Kubernetes...'
                script {
                    sh """
                        # 更新deployment.yaml中的镜像标签
                        sed -i 's|yys-app:latest|${DOCKER_IMAGE}:${DOCKER_TAG}|g' k8s/deployment.yaml
                        
                        # 部署应用
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/servicemonitor.yaml
                        
                        # 部署HPA和监控
                        kubectl apply -f hpa/service-hpa.yaml
                        kubectl apply -f hpa/metrics-server.yaml
                    """
                }
                echo 'Kubernetes deployment completed'
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo 'Verifying deployment...'
                script {
                    sh """
                        # 等待部署完成
                        echo "Waiting for deployment to complete..."
                        kubectl rollout status deployment/yys-app -n ${K8S_NAMESPACE} --timeout=600s
                        
                        # 检查Pod状态
                        echo "Checking pod status..."
                        kubectl get pods -l app=yys-app -n ${K8S_NAMESPACE}
                        
                        # 检查服务状态
                        echo "Checking service status..."
                        kubectl get svc yys-app-service -n ${K8S_NAMESPACE}
                        
                        # 检查HPA状态
                        echo "Checking HPA status..."
                        kubectl get hpa yys-app-hpa -n ${K8S_NAMESPACE}
                        
                        # 简单的健康检查
                        echo "Performing health check..."
                        kubectl run --rm -i --tty health-check --image=curlimages/curl --restart=Never -- \
                            curl -f http://yys-app-service.${K8S_NAMESPACE}.svc.cluster.local/actuator/health || \
                            (echo "Health check failed!" && exit 1)
                        
                        echo "Deployment verification completed successfully!"
                    """
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
