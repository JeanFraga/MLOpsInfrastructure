#!/bin/bash

# GitHub Repository Setup Script for MLOps Infrastructure
# This script helps you create and initialize your GitHub repository with best practices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository configuration
REPO_NAME="MLOpsInfrastructure"
REPO_DESCRIPTION="Complete MLOps infrastructure platform with Kafka, Spark, Airflow, MLflow, and observability components"
REPO_VISIBILITY="private"  # Change to "public" if you want a public repository

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command_exists git; then
        print_error "Git is not installed. Please install Git first."
        exit 1
    fi
    
    if ! command_exists gh; then
        print_error "GitHub CLI is not installed. Please install GitHub CLI first."
        print_status "Visit: https://cli.github.com/"
        exit 1
    fi
    
    # Check if user is logged in to GitHub CLI
    if ! gh auth status >/dev/null 2>&1; then
        print_error "You are not logged in to GitHub CLI."
        print_status "Please run: gh auth login"
        exit 1
    fi
    
    print_status "All prerequisites met!"
}

# Initialize git repository
init_git_repo() {
    print_header "Initializing Git Repository"
    
    if [ -d ".git" ]; then
        print_warning "Git repository already exists"
    else
        git init
        print_status "Git repository initialized"
    fi
    
    # Replace the original README with the GitHub-optimized one
    if [ -f "README-GITHUB.md" ]; then
        mv README-GITHUB.md README.md
        print_status "Updated README.md with GitHub-optimized version"
    fi
    
    # Create initial commit
    git add .
    git commit -m "feat: initial commit with complete MLOps infrastructure platform

- Add comprehensive MLOps stack with Kafka, Spark, Flink, Airflow, MLflow
- Include production-ready Kubernetes deployment with Ansible
- Add full observability with Prometheus and Grafana
- Include security best practices and RBAC
- Add comprehensive documentation and guides
- Include CI/CD pipelines with GitHub Actions
- Add development tools and pre-commit hooks
- Include demo workflows and validation scripts" || true
    
    print_status "Initial commit created"
}

# Create GitHub repository
create_github_repo() {
    print_header "Creating GitHub Repository"
    
    # Check if repository already exists
    if gh repo view "$REPO_NAME" >/dev/null 2>&1; then
        print_warning "Repository $REPO_NAME already exists"
        read -p "Do you want to continue and push to the existing repository? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Exiting without creating repository"
            exit 0
        fi
    else
        # Create the repository
        gh repo create "$REPO_NAME" \
            --description "$REPO_DESCRIPTION" \
            --"$REPO_VISIBILITY" \
            --clone=false \
            --add-readme=false
        
        print_status "GitHub repository created: $REPO_NAME"
    fi
    
    # Add remote origin
    REPO_URL=$(gh repo view "$REPO_NAME" --json url --jq '.url')
    git remote add origin "$REPO_URL.git" 2>/dev/null || git remote set-url origin "$REPO_URL.git"
    
    print_status "Remote origin set to: $REPO_URL"
}

# Setup repository settings
setup_repo_settings() {
    print_header "Configuring Repository Settings"
    
    # Enable features
    gh repo edit "$REPO_NAME" \
        --enable-issues \
        --enable-projects \
        --enable-wiki \
        --enable-discussions
    
    print_status "Enabled issues, projects, wiki, and discussions"
    
    # Set default branch protection (only for main branch)
    gh api repos/:owner/"$REPO_NAME"/branches/main/protection \
        --method PUT \
        --field required_status_checks='{"strict":true,"contexts":["validate-yaml","validate-helm","validate-python","validate-ansible","security-scan"]}' \
        --field enforce_admins=true \
        --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
        --field restrictions=null \
        --field required_linear_history=true \
        --field allow_force_pushes=false \
        --field allow_deletions=false 2>/dev/null || print_warning "Could not set branch protection (may require admin privileges)"
    
    print_status "Repository settings configured"
}

