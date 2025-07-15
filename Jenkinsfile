pipeline {
    agent none
    
    // 环境变量管理
    environment {
        HARBOR_REGISTRY = '172.22.83.19:30003'
        IMAGE_NAME = 'nju08/prometheus-test-demo'
        GIT_REPO = 'https://gitee.com/htw-gitee/prometheus-test-demo.git'
        NAMESPACE = 'nju08'
        MONITOR_NAMESPACE = 'nju08'
        HARBOR_USER = 'nju08'
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
        
        stage('Image Build') {
            agent {
                label 'master'
            }
            steps {
                echo "2.Image Build Stage (包含 Maven 构建)"
                script {
                    try {
                        // 使用 Dockerfile 多阶段构建，包含 Maven 构建和镜像构建
                        sh "docker build --cache-from ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:latest -t ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER} -t ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:latest ."
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
                echo "3.Push Docker Image Stage"
                script {
                    try {
                        sh "echo '${HARBOR_PASS}' | docker login --username=${HARBOR_USER} --password-stdin ${env.HARBOR_REGISTRY}"
                        sh "docker push ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER}"
                        sh "docker push ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:latest"
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
                            echo "4. Git Clone YAML To Slave"
                            try {
                                // 使用 checkout scm 获取当前流水线的源代码
                                checkout scm
                            } catch (Exception e) {
                                error "Git clone on slave failed: ${e.getMessage()}"
                            }
                        }
                        
                        stage('Config YAML') {
                            echo "5. Change YAML File Stage"
                            sh 'sed -i "s/{VERSION}/${BUILD_NUMBER}/g" ./jenkins/scripts/prometheus-test-demo.yaml'
                            sh 'sed -i "s/{NAMESPACE}/${NAMESPACE}/g" ./jenkins/scripts/prometheus-test-demo.yaml'
                            sh 'sed -i "s/{MONITOR_NAMESPACE}/${MONITOR_NAMESPACE}/g" ./jenkins/scripts/prometheus-test-serviceMonitor.yaml'
                            sh 'sed -i "s/{NAMESPACE}/${NAMESPACE}/g" ./jenkins/scripts/prometheus-test-serviceMonitor.yaml'

                            sh 'cat ./jenkins/scripts/prometheus-test-demo.yaml'
                            sh 'cat ./jenkins/scripts/prometheus-test-serviceMonitor.yaml'
                        }
                        
                        stage('Deploy prometheus-test-demo') {
                            echo "6. Deploy To K8s Stage"
                            sh 'kubectl apply -f ./jenkins/scripts/prometheus-test-demo.yaml'
                        }
                        
                        stage('Deploy prometheus-test-demo ServiceMonitor') {
                            echo "7. Deploy ServiceMonitor To K8s Stage"
                            try {
                                sh 'kubectl apply -f ./jenkins/scripts/prometheus-test-serviceMonitor.yaml'
                            } catch (Exception e) {
                                error "ServiceMonitor deployment failed: ${e.getMessage()}"
                            }
                        }
                        
                        stage('Health Check') {
                            echo "8. Health Check Stage"
                            try {
                                sh "kubectl wait --for=condition=ready pod -l app=prometheus-test-demo -n ${NAMESPACE} --timeout=300s"
                                echo "Application is healthy and ready!"
                            } catch (Exception e) {
                                error "Health check failed: ${e.getMessage()}"
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
            echo '🎉 Pipeline succeeded! Application deployed successfully.'
            script {
                echo "✅ Deployment Summary:"
                echo "   - Image: ${env.HARBOR_REGISTRY}/${env.IMAGE_NAME}:${BUILD_NUMBER}"
                echo "   - Namespace: ${NAMESPACE}"
                echo "   - Monitor Namespace: ${MONITOR_NAMESPACE}"
            }
        }
        failure {
            echo '❌ Pipeline failed! Please check the logs for details.'
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