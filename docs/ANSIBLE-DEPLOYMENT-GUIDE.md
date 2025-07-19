# MLOps Platform - Ansible-Based Deployment

## Overview

The MLOps platform has been updated to use Ansible for all deployment operations, providing a clean, maintainable, and team-friendly approach to managing the infrastructure.

## Architecture Updates

### 6-Tier Namespace Strategy
The platform now includes a dedicated observability namespace:

1. **platform-operators** - Platform Operators Layer
2. **data-plane** - Data and Storage Layer  
3. **orchestration** - Orchestration Layer
4. **ml-lifecycle** - ML Lifecycle Layer
5. **processing-jobs** - Processing Layer
6. **observability** - Monitoring and Alerting Layer ⭐ **NEW**

### Observability Stack

**Components Deployed:**
- **kube-prometheus-stack v65.1.1** - Complete monitoring solution
- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization and dashboards
- **AlertManager** - Alert routing and management
- **Node Exporter** - System-level metrics
- **kube-state-metrics** - Kubernetes resource metrics

**Pre-configured Dashboards:**
- Kubernetes Cluster Overview (Grafana ID: 7249)
- Kubernetes Pods (Grafana ID: 6336)
- Kubernetes Deployments (Grafana ID: 8588)
- Node Exporter Full (Grafana ID: 1860)

**ServiceMonitors for MLOps Operators:**
- Strimzi Kafka Operator metrics
- Spark Kubernetes Operator metrics
- Flink Kubernetes Operator metrics

## Deployment Script Changes

### New Ansible-Based Commands

The `deploy.sh` script now uses Ansible for all operations:

```bash
# Validation
./deploy.sh validate
# Uses: ansible-playbook ansible-playbook.yml --tags "validation"

# Prerequisites Installation
./deploy.sh install
# Uses: ansible-playbook ansible-playbook.yml --tags "prerequisites"

# Full Deployment
./deploy.sh deploy
# Uses: ansible-playbook ansible-playbook.yml

# Status Check
./deploy.sh status
# Uses: ansible-playbook ansible-playbook.yml --tags "status"

# Cleanup
./deploy.sh cleanup
# Uses: ansible-playbook ansible-playbook.yml --tags "cleanup"
```

### Available Ansible Tags

- **always** - Pre-tasks (OS detection, summary)
- **prerequisites** - Install Docker, Kubernetes, Helm
- **validation** - Validate prerequisites and cluster
- **deploy** - Full platform deployment
- **observability** - Observability stack only
- **status** - Status checking tasks
- **cleanup** - Cleanup and removal tasks
- **never** - Manual execution only (status, cleanup, validation)

## Team Maintainability Features

### 1. Consistent Tooling
- Single tool (Ansible) for all operations
- Standardized configuration management
- Version-controlled infrastructure as code

### 2. Granular Control
- Tagged tasks for selective execution
- Idempotent operations (safe to re-run)
- Comprehensive error handling

### 3. Comprehensive Monitoring
- Full observability from day one
- Automated metrics collection for all operators
- Ready-to-use dashboards for common scenarios

### 4. Team Collaboration
- Self-documenting playbooks
- Clear separation of concerns
- Environment-agnostic configuration

## Usage Examples

### Quick Start
```bash
# Validate environment
./deploy.sh validate

# Deploy full platform
./deploy.sh deploy

# Check status
./deploy.sh status
```

### Development Workflow
```bash
# Test deployment without execution
./deploy.sh deploy --dry-run

# Deploy with verbose output
./deploy.sh deploy --verbose

# Force deployment bypassing validation
./deploy.sh deploy --force
```

### Observability Access
```bash
# Access Grafana (default: admin/admin123)
kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80

# Access Prometheus
kubectl port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090

# Access AlertManager
kubectl port-forward -n observability svc/kube-prometheus-stack-alertmanager 9093:9093
```

### Advanced Operations
```bash
# Deploy only observability stack
cd infrastructure && ansible-playbook ansible-playbook.yml --tags "observability"

# Run only validation tasks
cd infrastructure && ansible-playbook ansible-playbook.yml --tags "validation"

# Clean environment for fresh deployment
./deploy.sh cleanup
```

