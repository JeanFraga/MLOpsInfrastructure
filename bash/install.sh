#!/bin/bash

# This script installs necessary tools and dependencies for MLOps components
# It also checks the installation status of the tools and dependencies

# if [ "$EUID" -ne 0 ]; then
#   echo "Please run as root"
#   exit 1
# fi

# import functions.sh
source bash/functions.sh

# Set up logging
setup_logging "install"

# Define required CLI tools
REQUIRED_TOOLS=("git" "aws" "az" "gcloud" "docker" "docker-compose" "helm" "kubectl" "terraform" "ansible" "k9s")
# REQUIRED_TOOLS+=("tool1" "tool2" "tool3") # Add more tools as needed

# Check for required command line tools
echo "Checking for required CLI tools..."
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v $tool &> /dev/null; then
        echo "Warning: $tool is not installed"
    else
        echo "$tool is installed: $($tool --version 2>/dev/null)"
    fi
done

# Update package list
# Detect OS and update package list
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Updating package list for macOS..."
    if command -v brew &> /dev/null; then
        brew update
    else
        echo "Homebrew not found. Please install Homebrew first."
        exit 1
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [[ -f /etc/debian_version ]]; then
        echo "Updating package list for Debian-based Linux..."
        sudo apt-get update
    elif [[ -f /etc/redhat-release ]]; then
        echo "Updating package list for RedHat-based Linux..."
        sudo yum update
    else
        echo "Unsupported Linux distribution"
        exit 1
    fi
elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
    echo "Windows detected. Package management not supported."
    echo "Please ensure you have package manager (like Chocolatey) installed manually."
else
    echo "Unsupported operating system: $OSTYPE"
    exit 1
fi

# Install Docker if not installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install --cask docker # Install Docker Desktop
    else
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
    fi
fi

# Install Docker Compose if not installed
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install docker-compose
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
fi

# Install and check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install kubectl
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
        echo "Windows detected. Please install kubectl manually."
        exit 1
    else
        echo "Unsupported OS for kubectl installation: $OSTYPE"
        exit 1
    fi
fi

# Install and check Helm
if ! command -v helm &> /dev/null; then
    echo "Helm not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install helm
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
        chmod 700 get_helm.sh
        ./get_helm.sh
        rm get_helm.sh
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
        echo "Windows detected. Please install Helm manually."
        exit 1
    else
        echo "Unsupported OS for Helm installation: $OSTYPE"
        exit 1
    fi
fi

# Install and check K9s
if ! command -v k9s &> /dev/null; then
    echo "K9s not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install k9s
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -LO
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
        choco install k9s
    else
        echo "Unsupported OS for K9s installation: $OSTYPE"
        exit 1
    fi
fi

# Install and check Terraform
if ! command -v terraform &> /dev/null; then
    echo "Terraform not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install terraform
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -fsSL -o terraform.zip https://releases.hashicorp.com/terraform/1.0.0/terraform_1.0.0_linux_amd64.zip
        sudo unzip terraform.zip -d /usr/local/bin
        rm terraform.zip
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
        choco install terraform
    else
        echo "Unsupported OS for Terraform installation: $OSTYPE"
        exit 1
    fi
fi

# Install and check Ansible
if ! command -v ansible &> /dev/null; then
    echo "Ansible not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install ansible
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get install -y ansible
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
        choco install ansible
    else
        echo "Unsupported OS for Ansible installation: $OSTYPE"
        exit 1
    fi
fi

# Install and check AWS CLI
# if ! command -v aws &> /dev/null; then
#     echo "AWS CLI not found. Installing..."
#     if [[ "$OSTYPE" == "darwin"* ]]; then
#         brew install awscli
#     elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
#         sudo apt-get install -y awscli
#     elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
#         choco install awscli
#     else
#         echo "Unsupported OS for AWS CLI installation: $OSTYPE"
#         exit 1
#     fi
# fi

# Install and check Azure CLI
# if ! command -v az &> /dev/null; then
#     echo "Azure CLI not found. Installing..."
#     if [[ "$OSTYPE" == "darwin"* ]]; then
#         brew install azure-cli
#     elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
#         curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
#     elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
#         choco install azure-cli
#     else
#         echo "Unsupported OS for Azure CLI installation: $OSTYPE"
#         exit 1
#     fi
# fi

# Install and check Google Cloud SDK
if ! command -v gcloud &> /dev/null; then
    echo "Google Cloud SDK not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install --cask google-cloud-sdk
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -fsSL https://sdk.cloud.google.com | bash
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
        choco install google-cloud-sdk
    else
        echo "Unsupported OS for Google Cloud SDK installation: $OSTYPE"
        exit 1
    fi
fi

# Pull necessary Docker images
# echo "Pulling necessary Docker images..."
# docker pull postgres:latest # For metadata storage
# docker pull apache/airflow:latest # For workflow orchestration
# docker pull apache/nifi:latest # For data ingestion
# docker pull confluentinc/cp-kafka:latest # For event streaming
# docker pull confluentinc/cp-zookeeper:latest # For event streaming
# # docker pull redis:latest # For caching
# docker pull bitnami/spark:latest # For data processing
# docker pull jupyter/pyspark-notebook:latest # For data exploration
# # Pull MLOps-specific containers
# echo "Pulling MLOps-specific containers..."
# docker pull minio/minio:latest  # For model artifact storage
# docker pull jenkins/jenkins:lts  # For CI/CD pipelines
# docker pull grafana/grafana:latest  # For metrics visualization
# docker pull prom/prometheus:latest  # For metrics collection
# docker pull ghcr.io/mlflow/mlflow:latest  # For ML experiment tracking
# docker pull tensorflow/serving:latest  # For model serving

echo "Installing MLOps components using helm..."
# Check if the Bitnami repo is already added, if not add it, otherwise update it
if ! helm repo list | grep -q 'https://charts.bitnami.com/bitnami'; then
    echo "Adding Bitnami Helm repository..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
else
    echo "Updating Bitnami Helm repository..."
    echo "Bitnami Helm repository already added."
fi

# Update the Helm repository
echo "Updating Bitnami Helm repository..."
helm repo update

# List of Helm charts to download
charts=("airflow" "minio" "spark" "jupyterhub" "mlflow" "prometheus" "grafana" "jenkins")

# Create a directory for the Helm charts
mkdir -p bitnami_config

# Download each chart into the bitnami_config directory
for chart in "${charts[@]}"; do
    if [ ! -d "bitnami_config/$chart" ]; then
        echo "Downloading $chart chart..."
        helm pull bitnami/"$chart" --untar --untardir bitnami_config
    else
        echo "$chart chart is already downloaded."
    fi
done

echo "All specified Helm charts have been downloaded."

# Create docker network for MLOps components
echo "Creating Docker network for MLOps components..."
docker network create MLOps-Infrastructure-network 2>/dev/null || true

# Create Docker shared volume for MinIO and PostgreSQL
echo "Creating Docker shared volumes for MinIO and PostgreSQL..."
docker volume create minio-pv 2>/dev/null || true
docker volume create postgresql-pv 2>/dev/null || true

# Check Docker containers status
echo "Checking Docker containers status..."
docker ps -a

# Check available disk space
echo "Checking available disk space..."
df -h /

echo "MLOps components installation and checks completed!"
echo "Please proceed with configuring the components as needed."

# Call the function to check status
check_status
