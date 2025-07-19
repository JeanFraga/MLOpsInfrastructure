# MLOps Platform Documentation

Welcome to the comprehensive documentation for the MLOps Platform on Kubernetes.

## 📚 Documentation Index

### 🚀 Getting Started
- **[Quick Start Guide](../README.md)** - Fast track to deployment
- **[Ansible Deployment Guide](ANSIBLE-DEPLOYMENT-GUIDE.md)** - Complete team-friendly deployment procedures

### 🏗️ Architecture & Design
- **[Platform Architecture](README.md)** - Detailed system architecture and design principles
- **[Project Structure](PROJECT-STRUCTURE.md)** - Optimized project organization and best practices
- **[Component Integration](README.md#part-5-weaving-the-fabric-integrating-the-platform-components)** - How services connect and communicate

### 📋 Deployment & Operations
- **[Deployment Summary](mlops-deployment-summary.txt)** - Platform deployment status and configuration
- **[Ansible Playbook Structure](ANSIBLE-DEPLOYMENT-GUIDE.md#deployment-script-changes)** - Understanding the automation structure

### 🔧 Configuration & Customization
- **[Namespace Strategy](ANSIBLE-DEPLOYMENT-GUIDE.md#6-tier-namespace-strategy)** - Six-tier namespace architecture
- **[Observability Stack](ANSIBLE-DEPLOYMENT-GUIDE.md#observability-stack)** - Monitoring and alerting configuration
- **[Team Maintainability](ANSIBLE-DEPLOYMENT-GUIDE.md#team-maintainability-features)** - Features for collaborative development

### 📊 Monitoring & Observability
- **[CPU Usage Monitoring](ANSIBLE-DEPLOYMENT-GUIDE.md#observability-access)** - Accessing monitoring dashboards
- **[ServiceMonitors](ANSIBLE-DEPLOYMENT-GUIDE.md#servicemonitors-for-mlops-operators)** - Automated metrics collection
- **[Dashboard Configuration](ANSIBLE-DEPLOYMENT-GUIDE.md#pre-configured-dashboards)** - Ready-to-use Grafana dashboards

### 🔄 MLOps Workflows
- **[End-to-End Pipelines](README.md#the-end-to-end-vision)** - Complete MLOps workflow examples
- **[Component Integration Matrix](README.md#component-integration-matrix)** - Service interaction patterns

### 👥 Team Collaboration
- **[GitOps Approach](ANSIBLE-DEPLOYMENT-GUIDE.md#team-collaboration)** - Version-controlled infrastructure
- **[Development Workflow](ANSIBLE-DEPLOYMENT-GUIDE.md#development-workflow)** - Best practices for teams
- **[Configuration Management](ANSIBLE-DEPLOYMENT-GUIDE.md#configuration-management)** - Maintaining consistent environments

## 🚀 Quick Demo

Experience the complete MLOps platform with our comprehensive demonstration:

```bash
# Run the end-to-end demo pipeline
./scripts/run-mlops-demo.sh

# View demo documentation
cat docs/DEMO-GUIDE.md
```

**Demo Features:**
- Real-time IoT sensor data simulation with Kafka
- Stream processing and feature engineering with Flink  
- ML model training and tracking with MLflow
- Data archival and versioning with MinIO
- Complete pipeline orchestration with Airflow
- Performance monitoring and alerting

The demo runs for 2 hours by default and generates comprehensive reports showing:
- ✅ Data throughput: 50+ events/second
- ✅ ML models: 4 algorithms trained and compared
- ✅ Model performance: F1 scores >0.7
- ✅ Infrastructure health: All services operational

See [DEMO-GUIDE.md](DEMO-GUIDE.md) for detailed instructions and customization options.

---

## 🛠️ Component Documentation

### Platform Components
| Component | Documentation | Purpose |
|-----------|---------------|---------|
| **Apache Airflow** | [Helm Chart Docs](../airflow/README.md) | Workflow orchestration |
| **Strimzi Kafka** | [Architecture Guide](README.md#deploying-apache-kafka-with-the-strimzi-operator) | Messaging & streaming |
| **MinIO** | [Architecture Guide](README.md#deploying-minio-with-the-minio-operator) | Object storage |
| **Apache Spark** | [Architecture Guide](README.md#deploying-apache-spark-with-the-kubernetes-operator) | Batch processing |
| **Apache Flink** | [Architecture Guide](README.md#deploying-apache-flink-with-the-kubernetes-operator) | Stream processing |
| **MLflow** | [Architecture Guide](README.md#deploying-mlflow) | ML lifecycle management |
| **Prometheus/Grafana** | [Observability Guide](ANSIBLE-DEPLOYMENT-GUIDE.md#observability-stack) | Monitoring & observability |

## 🎯 Quick Reference

### Common Commands
```bash
# Validate environment
./deploy.sh validate

# Deploy full platform  
./deploy.sh deploy

# Check status
./deploy.sh status

# Access monitoring
kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80
```

### Key URLs
- **Grafana**: `http://localhost:3000` (admin/admin123)
- **MLflow**: `http://localhost:5000`
- **Airflow**: `http://localhost:8080`
- **Prometheus**: `http://localhost:9090`

### Important Files
- `infrastructure/ansible-playbook.yml` - Main deployment automation
- `deploy.sh` - Primary deployment script
- `infrastructure/ansible.cfg` - Ansible configuration

## 📖 Reading Path

### For Platform Engineers
1. [Platform Architecture](README.md) - Understand the complete system design
2. [Ansible Deployment Guide](ANSIBLE-DEPLOYMENT-GUIDE.md) - Learn the deployment methodology
3. [Configuration Management](ANSIBLE-DEPLOYMENT-GUIDE.md#configuration-management) - Customize for your environment

### For Data Engineers
1. [Quick Start Guide](../README.md) - Get the platform running
2. [MLOps Workflows](README.md#the-end-to-end-vision) - Understand pipeline patterns
3. [Component Integration](README.md#part-5-weaving-the-fabric-integrating-the-platform-components) - Learn service connections

### For DevOps Teams
1. [Team Maintainability Features](ANSIBLE-DEPLOYMENT-GUIDE.md#team-maintainability-features) - Collaboration tools
2. [Observability Stack](ANSIBLE-DEPLOYMENT-GUIDE.md#observability-stack) - Monitoring setup
3. [Development Workflow](ANSIBLE-DEPLOYMENT-GUIDE.md#development-workflow) - Best practices

---

## 📞 Support

For additional help or questions:
- Review the comprehensive guides above
- Check the deployment logs: `ansible.log`
- Validate your setup: `./deploy.sh validate`
- Monitor platform status: `./deploy.sh status`

This documentation structure provides a clear path for understanding, deploying, and maintaining the MLOps platform.
