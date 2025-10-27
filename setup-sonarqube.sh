#!/bin/bash

# SonarQube Initial Configuration Script
# This script configures SonarQube with Quality Gates and project settings for Android development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_ADMIN_USER="admin"
DEFAULT_ADMIN_PASS="admin"
NEW_ADMIN_PASS="sonarqube123"
SONARQUBE_URL=""
PROJECT_KEY="android_app"

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
        
        # Try to get from Kubernetes service
        if command -v kubectl &> /dev/null; then
            SONARQUBE_PORT=$(kubectl get service sonarqube-service -n sonarqube -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
            if [ -n "$SONARQUBE_PORT" ]; then
                NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")
                SONARQUBE_URL="http://$NODE_IP:$SONARQUBE_PORT"
            fi
        fi
        
        # Fallback to localhost
        if [ -z "$SONARQUBE_URL" ]; then
            SONARQUBE_URL="http://localhost:30900"
        fi
    fi
    
    print_info "Using SonarQube URL: $SONARQUBE_URL"
}

# Function to wait for SonarQube to be ready
wait_for_sonarqube() {
    print_info "Waiting for SonarQube to be ready..."
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$SONARQUBE_URL/api/system/status" | grep -q '"status":"UP"'; then
            print_status "SonarQube is ready"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 10
    done
    
    print_error "SonarQube is not responding after 5 minutes"
    exit 1
}

# Function to change admin password
change_admin_password() {
    print_info "Changing default admin password..."
    
    # Check if password is still default
    if curl -s -u "$DEFAULT_ADMIN_USER:$DEFAULT_ADMIN_PASS" "$SONARQUBE_URL/api/authentication/validate" | grep -q '"valid":true'; then
        print_warning "Default password detected, changing it..."
        
        # Change password
        curl -s -u "$DEFAULT_ADMIN_USER:$DEFAULT_ADMIN_PASS" \
            -X POST "$SONARQUBE_URL/api/users/change_password" \
            -d "login=$DEFAULT_ADMIN_USER&password=$NEW_ADMIN_PASS&previousPassword=$DEFAULT_ADMIN_PASS"
        
        print_status "Admin password changed successfully"
        ADMIN_PASS="$NEW_ADMIN_PASS"
    else
        print_info "Admin password already changed"
        ADMIN_PASS="$NEW_ADMIN_PASS"
    fi
}

