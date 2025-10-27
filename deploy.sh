#!/bin/bash

# Kubernetes Deployment Script for SonarQube with PostgreSQL
# This script automates the complete deployment of the SonarQube system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="sonarqube"
KUBECTL_TIMEOUT="300s"

echo -e "${BLUE}🚀 Starting SonarQube Kubernetes Deployment${NC}"
echo "=================================================="

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    print_status "kubectl is available"
}

# Function to check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_status "Kubernetes cluster is accessible"
}

# Function to create namespace
create_namespace() {
    print_info "Creating namespace: $NAMESPACE"
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_warning "Namespace $NAMESPACE already exists"
    else
        kubectl apply -f k8s/namespace.yaml
        print_status "Namespace $NAMESPACE created"
    fi
}

# Function to create persistent volumes
create_persistent_volumes() {
    print_info "Creating persistent volumes..."
    
    # Create directories on host (for local development)
    print_info "Creating host directories for persistent storage..."
    sudo mkdir -p /data/postgresql /data/sonarqube
    sudo chmod 777 /data/postgresql /data/sonarqube
    
    kubectl apply -f k8s/postgresql-pv.yaml
    kubectl apply -f k8s/sonarqube-pv.yaml
    print_status "Persistent volumes created"
    
    kubectl apply -f k8s/postgresql-pvc.yaml
    kubectl apply -f k8s/sonarqube-pvc.yaml
    print_status "Persistent volume claims created"
}

# Function to create secrets
create_secrets() {
    print_info "Creating secrets..."
    kubectl apply -f k8s/postgresql-secret.yaml
    print_status "PostgreSQL secret created"
}

# Function to deploy PostgreSQL
deploy_postgresql() {
    print_info "Deploying PostgreSQL..."
    kubectl apply -f k8s/postgresql-deployment.yaml
    kubectl apply -f k8s/postgresql-service.yaml
    
    print_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=available --timeout=$KUBECTL_TIMEOUT deployment/postgresql -n $NAMESPACE
    print_status "PostgreSQL deployed and ready"
}

# Function to deploy SonarQube
deploy_sonarqube() {
    print_info "Deploying SonarQube..."
    kubectl apply -f k8s/sonarqube-deployment.yaml
    kubectl apply -f k8s/sonarqube-service.yaml
    
    print_info "Waiting for SonarQube to be ready (this may take several minutes)..."
    kubectl wait --for=condition=available --timeout=600s deployment/sonarqube -n $NAMESPACE
    print_status "SonarQube deployed and ready"
}

# Function to verify deployment
verify_deployment() {
    print_info "Verifying deployment..."
    
    # Check pods status
    echo "Pod Status:"
    kubectl get pods -n $NAMESPACE
    
    # Check services
    echo -e "\nService Status:"
    kubectl get services -n $NAMESPACE
    
    # Check persistent volumes
    echo -e "\nPersistent Volume Status:"
    kubectl get pv | grep -E "(postgresql|sonarqube)"
    
    # Check persistent volume claims
    echo -e "\nPersistent Volume Claims Status:"
    kubectl get pvc -n $NAMESPACE
    
    # Get SonarQube URL
    SONARQUBE_PORT=$(kubectl get service sonarqube-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    print_status "Deployment verification completed"
    echo -e "\n${GREEN}🎉 SonarQube is now accessible at:${NC}"
    echo -e "${BLUE}   http://$NODE_IP:$SONARQUBE_PORT${NC}"
    echo -e "${BLUE}   Default credentials: admin/admin${NC}"
}

# Function to show logs
show_logs() {
    if [ "$1" = "--logs" ]; then
        print_info "Showing recent logs..."
        echo -e "\n${YELLOW}PostgreSQL logs:${NC}"
        kubectl logs -n $NAMESPACE deployment/postgresql --tail=20
        
        echo -e "\n${YELLOW}SonarQube logs:${NC}"
        kubectl logs -n $NAMESPACE deployment/sonarqube --tail=20
    fi
}

# Function to cleanup (if --cleanup flag is provided)
cleanup() {
    if [ "$1" = "--cleanup" ]; then
        print_warning "Cleaning up existing deployment..."
        kubectl delete namespace $NAMESPACE --ignore-not-found=true
        kubectl delete pv postgresql-pv sonarqube-data-pv --ignore-not-found=true
        sudo rm -rf /data/postgresql /data/sonarqube
        print_status "Cleanup completed"
        exit 0
    fi
}

# Function to show help
show_help() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "SonarQube Kubernetes Deployment Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --cleanup      Remove existing deployment and data"
        echo "  --logs         Show logs after deployment"
        echo "  --verify-only  Only verify existing deployment"
        echo ""
        echo "Examples:"
        echo "  $0                 # Deploy SonarQube"
        echo "  $0 --logs          # Deploy and show logs"
        echo "  $0 --cleanup       # Remove existing deployment"
        echo "  $0 --verify-only   # Only verify deployment"
        exit 0
    fi
}

# Function to only verify
verify_only() {
    if [ "$1" = "--verify-only" ]; then
        print_info "Verifying existing deployment..."
        verify_deployment
        exit 0
    fi
}

# Main deployment function
main() {
    # Parse command line arguments
    show_help "$1"
    cleanup "$1"
    verify_only "$1"
    
    print_info "Starting deployment process..."
    
    # Pre-flight checks
    check_kubectl
    check_cluster
    
    # Deployment steps
    create_namespace
    create_persistent_volumes
    create_secrets
    deploy_postgresql
    deploy_sonarqube
    verify_deployment
    show_logs "$1"
    
    echo -e "\n${GREEN}🎉 SonarQube deployment completed successfully!${NC}"
    echo -e "${BLUE}📋 Next steps:${NC}"
    echo -e "   1. Access SonarQube web interface"
    echo -e "   2. Change default admin password"
    echo -e "   3. Run setup-sonarqube.sh to configure Quality Gates"
    echo -e "   4. Configure your CI/CD pipeline"
}

# Run main function with all arguments
main "$@"