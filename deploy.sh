#!/bin/bash

# MLOps Platform Deployment Script
# GitOps-based deployment using Flux CD
# For initial setup or legacy deployment, see scripts/ directory
# Author: GitHub Copilot Assistant
# Version: 2.0 (GitOps)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if GitOps structure exists
check_gitops_structure() {
    if [[ ! -d "gitops" ]]; then
        print_error "GitOps structure not found!"
        print_status "This platform now uses GitOps with Flux CD."
        print_status "Please run the migration script first:"
        print_status "  ./scripts/migrate-to-gitops.sh"
        exit 1
    fi
}

# Display GitOps deployment banner
show_gitops_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                   MLOps Platform GitOps                     ║
║                  Powered by Flux CD                         ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${PURPLE}🚀 GitOps-based MLOps Platform Deployment${NC}"
    echo -e "${BLUE}📋 Platform Components:${NC}"
    echo "   • Infrastructure: Operators, Observability, Security"
    echo "   • Applications: Airflow, MLflow, Kafka, MinIO"
    echo "   • GitOps: Automated deployment and management"
    echo ""
}

# Check prerequisites for GitOps
check_gitops_prerequisites() {
    print_step "Checking GitOps prerequisites..."
    
    local missing_tools=()
    
    for tool in kubectl flux helm git; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Please install the missing tools:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                kubectl) echo "  • kubectl: https://kubernetes.io/docs/tasks/tools/" ;;
                flux) echo "  • flux: curl -s https://fluxcd.io/install.sh | sudo bash" ;;
                helm) echo "  • helm: https://helm.sh/docs/intro/install/" ;;
                git) echo "  • git: https://git-scm.com/downloads" ;;
            esac
        done
        exit 1
    fi
    
    # Check Kubernetes connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_status "Please check your kubeconfig and cluster connectivity"
        exit 1
    fi
    
    # Check GitHub credentials
    if [[ -z "${GITHUB_USER:-}" ]] || [[ -z "${GITHUB_TOKEN:-}" ]]; then
        print_warning "GitHub credentials not set"
        print_status "For GitOps bootstrap, set:"
        print_status "  export GITHUB_USER=your-username"
        print_status "  export GITHUB_TOKEN=your-token"
    fi
    
    print_status "Prerequisites check completed"
}

# Display deployment status
show_deployment_status() {
    print_step "Checking Flux deployment status..."
    
    if ! kubectl get namespace flux-system &> /dev/null; then
        print_warning "Flux is not installed yet"
        print_status "Run migration script to bootstrap Flux:"
        print_status "  ./scripts/migrate-to-gitops.sh"
        return 1
    fi
    
    print_status "Flux system status:"
    flux get sources git
    echo ""
    
    print_status "Infrastructure status:"
    flux get kustomizations infrastructure || print_warning "Infrastructure not deployed yet"
    echo ""
    
    print_status "Applications status:"
    flux get kustomizations applications || print_warning "Applications not deployed yet"
    echo ""
    
    print_status "HelmReleases status:"
    flux get helmreleases -A
}

# Quick access to services
show_service_access() {
    print_step "Service Access Information:"
    
    echo -e "${CYAN}🔧 Management Interfaces:${NC}"
    echo "  • Grafana (Monitoring):     kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80"
    echo "  • Airflow (Orchestration):  kubectl port-forward -n orchestration svc/airflow-webserver 8080:8080"
    echo "  • MLflow (ML Lifecycle):    kubectl port-forward -n ml-lifecycle svc/mlflow 5000:5000"
    echo ""
    
    echo -e "${CYAN}📊 Data Services:${NC}"
    echo "  • MinIO Console:            kubectl port-forward -n data-plane svc/mlops-tenant-console 9001:9001"
    echo "  • Kafka (Internal):         mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092"
    echo ""
    
    echo -e "${CYAN}🔍 GitOps Monitoring:${NC}"
    echo "  • Flux Status:              flux get sources git"
    echo "  • Kustomizations:           flux get kustomizations"
    echo "  • HelmReleases:             flux get helmreleases -A"
    echo "  • Logs:                     flux logs --level=error --all-namespaces"
}

