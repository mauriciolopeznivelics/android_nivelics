#!/bin/bash

# Deployment Validation Script
# This script validates that the SonarQube deployment is working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="sonarqube"
SONARQUBE_URL=""

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

# Function to detect SonarQube URL
detect_sonarqube_url() {
    if [ -z "$SONARQUBE_URL" ]; then
        print_info "Detecting SonarQube URL..."
        
        if command -v kubectl &> /dev/null; then
            SONARQUBE_PORT=$(kubectl get service sonarqube-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
            if [ -n "$SONARQUBE_PORT" ]; then
                NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")
                SONARQUBE_URL="http://$NODE_IP:$SONARQUBE_PORT"
            fi
        fi
        
        if [ -z "$SONARQUBE_URL" ]; then
            SONARQUBE_URL="http://localhost:30900"
        fi
    fi
    
    print_info "Using SonarQube URL: $SONARQUBE_URL"
}

# Function to check Kubernetes resources
check_kubernetes_resources() {
    print_info "Checking Kubernetes resources..."
    
    # Check namespace
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_status "Namespace '$NAMESPACE' exists"
    else
        print_error "Namespace '$NAMESPACE' not found"
        return 1
    fi
    
    # Check pods
    PODS_READY=$(kubectl get pods -n $NAMESPACE --no-headers | grep -c "Running" || echo "0")
    TOTAL_PODS=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l || echo "0")
    
    if [ "$PODS_READY" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt "0" ]; then
        print_status "All pods are running ($PODS_READY/$TOTAL_PODS)"
    else
        print_error "Not all pods are running ($PODS_READY/$TOTAL_PODS)"
        kubectl get pods -n $NAMESPACE
        return 1
    fi
    
    # Check services
    SERVICES=$(kubectl get services -n $NAMESPACE --no-headers | wc -l || echo "0")
    if [ "$SERVICES" -ge "2" ]; then
        print_status "Services are created ($SERVICES services)"
    else
        print_error "Services not found or incomplete"
        return 1
    fi
    
    # Check persistent volumes
    PV_BOUND=$(kubectl get pvc -n $NAMESPACE --no-headers | grep -c "Bound" || echo "0")
    TOTAL_PVC=$(kubectl get pvc -n $NAMESPACE --no-headers | wc -l || echo "0")
    
    if [ "$PV_BOUND" -eq "$TOTAL_PVC" ] && [ "$TOTAL_PVC" -gt "0" ]; then
        print_status "All persistent volume claims are bound ($PV_BOUND/$TOTAL_PVC)"
    else
        print_error "Persistent volume claims not properly bound ($PV_BOUND/$TOTAL_PVC)"
        kubectl get pvc -n $NAMESPACE
        return 1
    fi
}

# Function to check PostgreSQL connectivity
check_postgresql() {
    print_info "Checking PostgreSQL connectivity..."
    
    # Test database connection from SonarQube pod
    SONARQUBE_POD=$(kubectl get pods -n $NAMESPACE -l app=sonarqube -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$SONARQUBE_POD" ]; then
        if kubectl exec -n $NAMESPACE "$SONARQUBE_POD" -- nc -z postgresql-service.sonarqube.svc.cluster.local 5432 &> /dev/null; then
            print_status "PostgreSQL is accessible from SonarQube pod"
        else
            print_error "PostgreSQL is not accessible from SonarQube pod"
            return 1
        fi
    else
        print_warning "SonarQube pod not found, skipping PostgreSQL connectivity test"
    fi
}

# Function to check SonarQube web interface
check_sonarqube_web() {
    print_info "Checking SonarQube web interface..."
    
    # Test HTTP connectivity
    if curl -s --connect-timeout 10 "$SONARQUBE_URL/api/system/status" &> /dev/null; then
        STATUS_RESPONSE=$(curl -s "$SONARQUBE_URL/api/system/status")
        STATUS=$(echo "$STATUS_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        
        if [ "$STATUS" = "UP" ]; then
            print_status "SonarQube web interface is UP and accessible"
        else
            print_warning "SonarQube web interface is accessible but status is: $STATUS"
        fi
    else
        print_error "SonarQube web interface is not accessible at $SONARQUBE_URL"
        return 1
    fi
}

# Function to check SonarQube system health
check_sonarqube_health() {
    print_info "Checking SonarQube system health..."
    
    # Get system health information
    HEALTH_RESPONSE=$(curl -s "$SONARQUBE_URL/api/system/health" 2>/dev/null || echo "ERROR")
    
    if [ "$HEALTH_RESPONSE" != "ERROR" ]; then
        HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | grep -o '"health":"[^"]*"' | cut -d'"' -f4)
        
        case "$HEALTH_STATUS" in
            "GREEN")
                print_status "SonarQube system health is GREEN"
                ;;
            "YELLOW")
                print_warning "SonarQube system health is YELLOW"
                ;;
            "RED")
                print_error "SonarQube system health is RED"
                return 1
                ;;
            *)
                print_warning "SonarQube system health status unknown: $HEALTH_STATUS"
                ;;
        esac
    else
        print_warning "Could not retrieve SonarQube health status"
    fi
}

