#!/bin/bash

# Quick SonarQube Setup Script for Development
# This script deploys a simple SonarQube instance for testing

set -e

echo "🚀 Quick SonarQube Setup for Development"
echo "========================================"

# Clean up existing deployment
echo "🧹 Cleaning up existing deployment..."
kubectl delete namespace sonarqube --ignore-not-found=true
sleep 10

# Create namespace
echo "📁 Creating namespace..."
kubectl create namespace sonarqube

# Deploy simple SonarQube with H2 database
echo "🔧 Deploying SonarQube..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonarqube
  namespace: sonarqube
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonarqube
  template:
    metadata:
      labels:
        app: sonarqube
    spec:
      containers:
      - name: sonarqube
        image: sonarqube:10.5-community
        ports:
        - containerPort: 9000
        env:
        - name: SONAR_ES_BOOTSTRAP_CHECKS_DISABLE
          value: "true"
        - name: SONAR_JDBC_URL
          value: "jdbc:h2:mem:sonarqube"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        readinessProbe:
          httpGet:
            path: /api/system/status
            port: 9000
          initialDelaySeconds: 120
          periodSeconds: 30
          timeoutSeconds: 10
        livenessProbe:
          httpGet:
            path: /api/system/status
            port: 9000
          initialDelaySeconds: 180
          periodSeconds: 30
          timeoutSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: sonarqube-service
  namespace: sonarqube
spec:
  type: NodePort
  ports:
  - port: 9000
    targetPort: 9000
    nodePort: 30900
  selector:
    app: sonarqube
EOF

echo "⏳ Waiting for SonarQube to be ready (this may take 3-5 minutes)..."
kubectl wait --for=condition=available --timeout=300s deployment/sonarqube -n sonarqube

echo "🎉 SonarQube deployed successfully!"

# Get access information
MINIKUBE_IP=$(minikube ip)
echo ""
echo "🔗 SonarQube Access Information:"
echo "   URL: http://$MINIKUBE_IP:30900"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "📋 For GitHub Actions, use:"
echo "   SONAR_HOST_URL = http://$MINIKUBE_IP:30900"
echo "   SONAR_TOKEN = [Generate after first login]"
echo ""

# Test connectivity
echo "🧪 Testing connectivity..."
if curl -s -f "http://$MINIKUBE_IP:30900/api/system/status" > /dev/null; then
    echo "✅ SonarQube is accessible and ready!"
else
    echo "⚠️  SonarQube may still be starting up. Please wait a few more minutes."
fi

echo ""
echo "🚀 Next steps:"
echo "1. Access SonarQube at http://$MINIKUBE_IP:30900"
echo "2. Login with admin/admin and change password"
echo "3. Generate authentication token"
echo "4. Configure GitHub Actions secrets"