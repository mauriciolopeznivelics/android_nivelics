#!/bin/bash

# GitHub Branch Protection Rules Setup Script
# This script configures branch protection rules to require SonarQube Quality Gate checks
# before allowing merges to protected branches

set -e

# Configuration
GITHUB_TOKEN="${GITHUB_TOKEN}"
GITHUB_REPO="${GITHUB_REPO}"  # Format: owner/repo
PROTECTED_BRANCHES=("main" "master" "develop")

# Required status checks
REQUIRED_CHECKS=(
    "SonarQube Quality Gate"
    "SonarQube Analysis"
    "Build Android Project"
    "Run Tests and Generate Coverage"
)

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

# Function to validate required environment variables
validate_environment() {
    print_info "Validating environment variables..."
    
    if [ -z "$GITHUB_TOKEN" ]; then
        print_error "GITHUB_TOKEN environment variable is required"
        print_info "Generate a token at: https://github.com/settings/tokens"
        print_info "Required scopes: repo, admin:repo_hook"
        exit 1
    fi
    
    if [ -z "$GITHUB_REPO" ]; then
        print_error "GITHUB_REPO environment variable is required"
        print_info "Format: owner/repository-name"
        print_info "Example: myorg/my-android-app"
        exit 1
    fi
    
    print_status "Environment variables validated"
}