# Function to check database connectivity
check_database_health() {
    print_info "Checking database connectivity from SonarQube..."
    
    DB_RESPONSE=$(curl -s "$SONARQUBE_URL/api/system/db_migration_status" 2>/dev/null || echo "ERROR")
    
    if [ "$DB_RESPONSE" != "ERROR" ]; then
        DB_STATE=$(echo "$DB_RESPONSE" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
        
        if [ "$DB_STATE" = "UP_TO_DATE" ]; then
            print_status "Database is connected and up to date"
        else
            print_warning "Database state: $DB_STATE"
        fi
    else
        print_warning "Could not retrieve database status"
    fi
}

# Function to check resource usage
check_resource_usage() {
    print_info "Checking resource usage..."
    
    # Get pod resource usage
    echo -e "\n${BLUE}Pod Resource Usage:${NC}"
    kubectl top pods -n $NAMESPACE 2>/dev/null || print_warning "Metrics server not available"
    
    # Get node resource usage
    echo -e "\n${BLUE}Node Resource Usage:${NC}"
    kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"
}

# Function to show deployment information
show_deployment_info() {
    echo -e "\n${BLUE}📋 Deployment Information:${NC}"
    echo -e "   - Namespace: $NAMESPACE"
    echo -e "   - SonarQube URL: $SONARQUBE_URL"
    
    # Get service information
    SONARQUBE_PORT=$(kubectl get service sonarqube-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    echo -e "   - NodePort: $SONARQUBE_PORT"
    
    # Get pod information
    echo -e "\n${BLUE}Pod Status:${NC}"
    kubectl get pods -n $NAMESPACE -o wide
    
    # Get service information
    echo -e "\n${BLUE}Service Status:${NC}"
    kubectl get services -n $NAMESPACE
    
    # Get persistent volume information
    echo -e "\n${BLUE}Storage Status:${NC}"
    kubectl get pvc -n $NAMESPACE
}

# Function to run all validation tests
run_validation_tests() {
    local failed_tests=0
    
    echo -e "${BLUE}🔍 Running Deployment Validation Tests${NC}"
    echo "=========================================="
    
    # Run each test and count failures
    check_kubernetes_resources || ((failed_tests++))
    check_postgresql || ((failed_tests++))
    check_sonarqube_web || ((failed_tests++))
    check_sonarqube_health || ((failed_tests++))
    check_database_health || ((failed_tests++))
    
    echo -e "\n${BLUE}📊 Validation Results:${NC}"
    if [ $failed_tests -eq 0 ]; then
        print_status "All validation tests passed! ✨"
        return 0
    else
        print_error "$failed_tests validation test(s) failed"
        return 1
    fi
}

# Function to show help
show_help() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "Deployment Validation Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h           Show this help message"
        echo "  --url URL            SonarQube URL (auto-detected if not provided)"
        echo "  --info-only          Show deployment information only"
        echo "  --resources-only     Check resource usage only"
        echo ""
        echo "Examples:"
        echo "  $0                                # Run full validation"
        echo "  $0 --info-only                   # Show deployment info only"
        echo "  $0 --url http://localhost:9000    # Use specific URL"
        exit 0
    fi
}

# Parse command line arguments
INFO_ONLY=false
RESOURCES_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help "$1"
            ;;
        --url)
            SONARQUBE_URL="$2"
            shift 2
            ;;
        --info-only)
            INFO_ONLY=true
            shift
            ;;
        --resources-only)
            RESOURCES_ONLY=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# Main validation function
main() {
    detect_sonarqube_url
    
    if [ "$INFO_ONLY" = true ]; then
        show_deployment_info
    elif [ "$RESOURCES_ONLY" = true ]; then
        check_resource_usage
    else
        if run_validation_tests; then
            check_resource_usage
            show_deployment_info
            echo -e "\n${GREEN}🎉 Deployment validation completed successfully!${NC}"
        else
            echo -e "\n${RED}❌ Deployment validation failed. Please check the errors above.${NC}"
            exit 1
        fi
    fi
}

# Run main function
main