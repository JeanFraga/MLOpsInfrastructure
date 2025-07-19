#!/bin/bash

# GitOps Bootstrap Script for MLOps Platform using Flux CD
# This script installs Flux CD controllers and bootstraps the MLOps platform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_USER="JeanFraga"
GITHUB_REPO="MLOpsInfrastructure"
GITHUB_BRANCH="main"
FLUX_NAMESPACE="flux-system"

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

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check kubectl connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    # Check Kubernetes version
    K8S_VERSION=$(kubectl version --output=json | jq -r '.serverVersion.gitVersion' | sed 's/v//')
    print_status "Kubernetes version: $K8S_VERSION"
    
    print_status "All prerequisites met!"
}

# Install Flux CD using the latest installation method
install_flux() {
    print_header "Installing Flux CD Controllers"
    
    # Check if Flux is already installed
    if kubectl get namespace $FLUX_NAMESPACE &> /dev/null; then
        print_warning "Flux namespace already exists. Checking if Flux is running..."
        if kubectl get deployment -n $FLUX_NAMESPACE source-controller &> /dev/null; then
            print_status "Flux is already installed and running"
            return 0
        fi
    fi
    
    print_status "Installing Flux components using the latest release manifests..."
    
    # Install Flux using kubectl and the latest manifests
    kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
    
    # Wait for Flux to be ready
    print_status "Waiting for Flux controllers to be ready..."
    kubectl wait --for=condition=ready pod -l app=source-controller -n $FLUX_NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app=kustomize-controller -n $FLUX_NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app=helm-controller -n $FLUX_NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app=notification-controller -n $FLUX_NAMESPACE --timeout=300s
    
    print_status "Flux CD installed successfully!"
}

# Apply Day 0 resources idempotently
apply_day0_resources() {
    print_header "Applying Day 0 Resources (Namespaces & RBAC)"
    
    print_status "Creating MLOps platform namespaces..."
    kubectl apply -f gitops/base/namespaces.yaml
    
    print_status "Setting up RBAC..."
    kubectl apply -f gitops/base/rbac.yaml
    
    print_status "Day 0 resources applied successfully!"
}

# Bootstrap GitOps repository
bootstrap_gitops() {
    print_header "Bootstrapping GitOps Repository"
    
    # Create the GitRepository source
    print_status "Creating GitRepository source..."
    cat <<EOF | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: mlops-infrastructure
  namespace: $FLUX_NAMESPACE
spec:
  interval: 1m
  ref:
    branch: $GITHUB_BRANCH
  url: https://github.com/$GITHUB_USER/$GITHUB_REPO
EOF

    # Create the base platform Kustomization
    print_status "Creating base platform Kustomization..."
    cat <<EOF | kubectl apply -f -
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: mlops-platform-base
  namespace: $FLUX_NAMESPACE
spec:
  interval: 1m
  path: "./gitops/base"
  prune: true
  sourceRef:
    kind: GitRepository
    name: mlops-infrastructure
  timeout: 5m
  wait: true
  healthChecks:
    - apiVersion: v1
      kind: Namespace
      name: platform-operators
    - apiVersion: v1
      kind: Namespace
      name: data-plane
    - apiVersion: v1
      kind: Namespace
      name: orchestration
    - apiVersion: v1
      kind: Namespace
      name: ml-lifecycle
    - apiVersion: v1
      kind: Namespace
      name: processing-jobs
    - apiVersion: v1
      kind: Namespace
      name: observability
EOF

    # Create the operators Kustomization
    print_status "Creating operators Kustomization..."
    cat <<EOF | kubectl apply -f -
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: mlops-operators
  namespace: $FLUX_NAMESPACE
spec:
  interval: 5m
  path: "./gitops/components"
  prune: true
  sourceRef:
    kind: GitRepository
    name: mlops-infrastructure
  timeout: 10m
  wait: true
  dependsOn:
    - name: mlops-platform-base
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: strimzi-cluster-operator
      namespace: platform-operators
    - apiVersion: apps/v1
      kind: Deployment
      name: minio-operator
      namespace: platform-operators
    - apiVersion: apps/v1
      kind: Deployment
      name: spark-operator
      namespace: platform-operators
EOF

    print_status "GitOps repository bootstrapped!"
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Deployment"
    
    print_status "Checking Flux components..."
    kubectl get pods -n $FLUX_NAMESPACE
    
    print_status "Checking GitRepository sync status..."
    kubectl get gitrepository -n $FLUX_NAMESPACE mlops-infrastructure -o yaml | grep -A 5 "conditions:"
    
    print_status "Checking Kustomization status..."
    kubectl get kustomization -n $FLUX_NAMESPACE
    
    print_status "Checking MLOps namespaces..."
    kubectl get namespaces | grep -E "(platform-operators|data-plane|orchestration|ml-lifecycle|processing-jobs|observability)" || true
    
    print_status "Checking operator deployments..."
    kubectl get deployments -n platform-operators || true
}