# Function to test GitHub API connection
test_github_connection() {
    print_info "Testing GitHub API connection..."
    
    RESPONSE=$(curl -s -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPO" -o /tmp/github_test.json)
    
    if [ "$RESPONSE" != "200" ]; then
        print_error "Failed to connect to GitHub API (HTTP $RESPONSE)"
        print_error "Please check your GITHUB_TOKEN and GITHUB_REPO"
        cat /tmp/github_test.json
        exit 1
    fi
    
    REPO_NAME=$(jq -r '.name' /tmp/github_test.json)
    print_status "Connected to repository: $REPO_NAME"
}

# Function to check if branch exists
check_branch_exists() {
    local branch=$1
    
    RESPONSE=$(curl -s -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPO/branches/$branch" -o /tmp/branch_check.json)
    
    if [ "$RESPONSE" = "200" ]; then
        return 0
    else
        return 1
    fi
}

# Function to configure branch protection for a single branch
configure_branch_protection() {
    local branch=$1
    print_info "Configuring branch protection for: $branch"
    
    # Check if branch exists
    if ! check_branch_exists "$branch"; then
        print_warning "Branch '$branch' does not exist, skipping..."
        return 0
    fi
    
    # Build required status checks array for JSON
    local status_checks_json=""
    for check in "${REQUIRED_CHECKS[@]}"; do
        if [ -n "$status_checks_json" ]; then
            status_checks_json="$status_checks_json,"
        fi
        status_checks_json="$status_checks_json\"$check\""
    done
    
    # Create branch protection configuration
    local protection_config=$(cat <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": [$status_checks_json]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true
}
EOF
    )
    
    # Apply branch protection
    RESPONSE=$(curl -s -w "%{http_code}" -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "$protection_config" \
        "https://api.github.com/repos/$GITHUB_REPO/branches/$branch/protection" \
        -o /tmp/protection_response.json)
    
    if [ "$RESPONSE" = "200" ]; then
        print_status "Branch protection configured for: $branch"
    else
        print_error "Failed to configure branch protection for: $branch (HTTP $RESPONSE)"
        cat /tmp/protection_response.json
        return 1
    fi
}

# Function to verify branch protection configuration
verify_branch_protection() {
    local branch=$1
    print_info "Verifying branch protection for: $branch"
    
    RESPONSE=$(curl -s -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPO/branches/$branch/protection" \
        -o /tmp/protection_verify.json)
    
    if [ "$RESPONSE" = "200" ]; then
        local strict_checks=$(jq -r '.required_status_checks.strict' /tmp/protection_verify.json)
        local enforce_admins=$(jq -r '.enforce_admins.enabled' /tmp/protection_verify.json)
        local required_reviews=$(jq -r '.required_pull_request_reviews.required_approving_review_count' /tmp/protection_verify.json)
        local contexts_count=$(jq -r '.required_status_checks.contexts | length' /tmp/protection_verify.json)
        
        print_status "Branch protection verified:"
        echo "  - Strict status checks: $strict_checks"
        echo "  - Enforce admins: $enforce_admins"
        echo "  - Required reviews: $required_reviews"
        echo "  - Required status checks: $contexts_count"
        
        # List required status checks
        echo "  - Status checks:"
        jq -r '.required_status_checks.contexts[]' /tmp/protection_verify.json | sed 's/^/    - /'
        
    else
        print_warning "Could not verify branch protection for: $branch"
    fi
}

# Function to show current branch protection status
show_protection_status() {
    print_info "Current branch protection status:"
    echo ""
    
    for branch in "${PROTECTED_BRANCHES[@]}"; do
        if check_branch_exists "$branch"; then
            echo -e "${BLUE}Branch: $branch${NC}"
            
            RESPONSE=$(curl -s -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" \
                "https://api.github.com/repos/$GITHUB_REPO/branches/$branch/protection" \
                -o /tmp/status_check.json)
            
            if [ "$RESPONSE" = "200" ]; then
                echo -e "  ${GREEN}✅ Protected${NC}"
                local contexts_count=$(jq -r '.required_status_checks.contexts | length' /tmp/status_check.json)
                echo "  📋 Required checks: $contexts_count"
            else
                echo -e "  ${RED}❌ Not protected${NC}"
            fi
        else
            echo -e "${BLUE}Branch: $branch${NC}"
            echo -e "  ${YELLOW}⚠️  Does not exist${NC}"
        fi
        echo ""
    done
}

# Function to remove branch protection (for cleanup)
remove_branch_protection() {
    local branch=$1
    print_warning "Removing branch protection for: $branch"
    
    RESPONSE=$(curl -s -w "%{http_code}" -X DELETE \
        -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPO/branches/$branch/protection" \
        -o /tmp/remove_response.json)
    
    if [ "$RESPONSE" = "204" ]; then
        print_status "Branch protection removed for: $branch"
    else
        print_error "Failed to remove branch protection for: $branch (HTTP $RESPONSE)"
    fi
}

# Function to show help
show_help() {
    echo "GitHub Branch Protection Setup Script"
    echo ""
    echo "This script configures branch protection rules to require SonarQube"
    echo "Quality Gate checks before allowing merges to protected branches."
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h         Show this help message"
    echo "  --status           Show current protection status"
    echo "  --remove           Remove branch protection (cleanup)"
    echo "  --verify           Only verify existing protection"
    echo ""
    echo "Environment Variables:"
    echo "  GITHUB_TOKEN       GitHub personal access token (required)"
    echo "  GITHUB_REPO        Repository in format owner/repo (required)"
    echo ""
    echo "Examples:"
    echo "  export GITHUB_TOKEN=ghp_xxxxxxxxxxxx"
    echo "  export GITHUB_REPO=myorg/my-android-app"
    echo "  $0                 # Configure branch protection"
    echo "  $0 --status        # Show current status"
    echo "  $0 --remove        # Remove protection (cleanup)"
    echo ""
    echo "Required GitHub Token Scopes:"
    echo "  - repo (Full control of private repositories)"
    echo "  - admin:repo_hook (Admin access to repository hooks)"
    echo ""
    echo "Protected Branches:"
    for branch in "${PROTECTED_BRANCHES[@]}"; do
        echo "  - $branch"
    done
    echo ""
    echo "Required Status Checks:"
    for check in "${REQUIRED_CHECKS[@]}"; do
        echo "  - $check"
    done
}

# Main execution function
main() {
    echo -e "${BLUE}🔒 GitHub Branch Protection Setup${NC}"
    echo "=================================="
    
    # Parse command line arguments
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --status)
            validate_environment
            test_github_connection
            show_protection_status
            exit 0
            ;;
        --remove)
            validate_environment
            test_github_connection
            print_warning "This will remove branch protection from all protected branches!"
            read -p "Are you sure? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                for branch in "${PROTECTED_BRANCHES[@]}"; do
                    if check_branch_exists "$branch"; then
                        remove_branch_protection "$branch"
                    fi
                done
            else
                print_info "Operation cancelled"
            fi
            exit 0
            ;;
        --verify)
            validate_environment
            test_github_connection
            for branch in "${PROTECTED_BRANCHES[@]}"; do
                if check_branch_exists "$branch"; then
                    verify_branch_protection "$branch"
                fi
            done
            exit 0
            ;;
        "")
            # Default action - configure protection
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    # Main configuration process
    validate_environment
    test_github_connection
    
    print_info "Configuring branch protection rules..."
    
    local success_count=0
    local total_count=0
    
    for branch in "${PROTECTED_BRANCHES[@]}"; do
        if check_branch_exists "$branch"; then
            total_count=$((total_count + 1))
            if configure_branch_protection "$branch"; then
                success_count=$((success_count + 1))
                verify_branch_protection "$branch"
            fi
        else
            print_warning "Branch '$branch' does not exist, skipping..."
        fi
        echo ""
    done
    
    # Summary
    echo -e "${BLUE}📊 Configuration Summary${NC}"
    echo "========================"
    echo "Branches configured: $success_count/$total_count"
    echo "Repository: $GITHUB_REPO"
    echo ""
    
    if [ $success_count -eq $total_count ] && [ $total_count -gt 0 ]; then
        print_status "All branch protection rules configured successfully!"
        echo ""
        print_info "🚀 Next steps:"
        echo "1. Test the protection by creating a pull request"
        echo "2. Verify that merges are blocked when Quality Gate fails"
        echo "3. Ensure your CI/CD pipeline reports the correct status check names"
        echo ""
        print_info "📋 Required status checks configured:"
        for check in "${REQUIRED_CHECKS[@]}"; do
            echo "  - $check"
        done
    else
        print_warning "Some branch protection rules could not be configured"
        print_info "Run '$0 --status' to check current configuration"
    fi
}

# Run main function with all arguments
main "$@"