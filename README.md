# Automated Student Placement Portal

A student placement dashboard built using HTML, CSS, JavaScript, Docker, and Kubernetes.

## Features

- Placement statistics dashboard
- Student placement records
- Search functionality
- Responsive user interface
- Docker containerization using Nginx
- Kubernetes Deployment with two replicas
- Kubernetes Service
- Readiness and liveness probes
- Rolling update strategy
- Git and GitHub version control

## Technology Stack

- HTML
- CSS
- JavaScript
- Docker
- Nginx
- Kubernetes
- Git
- GitHub

## Project Structure

    student-placement-portal/
    ├── index.html
    ├── Dockerfile
    ├── deployment.yaml
    ├── .gitignore
    └── README.md

## Build Docker Image

    docker build -t student-placement-portal:v1 .

## Run Using Docker

    docker run --rm -d --name placement-test -p 8080:80 student-placement-portal:v1

Open http://localhost:8080 in your browser.

Stop the container:

    docker stop placement-test

## Deploy to Kubernetes

    kubectl apply -f deployment.yaml

Check deployments:

    kubectl get deployments

Check pods:

    kubectl get pods

Check services:

    kubectl get services

## Access the Application

    kubectl port-forward service/student-placement-portal-service 8081:80

Open http://localhost:8081 in your browser.

Keep the PowerShell terminal open while accessing the application.

## Versioned Deployment

Build version 2 after modifying the application:

    docker build -t student-placement-portal:v2 .

Update the deployment:

    kubectl set image deployment/student-placement-portal student-placement-portal=student-placement-portal:v2

Check rollout status:

    kubectl rollout status deployment/student-placement-portal

View deployment history:

    kubectl rollout history deployment/student-placement-portal

Rollback to the previous revision:

    kubectl rollout undo deployment/student-placement-portal

Note: The v2 image must be available to the Kubernetes cluster before deploying it.

## CI/CD

Docker and Kubernetes are configured for containerization and deployment. A fully automated CI/CD pipeline can be added using Jenkins or GitHub Actions.

## Project Status

The Student Placement Portal frontend, Docker configuration, and Kubernetes Deployment and Service are included in this project.
