# MLOps Platform Deployment

Professional-grade automation for deploying a complete MLOps platform on Kubernetes. This project provides Infrastructure as Code using Ansible, with a single entry point script for easy deployment and management.

## 🏗️ Architecture Overview

This automation deploys a production-ready MLOps platform with the following components:

### Core Operators (platform-operators namespace)
- **Strimzi Kafka Operator** v0.46.1 - Manages Apache Kafka clusters
- **MinIO Operator** v7.1.1 - Manages distributed object storage
- **Spark Kubernetes Operator** v0.4.0 - Manages Apache Spark applications
- **Flink Kubernetes Operator** v1.12.0 - Manages Apache Flink stream processing
- **cert-manager** v1.14.4 - Manages TLS certificates (Flink dependency)

### Platform Namespaces
- `platform-operators` - Kubernetes operators
- `data-plane` - Kafka clusters and MinIO tenants
- `orchestration` - Apache Airflow (workflow orchestration)
- `ml-lifecycle` - MLflow (experiment tracking & model registry)
- `processing-jobs` - Transient Spark/Flink job pods

## 📁 Project Structure

```
├── deploy.sh                 # Single entry point script
├── infrastructure/           # Ansible automation
│   ├── ansible-playbook.yml  # Main deployment playbook
│   ├── ansible.cfg           # Ansible configuration
│   ├── inventory.ini         # Ansible inventory
│   └── requirements.yml      # Required Ansible collections
├── scripts/                  # Supporting utility scripts
│   ├── validate-setup.sh     # Validation and testing
│   ├── setup_script.sh       # Prerequisites installation
│   └── quick-setup.sh        # Quick setup helper
├── airflow/                  # Airflow Helm chart
└── README.md                 # This file
```

## 🚀 Quick Start

### Single Command Deployment

```bash
# Clone the repository
git clone <repository-url>
cd MLOPS-Helm-Charts

# Make the deploy script executable (if not already)
chmod +x deploy.sh

# Run complete deployment
./deploy.sh deploy
```

### Available Commands

```bash
# Validate setup and check prerequisites
./deploy.sh validate

# Install prerequisites only (Docker, Kubernetes, Helm)
./deploy.sh install

# Deploy the complete platform
./deploy.sh deploy

# Check deployment status
./deploy.sh status

# Clean up all resources
./deploy.sh cleanup

# Show help
./deploy.sh help
```

### Advanced Options

```bash
# Dry run (validation only, no actual deployment)
./deploy.sh deploy --dry-run

# Verbose output for debugging
./deploy.sh deploy --verbose

# Force deployment even if validation fails
./deploy.sh deploy --force

# Skip prerequisite installation
./deploy.sh deploy --skip-prereqs

# Use custom Ansible configuration
./deploy.sh deploy --config /path/to/custom/ansible.cfg
```

## 📋 Prerequisites

### System Requirements
- **Operating System**: macOS or Linux
- **Package Manager**: Homebrew (macOS) or apt/yum (Linux)
- **Network**: Internet connection for downloading packages
- **Permissions**: Administrative privileges for some installations

### Automatic Installation
The deployment script automatically installs:
- Docker or Docker Desktop
- Kubernetes (kubectl, minikube)
- Helm
- Required Ansible collections

### Manual Installation (Optional)

If you prefer to install prerequisites manually:

1. **Install Ansible** (choose one method):

   ```bash
   # Option 1: Using pipx (recommended)
   pipx install --include-deps ansible
   
   # Option 2: Using pip
   pip3 install ansible
   
   # Option 3: Using Homebrew (macOS)
   brew install ansible
   
   # Option 4: Using package manager (Linux)
   # Ubuntu/Debian
   sudo apt update && sudo apt install ansible
   
   # RHEL/CentOS/Fedora
   sudo dnf install ansible
   ```

2. **Install required Ansible collections**:
   ```bash
   cd infrastructure
   ansible-galaxy collection install -r requirements.yml
   ```

## 🔧 Configuration Options

You can customize the deployment by modifying variables in `infrastructure/ansible-playbook.yml` or by using the deployment script with environment variables.

### Platform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `platform_namespace` | `platform-operators` | Namespace for operators |
| `data_namespace` | `data-plane` | Namespace for data services |
| `orchestration_namespace` | `orchestration` | Namespace for Airflow |
| `ml_lifecycle_namespace` | `ml-lifecycle` | Namespace for MLflow |
| `processing_namespace` | `processing-jobs` | Namespace for job pods |
| `install_docker` | `true` | Install Docker if missing |
| `install_kubernetes` | `true` | Install Kubernetes tools |
| `install_helm` | `true` | Install Helm package manager |
| `clean_install` | `false` | Remove existing installations |

### Direct Ansible Usage (Advanced)

If you prefer to use Ansible directly instead of the deployment script:

```bash
# Navigate to infrastructure directory
cd infrastructure

# Basic deployment
ansible-playbook ansible-playbook.yml

# Custom configuration
ansible-playbook ansible-playbook.yml \
  -e platform_namespace="my-operators" \
  -e data_namespace="my-data"

# Specific operator versions
ansible-playbook ansible-playbook.yml \
  -e strimzi_version="0.45.0" \
  -e minio_operator_version="7.0.0"

# Clean installation (removes existing)
ansible-playbook ansible-playbook.yml -e clean_install=true
```

## 🔍 Verification & Monitoring

