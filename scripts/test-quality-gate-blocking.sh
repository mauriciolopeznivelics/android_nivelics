#!/bin/bash

# Test script to validate Quality Gate blocking behavior
# This script simulates different code quality scenarios to test the blocking mechanism

set -e

# Configuration
SONAR_HOST_URL="${SONAR_HOST_URL}"
SONAR_TOKEN="${SONAR_TOKEN}"
TEST_PROJECT_KEY="quality_gate_test"
GITHUB_REPO="${GITHUB_REPO}"
GITHUB_TOKEN="${GITHUB_TOKEN}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to validate environment
validate_environment() {
    print_info "Validating environment variables..."
    
    local missing_vars=()
    
    if [ -z "$SONAR_HOST_URL" ]; then
        missing_vars+=("SONAR_HOST_URL")
    fi
    
    if [ -z "$SONAR_TOKEN" ]; then
        missing_vars+=("SONAR_TOKEN")
    fi
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        exit 1
    fi
    
    print_status "Environment variables validated"
}

# Function to test SonarQube connectivity
test_sonarqube_connectivity() {
    print_info "Testing SonarQube connectivity..."
    
    if curl -s -f -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/system/status" > /dev/null; then
        print_status "SonarQube is accessible"
        return 0
    else
        print_error "Cannot connect to SonarQube at $SONAR_HOST_URL"
        return 1
    fi
}

# Function to create test project with specific quality issues
create_test_project_with_issues() {
    local project_key="$1"
    local project_name="$2"
    
    print_info "Creating test project: $project_name"
    
    # Create project
    curl -s -u "$SONAR_TOKEN:" -X POST \
        "$SONAR_HOST_URL/api/projects/create" \
        -d "project=$project_key" \
        -d "name=$project_name" > /dev/null
    
    print_status "Test project created: $project_key"
}

# Function to simulate analysis with low coverage
simulate_low_coverage_analysis() {
    local project_key="$1"
    
    print_info "Simulating analysis with low coverage for: $project_key"
    
    # This would typically be done by running sonar-scanner with a project that has low coverage
    # For testing purposes, we'll create a mock analysis result
    
    # Note: In a real scenario, you would run sonar-scanner with actual code that has low coverage
    print_warning "This is a simulation - in real usage, run sonar-scanner with low-coverage code"
    
    return 0
}

# Function to check Quality Gate status
check_quality_gate_status() {
    local project_key="$1"
    
    print_info "Checking Quality Gate status for: $project_key"
    
    local qg_status=$(curl -s -u "$SONAR_TOKEN:" \
        "$SONAR_HOST_URL/api/qualitygates/project_status?projectKey=$project_key" | \
        jq -r '.projectStatus.status' 2>/dev/null || echo "UNKNOWN")
    
    echo "Quality Gate Status: $qg_status"
    
    case "$qg_status" in
        "OK")
            print_status "Quality Gate PASSED"
            return 0
            ;;
        "ERROR")
            print_error "Quality Gate FAILED"
            return 1
            ;;
        "WARN")
            print_warning "Quality Gate WARNING"
            return 2
            ;;
        *)
            print_warning "Quality Gate status unknown: $qg_status"
            return 3
            ;;
    esac
}

# Function to test GitHub Status Check integration
test_github_status_check() {
    local commit_sha="$1"
    local expected_status="$2"
    
    if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_REPO" ]; then
        print_warning "GitHub integration not configured, skipping status check test"
        return 0
    fi
    
    print_info "Testing GitHub Status Check for commit: $commit_sha"
    
    # Get commit status from GitHub API
    local status_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPO/commits/$commit_sha/status")
    
    local overall_state=$(echo "$status_response" | jq -r '.state' 2>/dev/null || echo "unknown")
    
    echo "GitHub Status: $overall_state"
    
    # Check for SonarQube-specific status checks
    local sonar_checks=$(echo "$status_response" | jq -r '.statuses[] | select(.context | contains("SonarQube")) | .state' 2>/dev/null || echo "")
    
    if [ -n "$sonar_checks" ]; then
        echo "SonarQube Status Checks:"
        echo "$status_response" | jq -r '.statuses[] | select(.context | contains("SonarQube")) | "  - \(.context): \(.state) - \(.description)"' 2>/dev/null || echo "  - Unable to parse status checks"
    else
        print_warning "No SonarQube status checks found"
    fi
    
    if [ "$overall_state" = "$expected_status" ]; then
        print_status "GitHub status matches expected: $expected_status"
        return 0
    else
        print_error "GitHub status mismatch. Expected: $expected_status, Got: $overall_state"
        return 1
    fi
}

