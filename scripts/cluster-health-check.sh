#!/bin/bash
# MLOps Platform - Cluster Health Check and Cleanup Script
# Identifies and optionally removes orphaned resources not managed by Ansible

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check cluster connectivity
check_cluster() {
    print_status "Checking Kubernetes cluster connectivity..."
    if ! kubectl cluster-info &>/dev/null; then
        print_error "Cannot connect to Kubernetes cluster!"
        exit 1
    fi
    print_success "Cluster connectivity verified"
}

# Function to check for orphaned namespaces
check_orphaned_namespaces() {
    print_status "Checking for orphaned namespaces..."
    
    # Expected namespaces managed by Ansible
    MANAGED_NAMESPACES=(
        "kube-system"
        "kube-public" 
        "kube-node-lease"
        "default"
        "cert-manager"
        "platform-operators"
        "data-plane"
        "orchestration"
        "ml-lifecycle"
        "processing-jobs"
        "observability"
    )
    
    # Get all namespaces
    ALL_NAMESPACES=$(kubectl get namespaces -o name | cut -d'/' -f2)
    
    ORPHANED_NAMESPACES=()
    for ns in $ALL_NAMESPACES; do
        if [[ ! " ${MANAGED_NAMESPACES[@]} " =~ " ${ns} " ]]; then
            # Check if namespace is empty
            RESOURCE_COUNT=$(kubectl get all -n "$ns" 2>/dev/null | wc -l)
            if [ "$RESOURCE_COUNT" -le 1 ]; then
                ORPHANED_NAMESPACES+=("$ns")
            else
                print_warning "Namespace '$ns' contains resources and may need manual review"
            fi
        fi
    done
    
    if [ ${#ORPHANED_NAMESPACES[@]} -eq 0 ]; then
        print_success "No orphaned namespaces found"
    else
        print_warning "Found orphaned namespaces: ${ORPHANED_NAMESPACES[*]}"
        return 1
    fi
}

# Function to check for orphaned PVCs
check_orphaned_pvcs() {
    print_status "Checking for orphaned PVCs..."
    
    # Get PVCs not in managed namespaces
    ORPHANED_PVCS=$(kubectl get pvc --all-namespaces --no-headers | grep -v -E "(observability|data-plane|ml-lifecycle|orchestration)" | grep -v "NAME" || true)
    
    if [ -z "$ORPHANED_PVCS" ]; then
        print_success "No orphaned PVCs found"
    else
        print_warning "Found orphaned PVCs:"
        echo "$ORPHANED_PVCS"
        return 1
    fi
}

# Function to check for failed resources
check_failed_resources() {
    print_status "Checking for failed resources..."
    
    # Check for failed pods
    FAILED_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null || true)
    if [ -n "$FAILED_PODS" ]; then
        print_warning "Found failed pods:"
        echo "$FAILED_PODS"
    else
        print_success "No failed pods found"
    fi
    
    # Check for error state resources
    ERROR_RESOURCES=$(kubectl get all --all-namespaces 2>/dev/null | grep -E "(ERROR|Pending|CrashLoopBackOff|ImagePullBackOff)" || true)
    if [ -n "$ERROR_RESOURCES" ]; then
        print_warning "Found resources in error state:"
        echo "$ERROR_RESOURCES"
    else
        print_success "No resources in error state found"
    fi
}

# Function to check for orphaned CRDs
check_orphaned_crds() {
    print_status "Checking for orphaned CRDs..."
    
    ORPHANED_CRDS=$(kubectl get crd --no-headers 2>/dev/null | grep -v -E "(cert-manager|strimzi|minio|spark|flink|monitoring.coreos.com)" | awk '{print $1}' || true)
    
    if [ -z "$ORPHANED_CRDS" ]; then
        print_success "No orphaned CRDs found"
    else
        print_warning "Found orphaned CRDs:"
        echo "$ORPHANED_CRDS"
        return 1
    fi
}

# Function to check Helm releases
check_helm_releases() {
    print_status "Checking Helm releases..."
    
    EXPECTED_RELEASES=(
        "cert-manager"
        "strimzi-kafka-operator"
        "minio-operator"
        "spark-operator"
        "flink-operator"
        "kube-prometheus-stack"
    )
    
    ALL_RELEASES=$(helm list --all-namespaces --short 2>/dev/null || true)
    
    ORPHANED_RELEASES=()
    for release in $ALL_RELEASES; do
        if [[ ! " ${EXPECTED_RELEASES[@]} " =~ " ${release} " ]]; then
            ORPHANED_RELEASES+=("$release")
        fi
    done
    
    if [ ${#ORPHANED_RELEASES[@]} -eq 0 ]; then
        print_success "All Helm releases are managed by Ansible"
    else
        print_warning "Found unmanaged Helm releases: ${ORPHANED_RELEASES[*]}"
        return 1
    fi
}

# Function to perform cleanup
cleanup_orphaned_resources() {
    print_status "Starting cleanup of orphaned resources..."
    
    local cleanup_performed=false
    
    # Clean up orphaned namespaces
    if check_orphaned_namespaces 2>/dev/null; then
        : # No orphaned namespaces
    else
        if [ ${#ORPHANED_NAMESPACES[@]} -gt 0 ]; then
            print_status "Removing orphaned namespaces..."
            for ns in "${ORPHANED_NAMESPACES[@]}"; do
                kubectl delete namespace "$ns" --ignore-not-found=true
                print_success "Removed namespace: $ns"
                cleanup_performed=true
            done
        fi
    fi
    
    # Clean up orphaned PVCs in default namespace
    ORPHANED_DEFAULT_PVCS=$(kubectl get pvc -n default --no-headers 2>/dev/null | awk '{print $1}' || true)
    if [ -n "$ORPHANED_DEFAULT_PVCS" ]; then
        print_status "Removing orphaned PVCs from default namespace..."
        for pvc in $ORPHANED_DEFAULT_PVCS; do
            kubectl delete pvc "$pvc" -n default --ignore-not-found=true
            print_success "Removed PVC: $pvc"
            cleanup_performed=true
        done
    fi
    
    # Clean up completed jobs older than 1 hour
    print_status "Cleaning up old completed jobs..."
    kubectl delete jobs --field-selector=status.conditions[0].type=Complete --all-namespaces --ignore-not-found=true 2>/dev/null || true
    
    if [ "$cleanup_performed" = true ]; then
        print_success "Cleanup completed successfully"
    else
        print_success "No cleanup needed - cluster is clean"
    fi
}

# Function to display help
show_help() {
    echo "MLOps Platform - Cluster Health Check and Cleanup Script"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  check     Perform health check only (default)"
    echo "  cleanup   Perform health check and cleanup orphaned resources"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 # Run health check"
    echo "  $0 check           # Run health check"
    echo "  $0 cleanup         # Run health check and cleanup"
}

# Main execution
main() {
    local action="${1:-check}"
    
    case "$action" in
        "check")
            echo "🔍 MLOps Cluster Health Check"
            echo "=============================="
            check_cluster
            
            local issues_found=false
            
            check_orphaned_namespaces || issues_found=true
            check_orphaned_pvcs || issues_found=true
            check_failed_resources || issues_found=true
            check_orphaned_crds || issues_found=true
            check_helm_releases || issues_found=true
            
            echo ""
            if [ "$issues_found" = true ]; then
                print_warning "Health check completed with warnings. Run '$0 cleanup' to fix issues."
                exit 1
            else
                print_success "✅ Cluster health check passed - everything looks good!"
            fi
            ;;
        "cleanup")
            echo "🧹 MLOps Cluster Cleanup"
            echo "========================"
            check_cluster
            cleanup_orphaned_resources
            echo ""
            print_success "✅ Cluster cleanup completed!"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown option: $action"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
