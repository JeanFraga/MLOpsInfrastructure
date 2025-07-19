#!/usr/bin/env bash

# GitOps Structure Validation Script
# Validates the GitOps structure before migration

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_step() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] STEP:${NC} $1"
}

# Validate YAML syntax
validate_yaml_syntax() {
    local file="$1"
    local errors=0
    
    if command -v yq &> /dev/null; then
        if ! yq eval . "$file" > /dev/null 2>&1; then
            log_error "YAML syntax error in $file"
            errors=$((errors + 1))
        fi
    elif command -v python3 &> /dev/null; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            log_error "YAML syntax error in $file"
            errors=$((errors + 1))
        fi
    else
        log_warning "No YAML validator found (yq or python3). Skipping syntax validation for $file"
    fi
    
    return $errors
}

# Validate GitOps structure
validate_gitops_structure() {
    log_step "Validating GitOps repository structure..."
    
    local errors=0
    
    # Check required directories
    local required_dirs=(
        "gitops"
        "gitops/apps"
        "gitops/apps/base"
        "gitops/apps/staging" 
        "gitops/apps/production"
        "gitops/infrastructure"
        "gitops/infrastructure/base"
        "gitops/infrastructure/staging"
        "gitops/infrastructure/production"
        "gitops/clusters"
        "gitops/clusters/staging"
        "gitops/clusters/production"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Missing required directory: $dir"
            errors=$((errors + 1))
        fi
    done
    
    # Check required files
    local required_files=(
        "gitops/infrastructure/base/kustomization.yaml"
        "gitops/infrastructure/base/namespaces.yaml"
        "gitops/infrastructure/base/operators.yaml"
        "gitops/infrastructure/base/observability.yaml"
        "gitops/apps/base/kustomization.yaml"
        "gitops/apps/base/airflow.yaml"
        "gitops/apps/base/mlflow.yaml"
        "gitops/apps/base/kafka-cluster.yaml"
        "gitops/apps/base/minio-tenant.yaml"
        "gitops/clusters/staging/infrastructure.yaml"
        "gitops/clusters/staging/applications.yaml"
        "gitops/clusters/production/infrastructure.yaml"
        "gitops/clusters/production/applications.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Missing required file: $file"
            errors=$((errors + 1))
        else
            validate_yaml_syntax "$file" || errors=$((errors + 1))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        log_info "GitOps structure validation passed"
    else
        log_error "GitOps structure validation failed with $errors errors"
    fi
    
    return $errors
}

# Validate Kubernetes connectivity
validate_kubernetes() {
    log_step "Validating Kubernetes connectivity..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        return 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        return 1
    fi
    
    log_info "Kubernetes connectivity validated"
    return 0
}

# Validate Flux prerequisites
validate_flux_prereqs() {
    log_step "Validating Flux prerequisites..."
    
    local errors=0
    
    # Check if Flux CLI is available
    if ! command -v flux &> /dev/null; then
        log_warning "Flux CLI not found. It will be installed during migration."
    else
        local flux_version
        flux_version=$(flux version --client --short 2>/dev/null || echo "unknown")
        log_info "Flux CLI version: $flux_version"
    fi
    
    # Check GitHub credentials
    if [[ -z "${GITHUB_USER:-}" ]]; then
        log_error "GITHUB_USER environment variable not set"
        errors=$((errors + 1))
    fi
    
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN environment variable not set"
        errors=$((errors + 1))
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        log_error "Helm not found. Please install Helm."
        errors=$((errors + 1))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_info "Flux prerequisites validated"
    else
        log_error "Flux prerequisites validation failed with $errors errors"
    fi
    
    return $errors
}

# Check for conflicting resources
validate_existing_resources() {
    log_step "Checking for existing Flux resources..."
    
    # Check if Flux is already installed
    if kubectl get namespace flux-system &> /dev/null; then
        log_warning "flux-system namespace already exists"
        
        if kubectl get deployment -n flux-system source-controller &> /dev/null; then
            log_warning "Flux appears to be already installed"
            log_info "Migration script will detect this and handle appropriately"
        fi
    fi
    
    # Check for existing operators
    local operators=(
        "strimzi-kafka-operator"
        "minio-operator"
        "spark-kubernetes-operator"
        "flink-kubernetes-operator"
    )
    
    for operator in "${operators[@]}"; do
        if kubectl get deployment "$operator" -n platform-operators &> /dev/null; then
            log_info "Found existing operator: $operator"
        fi
    done
    
    log_info "Existing resources check completed"
}

# Validate GitOps manifests with dry-run
validate_manifests() {
    log_step "Validating Kubernetes manifests with dry-run..."
    
    local errors=0
    
    # Find all YAML files in gitops directory
    while IFS= read -r -d '' file; do
        log_info "Validating $file..."
        
        if ! kubectl apply --dry-run=client -f "$file" &> /dev/null; then
            log_error "Manifest validation failed for $file"
            errors=$((errors + 1))
        fi
    done < <(find gitops -name "*.yaml" -print0 2>/dev/null)
    
    if [[ $errors -eq 0 ]]; then
        log_info "All manifests passed validation"
    else
        log_error "Manifest validation failed with $errors errors"
    fi
    
    return $errors
}

# Generate validation report
generate_report() {
    log_step "Generating validation report..."
    
    cat > validation-report.txt << EOF
GitOps Migration Validation Report
Generated: $(date)

Environment:
- Kubernetes: $(kubectl version --short --client 2>/dev/null || echo "Not available")
- Helm: $(helm version --short 2>/dev/null || echo "Not available")  
- Flux: $(flux version --client --short 2>/dev/null || echo "Not available")

GitHub Configuration:
- GITHUB_USER: ${GITHUB_USER:-"Not set"}
- GITHUB_TOKEN: $(if [[ -n "${GITHUB_TOKEN:-}" ]]; then echo "Set (hidden)"; else echo "Not set"; fi)
- GITHUB_REPO: ${GITHUB_REPO:-"mlops-helm-charts (default)"}

Validation Results:
$(if [[ -d gitops ]]; then echo "✅ GitOps structure created"; else echo "❌ GitOps structure missing"; fi)
$(if kubectl cluster-info &> /dev/null; then echo "✅ Kubernetes connectivity"; else echo "❌ Kubernetes connectivity failed"; fi)
$(if command -v helm &> /dev/null; then echo "✅ Helm available"; else echo "❌ Helm not found"; fi)

Next Steps:
1. Fix any validation errors listed above
2. Set required environment variables if missing
3. Run migration script: ./scripts/migrate-to-gitops.sh

EOF

    log_info "Validation report saved to validation-report.txt"
}

# Main validation function
run_validation() {
    log_info "Starting GitOps migration validation..."
    
    local total_errors=0
    
    # Run all validations
    validate_kubernetes || total_errors=$((total_errors + 1))
    validate_flux_prereqs || total_errors=$((total_errors + 1))
    validate_existing_resources
    
    # Only validate GitOps structure if it exists
    if [[ -d gitops ]]; then
        validate_gitops_structure || total_errors=$((total_errors + 1))
        validate_manifests || total_errors=$((total_errors + 1))
    else
        log_info "GitOps structure not found (will be created during migration)"
    fi
    
    # Generate report
    generate_report
    
    # Summary
    log_info ""
    if [[ $total_errors -eq 0 ]]; then
        log_info "✅ All validations passed! Ready for GitOps migration."
        log_info "Run: ./scripts/migrate-to-gitops.sh"
    else
        log_error "❌ Validation failed with $total_errors error(s)"
        log_error "Please fix the issues before running migration"
    fi
    
    return $total_errors
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

GitOps Migration Validation Script

Options:
    -h, --help      Display this help message
    --report-only   Generate report without validation

Environment Variables:
    GITHUB_USER     GitHub username
    GITHUB_TOKEN    GitHub personal access token
    GITHUB_REPO     GitHub repository name

Examples:
    $0                    # Run full validation
    $0 --report-only     # Generate report only

EOF
}

# Parse arguments
main() {
    local report_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            --report-only)
                report_only=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    if [[ "$report_only" == true ]]; then
        generate_report
        exit 0
    fi
    
    run_validation
}

# Run main function
main "$@"
