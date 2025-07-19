#!/bin/bash

# Cleanup Unmanaged Kubernetes Resources
# This script removes Kubernetes resources that are not managed by Ansible
# Author: GitHub Copilot Assistant
# Version: 1.0

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}$1${NC}"
}

print_subheader() {
    echo -e "${BLUE}$1${NC}"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl could not be found. Please install kubectl first."
        exit 1
    fi
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_status "kubectl connectivity verified ✅"
}

# Function to clean up demo namespace and resources
cleanup_demo_namespace() {
    print_subheader "🧹 Cleaning up demo namespace and resources"
    
    # Check if mlops-demo namespace exists
    if kubectl get namespace mlops-demo &> /dev/null; then
        print_status "Found mlops-demo namespace, cleaning up..."
        
        # Get resource counts before cleanup
        local pod_count=$(kubectl get pods -n mlops-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
        local job_count=$(kubectl get jobs -n mlops-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
        local deployment_count=$(kubectl get deployments -n mlops-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
        local configmap_count=$(kubectl get configmaps -n mlops-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
        
        print_status "Resources to clean: ${pod_count} pods, ${job_count} jobs, ${deployment_count} deployments, ${configmap_count} configmaps"
        
        # Delete the entire namespace (this will delete all resources within it)
        kubectl delete namespace mlops-demo --timeout=300s || {
            print_warning "Failed to delete mlops-demo namespace cleanly, forcing deletion..."
            kubectl patch namespace mlops-demo -p '{"metadata":{"finalizers":[]}}' --type=merge || true
        }
        
        print_status "✅ Demo namespace cleaned up"
    else
        print_status "mlops-demo namespace not found, skipping"
    fi
}

# Function to clean up completed jobs across all namespaces
cleanup_completed_jobs() {
    print_subheader "🧹 Cleaning up completed jobs"
    
    # Get all completed jobs
    local completed_jobs=$(kubectl get jobs --all-namespaces --field-selector=status.successful=1 --no-headers 2>/dev/null | awk '{print $1 "/" $2}' || echo "")
    
    if [[ -n "$completed_jobs" ]]; then
        print_status "Found completed jobs to clean up:"
        echo "$completed_jobs"
        
        while IFS= read -r job; do
            if [[ -n "$job" ]]; then
                local namespace=$(echo "$job" | cut -d'/' -f1)
                local job_name=$(echo "$job" | cut -d'/' -f2)
                
                print_status "Deleting completed job: $namespace/$job_name"
                kubectl delete job "$job_name" -n "$namespace" --timeout=60s || {
                    print_warning "Failed to delete job $namespace/$job_name"
                }
            fi
        done <<< "$completed_jobs"
        
        print_status "✅ Completed jobs cleaned up"
    else
        print_status "No completed jobs found"
    fi
}

# Function to clean up failed jobs
cleanup_failed_jobs() {
    print_subheader "🧹 Cleaning up failed jobs"
    
    # Get all failed jobs
    local failed_jobs=$(kubectl get jobs --all-namespaces --field-selector=status.failed=1 --no-headers 2>/dev/null | awk '{print $1 "/" $2}' || echo "")
    
    if [[ -n "$failed_jobs" ]]; then
        print_status "Found failed jobs to clean up:"
        echo "$failed_jobs"
        
        while IFS= read -r job; do
            if [[ -n "$job" ]]; then
                local namespace=$(echo "$job" | cut -d'/' -f1)
                local job_name=$(echo "$job" | cut -d'/' -f2)
                
                print_status "Deleting failed job: $namespace/$job_name"
                kubectl delete job "$job_name" -n "$namespace" --timeout=60s || {
                    print_warning "Failed to delete job $namespace/$job_name"
                }
            fi
        done <<< "$failed_jobs"
        
        print_status "✅ Failed jobs cleaned up"
    else
        print_status "No failed jobs found"
    fi
}

# Function to clean up dangling pods (Completed, Failed, or Error state)
cleanup_dangling_pods() {
    print_subheader "🧹 Cleaning up dangling pods"
    
    # Clean up completed pods
    local completed_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Succeeded --no-headers 2>/dev/null | awk '{print $1 "/" $2}' || echo "")
    
    if [[ -n "$completed_pods" ]]; then
        print_status "Found completed pods to clean up:"
        while IFS= read -r pod; do
            if [[ -n "$pod" ]]; then
                local namespace=$(echo "$pod" | cut -d'/' -f1)
                local pod_name=$(echo "$pod" | cut -d'/' -f2)
                
                print_status "Deleting completed pod: $namespace/$pod_name"
                kubectl delete pod "$pod_name" -n "$namespace" --timeout=60s || {
                    print_warning "Failed to delete pod $namespace/$pod_name"
                }
            fi
        done <<< "$completed_pods"
    fi
    
    # Clean up failed pods
    local failed_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null | awk '{print $1 "/" $2}' || echo "")
    
    if [[ -n "$failed_pods" ]]; then
        print_status "Found failed pods to clean up:"
        while IFS= read -r pod; do
            if [[ -n "$pod" ]]; then
                local namespace=$(echo "$pod" | cut -d'/' -f1)
                local pod_name=$(echo "$pod" | cut -d'/' -f2)
                
                print_status "Deleting failed pod: $namespace/$pod_name"
                kubectl delete pod "$pod_name" -n "$namespace" --timeout=60s || {
                    print_warning "Failed to delete pod $namespace/$pod_name"
                }
            fi
        done <<< "$failed_pods"
    fi
    
    print_status "✅ Dangling pods cleaned up"
}

# Function to clean up temporary configmaps and secrets
cleanup_temporary_resources() {
    print_subheader "🧹 Cleaning up temporary resources"
    
    # Define patterns for temporary resources that are safe to delete
    local temp_patterns=("demo-scripts" "temp-" "test-" "*-demo-*")
    
    for pattern in "${temp_patterns[@]}"; do
        # Clean up configmaps matching pattern
        local temp_configmaps=$(kubectl get configmaps --all-namespaces --no-headers 2>/dev/null | grep -E "$pattern" | awk '{print $1 "/" $2}' || echo "")
        
        if [[ -n "$temp_configmaps" ]]; then
            print_status "Found temporary configmaps matching pattern '$pattern':"
            while IFS= read -r cm; do
                if [[ -n "$cm" ]]; then
                    local namespace=$(echo "$cm" | cut -d'/' -f1)
                    local cm_name=$(echo "$cm" | cut -d'/' -f2)
                    
                    # Skip system configmaps
                    if [[ "$cm_name" != "kube-root-ca.crt" && "$namespace" != "kube-system" ]]; then
                        print_status "Deleting temporary configmap: $namespace/$cm_name"
                        kubectl delete configmap "$cm_name" -n "$namespace" --timeout=60s || {
                            print_warning "Failed to delete configmap $namespace/$cm_name"
                        }
                    fi
                fi
            done <<< "$temp_configmaps"
        fi
    done
    
    print_status "✅ Temporary resources cleaned up"
}

# Function to clean up orphaned persistent volume claims
cleanup_orphaned_pvcs() {
    print_subheader "🧹 Checking for orphaned PVCs"
    
    # Get PVCs that are not bound or are from deleted namespaces
    local orphaned_pvcs=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | awk '$4 != "Bound" {print $1 "/" $2}' || echo "")
    
    if [[ -n "$orphaned_pvcs" ]]; then
        print_warning "Found potentially orphaned PVCs (not bound):"
        echo "$orphaned_pvcs"
        print_warning "Manual review recommended before deletion. These might be waiting for pods to start."
    else
        print_status "No obviously orphaned PVCs found"
    fi
}

# Function to show current resource usage
show_resource_summary() {
    print_subheader "📊 Current Resource Summary"
    
    echo "Namespaces:"
    kubectl get namespaces --no-headers | grep -v -E "(kube-system|kube-public|kube-node-lease|default)" | wc -l | xargs echo "  MLOps-related namespaces:"
    
    echo "Pods by namespace:"
    kubectl get pods --all-namespaces --no-headers | awk '{print $1}' | sort | uniq -c | grep -v -E "(kube-system|kube-public)" || echo "  No pods found"
    
    echo "Jobs:"
    kubectl get jobs --all-namespaces --no-headers | wc -l | xargs echo "  Total jobs:"
    
    echo "PVCs:"
    kubectl get pvc --all-namespaces --no-headers | wc -l | xargs echo "  Total PVCs:"
}

# Function to show detailed cleanup plan
show_cleanup_plan() {
    print_header "🔍 Cleanup Plan Analysis"
    print_header "======================="
    
    # Demo namespace analysis
    if kubectl get namespace mlops-demo &> /dev/null; then
        print_status "Demo namespace 'mlops-demo' found:"
        echo "  Pods: $(kubectl get pods -n mlops-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')"
        echo "  Jobs: $(kubectl get jobs -n mlops-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')"
        echo "  Deployments: $(kubectl get deployments -n mlops-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')"
        echo "  ConfigMaps: $(kubectl get configmaps -n mlops-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')"
        echo "  Services: $(kubectl get services -n mlops-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    fi
    
    # Completed jobs analysis
    local completed_jobs_count=$(kubectl get jobs --all-namespaces --field-selector=status.successful=1 --no-headers 2>/dev/null | wc -l | tr -d ' ')
    print_status "Completed jobs across all namespaces: $completed_jobs_count"
    
    # Failed jobs analysis
    local failed_jobs_count=$(kubectl get jobs --all-namespaces --field-selector=status.failed=1 --no-headers 2>/dev/null | wc -l | tr -d ' ')
    print_status "Failed jobs across all namespaces: $failed_jobs_count"
    
    # Dangling pods analysis
    local completed_pods_count=$(kubectl get pods --all-namespaces --field-selector=status.phase=Succeeded --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local failed_pods_count=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l | tr -d ' ')
    print_status "Completed pods: $completed_pods_count, Failed pods: $failed_pods_count"
}

# Main cleanup function
main_cleanup() {
    local dry_run="${1:-false}"
    local interactive="${2:-true}"
    
    print_header "🧹 MLOps Platform Unmanaged Resource Cleanup"
    print_header "============================================"
    
    if [[ "$dry_run" == "true" ]]; then
        print_warning "DRY RUN MODE - No resources will be deleted"
        echo ""
    fi
    
    # Show what will be cleaned up
    show_cleanup_plan
    echo ""
    
    if [[ "$interactive" == "true" && "$dry_run" != "true" ]]; then
        print_warning "This will delete unmanaged Kubernetes resources!"
        print_warning "This includes:"
        print_warning "  - Demo namespace and all its resources"
        print_warning "  - Completed and failed jobs"
        print_warning "  - Dangling pods"
        print_warning "  - Temporary configmaps and secrets"
        echo ""
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo ""
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Cleanup cancelled"
            exit 0
        fi
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        print_status "Would perform the following cleanup operations:"
        print_status "  1. Delete mlops-demo namespace (if exists)"
        print_status "  2. Clean up completed jobs"
        print_status "  3. Clean up failed jobs"
        print_status "  4. Clean up dangling pods"
        print_status "  5. Clean up temporary resources"
        print_status "  6. Check for orphaned PVCs"
        return 0
    fi
    
    # Perform cleanup operations
    cleanup_demo_namespace
    cleanup_completed_jobs
    cleanup_failed_jobs
    cleanup_dangling_pods
    cleanup_temporary_resources
    cleanup_orphaned_pvcs
    
    echo ""
    print_status "✅ Cleanup completed successfully!"
    echo ""
    
    # Show final resource summary
    show_resource_summary
}

# Function to show help
show_help() {
    cat << EOF
${CYAN}MLOps Platform Unmanaged Resource Cleanup${NC}

${BLUE}DESCRIPTION:${NC}
    Cleans up Kubernetes resources that are not managed by Ansible, including:
    - Demo namespaces and temporary resources
    - Completed and failed jobs
    - Dangling pods
    - Temporary configmaps and secrets

${BLUE}USAGE:${NC}
    $0 [OPTIONS]

${BLUE}OPTIONS:${NC}
    --dry-run       Show what would be cleaned up without actually doing it
    --non-interactive  Skip confirmation prompts (use with caution)
    --help          Show this help message

${BLUE}EXAMPLES:${NC}
    $0                      # Interactive cleanup with confirmation
    $0 --dry-run           # See what would be cleaned up
    $0 --non-interactive   # Clean up without prompts (dangerous)
EOF
}

# Parse command line arguments
main() {
    local dry_run="false"
    local interactive="true"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run="true"
                shift
                ;;
            --non-interactive)
                interactive="false"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_kubectl
    
    # Run main cleanup
    main_cleanup "$dry_run" "$interactive"
}

# Execute main function with all arguments
main "$@"
