#!/bin/bash

# Health check script for SonarQube Kubernetes deployment
# This script validates the deployment health and provides detailed status information

set -e

# Configuration
NAMESPACE="${NAMESPACE:-sonarqube}"
SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
SONAR_TOKEN="${SONAR_TOKEN}"
TIMEOUT="${TIMEOUT:-300}"  # 5 minutes timeout

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_status "kubectl is available and connected to cluster"
}

# Function to check namespace
check_namespace() {
    print_header "Checking namespace: ${NAMESPACE}"
    
    if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        print_error "Namespace '${NAMESPACE}' does not exist"
        return 1
    fi
    
    print_status "Namespace '${NAMESPACE}' exists"
    return 0
}

# Function to check pod status
check_pods() {
    print_header "Checking pod status in namespace: ${NAMESPACE}"
    
    # Get all pods in the namespace
    PODS=$(kubectl get pods -n "${NAMESPACE}" -o json)
    
    if [ "$(echo "$PODS" | jq '.items | length')" -eq 0 ]; then
        print_error "No pods found in namespace '${NAMESPACE}'"
        return 1
    fi
    
    # Check each pod
    echo "$PODS" | jq -r '.items[] | "\(.metadata.name) \(.status.phase) \(.status.containerStatuses[0].ready // false)"' | \
    while read -r pod_name phase ready; do
        if [ "$phase" = "Running" ] && [ "$ready" = "true" ]; then
            print_status "Pod ${pod_name}: ${phase} (Ready)"
        elif [ "$phase" = "Running" ] && [ "$ready" = "false" ]; then
            print_warning "Pod ${pod_name}: ${phase} (Not Ready)"
        else
            print_error "Pod ${pod_name}: ${phase}"
        fi
    done
    
    # Check for any failed pods
    FAILED_PODS=$(echo "$PODS" | jq -r '.items[] | select(.status.phase != "Running") | .metadata.name')
    if [ -n "$FAILED_PODS" ]; then
        print_error "Found failed pods:"
        echo "$FAILED_PODS"
        return 1
    fi
    
    return 0
}

# Function to check services
check_services() {
    print_header "Checking services in namespace: ${NAMESPACE}"
    
    SERVICES=$(kubectl get services -n "${NAMESPACE}" -o json)
    
    if [ "$(echo "$SERVICES" | jq '.items | length')" -eq 0 ]; then
        print_error "No services found in namespace '${NAMESPACE}'"
        return 1
    fi
    
    echo "$SERVICES" | jq -r '.items[] | "\(.metadata.name) \(.spec.type) \(.spec.ports[0].port // "N/A")"' | \
    while read -r service_name type port; do
        print_status "Service ${service_name}: ${type} (Port: ${port})"
    done
    
    return 0
}

# Function to check persistent volumes
check_persistent_volumes() {
    print_header "Checking persistent volumes"
    
    # Get PVCs in the namespace
    PVCS=$(kubectl get pvc -n "${NAMESPACE}" -o json)
    
    if [ "$(echo "$PVCS" | jq '.items | length')" -eq 0 ]; then
        print_warning "No PVCs found in namespace '${NAMESPACE}'"
        return 0
    fi
    
    echo "$PVCS" | jq -r '.items[] | "\(.metadata.name) \(.status.phase) \(.spec.resources.requests.storage)"' | \
    while read -r pvc_name phase storage; do
        if [ "$phase" = "Bound" ]; then
            print_status "PVC ${pvc_name}: ${phase} (${storage})"
        else
            print_error "PVC ${pvc_name}: ${phase}"
        fi
    done
    
    return 0
}

# Function to check SonarQube API health
check_sonarqube_api() {
    print_header "Checking SonarQube API health"
    
    # Try to get SonarQube service endpoint
    SONAR_SERVICE=$(kubectl get service -n "${NAMESPACE}" -l app=sonarqube -o json 2>/dev/null)
    
    if [ "$(echo "$SONAR_SERVICE" | jq '.items | length')" -eq 0 ]; then
        print_warning "SonarQube service not found, using provided URL: ${SONAR_HOST_URL}"
    else
        SERVICE_TYPE=$(echo "$SONAR_SERVICE" | jq -r '.items[0].spec.type')
        if [ "$SERVICE_TYPE" = "NodePort" ]; then
            NODE_PORT=$(echo "$SONAR_SERVICE" | jq -r '.items[0].spec.ports[0].nodePort')
            print_status "SonarQube service found: ${SERVICE_TYPE} on port ${NODE_PORT}"
        fi
    fi
    
    # Check system status
    print_status "Checking SonarQube system status..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "${SONAR_HOST_URL}/api/system/status" > /dev/null 2>&1; then
            STATUS_RESPONSE=$(curl -s "${SONAR_HOST_URL}/api/system/status")
            STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')
            VERSION=$(echo "$STATUS_RESPONSE" | jq -r '.version')
            
            if [ "$STATUS" = "UP" ]; then
                print_status "SonarQube is UP (Version: ${VERSION})"
                return 0
            else
                print_warning "SonarQube status: ${STATUS} (Attempt ${attempt}/${max_attempts})"
            fi
        else
            print_warning "SonarQube API not accessible (Attempt ${attempt}/${max_attempts})"
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            sleep 10
        fi
        
        ((attempt++))
    done
    
    print_error "SonarQube API health check failed after ${max_attempts} attempts"
    return 1
}

