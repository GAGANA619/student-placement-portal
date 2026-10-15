pipeline {
    agent any

    environment {
        IMAGE_NAME = 'YOUR-DOCKERHUB-USERNAME/student-placement-portal'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                sh 'git status --short'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                      -t ${IMAGE_NAME}:v1 \
                      .
                '''
            }
        }

        stage('Test Application') {
            steps {
                sh '''
                    docker run -d \
                      --name placement-ci-test \
                      -p 18080:80 \
                      ${IMAGE_NAME}:v1

                    trap 'docker rm -f placement-ci-test >/dev/null 2>&1 || true' EXIT

                    for i in $(seq 1 15); do
                      if curl -fsS http://127.0.0.1:18080/ >/dev/null; then
                        echo "Application test passed"
                        exit 0
                      fi
                      sleep 2
                    done

                    echo "Application test failed"
                    exit 1
                '''
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x

                        echo "$DOCKER_TOKEN" |
                          docker login \
                            --username "$DOCKER_USER" \
                            --password-stdin

                        docker push ${IMAGE_NAME}:v1

                        docker logout
                    '''
                }
            }
        }
    }

    post {
        always {
            echo 'CI pipeline finished.'
        }
    }
}