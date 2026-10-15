pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'DEMO_FAULTY_ROLLOUT',
            defaultValue: false,
            description: 'Enable the faulty deployment and automatic rollback demonstration'
        )
    }

    environment {
        DOCKERHUB_USER = 'gagana6969'
        IMAGE_NAME = 'gagana6969/student-placement-portal'

        DEPLOYMENT_NAME = 'student-placement-portal'
        SERVICE_NAME = 'student-placement-portal-service'
        CONTAINER_NAME = 'student-placement-portal'

        NAMESPACE = 'default'
        NODE_PORT = '30080'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo 'Source code checked out successfully.'
            }
        }

        stage('Verify Project Files') {
            steps {
                powershell '''
                    $requiredFiles = @(
                        "index.html",
                        "deployment.yaml",
                        "Jenkinsfile"
                    )

                    if ((Test-Path "Dockerfile") -eq $false -and
                        (Test-Path "dockerfile") -eq $false) {
                        throw "Dockerfile or dockerfile is missing."
                    }

                    foreach ($file in $requiredFiles) {
                        if (!(Test-Path $file)) {
                            throw "Required file missing: $file"
                        }
                        Write-Host "Found: $file"
                    }

                    Write-Host "Project files verified."
                '''
            }
        }

        stage('Verify Docker') {
            steps {
                powershell '''
                    docker --version

                    if ($LASTEXITCODE -ne 0) {
                        throw "Docker CLI is not working."
                    }

                    docker info

                    if ($LASTEXITCODE -ne 0) {
                        throw "Docker Engine is unavailable."
                    }

                    Write-Host "Docker is ready."
                '''
            }
        }

        stage('Verify Kubernetes Credential') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kuberconfig',
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    powershell '''
                        $env:KUBECONFIG = $env:KUBECONFIG_FILE

                        kubectl config current-context

                        if ($LASTEXITCODE -ne 0) {
                            throw "Kubernetes context could not be loaded from the Jenkins credential."
                        }

                        kubectl get nodes

                        if ($LASTEXITCODE -ne 0) {
                            throw "Jenkins cannot connect to Kubernetes."
                        }

                        Write-Host "Kubernetes connection verified."
                    '''
                }
            }
        }

        stage('Build Stable Image') {
            steps {
                powershell '''
                    docker build -t "${env:IMAGE_NAME}:v1" .
                    if ($LASTEXITCODE -ne 0) {
                        throw "Stable Docker image build failed."
                    }

                    docker tag "${env:IMAGE_NAME}:v1" "${env:IMAGE_NAME}:latest"
                    if ($LASTEXITCODE -ne 0) {
                        throw "Docker image tagging failed."
                    }

                    Write-Host "Stable image built successfully."
                '''
            }
        }

        stage('Test Stable Image') {
            steps {
                powershell '''
                    $existing = docker ps -aq --filter "name=placement-portal-test"

                    if ($existing) {
                        docker rm -f placement-portal-test
                    }

                    docker run -d `
                        --name placement-portal-test `
                        -p 18080:80 `
                        "${env:IMAGE_NAME}:v1"

                    if ($LASTEXITCODE -ne 0) {
                        throw "Could not start the stable test container."
                    }

                    Start-Sleep -Seconds 5

                    $containerState = docker inspect `
                        --format="{{.State.Running}}" placement-portal-test

                    if ($containerState -ne "true") {
                        docker logs placement-portal-test
                        throw "Stable test container is not running."
                    }

                    try {
                        $response = Invoke-WebRequest `
                            -Uri "http://localhost:18080" `
                            -UseBasicParsing `
                            -TimeoutSec 10

                        if ($response.StatusCode -ne 200) {
                            throw "Local webpage test failed."
                        }

                        Write-Host "Local webpage returned HTTP 200."
                    }
                    finally {
                        docker rm -f placement-portal-test
                    }
                '''
            }
        }

        stage('Push Stable Image to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    powershell '''
                        $env:DOCKERHUB_TOKEN | docker login `
                            --username $env:DOCKERHUB_USERNAME `
                            --password-stdin

                        if ($LASTEXITCODE -ne 0) {
                            throw "Docker Hub login failed."
                        }

                        docker push "${env:IMAGE_NAME}:v1"
                        if ($LASTEXITCODE -ne 0) {
                            throw "Failed to push stable v1 image."
                        }

                        docker push "${env:IMAGE_NAME}:latest"
                        if ($LASTEXITCODE -ne 0) {
                            throw "Failed to push latest image."
                        }

                        Write-Host "Stable images pushed to Docker Hub."
                    '''
                }
            }
        }

        stage('Deploy Stable Release') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kuberconfig',
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    powershell '''
                        $env:KUBECONFIG = $env:KUBECONFIG_FILE

                        kubectl apply -f deployment.yaml
                        if ($LASTEXITCODE -ne 0) {
                            throw "Applying deployment.yaml failed."
                        }

                        kubectl set image `
                            "deployment/${env:DEPLOYMENT_NAME}" `
                            "${env:CONTAINER_NAME}=${env:IMAGE_NAME}:v1" `
                            -n $env:NAMESPACE

                        if ($LASTEXITCODE -ne 0) {
                            throw "Updating the deployment image failed."
                        }

                        kubectl rollout status `
                            "deployment/${env:DEPLOYMENT_NAME}" `
                            -n $env:NAMESPACE `
                            --timeout=180s

                        if ($LASTEXITCODE -ne 0) {
                            throw "Stable deployment rollout failed."
                        }

                        Write-Host "Stable release deployed."
                    '''
                }
            }
        }

        stage('Verify Stable Deployment') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kuberconfig',
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    powershell '''
                        $env:KUBECONFIG = $env:KUBECONFIG_FILE

                        kubectl get deployment $env:DEPLOYMENT_NAME -n $env:NAMESPACE
                        kubectl get pods -n $env:NAMESPACE
                        kubectl get service $env:SERVICE_NAME -n $env:NAMESPACE

                        $ready = kubectl get deployment $env:DEPLOYMENT_NAME `
                            -n $env:NAMESPACE `
                            -o jsonpath="{.status.readyReplicas}"

                        if ($LASTEXITCODE -ne 0 -or "$ready" -ne "2") {
                            throw "Expected two ready replicas, but found: $ready"
                        }

                        Write-Host "Both replicas are ready."
                    '''
                }
            }
        }

        stage('Build Faulty Image') {
            when {
                expression { params.DEMO_FAULTY_ROLLOUT }
            }
            steps {
                powershell '''
                    if (!(Test-Path "Dockerfile.faulty")) {
                        throw "Dockerfile.faulty is missing. Create and commit it before enabling the rollback demonstration."
                    }

                    docker build `
                        -f Dockerfile.faulty `
                        -t "${env:IMAGE_NAME}:faulty" .

                    if ($LASTEXITCODE -ne 0) {
                        throw "Faulty image build failed."
                    }
                '''
            }
        }

        stage('Push Faulty Image') {
            when {
                expression { params.DEMO_FAULTY_ROLLOUT }
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    powershell '''
                        $env:DOCKERHUB_TOKEN | docker login `
                            --username $env:DOCKERHUB_USERNAME `
                            --password-stdin

                        if ($LASTEXITCODE -ne 0) {
                            throw "Docker Hub login failed."
                        }

                        docker push "${env:IMAGE_NAME}:faulty"

                        if ($LASTEXITCODE -ne 0) {
                            throw "Faulty image push failed."
                        }
                    '''
                }
            }
        }

        stage('Demonstrate Failed Rollout and Rollback') {
            when {
                expression { params.DEMO_FAULTY_ROLLOUT }
            }
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kuberconfig',
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    powershell '''
                        $env:KUBECONFIG = $env:KUBECONFIG_FILE

                        $previousImage = kubectl get deployment `
                            $env:DEPLOYMENT_NAME `
                            -n $env:NAMESPACE `
                            -o jsonpath="{.spec.template.spec.containers[0].image}"

                        if ($LASTEXITCODE -ne 0 -or !$previousImage) {
                            throw "Could not determine the current deployment image."
                        }

                        Write-Host "Previous stable image: $previousImage"

                        if ($previousImage -ne "${env:IMAGE_NAME}:v1") {
                            throw "Expected stable v1 before rollback demo. Current image: $previousImage"
                        }

                        kubectl set image `
                            "deployment/${env:DEPLOYMENT_NAME}" `
                            "${env:CONTAINER_NAME}=${env:IMAGE_NAME}:faulty" `
                            -n $env:NAMESPACE

                        if ($LASTEXITCODE -ne 0) {
                            throw "Could not apply the faulty image."
                        }

                        Write-Host "Waiting for the faulty rollout to fail..."

                        kubectl rollout status `
                            "deployment/${env:DEPLOYMENT_NAME}" `
                            -n $env:NAMESPACE `
                            --timeout=90s

                        $rolloutExitCode = $LASTEXITCODE

                        if ($rolloutExitCode -eq 0) {
                            throw "The faulty rollout unexpectedly succeeded. Rollback demonstration is inconclusive."
                        }

                        Write-Host "Faulty rollout failed as expected."
                        Write-Host "Automatically rolling back to the previous release..."

                        kubectl rollout undo `
                            "deployment/${env:DEPLOYMENT_NAME}" `
                            -n $env:NAMESPACE

                        if ($LASTEXITCODE -ne 0) {
                            throw "Kubernetes rollback command failed."
                        }

                        kubectl rollout status `
                            "deployment/${env:DEPLOYMENT_NAME}" `
                            -n $env:NAMESPACE `
                            --timeout=180s

                        if ($LASTEXITCODE -ne 0) {
                            throw "The restored deployment did not become ready."
                        }

                        $restoredImage = kubectl get deployment `
                            $env:DEPLOYMENT_NAME `
                            -n $env:NAMESPACE `
                            -o jsonpath="{.spec.template.spec.containers[0].image}"

                        if ($restoredImage -ne $previousImage) {
                            throw "Rollback image mismatch. Expected $previousImage but found $restoredImage"
                        }

                        $ready = kubectl get deployment `
                            $env:DEPLOYMENT_NAME `
                            -n $env:NAMESPACE `
                            -o jsonpath="{.status.readyReplicas}"

                        if ($LASTEXITCODE -ne 0 -or "$ready" -ne "2") {
                            throw "Rollback completed, but two replicas are not ready."
                        }

                        kubectl get pods -n $env:NAMESPACE
                        kubectl rollout history `
                            "deployment/${env:DEPLOYMENT_NAME}" `
                            -n $env:NAMESPACE

                        Write-Host "SUCCESS: Previous stable release restored with two ready replicas."
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'PIPELINE SUCCESS: Student Placement Portal CI/CD stages completed.'
        }

        failure {
            echo 'PIPELINE FAILED: Open Console Output and inspect the first failing stage.'
        }

        always {
            echo 'Student Placement Portal pipeline finished.'
        }
    }
}