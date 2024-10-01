def previousVersion

pipeline {
    agent any

    parameters {
        string(name: 'IMAGE_TAG', defaultValue: '', description: '배포할 이미지 태그 (비워두면 최신 빌드 번호 사용)')
    }

    environment {
        PROJECT_NAME = "kwt"
        APP_NAME = "front"
        DOCKER_CONFIG = credentials('docker-hub-credentials')
        K8S_CONFIG = readFile 'k8s/jenkins-pod-template.yaml'
        DOCKER_TAG = "${params.IMAGE_TAG ?: env.BUILD_NUMBER}"
        DOCKER_USERNAME = "wondookong"
        K8S_NAMESPACE = "${PROJECT_NAME}-${params.ENV}"
        DOCKER_IMAGE = "${DOCKER_USERNAME}/${K8S_NAMESPACE}-${APP_NAME}"
    }

    stages {
        stage('Main Pipeline') {
            agent {
                kubernetes {
                    yaml "${env.K8S_CONFIG}"
                }
            }

            stages {
                stage('Create Namespace if not exists') {
                    steps {
                        container('kubectl') {
                            script {
                                def namespaceExists = sh(
                                        script: "kubectl get namespace ${env.K8S_NAMESPACE}",
                                        returnStatus: true
                                ) == 0

                                if (!namespaceExists) {
                                    echo "Namespace does not exist. Creating new Namespace..."
                                    sh "kubectl create namespace ${env.K8S_NAMESPACE}"
                                } else {
                                    echo "Namespace already exists. Skipping creation."
                                }
                            }
                        }
                    }
                }
                stage('Create Deployment if not exists') {
                    steps {
                        container('kubectl') {
                            script {
                                def deploymentExists = sh(
                                        script: "kubectl get deployment ${env.APP_NAME} -n ${env.K8S_NAMESPACE}",
                                        returnStatus: true
                                ) == 0

                                if (!deploymentExists) {
                                    echo "Deployment does not exist. Creating new Deployment..."
                                    sh "kubectl apply -f k8s/deployment-${params.ENV}.yaml -n ${env.K8S_NAMESPACE}"
                                } else {
                                    echo "Deployment already exists. Skipping creation."
                                }
                            }
                        }
                    }
                }
                stage('Create Service if not exists') {
                    steps {
                        container('kubectl') {
                            script {
                                def serviceExists = sh(
                                        script: "kubectl get service ${env.APP_NAME} -n ${env.K8S_NAMESPACE}",
                                        returnStatus: true
                                ) == 0

                                if (!serviceExists) {
                                    echo "Service does not exist. Creating new Service..."
                                    sh "kubectl apply -f k8s/service-${params.ENV}.yaml -n ${env.K8S_NAMESPACE}"
                                } else {
                                    echo "Service already exists. Skipping creation."
                                }
                            }
                        }
                    }
                }
                stage('Get Previous Version') {
                    steps {
                        container('kubectl') {
                            script {
                                echo "K8S_NAMESPACE: ${env.K8S_NAMESPACE}"
                                echo "DEPLOYMENT_NAME: ${env.APP_NAME}"
                                try {
                                    previousVersion = sh(
                                            script: "kubectl get deployment ${env.APP_NAME} -n ${env.K8S_NAMESPACE} -o=jsonpath='{.spec.template.spec.containers[0].image}'",
                                            returnStdout: true
                                    ).trim()
                                    echo "Previous version: ${previousVersion}"
                                } catch (Exception e) {
                                    echo "Error details: ${e.getMessage()}"
                                    echo "Failed to get previous version. This might be the first deployment."
                                    previousVersion = "${env.DOCKER_IMAGE}:latest"
                                }
                            }
                        }
                    }
                }
                stage('Build and Push with Kaniko') {
                    steps {
                        echo "Building and Pushing image"
                        container('kaniko') {
                            withEnv(['DOCKER_CONFIG=/kaniko/.docker']) {
                                sh """
                            /kaniko/executor \\
                            --context `pwd` \\
                            --destination ${env.DOCKER_IMAGE}:${env.DOCKER_TAG} \\
                            --destination ${env.DOCKER_IMAGE}:latest \\
                            --dockerfile Dockerfile \\
                            --verbosity debug \\
                            --build-arg NODE_ENV=${params.ENV}
                        """
                            }
                        }
                    }
                }
                stage('Update Kubernetes manifests') {
                    steps {
                        container('kubectl') {
                            script {
                                sh """sed -i 's|image: .*|image: ${env.DOCKER_IMAGE}:${env.DOCKER_TAG}|' k8s/deployment-${params.ENV}.yaml"""
                                sh "cat k8s/deployment-${params.ENV}.yaml"
                            }
                        }
                    }
                }
                stage('Deploy to Kubernetes') {
                    steps {
                        container('kubectl') {
                            script {
                                try {
                                    sh "kubectl apply -f k8s/deployment-${params.ENV}.yaml -n ${env.K8S_NAMESPACE}"
                                    sh "kubectl apply -f k8s/service-${params.ENV}.yaml -n ${env.K8S_NAMESPACE}"
                                    sh "kubectl rollout status deployment/${env.APP_NAME} -n ${env.K8S_NAMESPACE} --timeout=180s"
                                } catch (Exception e) {
                                    echo "Deployment failed: ${e.message}"
                                    if (previousVersion) {
                                        echo "Rolling back to ${previousVersion}"
                                        sh "kubectl set image deployment/${env.APP_NAME} ${env.APP_NAME}=${previousVersion} -n ${env.K8S_NAMESPACE}"
                                        sh "kubectl rollout status deployment/${env.APP_NAME} -n ${env.K8S_NAMESPACE} --timeout=180s"
                                    } else {
                                        echo "No previous version available for rollback"
                                    }
                                    error "Deployment failed, check logs for details"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            echo "Pipeline execution completed"
        }
        success {
            echo 'The Pipeline succeeded :)'
        }
        aborted {
            echo "aborted Pipeline"
        }
        failure {
            echo "failure Pipeline :("
        }
    }
}