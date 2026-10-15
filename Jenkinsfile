pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Project Files') {
            steps {
                powershell '''
                    Write-Host "Checking Student Placement Portal files..."
                    Get-ChildItem -Force

                    if (!(Test-Path "index.html")) {
                        throw "index.html is missing"
                    }

                    if (!(Test-Path "Dockerfile")) {
                        throw "Dockerfile is missing"
                    }

                    if (!(Test-Path "deployment.yaml")) {
                        throw "deployment.yaml is missing"
                    }

                    Write-Host "All required project files exist."
                '''
            }
        }

        stage('Verify Docker') {
            steps {
                powershell '''
                    docker --version

                    if ($LASTEXITCODE -ne 0) {
                        throw "Docker CLI is unavailable"
                    }

                    docker info

                    if ($LASTEXITCODE -ne 0) {
                        throw "Docker engine is unavailable to Jenkins"
                    }
                '''
            }
        }

        stage('Verify Kubernetes') {
            steps {
                powershell '''
                    kubectl config current-context

                    if ($LASTEXITCODE -ne 0) {
                        throw "Kubernetes context is unavailable to Jenkins"
                    }

                    kubectl get nodes

                    if ($LASTEXITCODE -ne 0) {
                        throw "Jenkins cannot access Kubernetes"
                    }
                '''
            }
        }
    }

    post {
        success {
            echo 'Project files, Docker, and Kubernetes checks passed.'
        }

        failure {
            echo 'A verification stage failed. Check Console Output.'
        }
    }
}