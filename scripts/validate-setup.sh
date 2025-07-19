#!/bin/bash

# Ansible Playbook Validation Script
# Tests the MLOps platform deployment playbook for syntax and basic functionality

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRASTRUCTURE_DIR="$(dirname "$SCRIPT_DIR")/infrastructure"

echo "🔍 MLOps Platform Ansible Validation"
echo "===================================="

# Change to infrastructure directory
cd "$INFRASTRUCTURE_DIR"

# Check if files exist
REQUIRED_FILES=(
    "ansible-playbook.yml"
    "requirements.yml"
    "inventory.ini"
    "ansible.cfg"
)

echo "📁 Checking required files..."
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (missing)"
        exit 1
    fi
done

# Check Ansible installation
echo ""
echo "🔧 Checking Ansible installation..."
if command -v ansible >/dev/null 2>&1; then
    echo "  ✅ Ansible installed: $(ansible --version | head -n1)"
else
    echo "  ❌ Ansible not found. Run ./quick-setup.sh first."
    exit 1
fi

# Check required collections
echo ""
echo "📦 Checking Ansible collections..."
REQUIRED_COLLECTIONS=(
    "kubernetes.core"
    "community.general"
    "community.docker"
    "ansible.posix"
)

for collection in "${REQUIRED_COLLECTIONS[@]}"; do
    if ansible-galaxy collection list | grep -q "$collection"; then
        echo "  ✅ $collection"
    else
        echo "  ❌ $collection (missing)"
        echo "     Run: ansible-galaxy collection install -r requirements.yml"
        exit 1
    fi
done

# Validate playbook syntax
echo ""
echo "🧹 Validating playbook syntax..."
if ansible-playbook ansible-playbook.yml --syntax-check; then
    echo "  ✅ Syntax validation passed"
else
    echo "  ❌ Syntax validation failed"
    exit 1
fi

# Test inventory
echo ""
echo "📋 Testing inventory..."
if ansible localhost -i inventory.ini -m ping; then
    echo "  ✅ Inventory connectivity test passed"
else
    echo "  ❌ Inventory connectivity test failed"
    exit 1
fi

# Dry run test
echo ""
echo "🏃 Running dry-run test..."
if ansible-playbook ansible-playbook.yml --check --diff -e install_docker=false -e install_kubernetes=false -e install_helm=false; then
    echo "  ✅ Dry-run test passed"
else
    echo "  ❌ Dry-run test failed"
    exit 1
fi

echo ""
echo "🎉 Validation Complete!"
echo "======================="
echo ""
echo "All checks passed! Your Ansible setup is ready for MLOps platform deployment."
echo ""
echo "Next steps:"
echo "  1. Review configuration in ansible-playbook.yml"
echo "  2. Customize variables as needed (see README.md)"
echo "  3. Run: ansible-playbook ansible-playbook.yml"
echo ""
echo "For a fresh system setup including Docker/Kubernetes/Helm:"
echo "  ansible-playbook ansible-playbook.yml -e install_docker=true -e install_kubernetes=true -e install_helm=true"
