#!/usr/bin/env bash

# Exit on error, undefined variable, and pipe failures
set -euo pipefail

# Configuration variables
NAMESPACE="platform-operators"
STRIMZI_RELEASE="strimzi-kafka-operator"
MINIO_RELEASE="minio-operator"
SPARK_RELEASE="spark-operator"
FLINK_RELEASE="flink-operator"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if required commands exist
check_prerequisites() {
    local missing_tools=()
    
    for tool in helm kubectl; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools before running this script."
        exit 1
    fi
    
    # Check kubernetes connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    log_info "All prerequisites satisfied"
}

# Check if a Helm release is already installed
is_helm_release_installed() {
    local release_name=$1
    local namespace=$2
    helm list -n "$namespace" 2>/dev/null | grep -q "^${release_name}"
}



# Add Helm repositories
add_helm_repos() {
    log_info "Adding Helm repositories..."
    
    local repos=(
        "strimzi https://strimzi.io/charts/"
        "minio-operator https://operator.min.io/"
        "spark https://apache.github.io/spark-kubernetes-operator"
        "flink-operator https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.12.0/"
    )
    
    for repo in "${repos[@]}"; do
        read -r name url <<< "$repo"
        helm repo add "$name" "$url" --force-update 2>/dev/null || true
    done
    
    log_info "Updating Helm repositories..."
    helm repo update
}

# Install cert-manager (required for Flink Operator)
install_cert_manager() {
    if kubectl get namespace cert-manager &> /dev/null; then
        log_info "cert-manager is already installed. Skipping..."
        return
    fi
    
    log_info "Installing cert-manager (required for Flink Operator)..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
    
    # Wait for cert-manager to be ready
    log_info "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s
    kubectl wait --for=condition=ready pod -l app=cainjector -n cert-manager --timeout=300s  
    kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=300s
    
    log_info "cert-manager installed successfully"
}

# Install operator with retry logic
install_operator() {
    local name=$1
    local release=$2
    local chart=$3
    
    if is_helm_release_installed "$release" "$NAMESPACE"; then
        log_warning "$name is already installed. Skipping..."
        return
    fi
    
    log_info "Installing $name..."
    if helm install "$release" "$chart" --namespace "$NAMESPACE" --create-namespace --wait --timeout 10m; then
        log_info "$name installed successfully"
    else
        log_error "Failed to install $name"
        return 1
    fi
}

# Create namespace if it doesn't exist
create_namespace() {
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Namespace '$NAMESPACE' already exists"
    else
        log_info "Creating namespace '$NAMESPACE'..."
        kubectl create namespace "$NAMESPACE"
    fi
}

# Main setup function
setup_platform_operators_namespace() {
    log_info "Starting platform operators setup..."
    
    check_prerequisites
    add_helm_repos
    create_namespace
    # install_cert_manager # Will be installed by Ansible via Helm
    
    # Install operators
    install_operator "Strimzi Kafka Operator" "$STRIMZI_RELEASE" "strimzi/strimzi-kafka-operator"
    install_operator "MinIO Operator" "$MINIO_RELEASE" "minio-operator/operator"
    install_operator "Spark Operator" "$SPARK_RELEASE" "spark/spark-kubernetes-operator"
    install_operator "Flink Operator" "$FLINK_RELEASE" "flink-operator/flink-kubernetes-operator"
    
    log_info "Platform operators setup completed successfully!"
    
    # Display installed operators
    log_info "Installed operators in namespace '$NAMESPACE':"
    helm list -n "$NAMESPACE"
}

# Uninstall function for cleanup
uninstall_platform_operators() {
    log_warning "Uninstalling platform operators..."
    
    # Get all releases in the namespace
    local all_releases
    all_releases=$(helm list -n "$NAMESPACE" --short 2>/dev/null || true)
    
    if [ -z "$all_releases" ]; then
        log_info "No Helm releases found in namespace '$NAMESPACE'"
        return
    fi
    
    # List of expected release names (including alternative names)
    local releases=("$FLINK_RELEASE" "$SPARK_RELEASE" "$MINIO_RELEASE" "$STRIMZI_RELEASE" "operator")
    
    # Track what was actually uninstalled
    local uninstalled_count=0
    
    for release in "${releases[@]}"; do
        if is_helm_release_installed "$release" "$NAMESPACE"; then
            log_info "Uninstalling $release..."
            if helm uninstall "$release" -n "$NAMESPACE"; then
                log_info "Successfully uninstalled $release"
                uninstalled_count=$((uninstalled_count + 1))
            else
                log_error "Failed to uninstall $release"
            fi
        fi
    done
    
    # Check for any remaining releases that might be related to our operators
    local remaining_releases
    remaining_releases=$(helm list -n "$NAMESPACE" --short 2>/dev/null || true)
    
    if [ -n "$remaining_releases" ]; then
        log_warning "The following releases are still present in namespace '$NAMESPACE':"
        helm list -n "$NAMESPACE"
        log_info "You may want to manually review and remove them if they're related to the operators."
    fi
    
    if [ $uninstalled_count -gt 0 ]; then
        log_info "Successfully uninstalled $uninstalled_count operator(s)"
    else
        log_info "No platform operators were found to uninstall"
    fi
    
    # Optionally ask about cleaning up the namespace
    log_info "Note: The namespace '$NAMESPACE' has been left intact."
    log_info "To remove it manually, run: kubectl delete namespace $NAMESPACE"
}

# Display usage information
usage() {
    cat << EOF
Usage: $0 [OPTION]

Platform Operators Setup Script - Installs Kafka, MinIO, Spark, and Flink operators

Options:
    -h, --help      Display this help message
    -u, --uninstall Uninstall platform operators
    --clean         Uninstall platform operators and remove namespace
    -n, --namespace Set custom namespace (default: platform-operators)

Examples:
    $0                    # Install all operators
    $0 --uninstall        # Uninstall all operators
    $0 --clean            # Uninstall all operators and remove namespace
    $0 -n my-namespace    # Install in custom namespace

EOF
}

# Parse command line arguments
main() {
    local action="install"
    local clean_namespace=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -u|--uninstall)
                action="uninstall"
                shift
                ;;
            --clean)
                action="uninstall"
                clean_namespace=true
                shift
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Execute action
    case $action in
        install)
            setup_platform_operators_namespace
            ;;
        uninstall)
            uninstall_platform_operators
            if [ "$clean_namespace" = true ]; then
                log_info "Removing namespace '$NAMESPACE'..."
                if kubectl delete namespace "$NAMESPACE" 2>/dev/null; then
                    log_info "Namespace '$NAMESPACE' removed successfully"
                else
                    log_warning "Failed to remove namespace '$NAMESPACE' or it doesn't exist"
                fi
                
                # Ask if user wants to remove cert-manager as well
                log_info "cert-manager was installed as a dependency. To remove it manually, run:"
                log_info "kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml"
            fi
            ;;
    esac
}

# Run main function
main "$@"