# Function to check database connectivity
check_database_connectivity() {
    print_header "Checking PostgreSQL database connectivity"
    
    # Get PostgreSQL pod
    PG_POD=$(kubectl get pods -n "${NAMESPACE}" -l app=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$PG_POD" ]; then
        print_error "PostgreSQL pod not found"
        return 1
    fi
    
    print_status "Found PostgreSQL pod: ${PG_POD}"
    
    # Test database connection
    if kubectl exec -n "${NAMESPACE}" "${PG_POD}" -- pg_isready -U sonarqube -d sonarqube > /dev/null 2>&1; then
        print_status "PostgreSQL database is ready"
        
        # Get database size
        DB_SIZE=$(kubectl exec -n "${NAMESPACE}" "${PG_POD}" -- psql -U sonarqube -d sonarqube -t -c "SELECT pg_size_pretty(pg_database_size('sonarqube'));" 2>/dev/null | xargs)
        if [ -n "$DB_SIZE" ]; then
            print_status "Database size: ${DB_SIZE}"
        fi
        
        return 0
    else
        print_error "PostgreSQL database is not ready"
        return 1
    fi
}

# Function to check resource usage
check_resource_usage() {
    print_header "Checking resource usage"
    
    # Get pod resource usage
    PODS=$(kubectl get pods -n "${NAMESPACE}" -o json)
    
    echo "$PODS" | jq -r '.items[] | "\(.metadata.name) \(.spec.containers[0].resources.requests.memory // "N/A") \(.spec.containers[0].resources.requests.cpu // "N/A")"' | \
    while read -r pod_name memory cpu; do
        print_status "Pod ${pod_name}: Memory request: ${memory}, CPU request: ${cpu}"
    done
    
    return 0
}

# Function to check logs for errors
check_logs_for_errors() {
    print_header "Checking recent logs for errors"
    
    # Check SonarQube logs
    SONAR_POD=$(kubectl get pods -n "${NAMESPACE}" -l app=sonarqube -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$SONAR_POD" ]; then
        ERROR_COUNT=$(kubectl logs -n "${NAMESPACE}" "${SONAR_POD}" --tail=100 2>/dev/null | grep -i error | wc -l)
        if [ "$ERROR_COUNT" -gt 0 ]; then
            print_warning "Found ${ERROR_COUNT} error messages in SonarQube logs (last 100 lines)"
        else
            print_status "No errors found in recent SonarQube logs"
        fi
    fi
    
    # Check PostgreSQL logs
    PG_POD=$(kubectl get pods -n "${NAMESPACE}" -l app=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$PG_POD" ]; then
        ERROR_COUNT=$(kubectl logs -n "${NAMESPACE}" "${PG_POD}" --tail=100 2>/dev/null | grep -i error | wc -l)
        if [ "$ERROR_COUNT" -gt 0 ]; then
            print_warning "Found ${ERROR_COUNT} error messages in PostgreSQL logs (last 100 lines)"
        else
            print_status "No errors found in recent PostgreSQL logs"
        fi
    fi
    
    return 0
}

# Function to generate health report
generate_health_report() {
    print_header "Health Check Summary"
    
    local overall_status="HEALTHY"
    local issues=0
    
    # Run all checks and collect results
    check_namespace || { overall_status="UNHEALTHY"; ((issues++)); }
    check_pods || { overall_status="UNHEALTHY"; ((issues++)); }
    check_services || { overall_status="UNHEALTHY"; ((issues++)); }
    check_persistent_volumes || { overall_status="DEGRADED"; }
    check_database_connectivity || { overall_status="UNHEALTHY"; ((issues++)); }
    check_sonarqube_api || { overall_status="UNHEALTHY"; ((issues++)); }
    check_resource_usage
    check_logs_for_errors
    
    echo ""
    print_header "=== HEALTH CHECK REPORT ==="
    
    if [ "$overall_status" = "HEALTHY" ]; then
        print_status "Overall Status: ${overall_status}"
        print_status "All critical components are functioning properly"
    elif [ "$overall_status" = "DEGRADED" ]; then
        print_warning "Overall Status: ${overall_status}"
        print_warning "Some non-critical issues detected"
    else
        print_error "Overall Status: ${overall_status}"
        print_error "Critical issues detected: ${issues}"
    fi
    
    echo ""
    print_status "Timestamp: $(date)"
    print_status "Namespace: ${NAMESPACE}"
    print_status "SonarQube URL: ${SONAR_HOST_URL}"
    
    # Return appropriate exit code
    if [ "$overall_status" = "UNHEALTHY" ]; then
        return 1
    else
        return 0
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE    Kubernetes namespace (default: sonarqube)"
    echo "  -u, --url URL               SonarQube URL (default: http://localhost:9000)"
    echo "  -t, --timeout SECONDS       Timeout for checks (default: 300)"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE                   Kubernetes namespace"
    echo "  SONAR_HOST_URL             SonarQube URL"
    echo "  SONAR_TOKEN                SonarQube authentication token"
    echo "  TIMEOUT                    Timeout for checks"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -u|--url)
            SONAR_HOST_URL="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_status "Starting SonarQube deployment health check..."
    print_status "Namespace: ${NAMESPACE}"
    print_status "SonarQube URL: ${SONAR_HOST_URL}"
    print_status "Timeout: ${TIMEOUT} seconds"
    echo ""
    
    # Check prerequisites
    check_kubectl
    
    # Generate health report
    if generate_health_report; then
        print_status "Health check completed successfully"
        exit 0
    else
        print_error "Health check failed"
        exit 1
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi