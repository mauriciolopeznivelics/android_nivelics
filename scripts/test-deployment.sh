#!/bin/bash

# Integration Test Script for SonarQube Kubernetes Deployment
# This script validates the complete deployment and functionality

set -e

# Configuration
NAMESPACE="sonarqube"
TIMEOUT="300s"
TEST_PROJECT_KEY="android_app_test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

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

print_test_header() {
    echo -e "\n${BLUE}🧪 Test: $1${NC}"
    echo "----------------------------------------"
}

# Function to run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    print_test_header "$test_name"
    
    if eval "$test_command"; then
        print_status "PASSED: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "FAILED: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Kubernetes cluster connectivity
test_cluster_connectivity() {
    kubectl cluster-info > /dev/null 2>&1
}

# Test 2: Namespace exists
test_namespace_exists() {
    kubectl get namespace $NAMESPACE > /dev/null 2>&1
}

# Test 3: All pods are running
test_pods_running() {
    local not_running=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    [ "$not_running" -eq 0 ]
}

# Test 4: PostgreSQL is ready
test_postgresql_ready() {
    kubectl wait --for=condition=ready pod -l app=postgresql -n $NAMESPACE --timeout=60s > /dev/null 2>&1
}

# Test 5: SonarQube is ready
test_sonarqube_ready() {
    kubectl wait --for=condition=ready pod -l app=sonarqube -n $NAMESPACE --timeout=120s > /dev/null 2>&1
}

# Test 6: PostgreSQL database connectivity
test_postgresql_connectivity() {
    kubectl exec deployment/postgresql -n $NAMESPACE -- pg_isready -U sonarqube -d sonarqube > /dev/null 2>&1
}

