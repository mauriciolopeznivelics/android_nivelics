#!/bin/bash

# Configure Quality Gate script for SonarQube Android projects
# This script creates an "Android Strict" Quality Gate with 80% coverage requirement
# and configures Kotlin/Java quality profiles

set -e

# Configuration
SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
SONAR_TOKEN="${SONAR_TOKEN}"
QUALITY_GATE_NAME="Android Strict"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to check if SonarQube is accessible
check_sonarqube_connection() {
    print_status "Checking SonarQube connection..."
    
    if ! curl -s -f -u "${SONAR_TOKEN}:" "${SONAR_HOST_URL}/api/system/status" > /dev/null; then
        print_error "Cannot connect to SonarQube at ${SONAR_HOST_URL}"
        print_error "Please ensure SonarQube is running and SONAR_TOKEN is valid"
        exit 1
    fi
    
    print_status "SonarQube connection successful"
}

# Function to create Quality Gate
create_quality_gate() {
    print_status "Creating Quality Gate: ${QUALITY_GATE_NAME}"
    
    # Check if Quality Gate already exists
    EXISTING_QG=$(curl -s -u "${SONAR_TOKEN}:" "${SONAR_HOST_URL}/api/qualitygates/list" | \
        jq -r ".qualitygates[] | select(.name==\"${QUALITY_GATE_NAME}\") | .id")
    
    if [ -n "$EXISTING_QG" ] && [ "$EXISTING_QG" != "null" ]; then
        print_warning "Quality Gate '${QUALITY_GATE_NAME}' already exists (ID: ${EXISTING_QG})"
        QG_ID=$EXISTING_QG
    else
        # Create new Quality Gate
        QG_RESPONSE=$(curl -s -u "${SONAR_TOKEN}:" -X POST \
            "${SONAR_HOST_URL}/api/qualitygates/create" \
            -d "name=${QUALITY_GATE_NAME}")
        
        QG_ID=$(echo "$QG_RESPONSE" | jq -r '.id')
        
        if [ "$QG_ID" = "null" ] || [ -z "$QG_ID" ]; then
            print_error "Failed to create Quality Gate"
            echo "$QG_RESPONSE"
            exit 1
        fi
        
        print_status "Quality Gate created with ID: ${QG_ID}"
    fi
}

# Function to add conditions to Quality Gate
add_quality_gate_conditions() {
    print_status "Adding conditions to Quality Gate..."
    
    # Remove existing conditions first
    EXISTING_CONDITIONS=$(curl -s -u "${SONAR_TOKEN}:" \
        "${SONAR_HOST_URL}/api/qualitygates/show?id=${QG_ID}" | \
        jq -r '.conditions[]?.id // empty')
    
    for condition_id in $EXISTING_CONDITIONS; do
        curl -s -u "${SONAR_TOKEN}:" -X POST \
            "${SONAR_HOST_URL}/api/qualitygates/delete_condition" \
            -d "id=${condition_id}" > /dev/null
    done
    
    # Add new conditions
    declare -a conditions=(
        "coverage:LT:80.0"                    # Coverage >= 80%
        "bugs:GT:0"                          # Bugs (all) = 0
        "vulnerabilities:GT:0"               # Vulnerabilities (all) = 0
        "code_smells:GT:0"                   # Code Smells (Blocker) = 0
        "duplicated_lines_density:GT:3.0"    # Duplicated Lines <= 3%
        "sqale_rating:GT:1"                  # Maintainability Rating <= A
        "reliability_rating:GT:1"            # Reliability Rating <= A
        "security_rating:GT:1"               # Security Rating <= A
        "new_coverage:LT:80.0"               # New Coverage >= 80%
        "new_bugs:GT:0"                      # New Bugs = 0
        "new_vulnerabilities:GT:0"           # New Vulnerabilities = 0
    )
    
    for condition in "${conditions[@]}"; do
        IFS=':' read -r metric operator threshold <<< "$condition"
        
        curl -s -u "${SONAR_TOKEN}:" -X POST \
            "${SONAR_HOST_URL}/api/qualitygates/create_condition" \
            -d "gateId=${QG_ID}" \
            -d "metric=${metric}" \
            -d "op=${operator}" \
            -d "error=${threshold}" > /dev/null
        
        print_status "Added condition: ${metric} ${operator} ${threshold}"
    done
}