### Check Deployment Status
```bash
# View all operators
kubectl get pods -n platform-operators

# Check all namespaces
kubectl get namespaces | grep -E "(platform|data|orchestration|ml-lifecycle|processing)"

# View Helm releases
helm list -A

# Check operator logs
kubectl logs -n platform-operators -l app.kubernetes.io/name=strimzi-cluster-operator
## 🛠️ Troubleshooting

### Validation Issues
```bash
# Run validation to check for issues
./deploy.sh validate

# Check specific components
kubectl get pods -n platform-operators
kubectl get events -n platform-operators --sort-by='.lastTimestamp'
```

### Deployment Failures
```bash
# Check deployment status
./deploy.sh status

# View logs for specific operators
kubectl logs -n platform-operators -l app.kubernetes.io/name=strimzi-cluster-operator
kubectl logs -n platform-operators -l app.kubernetes.io/name=minio-operator
```

### Clean Up and Retry
```bash
# Clean up everything and start fresh
./deploy.sh cleanup

# Redeploy
./deploy.sh deploy --force
```

### Manual Ansible Debugging
```bash
# Navigate to infrastructure directory
cd infrastructure

# Run with verbose output
ansible-playbook ansible-playbook.yml -vvv

# Check syntax only
ansible-playbook ansible-playbook.yml --syntax-check

# Dry run to see changes
ansible-playbook ansible-playbook.yml --check --diff
```

## 🏗️ Next Steps: Deploy Application Services

After operators are running, deploy the actual services:

### 1. Kafka Cluster
```bash
# Create Kafka cluster using Strimzi
kubectl apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: mlops-kafka-cluster
  namespace: data-plane
spec:
  kafka:
    version: 3.7.0
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    storage:
      type: jbod
      volumes:
        - id: 0
          type: persistent-claim
          size: 100Gi
          deleteClaim: false
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 10Gi
      deleteClaim: false
EOF
```

### 2. MinIO Tenant
```bash
# Deploy MinIO distributed storage
helm install minio-tenant minio-operator/tenant \
  --namespace data-plane \
  --set tenant.pools[0].servers=4 \
  --set tenant.pools[0].volumesPerServer=4 \
  --set tenant.pools[0].size=256Gi
```

### 3. Apache Airflow
```bash
# Deploy workflow orchestration
helm install airflow apache-airflow/airflow \
  --namespace orchestration \
  --create-namespace \
  --set executor=CeleryKubernetesExecutor \
  --set dags.gitSync.enabled=true \
  --set dags.gitSync.repo="https://github.com/your-org/airflow-dags.git"
```

### 4. MLflow
```bash
# Deploy ML lifecycle management
helm install mlflow community-charts/mlflow \
  --namespace ml-lifecycle \
  --create-namespace \
  --set artifactRoot="s3://mlflow-artifacts" \
  --set extraEnvVars.MLFLOW_S3_ENDPOINT_URL="http://minio-tenant.data-plane.svc.cluster.local:9000"
```

## 🐛 Troubleshooting

### Common Issues

1. **Minikube insufficient resources**:
   ```bash
   minikube stop
   minikube start --driver=docker --memory=16384 --cpus=8
   ```

2. **Flink operator webhook errors**:
   ```bash
   kubectl get validatingwebhookconfiguration
   kubectl get mutatingwebhookconfiguration
   # Ensure cert-manager is running
   kubectl get pods -n cert-manager
   ```

3. **Docker permission issues (Linux)**:
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

4. **Helm repository issues**:
   ```bash
   helm repo update
   helm repo list
   ```

### Log Collection
```bash
# Collect all logs for debugging
kubectl logs -n platform-operators --all-containers=true > platform-logs.txt
kubectl get events -A --sort-by='.lastTimestamp' > cluster-events.txt
```

## 📁 File Structure

```
.
├── ansible-playbook.yml     # Main deployment playbook
├── requirements.yml         # Ansible collections requirements
├── inventory.ini           # Ansible inventory (localhost)
├── ansible.cfg            # Ansible configuration
├── setup_script.sh        # Legacy bash script (deprecated)
├── mlops-deployment-summary.txt  # Generated deployment summary
└── README.md              # This file
```

## 🔄 Migration from Bash Script

This Ansible playbook replaces the previous `setup_script.sh` with several advantages:

- **Idempotent**: Safe to run multiple times
- **Declarative**: Infrastructure as Code principles
- **Comprehensive**: Handles all prerequisites automatically
- **Cross-platform**: Supports macOS and Linux
- **Production-ready**: Error handling, logging, and verification
- **Maintainable**: Version-controlled configuration
- **Extensible**: Easy to add new components

## 📖 References

- [MLOps Infrastructure Guide](./mlopsinfrastructure.instructions.md)
- [Ansible Documentation](https://docs.ansible.com/)
- [Kubernetes Collection](https://galaxy.ansible.com/kubernetes/core)
- [Strimzi Operator](https://strimzi.io/)
- [MinIO Operator](https://min.io/docs/minio/kubernetes/)
- [Spark on Kubernetes](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
- [Flink Kubernetes Operator](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/)

## 🤝 Contributing

1. Follow the architectural patterns in `mlopsinfrastructure.instructions.md`
2. Test on both macOS and Linux
3. Update version variables for new operator releases
4. Add verification steps for new components
5. Document any new configuration options

## 📝 License

This project follows the same license as the underlying open-source components.

---

🚀 **Ready to deploy?** Run `ansible-playbook ansible-playbook.yml` to get started!
