#!/bin/bash

# Quality Gate Validation Script
# This script polls SonarQube API to check Quality Gate status and blocks deployment if it fails

set -e

echo "🔍 Starting Quality Gate validation..."

# Configuration
PROJECT_KEY="android_app"
MAX_ATTEMPTS=30
SLEEP_INTERVAL=10
TIMEOUT_MINUTES=5

# Validate required environment variables
if [ -z "$SONAR_HOST_URL" ]; then
    echo "❌ Error: SONAR_HOST_URL environment variable is not set"
    exit 1
fi

if [ -z "$SONAR_TOKEN" ]; then
    echo "❌ Error: SONAR_TOKEN environment variable is not set"
    exit 1
fi

echo "📋 Quality Gate Configuration:"
echo "  - Project Key: $PROJECT_KEY"
echo "  - SonarQube Host: $SONAR_HOST_URL"
echo "  - Max Attempts: $MAX_ATTEMPTS"
echo "  - Timeout: $TIMEOUT_MINUTES minutes"

# Function to get project analysis status
get_quality_gate_status() {
    local response
    response=$(curl -s -u "$SONAR_TOKEN:" \
        "$SONAR_HOST_URL/api/qualitygates/project_status?projectKey=$PROJECT_KEY" \
        2>/dev/null || echo "ERROR")
    echo "$response"
}

# Function to extract status from JSON response
extract_status() {
    local response="$1"
    echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "UNKNOWN"
}

# Function to get coverage information
get_coverage_info() {
    local coverage_response
    coverage_response=$(curl -s -u "$SONAR_TOKEN:" \
        "$SONAR_HOST_URL/api/measures/component?component=$PROJECT_KEY&metricKeys=coverage,bugs,vulnerabilities,code_smells" \
        2>/dev/null || echo "ERROR")
    
    if [ "$coverage_response" != "ERROR" ]; then
        local coverage
        coverage=$(echo "$coverage_response" | grep -o '"metric":"coverage"[^}]*"value":"[^"]*"' | grep -o '"value":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "N/A")
        
        local bugs
        bugs=$(echo "$coverage_response" | grep -o '"metric":"bugs"[^}]*"value":"[^"]*"' | grep -o '"value":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "N/A")
        
        local vulnerabilities
        vulnerabilities=$(echo "$coverage_response" | grep -o '"metric":"vulnerabilities"[^}]*"value":"[^"]*"' | grep -o '"value":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "N/A")
        
        local code_smells
        code_smells=$(echo "$coverage_response" | grep -o '"metric":"code_smells"[^}]*"value":"[^"]*"' | grep -o '"value":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "N/A")
        
        echo "📊 Quality Metrics:"
        echo "  - Coverage: ${coverage}%"
        echo "  - Bugs: $bugs"
        echo "  - Vulnerabilities: $vulnerabilities"
        echo "  - Code Smells: $code_smells"
    fi
}

# Function to get detailed failure conditions
get_failure_details() {
    local response="$1"
    echo "❌ Quality Gate Failure Details:"
    
    # Extract conditions from response
    local conditions
    conditions=$(echo "$response" | grep -o '"conditions":\[[^]]*\]' 2>/dev/null || echo "")
    
    if [ -n "$conditions" ]; then
        echo "$conditions" | grep -o '"metricKey":"[^"]*","operator":"[^"]*","value":"[^"]*","status":"[^"]*"' | while read -r condition; do
            local metric
            metric=$(echo "$condition" | grep -o '"metricKey":"[^"]*"' | cut -d'"' -f4)
            local operator
            operator=$(echo "$condition" | grep -o '"operator":"[^"]*"' | cut -d'"' -f4)
            local value
            value=$(echo "$condition" | grep -o '"value":"[^"]*"' | cut -d'"' -f4)
            local status
            status=$(echo "$condition" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            
            if [ "$status" = "ERROR" ]; then
                echo "  ❌ $metric $operator $value (FAILED)"
            fi
        done
    else
        echo "  Unable to parse failure details"
    fi
}

# Main Quality Gate checking loop
ATTEMPT=0
echo "⏳ Waiting for Quality Gate analysis to complete..."

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "🔄 Checking Quality Gate status (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
    
    # Get Quality Gate status
    RESPONSE=$(get_quality_gate_status)
    
    if [ "$RESPONSE" = "ERROR" ]; then
        echo "⚠️  Failed to connect to SonarQube API. Retrying..."
        sleep $SLEEP_INTERVAL
        continue
    fi
    
    # Extract status
    STATUS=$(extract_status "$RESPONSE")
    
    case "$STATUS" in
        "OK")
            echo "✅ Quality Gate PASSED! Code quality meets all requirements."
            get_coverage_info
            echo "🎉 Deployment can proceed!"
            echo "🔗 View detailed results: $SONAR_HOST_URL/dashboard?id=$PROJECT_KEY"
            exit 0
            ;;
        "ERROR")
            echo "❌ Quality Gate FAILED! Code does not meet quality requirements."
            get_coverage_info
            get_failure_details "$RESPONSE"
            echo ""
            echo "🚫 Deployment is BLOCKED until quality issues are resolved."
            echo "🔗 Fix issues at: $SONAR_HOST_URL/dashboard?id=$PROJECT_KEY"
            exit 1
            ;;
        "IN_PROGRESS"|"PENDING")
            echo "⏳ Quality Gate analysis in progress... (status: $STATUS)"
            ;;
        *)
            echo "⚠️  Unknown Quality Gate status: $STATUS"
            ;;
    esac
    
    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
        echo "⏰ Waiting $SLEEP_INTERVAL seconds before next check..."
        sleep $SLEEP_INTERVAL
    fi
done

# Timeout reached
echo "❌ Timeout reached after $TIMEOUT_MINUTES minutes waiting for Quality Gate result"
echo "🔗 Check analysis status manually: $SONAR_HOST_URL/dashboard?id=$PROJECT_KEY"
echo "🚫 Deployment is BLOCKED due to timeout"
exit 1