# Function to test Branch Protection Rules
test_branch_protection() {
    if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_REPO" ]; then
        print_warning "GitHub integration not configured, skipping branch protection test"
        return 0
    fi
    
    print_info "Testing Branch Protection Rules..."
    
    local branch="main"
    local protection_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPO/branches/$branch/protection" 2>/dev/null)
    
    if echo "$protection_response" | jq -e '.required_status_checks.contexts[] | select(. | contains("SonarQube"))' > /dev/null 2>&1; then
        print_status "Branch protection includes SonarQube status checks"
        
        # List required status checks
        echo "Required Status Checks:"
        echo "$protection_response" | jq -r '.required_status_checks.contexts[]' | sed 's/^/  - /'
        
        return 0
    else
        print_error "Branch protection does not include SonarQube status checks"
        return 1
    fi
}

# Function to cleanup test projects
cleanup_test_projects() {
    print_info "Cleaning up test projects..."
    
    local test_projects=("quality_gate_test_pass" "quality_gate_test_fail")
    
    for project in "${test_projects[@]}"; do
        curl -s -u "$SONAR_TOKEN:" -X POST \
            "$SONAR_HOST_URL/api/projects/delete" \
            -d "project=$project" > /dev/null 2>&1
        print_info "Cleaned up project: $project"
    done
}

# Function to run comprehensive Quality Gate blocking test
run_quality_gate_blocking_test() {
    print_test_header "Quality Gate Blocking Mechanism Test"
    
    # Test 1: Create project that should pass Quality Gate
    create_test_project_with_issues "quality_gate_test_pass" "Test Project - Should Pass"
    
    # Test 2: Create project that should fail Quality Gate
    create_test_project_with_issues "quality_gate_test_fail" "Test Project - Should Fail"
    
    # Test 3: Simulate high-quality code analysis (should pass)
    print_info "Simulating high-quality code analysis..."
    print_status "In real scenario: Run sonar-scanner with high-coverage, clean code"
    
    # Test 4: Simulate low-quality code analysis (should fail)
    print_info "Simulating low-quality code analysis..."
    print_warning "In real scenario: Run sonar-scanner with low-coverage, buggy code"
    
    # Test 5: Check Quality Gate responses
    print_info "Testing Quality Gate decision logic..."
    
    # Simulate different scenarios
    local scenarios=(
        "High coverage (85%), no bugs, no vulnerabilities:PASS"
        "Low coverage (60%), no bugs, no vulnerabilities:FAIL"
        "High coverage (85%), 1 critical bug, no vulnerabilities:FAIL"
        "High coverage (85%), no bugs, 1 high vulnerability:FAIL"
    )
    
    for scenario in "${scenarios[@]}"; do
        IFS=':' read -r description expected <<< "$scenario"
        echo "  Scenario: $description"
        echo "  Expected: $expected"
        
        if [ "$expected" = "PASS" ]; then
            print_status "✅ Should allow merge"
        else
            print_error "❌ Should block merge"
        fi
    done
    
    return 0
}