# Function to set Quality Gate as default
set_default_quality_gate() {
    print_status "Setting Quality Gate as default..."
    
    curl -s -u "${SONAR_TOKEN}:" -X POST \
        "${SONAR_HOST_URL}/api/qualitygates/set_as_default" \
        -d "id=${QG_ID}" > /dev/null
    
    print_status "Quality Gate set as default"
}

# Function to configure Kotlin/Java quality profiles
configure_quality_profiles() {
    print_status "Configuring Kotlin/Java quality profiles..."
    
    # Get available quality profiles
    PROFILES=$(curl -s -u "${SONAR_TOKEN}:" "${SONAR_HOST_URL}/api/qualityprofiles/search")
    
    # Configure Java profile
    JAVA_PROFILE=$(echo "$PROFILES" | jq -r '.profiles[] | select(.language=="java" and .name=="Sonar way") | .key')
    if [ -n "$JAVA_PROFILE" ] && [ "$JAVA_PROFILE" != "null" ]; then
        print_status "Found Java profile: ${JAVA_PROFILE}"
        
        # Set as default for Java
        curl -s -u "${SONAR_TOKEN}:" -X POST \
            "${SONAR_HOST_URL}/api/qualityprofiles/set_default" \
            -d "qualityProfile=${JAVA_PROFILE}" > /dev/null
    fi
    
    # Configure Kotlin profile
    KOTLIN_PROFILE=$(echo "$PROFILES" | jq -r '.profiles[] | select(.language=="kotlin" and .name=="Sonar way") | .key')
    if [ -n "$KOTLIN_PROFILE" ] && [ "$KOTLIN_PROFILE" != "null" ]; then
        print_status "Found Kotlin profile: ${KOTLIN_PROFILE}"
        
        # Set as default for Kotlin
        curl -s -u "${SONAR_TOKEN}:" -X POST \
            "${SONAR_HOST_URL}/api/qualityprofiles/set_default" \
            -d "qualityProfile=${KOTLIN_PROFILE}" > /dev/null
    fi
}

# Function to validate configuration
validate_configuration() {
    print_status "Validating Quality Gate configuration..."
    
    # Get Quality Gate details
    QG_DETAILS=$(curl -s -u "${SONAR_TOKEN}:" "${SONAR_HOST_URL}/api/qualitygates/show?id=${QG_ID}")
    
    CONDITIONS_COUNT=$(echo "$QG_DETAILS" | jq '.conditions | length')
    print_status "Quality Gate has ${CONDITIONS_COUNT} conditions configured"
    
    # Check if it's set as default
    IS_DEFAULT=$(echo "$QG_DETAILS" | jq -r '.isDefault')
    if [ "$IS_DEFAULT" = "true" ]; then
        print_status "Quality Gate is set as default"
    else
        print_warning "Quality Gate is not set as default"
    fi
}

# Main execution
main() {
    print_status "Starting SonarQube Quality Gate configuration..."
    
    # Validate required environment variables
    if [ -z "$SONAR_TOKEN" ]; then
        print_error "SONAR_TOKEN environment variable is required"
        exit 1
    fi
    
    # Execute configuration steps
    check_sonarqube_connection
    create_quality_gate
    add_quality_gate_conditions
    set_default_quality_gate
    configure_quality_profiles
    validate_configuration
    
    print_status "Quality Gate configuration completed successfully!"
    print_status "Quality Gate Name: ${QUALITY_GATE_NAME}"
    print_status "Quality Gate ID: ${QG_ID}"
    print_status "SonarQube URL: ${SONAR_HOST_URL}"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi