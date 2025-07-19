# 🚀 MLOps Infrastructure Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.25+-blue.svg)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-3.10+-blue.svg)](https://helm.sh/)
[![Ansible](https://img.shields.io/badge/Ansible-6.0+-red.svg)](https://ansible.com/)
[![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://python.org/)

A complete, production-grade MLOps infrastructure platform built on Kubernetes with Apache Airflow, Apache Spark, Apache Flink, Apache Kafka, MinIO, and MLflow. Designed for scalability, reliability, and enterprise-grade operations.

## 🎯 Features

- **🔧 Complete MLOps Stack**: Kafka, Spark, Flink, Airflow, MLflow, MinIO, PostgreSQL
- **🏗️ Production-Ready**: High availability, scalability, and security best practices
- **📊 Full Observability**: Prometheus, Grafana, and comprehensive monitoring
- **🚀 Easy Deployment**: Ansible-based automation with one-command deployment
- **🔒 Security First**: RBAC, secrets management, and security scanning
- **📖 Comprehensive Documentation**: Detailed guides and architectural documentation
- **🔄 CI/CD Integration**: GitHub Actions for validation and deployment
- **🎛️ GitOps Ready**: Declarative configurations and version control

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    MLOps Infrastructure Platform                │
├─────────────────────────────────────────────────────────────────┤
│  Observability Layer (Prometheus, Grafana, Jaeger)            │
├─────────────────────────────────────────────────────────────────┤
│  ML Lifecycle (MLflow, Model Registry, Experiment Tracking)    │
├─────────────────────────────────────────────────────────────────┤
│  Orchestration Layer (Apache Airflow, Workflow Management)     │
├─────────────────────────────────────────────────────────────────┤
│  Processing Layer (Apache Spark, Apache Flink)                │
├─────────────────────────────────────────────────────────────────┤
│  Data Layer (Apache Kafka, MinIO, PostgreSQL)                 │
├─────────────────────────────────────────────────────────────────┤
│  Platform Layer (Kubernetes, Operators, RBAC)                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (v1.25+)
- Helm (v3.10+)
- Ansible (v6.0+)
- kubectl configured

### One-Command Deployment

```bash
# Clone the repository
git clone https://github.com/yourusername/MLOpsInfrastructure.git
cd MLOpsInfrastructure

# Validate environment
./deploy.sh validate

# Deploy full platform
./deploy.sh deploy

# Check status
./deploy.sh status
```

### Manual Deployment

```bash
# Deploy with Ansible
cd infrastructure
ansible-playbook -i inventory.ini ansible-playbook.yml

# Validate deployment
./scripts/validate-setup.sh

# Run health checks
./scripts/cluster-health-check.sh
```

## 📋 Components

| Component | Version | Purpose | Namespace |
|-----------|---------|---------|-----------|
| **Apache Kafka** | 3.5.0 | Event Streaming | `data-plane` |
| **Apache Spark** | 3.4.0 | Big Data Processing | `processing-jobs` |
| **Apache Flink** | 1.17.0 | Stream Processing | `processing-jobs` |
| **Apache Airflow** | 2.6.0 | Workflow Orchestration | `orchestration` |
| **MLflow** | 2.4.0 | ML Lifecycle Management | `ml-lifecycle` |
| **MinIO** | 2023.7.7 | Object Storage | `data-plane` |
| **PostgreSQL** | 15.0 | Relational Database | `data-plane` |
| **Prometheus** | 2.45.0 | Monitoring | `observability` |
| **Grafana** | 10.0.0 | Visualization | `observability` |

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[📖 Complete Documentation](docs/INDEX.md)** | Comprehensive guides and architecture |
| **[🏗️ Architecture Overview](docs/README.md)** | Detailed platform architecture |
| **[🚀 Deployment Guide](docs/ANSIBLE-DEPLOYMENT-GUIDE.md)** | Step-by-step deployment instructions |
| **[📂 Project Structure](docs/PROJECT-STRUCTURE.md)** | Repository organization and best practices |
| **[🧹 Cleanup Guide](docs/CLEANUP-GUIDE.md)** | Resource cleanup and maintenance |
| **[🎮 Demo Guide](docs/DEMO-GUIDE.md)** | End-to-end demo walkthrough |
| **[⚙️ GitOps Migration](docs/GITOPS-MIGRATION-PLAN.md)** | GitOps implementation guide |

## 🔧 Configuration

### Environment Variables

```bash
# Required
export KUBECONFIG=/path/to/kubeconfig
export MLOPS_ENV=production  # or staging, development

# Optional
export MLOPS_NAMESPACE_PREFIX=mlops
export MLOPS_DOMAIN=mlops.example.com
export MLOPS_STORAGE_CLASS=fast-ssd
```

### Customization

Edit the configuration files:

- **Ansible Variables**: `infrastructure/inventory.ini`
- **Helm Values**: `infrastructure/helm-values/*.yaml`
- **Kubernetes Manifests**: `infrastructure/manifests/`

## 🛠️ Development

### Local Development

```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run validation
./scripts/validate-setup.sh

# Run tests
python -m pytest tests/
```

### Running the Demo

```bash
# Deploy demo components
./scripts/run-mlops-demo.sh

# Access services
kubectl port-forward svc/airflow-webserver 8080:8080 -n orchestration
kubectl port-forward svc/mlflow-server 5000:5000 -n ml-lifecycle
```

## 🔒 Security

- **RBAC**: Role-based access control for all components
- **Secrets Management**: Kubernetes secrets with rotation
- **Network Policies**: Micro-segmentation between components
- **Security Scanning**: Automated vulnerability scanning
- **TLS/SSL**: End-to-end encryption

See [SECURITY.md](SECURITY.md) for detailed security guidelines.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and validation
5. Submit a pull request

## 📊 Monitoring & Observability

### Metrics

- **Infrastructure Metrics**: CPU, memory, network, storage
- **Application Metrics**: Kafka lag, Spark job metrics, Airflow DAG success rates
- **ML Metrics**: Model performance, data drift, experiment tracking

### Dashboards

- **Platform Overview**: Overall system health
- **Component-Specific**: Detailed metrics for each component
- **ML Operations**: ML-specific metrics and alerts

### Alerts

- **Infrastructure**: Resource utilization, node failures
- **Applications**: Service failures, performance degradation
- **ML Operations**: Model performance issues, data quality problems

## 🚨 Troubleshooting

### Common Issues

1. **Pod Stuck in Pending**: Check resource requests and node capacity
2. **Service Unavailable**: Verify ingress and service configurations
3. **Kafka Connection Issues**: Check network policies and security groups
4. **Spark Job Failures**: Review resource allocation and driver logs

### Getting Help

- 📖 Check the [documentation](docs/INDEX.md)
- 🐛 Create an [issue](https://github.com/yourusername/MLOpsInfrastructure/issues)
- 💬 Start a [discussion](https://github.com/yourusername/MLOpsInfrastructure/discussions)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Apache Software Foundation for the amazing open-source projects
- Kubernetes community for the robust container orchestration platform
- MLflow community for the ML lifecycle management tools
- Contributors and maintainers of all the integrated components

## 📞 Support

- **Email**: support@example.com
- **Documentation**: [docs/INDEX.md](docs/INDEX.md)
- **Issues**: [GitHub Issues](https://github.com/yourusername/MLOpsInfrastructure/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/MLOpsInfrastructure/discussions)

---

<div align="center">
  <strong>🚀 Ready to build your MLOps platform? Let's get started!</strong>
</div>