# Test 7: SonarQube web interface accessibility
test_sonarqube_web_access() {
    local sonarqube_port=$(kubectl get service sonarqube-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    
    if [ -n "$sonarqube_port" ] && [ -n "$node_ip" ]; then
        curl -s -f "http://$node_ip:$sonarqube_port/api/system/status" > /dev/null 2>&1
    else
        return 1
    fi
}

# Test 8: SonarQube API authentication
test_sonarqube_api_auth() {
    if [ -z "$SONAR_TOKEN" ]; then
        print_warning "SONAR_TOKEN not set, skipping API authentication test"
        return 0
    fi
    
    local sonarqube_url=$(get_sonarqube_url)
    curl -s -f -u "$SONAR_TOKEN:" "$sonarqube_url/api/authentication/validate" > /dev/null 2>&1
}

# Test 9: Quality Gate configuration
test_quality_gate_config() {
    if [ -z "$SONAR_TOKEN" ]; then
        print_warning "SONAR_TOKEN not set, skipping Quality Gate test"
        return 0
    fi
    
    local sonarqube_url=$(get_sonarqube_url)
    local qg_response=$(curl -s -u "$SONAR_TOKEN:" "$sonarqube_url/api/qualitygates/list")
    echo "$qg_response" | jq -e '.qualitygates[] | select(.name=="Android Strict")' > /dev/null 2>&1
}

# Test 10: Persistent volumes are bound
test_persistent_volumes() {
    local unbound_pvs=$(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[?(@.status.phase!="Bound")].metadata.name}' 2>/dev/null)
    [ -z "$unbound_pvs" ]
}

# Test 11: Services are accessible
test_services_accessible() {
    kubectl get service postgresql-service -n $NAMESPACE > /dev/null 2>&1 &&
    kubectl get service sonarqube-service -n $NAMESPACE > /dev/null 2>&1
}

# Test 12: Resource limits are configured
test_resource_limits() {
    local sonarqube_limits=$(kubectl get deployment sonarqube -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.limits}' 2>/dev/null)
    local postgresql_limits=$(kubectl get deployment postgresql -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.limits}' 2>/dev/null)
    
    [ -n "$sonarqube_limits" ] && [ -n "$postgresql_limits" ]
}

# Test 13: Health checks are configured
test_health_checks() {
    local sonarqube_probes=$(kubectl get deployment sonarqube -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null)
    local postgresql_probes=$(kubectl get deployment postgresql -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null)
    
    [ -n "$sonarqube_probes" ] && [ -n "$postgresql_probes" ]
}

# Test 14: Secrets are properly configured
test_secrets_configured() {
    kubectl get secret postgresql-secret -n $NAMESPACE > /dev/null 2>&1 &&
    [ -n "$(kubectl get secret postgresql-secret -n $NAMESPACE -o jsonpath='{.data.postgres-password}' 2>/dev/null)" ]
}

# Test 15: Mock project analysis (if SONAR_TOKEN is available)
test_mock_project_analysis() {
    if [ -z "$SONAR_TOKEN" ]; then
        print_warning "SONAR_TOKEN not set, skipping mock project analysis"
        return 0
    fi
    
    local sonarqube_url=$(get_sonarqube_url)
    
    # Create a mock project
    curl -s -u "$SONAR_TOKEN:" -X POST \
        "$sonarqube_url/api/projects/create" \
        -d "project=$TEST_PROJECT_KEY" \
        -d "name=Test Android Project" > /dev/null 2>&1
    
    # Check if project was created
    local project_exists=$(curl -s -u "$SONAR_TOKEN:" "$sonarqube_url/api/projects/search?projects=$TEST_PROJECT_KEY" | jq -r '.components | length')
    
    # Cleanup test project
    curl -s -u "$SONAR_TOKEN:" -X POST \
        "$sonarqube_url/api/projects/delete" \
        -d "project=$TEST_PROJECT_KEY" > /dev/null 2>&1
    
    [ "$project_exists" -gt 0 ]
}

# Helper function to get SonarQube URL
get_sonarqube_url() {
    local sonarqube_port=$(kubectl get service sonarqube-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    
    if [ -n "$sonarqube_port" ] && [ -n "$node_ip" ]; then
        echo "http://$node_ip:$sonarqube_port"
    else
        echo "${SONAR_HOST_URL:-http://localhost:9000}"
    fi
}

# Function to show deployment status
show_deployment_status() {
    print_info "Current deployment status:"
    echo ""
    
    echo "Namespace: $NAMESPACE"
    kubectl get namespace $NAMESPACE 2>/dev/null || echo "  ❌ Namespace not found"
    echo ""
    
    echo "Pods:"
    kubectl get pods -n $NAMESPACE 2>/dev/null || echo "  ❌ No pods found"
    echo ""
    
    echo "Services:"
    kubectl get services -n $NAMESPACE 2>/dev/null || echo "  ❌ No services found"
    echo ""
    
    echo "Persistent Volume Claims:"
    kubectl get pvc -n $NAMESPACE 2>/dev/null || echo "  ❌ No PVCs found"
    echo ""
    
    echo "Persistent Volumes:"
    kubectl get pv | grep -E "(postgresql|sonarqube)" 2>/dev/null || echo "  ❌ No PVs found"
    echo ""
}

# Function to show SonarQube access information
show_access_info() {
    local sonarqube_url=$(get_sonarqube_url)
    
    print_info "SonarQube Access Information:"
    echo "  URL: $sonarqube_url"
    echo "  Default credentials: admin/admin"
    echo "  Change password on first login"
    echo ""
}

# Function to run performance tests
test_performance() {
    print_test_header "Performance Tests"
    
    # Test SonarQube response time
    local sonarqube_url=$(get_sonarqube_url)
    local response_time=$(curl -o /dev/null -s -w '%{time_total}' "$sonarqube_url/api/system/status" 2>/dev/null || echo "999")
    
    echo "SonarQube API response time: ${response_time}s"
    
    # Check if response time is acceptable (< 5 seconds)
    if (( $(echo "$response_time < 5.0" | bc -l 2>/dev/null || echo "0") )); then
        print_status "Response time acceptable: ${response_time}s"
        return 0
    else
        print_warning "Response time slow: ${response_time}s"
        return 1
    fi
}

# Function to test GitHub Actions integration
test_github_integration() {
    print_test_header "GitHub Actions Integration"
    
    # Check if GitHub Actions workflow file exists
    if [ -f ".github/workflows/sonar-analysis.yml" ]; then
        print_status "GitHub Actions workflow file exists"
        
        # Check if workflow contains required jobs
        local required_jobs=("build" "test" "sonar-analysis" "quality-gate")
        local workflow_content=$(cat .github/workflows/sonar-analysis.yml)
        
        for job in "${required_jobs[@]}"; do
            if echo "$workflow_content" | grep -q "$job:"; then
                print_status "Job '$job' found in workflow"
            else
                print_error "Job '$job' missing in workflow"
                return 1
            fi
        done
        
        return 0
    else
        print_error "GitHub Actions workflow file not found"
        return 1
    fi
}

# Function to run all tests
run_all_tests() {
    echo -e "${BLUE}🚀 Starting SonarQube Deployment Integration Tests${NC}"
    echo "=================================================="
    
    # Infrastructure tests
    run_test "Kubernetes Cluster Connectivity" "test_cluster_connectivity"
    run_test "Namespace Exists" "test_namespace_exists"
    run_test "All Pods Running" "test_pods_running"
    run_test "PostgreSQL Ready" "test_postgresql_ready"
    run_test "SonarQube Ready" "test_sonarqube_ready"
    
    # Connectivity tests
    run_test "PostgreSQL Database Connectivity" "test_postgresql_connectivity"
    run_test "SonarQube Web Interface Access" "test_sonarqube_web_access"
    run_test "SonarQube API Authentication" "test_sonarqube_api_auth"
    
    # Configuration tests
    run_test "Quality Gate Configuration" "test_quality_gate_config"
    run_test "Persistent Volumes Bound" "test_persistent_volumes"
    run_test "Services Accessible" "test_services_accessible"
    run_test "Resource Limits Configured" "test_resource_limits"
    run_test "Health Checks Configured" "test_health_checks"
    run_test "Secrets Configured" "test_secrets_configured"
    
    # Functional tests
    run_test "Mock Project Analysis" "test_mock_project_analysis"
    run_test "GitHub Actions Integration" "test_github_integration"
    
    # Performance tests
    if ! test_performance; then
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

# Function to show test summary
show_test_summary() {
    echo -e "\n${BLUE}📊 Test Summary${NC}"
    echo "==============="
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    local success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    echo "Success rate: $success_rate%"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All tests passed! Deployment is healthy.${NC}"
        return 0
    else
        echo -e "\n${RED}❌ Some tests failed. Please check the deployment.${NC}"
        return 1
    fi
}

# Function to show help
show_help() {
    echo "SonarQube Deployment Integration Test Script"
    echo ""
    echo "This script validates the complete SonarQube deployment"
    echo "and tests integration with GitHub Actions pipeline."
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h         Show this help message"
    echo "  --status           Show deployment status only"
    echo "  --quick            Run quick tests only (infrastructure)"
    echo "  --performance      Run performance tests only"
    echo "  --github           Test GitHub Actions integration only"
    echo ""
    echo "Environment Variables:"
    echo "  SONAR_TOKEN        SonarQube authentication token (optional)"
    echo "  SONAR_HOST_URL     SonarQube server URL (optional)"
    echo ""
    echo "Examples:"
    echo "  $0                 # Run all tests"
    echo "  $0 --quick         # Run infrastructure tests only"
    echo "  $0 --status        # Show deployment status"
    echo ""
    echo "Prerequisites:"
    echo "  - kubectl configured and connected to cluster"
    echo "  - SonarQube deployed in 'sonarqube' namespace"
    echo "  - curl and jq installed"
}

# Main execution function
main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --status)
            show_deployment_status
            show_access_info
            exit 0
            ;;
        --quick)
            print_info "Running quick infrastructure tests..."
            run_test "Kubernetes Cluster Connectivity" "test_cluster_connectivity"
            run_test "Namespace Exists" "test_namespace_exists"
            run_test "All Pods Running" "test_pods_running"
            run_test "PostgreSQL Ready" "test_postgresql_ready"
            run_test "SonarQube Ready" "test_sonarqube_ready"
            show_test_summary
            exit $?
            ;;
        --performance)
            test_performance
            exit $?
            ;;
        --github)
            run_test "GitHub Actions Integration" "test_github_integration"
            show_test_summary
            exit $?
            ;;
        "")
            # Default action - run all tests
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed - some tests may be skipped"
    fi
    
    # Run all tests
    run_all_tests
    show_test_summary
    
    # Show access information if tests passed
    if [ $TESTS_FAILED -eq 0 ]; then
        show_access_info
        
        print_info "🚀 Next steps:"
        echo "1. Access SonarQube web interface and change default password"
        echo "2. Generate authentication token for CI/CD"
        echo "3. Configure GitHub repository secrets"
        echo "4. Set up Branch Protection Rules"
        echo "5. Test the complete pipeline with a pull request"
    fi
    
    exit $?
}

# Run main function with all arguments
main "$@"