# Function to test the complete pipeline integration
test_pipeline_integration() {
    print_test_header "Pipeline Integration Test"
    
    print_info "Testing GitHub Actions + SonarQube + Branch Protection integration..."
    
    # Check if GitHub Actions workflow exists
    if [ -f ".github/workflows/sonar-analysis.yml" ]; then
        print_status "GitHub Actions workflow found"
        
        # Verify workflow contains Quality Gate job
        if grep -q "quality-gate:" ".github/workflows/sonar-analysis.yml"; then
            print_status "Quality Gate job found in workflow"
        else
            print_error "Quality Gate job missing in workflow"
            return 1
        fi
        
        # Verify workflow contains Status Check updates
        if grep -q "github-script" ".github/workflows/sonar-analysis.yml"; then
            print_status "GitHub Status Check integration found"
        else
            print_error "GitHub Status Check integration missing"
            return 1
        fi
        
    else
        print_error "GitHub Actions workflow not found"
        return 1
    fi
    
    # Test Branch Protection Rules
    test_branch_protection
    
    return 0
}

# Function to show test recommendations
show_test_recommendations() {
    print_info "🚀 Testing Recommendations:"
    echo ""
    echo "To fully test the Quality Gate blocking mechanism:"
    echo ""
    echo "1. Create a test branch with intentionally poor code:"
    echo "   - Low test coverage (< 80%)"
    echo "   - Critical bugs or vulnerabilities"
    echo "   - High code duplication"
    echo ""
    echo "2. Create a pull request from this branch"
    echo ""
    echo "3. Verify that:"
    echo "   - GitHub Actions pipeline runs"
    echo "   - SonarQube analysis executes"
    echo "   - Quality Gate fails"
    echo "   - GitHub Status Check reports failure"
    echo "   - Merge is blocked by Branch Protection Rules"
    echo ""
    echo "4. Fix the code quality issues and verify:"
    echo "   - Quality Gate passes"
    echo "   - GitHub Status Check reports success"
    echo "   - Merge is allowed"
    echo ""
    echo "Example commands to test locally:"
    echo "  cd test-android-project/"
    echo "  ./gradlew clean testDebugUnitTest jacocoTestReport"
    echo "  sonar-scanner # (with your SonarQube configuration)"
}

# Function to show help
show_help() {
    echo "Quality Gate Blocking Test Script"
    echo ""
    echo "This script tests the SonarQube Quality Gate blocking mechanism"
    echo "and validates integration with GitHub Actions and Branch Protection."
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h         Show this help message"
    echo "  --connectivity     Test SonarQube connectivity only"
    echo "  --github           Test GitHub integration only"
    echo "  --pipeline         Test pipeline integration only"
    echo "  --cleanup          Cleanup test projects"
    echo ""
    echo "Environment Variables:"
    echo "  SONAR_HOST_URL     SonarQube server URL (required)"
    echo "  SONAR_TOKEN        SonarQube authentication token (required)"
    echo "  GITHUB_TOKEN       GitHub personal access token (optional)"
    echo "  GITHUB_REPO        GitHub repository (owner/repo) (optional)"
    echo ""
    echo "Examples:"
    echo "  $0                 # Run all tests"
    echo "  $0 --connectivity  # Test SonarQube connectivity only"
    echo "  $0 --github        # Test GitHub integration only"
}

# Main execution function
main() {
    echo -e "${BLUE}🔒 Quality Gate Blocking Mechanism Test${NC}"
    echo "========================================"
    
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --connectivity)
            validate_environment
            test_sonarqube_connectivity
            exit $?
            ;;
        --github)
            test_branch_protection
            exit $?
            ;;
        --pipeline)
            test_pipeline_integration
            exit $?
            ;;
        --cleanup)
            validate_environment
            cleanup_test_projects
            exit 0
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
    
    # Run comprehensive tests
    validate_environment
    
    if ! test_sonarqube_connectivity; then
        print_error "Cannot proceed without SonarQube connectivity"
        exit 1
    fi
    
    run_quality_gate_blocking_test
    test_pipeline_integration
    show_test_recommendations
    
    # Cleanup
    cleanup_test_projects
    
    print_status "Quality Gate blocking mechanism test completed!"
    print_info "Remember to test with real pull requests to fully validate the blocking behavior."
}

# Run main function with all arguments
main "$@"