## Configuration Management

### Key Configuration Files
- `infrastructure/ansible-playbook.yml` - Main deployment playbook
- `deploy.sh` - Primary deployment script
- `infrastructure/ansible.cfg` - Ansible configuration

### Customization Points
- Operator versions in playbook variables
- Resource limits and requests
- Storage configurations
- Dashboard selections
- ServiceMonitor configurations

## Benefits for Teams

### 1. Reduced Complexity
- Single entry point for all operations
- Consistent deployment patterns
- Automated dependency management

### 2. Enhanced Observability
- Complete monitoring from deployment
- CPU usage monitoring built-in
- Application metrics automatically collected

### 3. Production Readiness
- Operator-driven architecture
- Proper resource isolation
- Security-focused namespace separation

### 4. Developer Experience
- Self-validating deployments
- Clear error messages
- Comprehensive status reporting

## Next Steps

1. **Deploy Application Instances** using the operator pattern
2. **Configure Custom Dashboards** for specific MLOps workflows
3. **Set up Alerting Rules** for production monitoring
4. **Implement GitOps** workflows for continuous deployment

This architecture provides a solid foundation for production MLOps workloads with comprehensive observability and team-friendly maintenance.

## Docker Desktop Compatibility

### Node Exporter Configuration

For Docker Desktop environments, the Node Exporter is disabled by default due to mount propagation limitations. This component is primarily used for host-level system metrics and is not critical for MLOps platform functionality.

**Production environments** can enable Node Exporter by updating the Ansible playbook:

```yaml
nodeExporter:
  enabled: true
  hostNetwork: true
  hostRootFsMount:
    enabled: true
    mountPropagation: HostToContainer
```

### Storage Configuration

The observability stack uses the `hostpath` storage class for persistent volumes, which is suitable for development environments. For production deployments, consider using:

- Cloud provider storage classes (EBS, GCE-PD, Azure Disk)
- Network-attached storage solutions
- Distributed storage systems (Ceph, GlusterFS)

## Cluster Cleanup Commands

### Automated Health Check

Use the automated cluster health check script for regular maintenance:

```bash
# Run health check only
./scripts/cluster-health-check.sh check

# Run health check and cleanup orphaned resources
./scripts/cluster-health-check.sh cleanup

# Get help
./scripts/cluster-health-check.sh help
```

The health check script automatically identifies:
- Orphaned namespaces not managed by Ansible
- Orphaned PVCs from old deployments  
- Failed pods and resources in error states
- Orphaned Custom Resource Definitions
- Unmanaged Helm releases

### Manual Resource Cleanup

If you need to clean up orphaned resources not managed by Ansible:

```bash
# Remove orphaned namespaces
./deploy.sh cleanup  # Uses Ansible cleanup tasks

# Manual cleanup commands for specific scenarios:

# 1. Remove orphaned PVCs from old deployments
kubectl get pvc --all-namespaces | grep -v "observability\|data-plane"
kubectl delete pvc <pvc-name> -n <namespace>

# 2. Remove empty namespaces
kubectl get namespace | grep -v "kube-\|default\|cert-manager\|platform-operators\|data-plane\|orchestration\|ml-lifecycle\|processing-jobs\|observability"
kubectl delete namespace <orphaned-namespace>

# 3. Remove orphaned CRDs from old installations
kubectl get crd | grep -v "cert-manager\|strimzi\|minio\|spark\|flink\|monitoring.coreos.com"
kubectl delete crd <orphaned-crd>

# 4. Check for orphaned Helm releases
helm list --all-namespaces
helm uninstall <release-name> -n <namespace>
```

### Regular Maintenance

Run these commands periodically to keep the cluster clean:

```bash
# Check for failed pods
kubectl get pods --all-namespaces --field-selector=status.phase=Failed

# Check for orphaned resources
kubectl get all --all-namespaces | grep -E "(ERROR|Pending|CrashLoopBackOff|Failed)"

# Clean up completed jobs older than 1 hour
kubectl delete jobs --field-selector=status.conditions[0].type=Complete --all-namespaces

# Check persistent volume usage
kubectl get pv,pvc --all-namespaces
```
