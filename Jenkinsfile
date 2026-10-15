pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        booleanParam(
            name: 'DEMO_FAULTY_ROLLOUT',
            defaultValue: false,
            description: 'Demonstrate a faulty deployment and automatic rollback'
        )
    }

    environment {
        IMAGE_NAME = 'YOUR-DOCKERHUB-USERNAME/student-placement-portal'
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

                powershell '''
                    Write-Host "Repository checkout successful."
                    Get-ChildItem -Force
                '''
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

                    foreach ($file in $requiredFiles) {
                        if (!(Test-Path $file)) {
                            throw "Required file is missing: $file"
                        }

                        Write-Host "Found: $file"
                    }

                    if (!(Test-Path "Dockerfile") -and
                        !(Test-Path "dockerfile")) {
                        throw "Dockerfile is missing."
                    }

                    Write-Host "All required files are present."
                '''
            }
        }

        stage('Verify Docker') {
            steps {
                powershell '''
                    docker --version

                    if ($LASTEXITCODE -ne 0) {
                        throw "Docker CLI is unavailable."
                    }

                    docker info

                    if ($LASTEXITCODE -ne 0) {
                        throw "Docker Engine is unavailable."
                    }

                    Write-Host "Docker Engine is accessible."
                '''
            }
        }

        stage('Verify Kubernetes Credential') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kubeconfig-file',
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    powershell '''
                        $env:KUBECONFIG = $env:KUBECONFIG_FILE

                        kubectl config current-context

                        if ($LASTEXITCODE -ne 0) {
                            throw "Kubernetes context is unavailable in kubeconfig."
                        }

                        kubectl get nodes

                        if ($LASTEXITCODE -ne 0) {
                            throw "Cannot connect to Kubernetes API server."
                        }

                        Write-Host "Kubernetes access verified."
                    '''
                }
            }
        }

        stage('Build Stable Image') {
            steps {
                powershell '''
                    $dockerfile = "Dockerfile"

                    if (!(Test-Path $dockerfile)) {
                        $dockerfile = "dockerfile"
                    }

                    docker build `
                        -f $dockerfile `
                        -t "$env:IMAGE_NAME`:v1" `
                        .

                    if ($LASTEXITCODE -ne 0) {
                        throw "Stable Docker image build failed."
                    }
                '''
            }
        }

        stage('Test Stable Image') {
            steps {
                powershell '''
                    $testName = "placement-ci-test-$env:BUILD_NUMBER"

                    docker rm -f $testName 2>$null

                    docker run -d `
                        --name $testName `
                        -p 18080:80 `
                        "$env:IMAGE_NAME`:v1"

                    if ($LASTEXITCODE -ne 0) {
                        throw "Unable to start the test container."
                    }

                    try {
                        $success = $false

                        for ($i = 0; $i -lt 15; $i++) {
                            Start-Sleep -Seconds 2

                            try {
                                $response = Invoke-WebRequest `
                                    -Uri "http://127.0.0.1:18080/" `
                                    -UseBasicParsing `
                                    -TimeoutSec 3

                                if ($response.StatusCode -eq 200) {
                                    $success = $true
                                    break
                                }
                            }
                            catch {
                                Write-Host "Waiting for web server..."
                            }
                        }

                        if (!$success) {
                            throw "Stable application HTTP test failed."
                        }

                        Write-Host "Stable application returned HTTP 200."
                    }
                    finally {
                        docker rm -f $testName 2>$null
                    }
                '''
            }
        }

        stage('Push Stable Image to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_TOKEN'
                    )
                ]) {
                    powershell '''
                        $env:DOCKER_TOKEN |
                            docker login `
                                --username $env:DOCKER_USER `
                                --password-stdin

                        if ($LASTEXITCODE -ne 0) {
                            throw "Docker Hub authentication failed."
                        }

                        docker push "$env:IMAGE_NAME`:v1"

                        if ($LASTEXITCODE -ne 0) {
                            throw "Docker Hub push failed."
                        }

                        docker logout
                    '''
                }
            }
        }

        stage('Deploy Stable Release') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kubeconfig-file',
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    powershell '''
                        $env:KUBECONFIG = $env:KUBECONFIG_FILE

                        kubectl apply -f deployment.yaml

                        if ($LASTEXITCODE -ne 0) {
                            throw "Applying Kubernetes configuration failed."
                        }

                        kubectl set image `
                            "deployment/$env:DEPLOYMENT_NAME" `
                            "$env:CONTAINER_NAME=$env:IMAGE_NAME`:v1"

                        if ($LASTEXITCODE -ne 0) {
                            throw "Updating the stable image failed."
                        }

                        kubectl rollout status `
                            "deployment/$env:DEPLOYMENT_NAME" `
                            --timeout=180s

                        if ($LASTEXITCODE -ne 0) {
                            throw "Stable deployment rollout failed."
                        }
                    '''
                }
            }
        }

        stage('Verify Stable Deployment') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kubeconfig-file',
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    powershell '''
                        $env:KUBECONFIG = $env:KUBECONFIG_FILE

                        kubectl get deployments
                        kubectl get pods -l app=student-placement-portal
                        kubectl get services

                        if ($LASTEXITCODE -ne 0) {
                            throw "Unable to query Kubernetes resources."
                        }

                        kubectl wait `
                            --for=condition=available `
                            "deployment/$env:DEPLOYMENT_NAME" `
                            --timeout=120s

                        if ($LASTEXITCODE -ne 0) {
                            throw "Deployment did not become available."
                        }

                        $ready = kubectl get deployment `
                            $env:DEPLOYMENT_NAME `
                            -o jsonpath='{.status.readyReplicas}'

                        if ($ready -ne "2") {
                            throw "Expected two ready replicas; found $ready."
                        }

                        Write-Host "Both replicas are available."
                    '''
                }
            }
        }

        stage('Build Faulty Image') {
            when {
                expression {
                    return params.DEMO_FAULTY_ROLLOUT
                }
            }

            steps {
                powershell '''
                    if (!(Test-Path "Dockerfile.faulty")) {
                        throw "Dockerfile.faulty is missing."
                    }

                    docker build `
                        -f Dockerfile.faulty `
                        -t "$env:IMAGE_NAME`:faulty" `
                        .

                    if ($LASTEXITCODE -ne 0) {
                        throw "Faulty image build failed."
                    }
                '''
            }
        }

        stage('Push Faulty Image') {
            when {
                expression {
                    return params.DEMO_FAULTY_ROLLOUT
                }
            }

            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_TOKEN'
                    )
                ]) {
                    powershell '''
                        $env:DOCKER_TOKEN |
                            docker login `
                                --username $env:DOCKER_USER `
                                --password-stdin

                        if ($LASTEXITCODE -ne 0) {
                            throw "Docker Hub authentication failed."
                        }

                        docker push "$env:IMAGE_NAME`:faulty"

                        if ($LASTEXITCODE -ne 0) {
                            throw "Faulty image push failed."
                        }

                        docker logout
                    '''
                }
            }
        }

        stage('Demonstrate Failed Rollout and Rollback') {
            when {
                expression {
                    return params.DEMO_FAULTY_ROLLOUT
                }
            }

            steps {
                withCredentials([
                    file(
                        credentialsId: 'kubeconfig-file',
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    powershell '''
                        $env:KUBECONFIG = $env:KUBECONFIG_FILE

                        $previousImage = kubectl get deployment `
                            $env:DEPLOYMENT_NAME `
                            -o jsonpath='{.spec.template.spec.containers[0].image}'

                        if ($LASTEXITCODE -ne 0 -or !$previousImage) {
                            throw "Cannot identify the current deployment image."
                        }

                        Write-Host "Previous image: $previousImage"

                        if ($previousImage -ne "$env:IMAGE_NAME`:v1") {
                            throw "Expected the stable v1 image before failure demonstration."
                        }

                        kubectl set image `
                            "deployment/$env:DEPLOYMENT_NAME" `
                            "$env:CONTAINER_NAME=$env:IMAGE_NAME`:faulty"

                        if ($LASTEXITCODE -ne 0) {
                            throw "Unable to submit faulty rollout."
                        }

                        kubectl rollout status `
                            "deployment/$env:DEPLOYMENT_NAME" `
                            --timeout=90s

                        $rolloutExitCode = $LASTEXITCODE

                        if ($rolloutExitCode -eq 0) {
                            Write-Host "Faulty rollout unexpectedly succeeded."

                            kubectl rollout undo `
                                "deployment/$env:DEPLOYMENT_NAME"

                            kubectl rollout status `
                                "deployment/$env:DEPLOYMENT_NAME" `
                                --timeout=180s

                            throw "Failure demonstration invalid: faulty rollout succeeded."
                        }

                        Write-Host "Faulty rollout failed as expected."
                        Write-Host "Starting automatic rollback."

                        kubectl rollout undo `
                            "deployment/$env:DEPLOYMENT_NAME"

                        if ($LASTEXITCODE -ne 0) {
                            throw "Rollback command failed."
                        }

                        kubectl rollout status `
                            "deployment/$env:DEPLOYMENT_NAME" `
                            --timeout=180s

                        if ($LASTEXITCODE -ne 0) {
                            throw "Stable rollout was not restored."
                        }

                        $restoredImage = kubectl get deployment `
                            $env:DEPLOYMENT_NAME `
                            -o jsonpath='{.spec.template.spec.containers[0].image}'

                        if ($restoredImage -ne $previousImage) {
                            throw "The previous stable image was not restored."
                        }

                        $ready = kubectl get deployment `
                            $env:DEPLOYMENT_NAME `
                            -o jsonpath='{.status.readyReplicas}'

                        if ($ready -ne "2") {
                            throw "Rollback completed but two replicas are not ready."
                        }

                        kubectl get deployments
                        kubectl get pods -l app=student-placement-portal
                        kubectl rollout history `
                            "deployment/$env:DEPLOYMENT_NAME"

                        Write-Host "Automatic rollback verified."
                        Write-Host "Stable image restored: $restoredImage"
                        Write-Host "Ready replicas: $ready"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully.'
        }

        failure {
            echo 'Pipeline failed. Review the first failing stage in Console Output.'
        }

        always {
            echo 'Student Placement Portal CI/CD pipeline finished.'
        }
    }
}