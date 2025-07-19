#!/bin/bash

# MLOps Platform Quick Setup Script
# This script prepares your system for Ansible-based MLOps platform deployment

set -e

echo "🚀 MLOps Platform Quick Setup"
echo "=============================="

# Detect operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    echo "❌ Unsupported operating system: $OSTYPE"
    echo "This script supports macOS and Linux only."
    exit 1
fi

echo "📍 Detected OS: $OS"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Ansible if not present
if ! command_exists ansible; then
    echo "📦 Installing Ansible..."
    
    if [[ "$OS" == "macos" ]]; then
        if ! command_exists brew; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install ansible
    elif [[ "$OS" == "linux" ]]; then
        if command_exists apt; then
            sudo apt update
            sudo apt install -y ansible
        elif command_exists dnf; then
            sudo dnf install -y ansible
        elif command_exists yum; then
            sudo yum install -y ansible
        elif command_exists pacman; then
            sudo pacman -S ansible
        else
            echo "❌ Package manager not supported. Please install Ansible manually:"
            echo "   pip3 install ansible"
            exit 1
        fi
    fi
    
    echo "✅ Ansible installed successfully"
else
    echo "✅ Ansible already installed: $(ansible --version | head -n1)"
fi

# Install Python Kubernetes client
echo "📦 Installing Python Kubernetes client..."
if command_exists pip3; then
    pip3 install kubernetes PyYAML
elif command_exists pip; then
    pip install kubernetes PyYAML
else
    echo "❌ pip not found. Please install Python and pip first."
    exit 1
fi

# Install Ansible collections
echo "📦 Installing required Ansible collections..."
ansible-galaxy collection install -r requirements.yml

# Verify installation
echo "🔍 Verifying installation..."
ansible --version
ansible-galaxy collection list | grep -E "(kubernetes|community)"

echo ""
echo "✅ Setup complete! You can now run:"
echo ""
echo "   # Deploy complete MLOps platform"
echo "   ansible-playbook ansible-playbook.yml"
echo ""
echo "   # Fresh system setup (includes Docker, Kubernetes, Helm)"
echo "   ansible-playbook ansible-playbook.yml -e install_docker=true -e install_kubernetes=true -e install_helm=true"
echo ""
echo "   # Check what would be deployed without applying changes"
echo "   ansible-playbook ansible-playbook.yml --check --diff"
echo ""
echo "📖 See README.md for detailed usage instructions and configuration options."
