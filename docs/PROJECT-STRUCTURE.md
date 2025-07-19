# MLOps Platform Project Structure

## 📁 Optimized Directory Structure

This document outlines the optimized, production-ready project structure following DevOps best practices.

```
mlops-platform/
├── deploy.sh                    # 🚀 Single entry point for all operations
├── README.md                    # 📖 Main project documentation
│
├── docs/                        # 📚 Comprehensive documentation
│   ├── INDEX.md                 # Documentation index and navigation
│   ├── ANSIBLE-DEPLOYMENT-GUIDE.md  # Team-friendly deployment procedures
│   ├── CLEANUP-GUIDE.md         # Resource cleanup procedures
│   ├── DEMO-GUIDE.md            # End-to-end demo workflows
│   ├── PROJECT-STRUCTURE.md     # This file - project organization
│   ├── README.md                # Architecture and design principles
│   └── mlops-deployment-summary.txt  # Deployment status and configuration
│
├── infrastructure/              # 🏗️ Infrastructure as Code (IaC)
│   ├── ansible-playbook.yml     # Main Ansible automation (1,300+ lines)
│   ├── ansible.cfg              # Ansible configuration
│   ├── inventory.ini            # Ansible inventory
│   ├── requirements.yml         # Ansible Galaxy requirements
│   ├── kafka-cluster.yaml       # Modern Kafka with KRaft + NodePools
│   ├── minio-tenant.yaml        # MinIO object storage configuration
│   ├── airflow-values.yaml      # Apache Airflow Helm values
│   └── mlflow-values.yaml       # MLflow Helm values
│
├── scripts/                     # 🔧 Operational scripts
│   ├── cleanup-unmanaged-resources.sh  # Advanced Kubernetes cleanup
│   ├── cluster-health-check.sh         # Health monitoring
│   ├── quick-setup.sh                  # Fast deployment
│   ├── run-mlops-demo.sh              # Demo execution
│   ├── setup_script.sh                # Environment setup
│   └── validate-setup.sh              # Pre-deployment validation
│
└── src/demo/                    # 🧪 Demo application code
    ├── generate_data.py         # Data generation
    ├── mlops_demo_dag.py        # Airflow DAG definition
    ├── process_streams.py       # Kafka stream processing
    ├── train_model.py           # ML model training
    ├── requirements.txt         # Python dependencies
    └── README.md                # Demo-specific documentation
```

## 🎯 Design Principles

### 1. **Single Source of Truth**
- **`infrastructure/ansible-playbook.yml`** is the authoritative deployment definition
- **`deploy.sh`** provides unified interface for all operations
- **Configuration centralized** in `infrastructure/` directory

### 2. **Separation of Concerns**
- **Infrastructure**: Ansible playbooks, Kubernetes manifests, Helm values
- **Documentation**: Comprehensive guides for different audiences
- **Scripts**: Operational utilities and automation
- **Source Code**: Demo applications and examples

### 3. **Modern Best Practices**
- **Kafka**: KRaft mode with NodePools (no Zookeeper dependency)
- **GitOps Ready**: Version-controlled infrastructure
- **Observability**: Built-in monitoring and alerting
- **Team Collaboration**: Multi-environment support

## 🚀 Entry Points

### Primary Interface
```bash
./deploy.sh [COMMAND] [OPTIONS]
```

**Commands:**
- `validate` - Pre-deployment checks
- `install` - Prerequisites installation
- `deploy` - Full platform deployment
- `status` - Deployment status
- `cleanup` - Ansible-managed cleanup
- `cleanup-all` - Complete resource cleanup

### Quick Operations
```bash
# Fast setup for demos
./scripts/quick-setup.sh

# Run end-to-end demo
./scripts/run-mlops-demo.sh

# Advanced cleanup
./scripts/cleanup-unmanaged-resources.sh
```

## 📊 Component Architecture

### Core Platform
- **Kubernetes Operators**: Strimzi (Kafka), MinIO, Spark, Flink
- **ML Platforms**: MLflow, Apache Airflow
- **Observability**: Prometheus, Grafana, AlertManager
- **Storage**: MinIO object storage, Kafka streaming

### Namespace Strategy
```
control-plane/      # Observability stack
data-plane/         # Kafka, MinIO, core data services
compute-plane/      # Spark, Flink processing engines
ml-platform/        # MLflow, ML-specific services
workflow-plane/     # Airflow, workflow orchestration
application-plane/  # Demo applications and user workloads
```

## 🔧 Removed Redundancies

### Files Eliminated
- ❌ `ansible-playbook.yml` (root) - Basic 115-line version
- ❌ `ansible.cfg` (root) - Duplicate configuration
- ❌ `kafka-cluster.yaml` - Legacy Zookeeper mode
- ❌ `kafka-cluster-kraft.yaml` - Superseded by NodePools version
- ❌ `infrastructure/mlops-deployment-summary.txt` - Duplicate summary

### Consolidations
- ✅ **Kafka Configuration**: Single modern KRaft + NodePools implementation
- ✅ **Ansible Configuration**: Centralized in `infrastructure/`
- ✅ **Deployment Logic**: Unified in comprehensive playbook
- ✅ **Documentation**: Organized by purpose and audience

## 🎖️ Best Practices Implemented

### Infrastructure as Code
- **Version Control**: All infrastructure definitions tracked
- **Idempotency**: Ansible ensures consistent deployments
- **Validation**: Pre-deployment checks and health monitoring

### Operational Excellence
- **Monitoring**: ServiceMonitors and dashboards
- **Alerting**: Comprehensive alert rules
- **Cleanup**: Automated resource management
- **Documentation**: Role-based documentation strategy

### Team Collaboration
- **Single Entry Point**: `deploy.sh` for all operations
- **Self-Documenting**: Comprehensive inline documentation
- **Environment Consistency**: Reproducible deployments
- **Troubleshooting**: Detailed logs and status reporting

## 🔄 Maintenance Guidelines

### Regular Tasks
1. **Update Dependencies**: Helm charts, operator versions
2. **Review Configurations**: Ensure alignment with platform evolution
3. **Test Deployments**: Validate in staging environments
4. **Update Documentation**: Keep guides current with changes

### Best Practices
- **Test Before Deploy**: Use `--dry-run` and `validate` commands
- **Monitor Resources**: Regular health checks and cleanup
- **Version Components**: Track Helm chart and operator versions
- **Document Changes**: Update relevant documentation

This optimized structure eliminates redundancy while maintaining comprehensive functionality and following modern DevOps practices.
