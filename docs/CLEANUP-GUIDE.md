# Kubernetes Resource Cleanup Guide

This guide explains how to clean up Kubernetes resources from the MLOps platform, including both Ansible-managed and unmanaged resources.

## Overview

The MLOps platform creates two types of Kubernetes resources:

1. **Ansible-managed resources**: Infrastructure deployed via Ansible playbooks
   - Namespaces, operators, Helm releases
   - Kafka clusters, MinIO tenants, MLflow servers
   - Managed through `cleanup` command

2. **Unmanaged resources**: Resources created during demos and testing
   - Demo namespaces and temporary pods
   - Completed/failed jobs and their artifacts
   - Manual kubectl deployments
   - Managed through `cleanup-all` command

## Cleanup Commands

### 1. Ansible-Managed Resource Cleanup

```bash
# Clean up only Ansible-managed infrastructure
./deploy.sh cleanup
```

This command:
- Removes MLOps namespaces created by Ansible
- Uninstalls Helm releases
- Preserves user-created resources and demos

### 2. Complete Resource Cleanup

```bash
# Clean up ALL resources (Ansible-managed + unmanaged)
./deploy.sh cleanup-all

# Preview what would be cleaned up
./deploy.sh cleanup-all --dry-run

# Non-interactive cleanup (use with caution)
./deploy.sh cleanup-all --non-interactive
```

This command performs a comprehensive cleanup:
1. **Demo Resources**: Removes `mlops-demo` namespace and all contents
2. **Completed Jobs**: Cleans up successful job pods across all namespaces
3. **Failed Jobs**: Removes failed job pods and their resources
4. **Dangling Pods**: Cleans pods in Completed/Failed/Error states
5. **Temporary Resources**: Removes configmaps/secrets with demo patterns
6. **Ansible Resources**: Runs standard Ansible cleanup

### 3. Standalone Unmanaged Cleanup

```bash
# Use the dedicated cleanup script directly
./scripts/cleanup-unmanaged-resources.sh

# Options:
./scripts/cleanup-unmanaged-resources.sh --dry-run
./scripts/cleanup-unmanaged-resources.sh --non-interactive
```

## What Gets Cleaned Up

### Demo Namespace (`mlops-demo`)
- **Pods**: Data generators, stream processors, training jobs
- **Jobs**: Kafka setup, Flink processing, ML training
- **Deployments**: Sensor data generators
- **ConfigMaps**: Demo scripts and configurations
- **Services**: Demo-specific services

### Completed Jobs (All Namespaces)
- Jobs with `status.successful=1`
- Associated pods and logs
- Temporary volumes and configs

### Failed Jobs (All Namespaces)
- Jobs with `status.failed=1`
- Stuck or errored job pods
- Cleanup prevents resource accumulation

### Dangling Pods
- Pods in `Succeeded` state
- Pods in `Failed` state
- Pods in `Error` state

### Temporary Resources
Pattern-based cleanup of:
- ConfigMaps: `demo-scripts`, `temp-*`, `test-*`, `*-demo-*`
- Secrets: Similar patterns (excluding system secrets)

### What's NOT Cleaned Up
- **Core Kubernetes resources**: `kube-system`, `kube-public`
- **System ConfigMaps**: `kube-root-ca.crt`
- **Bound PVCs**: Storage still in use
- **Running pods**: Active workloads

## Safety Features

### Dry Run Mode
```bash
# Preview cleanup without execution
./deploy.sh cleanup-all --dry-run
```

Shows:
- Resources that would be deleted
- Counts by resource type
- Estimated cleanup scope

### Interactive Confirmation
```bash
# Default behavior includes confirmation prompts
./deploy.sh cleanup-all

# Example output:
# This will remove ALL MLOps platform resources including:
#   - Ansible-managed infrastructure
#   - Demo namespaces and temporary resources
#   - Completed and failed jobs
#   - Dangling pods and temporary configs
# 
# Are you sure you want to continue? (y/N):
```

### Non-Interactive Mode
```bash
# Skip confirmations (for automation)
./deploy.sh cleanup-all --non-interactive
```

Use with caution in:
- CI/CD pipelines
- Automated testing
- Scheduled maintenance

## Troubleshooting

### Stuck Namespace Deletion
If namespaces are stuck in `Terminating` state:

```bash
# Check namespace status
kubectl get namespaces

# Force finalize namespace (use carefully)
kubectl patch namespace mlops-demo -p '{"metadata":{"finalizers":[]}}'
```

### PVC Warnings
Cleanup may report orphaned PVCs:
```
[WARN] Found potentially orphaned PVCs (not bound):
data-plane/data-0-mlops-kafka-cluster-broker-0
```

These are usually:
- Kafka/MinIO persistent storage
- Waiting for pods to restart
- Safe to ignore unless specifically problematic

### Permission Issues
Ensure your kubectl context has sufficient permissions:

```bash
# Check current context
kubectl config current-context

# Verify cluster admin access
kubectl auth can-i delete namespaces
kubectl auth can-i delete jobs --all-namespaces
```

## Recovery Scenarios

### Partial Cleanup Failure
If cleanup fails partway through:

1. **Check what remains**:
   ```bash
   kubectl get namespaces | grep -E "(data-plane|mlops-demo|orchestration)"
   kubectl get jobs --all-namespaces
   ```

2. **Re-run specific cleanup**:
   ```bash
   # Just unmanaged resources
   ./scripts/cleanup-unmanaged-resources.sh
   
   # Just Ansible resources
   ./deploy.sh cleanup
   ```

3. **Manual cleanup** if needed:
   ```bash
   kubectl delete namespace mlops-demo --force --grace-period=0
   kubectl delete jobs --all --all-namespaces
   ```

### Post-Cleanup Verification
After cleanup, verify the environment:

```bash
# Check remaining MLOps resources
kubectl get all --all-namespaces | grep -E "(kafka|minio|mlflow|airflow|flink|spark)"

# Verify only system namespaces remain
kubectl get namespaces

# Check for any stuck resources
kubectl get jobs,pods --all-namespaces | grep -E "(Completed|Failed|Error)"
```

## Best Practices

1. **Always dry-run first**: Use `--dry-run` to preview changes
2. **Backup important data**: Export ML models, datasets before cleanup
3. **Check dependencies**: Ensure no external services depend on resources
4. **Monitor progress**: Watch for stuck deletions or errors
5. **Verify completion**: Check final state after cleanup

## Automation Integration

### CI/CD Pipeline Example
```yaml
# Example GitHub Actions step
- name: Cleanup Test Environment
  run: |
    ./deploy.sh cleanup-all --non-interactive --dry-run
    if [ $? -eq 0 ]; then
      ./deploy.sh cleanup-all --non-interactive
    fi
```

### Scheduled Maintenance
```bash
#!/bin/bash
# cleanup-maintenance.sh
# Run weekly to clean up accumulated test resources

./scripts/cleanup-unmanaged-resources.sh --non-interactive
```

This comprehensive cleanup system ensures your Kubernetes cluster stays clean and doesn't accumulate unnecessary resources from MLOps experiments and demos.