# Function to create Quality Gate
create_quality_gate() {
    print_info "Creating 'Android Strict' Quality Gate..."
    
    # Create Quality Gate
    QG_RESPONSE=$(curl -s -u "admin:$ADMIN_PASS" \
        -X POST "$SONARQUBE_URL/api/qualitygates/create" \
        -d "name=Android Strict")
    
    QG_ID=$(echo "$QG_RESPONSE" | grep -o '"id":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$QG_ID" ]; then
        print_status "Quality Gate created with ID: $QG_ID"
        
        # Add conditions to Quality Gate
        print_info "Adding Quality Gate conditions..."
        
        # Coverage >= 80%
        curl -s -u "admin:$ADMIN_PASS" \
            -X POST "$SONARQUBE_URL/api/qualitygates/create_condition" \
            -d "gateId=$QG_ID&metric=coverage&op=LT&error=80"
        
        # Bugs (Critical) = 0
        curl -s -u "admin:$ADMIN_PASS" \
            -X POST "$SONARQUBE_URL/api/qualitygates/create_condition" \
            -d "gateId=$QG_ID&metric=bugs&op=GT&error=0"
        
        # Vulnerabilities (High) = 0
        curl -s -u "admin:$ADMIN_PASS" \
            -X POST "$SONARQUBE_URL/api/qualitygates/create_condition" \
            -d "gateId=$QG_ID&metric=vulnerabilities&op=GT&error=0"
        
        # Code Smells (Blocker) = 0
        curl -s -u "admin:$ADMIN_PASS" \
            -X POST "$SONARQUBE_URL/api/qualitygates/create_condition" \
            -d "gateId=$QG_ID&metric=blocker_violations&op=GT&error=0"
        
        # Duplicated Lines <= 3%
        curl -s -u "admin:$ADMIN_PASS" \
            -X POST "$SONARQUBE_URL/api/qualitygates/create_condition" \
            -d "gateId=$QG_ID&metric=duplicated_lines_density&op=GT&error=3"
        
        # Maintainability Rating <= A
        curl -s -u "admin:$ADMIN_PASS" \
            -X POST "$SONARQUBE_URL/api/qualitygates/create_condition" \
            -d "gateId=$QG_ID&metric=sqale_rating&op=GT&error=1"
        
        # Reliability Rating <= A
        curl -s -u "admin:$ADMIN_PASS" \
            -X POST "$SONARQUBE_URL/api/qualitygates/create_condition" \
            -d "gateId=$QG_ID&metric=reliability_rating&op=GT&error=1"
        
        # Security Rating <= A
        curl -s -u "admin:$ADMIN_PASS" \
            -X POST "$SONARQUBE_URL/api/qualitygates/create_condition" \
            -d "gateId=$QG_ID&metric=security_rating&op=GT&error=1"
        
        print_status "Quality Gate conditions added"
        
        # Set as default Quality Gate
        curl -s -u "admin:$ADMIN_PASS" \
            -X POST "$SONARQUBE_URL/api/qualitygates/set_as_default" \
            -d "id=$QG_ID"
        
        print_status "Android Strict Quality Gate set as default"
    else
        print_warning "Quality Gate might already exist or creation failed"
    fi
}

# Function to create project
create_project() {
    print_info "Creating Android project..."
    
    # Create project
    curl -s -u "admin:$ADMIN_PASS" \
        -X POST "$SONARQUBE_URL/api/projects/create" \
        -d "project=$PROJECT_KEY&name=AndroidApp"
    
    print_status "Project created: $PROJECT_KEY"
}

# Function to generate authentication token
generate_token() {
    print_info "Generating authentication token..."
    
    TOKEN_RESPONSE=$(curl -s -u "admin:$ADMIN_PASS" \
        -X POST "$SONARQUBE_URL/api/user_tokens/generate" \
        -d "name=ci-cd-token")
    
    TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$TOKEN" ]; then
        print_status "Authentication token generated"
        echo -e "\n${YELLOW}🔑 IMPORTANT: Save this token for CI/CD configuration:${NC}"
        echo -e "${GREEN}$TOKEN${NC}"
        echo -e "\n${BLUE}Add this to your CI/CD environment variables as SONAR_TOKEN${NC}"
    else
        print_error "Failed to generate token"
    fi
}

# Function to show configuration summary
show_summary() {
    echo -e "\n${GREEN}🎉 SonarQube configuration completed!${NC}"
    echo -e "${BLUE}📋 Configuration Summary:${NC}"
    echo -e "   - SonarQube URL: $SONARQUBE_URL"
    echo -e "   - Admin credentials: admin/$ADMIN_PASS"
    echo -e "   - Quality Gate: Android Strict (default)"
    echo -e "   - Project Key: $PROJECT_KEY"
    echo -e "\n${BLUE}📋 Quality Gate Rules:${NC}"
    echo -e "   - Coverage: >= 80%"
    echo -e "   - Bugs: = 0"
    echo -e "   - Vulnerabilities: = 0"
    echo -e "   - Code Smells (Blocker): = 0"
    echo -e "   - Duplicated Lines: <= 3%"
    echo -e "   - Maintainability Rating: <= A"
    echo -e "   - Reliability Rating: <= A"
    echo -e "   - Security Rating: <= A"
    echo -e "\n${BLUE}📋 Next Steps:${NC}"
    echo -e "   1. Configure your CI/CD pipeline with the generated token"
    echo -e "   2. Add sonar-project.properties to your Android project"
    echo -e "   3. Test the pipeline with a sample commit"
}

# Function to show help
show_help() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "SonarQube Configuration Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h           Show this help message"
        echo "  --url URL            SonarQube URL (auto-detected if not provided)"
        echo "  --project-key KEY    Project key (default: android_app)"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Auto-detect URL and configure"
        echo "  $0 --url http://localhost:9000        # Use specific URL"
        echo "  $0 --project-key my_android_project   # Use custom project key"
        exit 0
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help "$1"
            ;;
        --url)
            SONARQUBE_URL="$2"
            shift 2
            ;;
        --project-key)
            PROJECT_KEY="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# Main configuration function
main() {
    echo -e "${BLUE}🔧 Starting SonarQube Configuration${NC}"
    echo "============================================"
    
    detect_sonarqube_url
    wait_for_sonarqube
    change_admin_password
    create_quality_gate
    create_project
    generate_token
    show_summary
}

# Run main function
main