# Create labels
create_labels() {
    print_header "Creating Repository Labels"
    
    # Component labels
    gh label create "kafka" --color "FF6B6B" --description "Kafka related issues" --force
    gh label create "spark" --color "FF8E53" --description "Spark related issues" --force
    gh label create "flink" --color "FFD93D" --description "Flink related issues" --force
    gh label create "airflow" --color "6BCF7F" --description "Airflow related issues" --force
    gh label create "mlflow" --color "4D96FF" --description "MLflow related issues" --force
    gh label create "minio" --color "9775FA" --description "MinIO related issues" --force
    gh label create "observability" --color "FF6B9D" --description "Monitoring and observability" --force
    
    # Type labels
    gh label create "deployment" --color "FFA500" --description "Deployment related issues" --force
    gh label create "security" --color "FF0000" --description "Security related issues" --force
    gh label create "performance" --color "00FF00" --description "Performance related issues" --force
    gh label create "documentation" --color "0000FF" --description "Documentation improvements" --force
    gh label create "demo" --color "800080" --description "Demo related issues" --force
    
    # Priority labels
    gh label create "priority/high" --color "FF0000" --description "High priority" --force
    gh label create "priority/medium" --color "FFA500" --description "Medium priority" --force
    gh label create "priority/low" --color "00FF00" --description "Low priority" --force
    
    print_status "Repository labels created"
}

# Push to GitHub
push_to_github() {
    print_header "Pushing to GitHub"
    
    # Set upstream and push
    git branch -M main
    git push -u origin main
    
    print_status "Code pushed to GitHub successfully!"
}

# Setup secrets template
setup_secrets() {
    print_header "Setting up Secrets Template"
    
    cat > .github/secrets-template.md << 'EOF'
# GitHub Secrets Setup

Configure the following secrets in your GitHub repository:

## Required Secrets

### Kubernetes Configuration
- `KUBECONFIG` - Base64 encoded kubeconfig file for your Kubernetes cluster

### Optional Secrets (for production)
- `DOCKER_REGISTRY_URL` - Docker registry URL
- `DOCKER_REGISTRY_USERNAME` - Docker registry username
- `DOCKER_REGISTRY_PASSWORD` - Docker registry password
- `SLACK_WEBHOOK_URL` - Slack webhook for notifications
- `MLOPS_DOMAIN` - Domain name for MLOps services

## Setup Instructions

1. Go to your repository settings
2. Navigate to "Secrets and variables" > "Actions"
3. Add the required secrets listed above

## Generating KUBECONFIG Secret

```bash
# Encode your kubeconfig
cat ~/.kube/config | base64 | tr -d '\n'
```

Copy the output and paste it as the value for the `KUBECONFIG` secret.
EOF
    
    print_status "Secrets template created at .github/secrets-template.md"
}

# Create initial issues
create_initial_issues() {
    print_header "Creating Initial Issues"
    
    # Welcome issue
    gh issue create \
        --title "🚀 Welcome to MLOps Infrastructure Platform!" \
        --body "Welcome to the MLOps Infrastructure Platform repository!

This issue serves as a starting point for new contributors and users.

## Getting Started

1. 📖 Read the [Documentation](docs/INDEX.md)
2. 🚀 Try the [Quick Start Guide](README.md#quick-start)
3. 🎮 Run the [Demo](docs/DEMO-GUIDE.md)
4. 🤝 Check the [Contributing Guide](CONTRIBUTING.md)

## What's Included

- ✅ Complete MLOps stack (Kafka, Spark, Flink, Airflow, MLflow)
- ✅ Production-ready Kubernetes deployment
- ✅ Full observability with Prometheus and Grafana
- ✅ Security best practices
- ✅ CI/CD pipelines
- ✅ Comprehensive documentation

## Need Help?

- 📖 Check the documentation
- 🐛 Create an issue for bugs
- 💬 Start a discussion for questions
- 🤝 Submit a PR for improvements

Happy building! 🎉" \
        --label "documentation" \
        --label "good first issue"
    
    print_status "Initial issues created"
}

# Main function
main() {
    print_header "MLOps Infrastructure Repository Setup"
    
    check_prerequisites
    init_git_repo
    create_github_repo
    setup_repo_settings
    create_labels
    setup_secrets
    push_to_github
    create_initial_issues
    
    print_header "Setup Complete!"
    print_status "Your MLOps Infrastructure repository is ready!"
    print_status "Repository URL: $(gh repo view $REPO_NAME --json url --jq '.url')"
    print_status ""
    print_status "Next steps:"
    print_status "1. Configure GitHub secrets (see .github/secrets-template.md)"
    print_status "2. Review and customize the configuration files"
    print_status "3. Deploy to your Kubernetes cluster"
    print_status "4. Start building your MLOps platform!"
    print_status ""
    print_status "📖 Documentation: docs/INDEX.md"
    print_status "🚀 Quick Start: README.md#quick-start"
    print_status "🎮 Demo Guide: docs/DEMO-GUIDE.md"
}

# Run the main function
main "$@"