# Monitor sync status
monitor_sync() {
    print_header "Monitoring GitOps Sync"
    
    print_status "Watching GitRepository reconciliation for 30 seconds..."
    timeout 30s kubectl get gitrepository -n $FLUX_NAMESPACE mlops-infrastructure -w || true
    
    print_status "Current sync status:"
    kubectl get gitrepository -n $FLUX_NAMESPACE
    kubectl get kustomization -n $FLUX_NAMESPACE
}

# Test idempotency
test_idempotency() {
    print_header "Testing Idempotency"
    
    print_status "Re-applying all configurations to test idempotency..."
    
    # Re-apply Day 0 resources
    kubectl apply -f gitops/base/namespaces.yaml
    kubectl apply -f gitops/base/rbac.yaml
    
    # Re-apply GitOps configurations
    bootstrap_gitops
    
    print_status "Idempotency test completed - no errors should have occurred"
}

# Show next steps
show_next_steps() {
    print_header "Next Steps"
    
    print_status "Your GitOps platform is now set up! Here's what you can do:"
    echo ""
    echo "1. 📊 Monitor the deployment:"
    echo "   kubectl get kustomization -n $FLUX_NAMESPACE -w"
    echo "   kubectl get pods -A"
    echo ""
    echo "2. 🔍 Check GitOps sync status:"
    echo "   kubectl describe gitrepository mlops-infrastructure -n $FLUX_NAMESPACE"
    echo "   kubectl describe kustomization mlops-platform-base -n $FLUX_NAMESPACE"
    echo ""
    echo "3. 📝 Make changes to the platform:"
    echo "   - Edit files in gitops/ directory"
    echo "   - Commit and push to GitHub"
    echo "   - Changes will be automatically applied within 1 minute"
    echo ""
    echo "4. 🚀 Deploy MLOps applications:"
    echo "   - Kafka cluster will be deployed by the operators"
    echo "   - MinIO tenant will be deployed by the operators"
    echo "   - Add more resources to gitops/components/ as needed"
    echo ""
    echo "5. 🛠️ Debug issues:"
    echo "   kubectl logs -n $FLUX_NAMESPACE -l app=kustomize-controller"
    echo "   kubectl logs -n $FLUX_NAMESPACE -l app=source-controller"
}

# Cleanup function
cleanup_if_needed() {
    print_header "Cleanup Information"
    
    print_status "To clean up everything, run this script with 'cleanup' argument:"
    echo "  $0 cleanup"
    echo ""
    print_status "Manual cleanup commands:"
    echo "  kubectl delete kustomization --all -n $FLUX_NAMESPACE"
    echo "  kubectl delete gitrepository --all -n $FLUX_NAMESPACE"
    echo "  kubectl delete -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml"
    echo "  kubectl delete namespace platform-operators data-plane orchestration ml-lifecycle processing-jobs observability"
}

# Main function
main() {
    print_header "MLOps Platform GitOps Bootstrap with Flux CD"
    
    check_prerequisites
    install_flux
    apply_day0_resources
    bootstrap_gitops
    
    print_status "Waiting for initial reconciliation..."
    sleep 15
    
    verify_deployment
    monitor_sync
    test_idempotency
    show_next_steps
    cleanup_if_needed
    
    print_header "Bootstrap Complete!"
    print_status "Your MLOps platform is now managed by GitOps!"
    print_status "🚀 Flux CD is running as containers in your Kubernetes cluster"
    print_status "🔄 Any commits to the repository will automatically deploy changes"
    print_status "📊 Monitor: kubectl get kustomization -n $FLUX_NAMESPACE -w"
}

# Handle script arguments
case "${1:-}" in
    "cleanup")
        print_header "Cleaning up GitOps deployment"
        kubectl delete kustomization --all -n $FLUX_NAMESPACE 2>/dev/null || true
        kubectl delete gitrepository --all -n $FLUX_NAMESPACE 2>/dev/null || true
        kubectl delete -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml 2>/dev/null || true
        kubectl delete namespace platform-operators data-plane orchestration ml-lifecycle processing-jobs observability 2>/dev/null || true
        print_status "Cleanup complete!"
        ;;
    "status")
        print_header "GitOps Status"
        kubectl get gitrepository -n $FLUX_NAMESPACE 2>/dev/null || echo "No GitRepositories found"
        kubectl get kustomization -n $FLUX_NAMESPACE 2>/dev/null || echo "No Kustomizations found"
        kubectl get namespaces | grep -E "(platform-operators|data-plane|orchestration|ml-lifecycle|processing-jobs|observability)" || echo "No MLOps namespaces found"
        ;;
    "logs")
        print_header "Flux Logs"
        echo "Source Controller logs:"
        kubectl logs -n $FLUX_NAMESPACE -l app=source-controller --tail=20
        echo "Kustomize Controller logs:"
        kubectl logs -n $FLUX_NAMESPACE -l app=kustomize-controller --tail=20
        ;;
    *)
        main "$@"
        ;;
esac