# GitOps management commands
gitops_management() {
    local action="${1:-status}"
    
    case $action in
        status)
            show_deployment_status
            ;;
        reconcile)
            print_step "Forcing Flux reconciliation..."
            flux reconcile source git flux-system
            flux reconcile kustomization infrastructure
            flux reconcile kustomization applications
            print_status "Reconciliation triggered"
            ;;
        logs)
            print_step "Showing Flux logs..."
            flux logs --level=error --all-namespaces --tail=50
            ;;
        suspend)
            print_step "Suspending GitOps reconciliation..."
            flux suspend kustomization infrastructure
            flux suspend kustomization applications
            print_warning "GitOps reconciliation suspended"
            ;;
        resume)
            print_step "Resuming GitOps reconciliation..."
            flux resume kustomization infrastructure
            flux resume kustomization applications
            print_status "GitOps reconciliation resumed"
            ;;
        *)
            print_error "Unknown GitOps action: $action"
            print_status "Available actions: status, reconcile, logs, suspend, resume"
            exit 1
            ;;
    esac
}

# Legacy support
run_legacy_deployment() {
    print_warning "Legacy deployment mode requested"
    print_status "This will use the old Ansible-based deployment"
    print_status "Consider migrating to GitOps for better automation"
    
    if [[ -f "${SCRIPT_DIR}/infrastructure/ansible-playbook.yml" ]]; then
        print_step "Running legacy Ansible deployment..."
        cd "${SCRIPT_DIR}"
        ansible-playbook infrastructure/ansible-playbook.yml "$@"
    else
        print_error "Legacy Ansible playbook not found"
        exit 1
    fi
}

# Display usage information
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

GitOps-based MLOps Platform Deployment

Commands:
    deploy              Deploy platform using GitOps (default)
    status              Show deployment status
    reconcile           Force Flux reconciliation
    logs                Show Flux logs
    suspend             Suspend GitOps reconciliation
    resume              Resume GitOps reconciliation
    migrate             Run GitOps migration
    validate            Validate GitOps structure
    legacy              Use legacy Ansible deployment
    services            Show service access information
    help                Show this help message

Options:
    --environment ENV   Target environment (staging/production)
    --dry-run          Show what would be done
    --force            Force operation without confirmation

Examples:
    $0                          # Show deployment status
    $0 deploy                   # Deploy platform (GitOps)
    $0 reconcile               # Force reconciliation
    $0 migrate                 # Migrate to GitOps
    $0 legacy                  # Use legacy deployment
    $0 services               # Show service access info

Environment Variables:
    GITHUB_USER       GitHub username for GitOps bootstrap
    GITHUB_TOKEN      GitHub token for GitOps bootstrap
    CLUSTER_NAME      Target cluster name (default: local-cluster)

EOF
}

# Main function
main() {
    local command="${1:-status}"
    shift || true
    
    case $command in
        deploy)
            show_gitops_banner
            check_gitops_structure
            check_gitops_prerequisites
            show_deployment_status
            show_service_access
            ;;
        status)
            show_gitops_banner
            check_gitops_structure
            show_deployment_status
            ;;
        reconcile|logs|suspend|resume)
            gitops_management "$command"
            ;;
        migrate)
            print_step "Running GitOps migration..."
            exec "${SCRIPTS_DIR}/migrate-to-gitops.sh" "$@"
            ;;
        validate)
            print_step "Validating GitOps structure..."
            exec "${SCRIPTS_DIR}/validate-gitops.sh" "$@"
            ;;
        legacy)
            run_legacy_deployment "$@"
            ;;
        services)
            show_service_access
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
