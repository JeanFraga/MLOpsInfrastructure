# MLOps Platform Operations Guide

## 🎯 Daily Operations

This guide provides practical instructions for operating and maintaining the MLOps platform on a day-to-day basis.

## 📊 Platform Monitoring Dashboard

### Quick Health Check Commands

```bash
# Overall platform status (run this first)
kubectl get namespaces | grep -E "(platform-operators|data-plane|orchestration|ml-lifecycle|processing-jobs|flux-system)"

# GitOps health check
kubectl get kustomization -n flux-system
kubectl get gitrepository -n flux-system

# Core services status
kubectl get pods -n platform-operators
kubectl get pods -n data-plane
kubectl get pods -n flux-system

# Resource usage overview
kubectl top nodes
kubectl top pods -A --sort-by=memory
```

### Automated Health Check Script

```bash
#!/bin/bash
# Save as: scripts/health-check.sh

echo "🔍 MLOps Platform Health Check $(date)"
echo "================================================"

# Check GitOps status
echo "📋 GitOps Status:"
kubectl get gitrepository -n flux-system --no-headers | while read line; do
  echo "  ✓ $line"
done

echo ""
echo "📋 Kustomization Status:"
kubectl get kustomization -n flux-system --no-headers | while read line; do
  echo "  ✓ $line"
done

# Check operators
echo ""
echo "🔧 Platform Operators:"
kubectl get deployments -n platform-operators --no-headers | while read name ready uptodate available age; do
  if [[ "$ready" == "$available" ]] && [[ "$available" != "0" ]]; then
    echo "  ✅ $name ($ready/$available ready)"
  else
    echo "  ❌ $name ($ready/$available ready)"
  fi
done

# Check data services
echo ""
echo "💾 Data Services:"
kubectl get pods -n data-plane --no-headers | while read name ready status restarts age; do
  if [[ "$status" == "Running" ]]; then
    echo "  ✅ $name ($status)"
  else
    echo "  ❌ $name ($status)"
  fi
done

echo ""
echo "📈 Resource Usage:"
kubectl top nodes --no-headers | while read name cpu_percent cpu_abs memory_percent memory_abs; do
  echo "  📊 $name: CPU $cpu_percent, Memory $memory_percent"
done
```

## 🔄 Common Operations

### 1. Deploying New Components

#### Adding a New Operator

**Step 1: Create the HelmRelease**
```bash
# Create new operator configuration
cat > gitops/components/redis-operator.yaml << 'EOF'
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: redis-operator
  namespace: platform-operators
  labels:
    app.kubernetes.io/name: redis-operator
    app.kubernetes.io/component: operators
spec:
  interval: 5m
  chart:
    spec:
      chart: redis-operator
      version: "1.2.4"
      sourceRef:
        kind: HelmRepository
        name: redis-repo
        namespace: flux-system
  values:
    replicaCount: 1
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
EOF
```

**Step 2: Add Helm Repository (if needed)**
```bash
cat > gitops/components/redis-repo.yaml << 'EOF'
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: redis-repo
  namespace: flux-system
spec:
  interval: 5m
  url: https://charts.redis.com/
EOF
```

**Step 3: Update Kustomization**
```bash
# Add to gitops/components/kustomization.yaml
echo "  - redis-operator.yaml" >> gitops/components/kustomization.yaml
echo "  - redis-repo.yaml" >> gitops/components/kustomization.yaml
```

**Step 4: Deploy via GitOps**
```bash
git add gitops/components/
git commit -m "Add Redis operator for session management"
git push origin main

# Monitor deployment
kubectl get kustomization -n flux-system -w
```

#### Adding a New Application Instance

**Example: Deploy Kafka Cluster**
```bash
# Check if operator is ready
kubectl get deployment strimzi-cluster-operator -n platform-operators

# Apply Kafka cluster manifest
kubectl apply -f infrastructure/manifests/kafka/kafka-cluster.yaml

# Monitor cluster creation
kubectl get kafka -n data-plane -w
kubectl describe kafka mlops-kafka-cluster -n data-plane
```

### 2. Updating Component Versions

#### Updating Operator Versions
```bash
# Find current version
grep -r "version:" gitops/components/strimzi-operator.yaml

# Update to new version
sed -i 's/version: "0.43.0"/version: "0.44.0"/' gitops/components/strimzi-operator.yaml

# Commit and push
git add gitops/components/strimzi-operator.yaml
git commit -m "Update Strimzi operator to v0.44.0"
git push origin main

# Monitor update
kubectl get helmrelease strimzi-kafka-operator -n platform-operators -w
```

#### Updating Application Versions
```bash
# Update Kafka version in cluster manifest
sed -i 's/version: 3.7.0/version: 3.8.0/' infrastructure/manifests/kafka/kafka-cluster.yaml

# Apply update
kubectl apply -f infrastructure/manifests/kafka/kafka-cluster.yaml

# Monitor rolling update
kubectl get kafka mlops-kafka-cluster -n data-plane -o yaml | grep -A 10 status
```

### 3. Scaling Operations

#### Scaling Kafka Cluster
```bash
# Edit Kafka cluster configuration
kubectl edit kafka mlops-kafka-cluster -n data-plane

# Or update the manifest file
sed -i 's/replicas: 3/replicas: 5/' infrastructure/manifests/kafka/kafka-cluster.yaml
kubectl apply -f infrastructure/manifests/kafka/kafka-cluster.yaml

# Monitor scaling
kubectl get pods -n data-plane -l strimzi.io/name=mlops-kafka-cluster-kafka -w
```

#### Scaling MinIO Tenant
```bash
# Scale MinIO servers
kubectl edit tenant minio-tenant -n data-plane

# Monitor scaling
kubectl get pods -n data-plane -l v1.min.io/tenant=minio-tenant -w
```

## 🐛 Troubleshooting Playbook

### GitOps Issues

#### Issue: GitRepository Not Syncing
```bash
# Check GitRepository status
kubectl describe gitrepository mlops-infrastructure -n flux-system

# Common solutions:
# 1. Force reconciliation
flux reconcile source git mlops-infrastructure

# 2. Check repository accessibility
curl -I https://github.com/YourUser/MLOpsInfrastructure

# 3. Restart source controller
kubectl rollout restart deployment source-controller -n flux-system
```

#### Issue: Kustomization Failing
```bash
# Check Kustomization status
kubectl describe kustomization mlops-platform-base -n flux-system

# View controller logs
kubectl logs -n flux-system -l app=kustomize-controller --tail=50

# Test locally
kustomize build gitops/base/

# Common fixes:
# 1. Validate YAML syntax
yamllint gitops/base/*.yaml

# 2. Check for missing CRDs
kubectl get crd | grep -E "(kafka|minio|spark)"

# 3. Verify dependencies
kubectl get kustomization -n flux-system
```

### Operator Issues

#### Issue: Strimzi Operator Not Ready
```bash
# Check operator deployment
kubectl describe deployment strimzi-cluster-operator -n platform-operators

# Check operator logs
kubectl logs -n platform-operators -l name=strimzi-cluster-operator

# Verify CRDs are installed
kubectl get crd | grep kafka

# Common solutions:
# 1. Restart operator
kubectl rollout restart deployment strimzi-cluster-operator -n platform-operators

# 2. Check RBAC permissions
kubectl describe clusterrolebinding strimzi-cluster-operator
```

#### Issue: Kafka Cluster Stuck in Creation
```bash
# Check Kafka resource status
kubectl describe kafka mlops-kafka-cluster -n data-plane

# Check operator logs for specific cluster
kubectl logs -n platform-operators -l name=strimzi-cluster-operator | grep mlops-kafka-cluster

# Check pod events
kubectl get events -n data-plane --sort-by='.lastTimestamp'

# Common causes and solutions:
# 1. Insufficient resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# 2. Storage class issues
kubectl get storageclass
kubectl describe pvc -n data-plane

# 3. Network policies blocking communication
kubectl get networkpolicy -A
```

### Application Issues

#### Issue: Kafka Cluster Performance Problems
```bash
# Check Kafka metrics
kubectl exec -n data-plane mlops-kafka-cluster-kafka-0 -- bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092

# Check disk usage
kubectl exec -n data-plane mlops-kafka-cluster-kafka-0 -- df -h

# Check network connectivity
kubectl exec -n data-plane mlops-kafka-cluster-kafka-0 -- netstat -tlnp

# Performance tuning:
# 1. Increase broker resources
kubectl edit kafka mlops-kafka-cluster -n data-plane
# Modify spec.kafka.resources

# 2. Optimize storage
# Check if using SSDs, increase storage size
```

#### Issue: MinIO Tenant Access Problems
```bash
# Check MinIO tenant status
kubectl describe tenant minio-tenant -n data-plane

# Check MinIO console accessibility
kubectl get service -n data-plane | grep minio

# Test MinIO API connectivity
kubectl port-forward -n data-plane svc/minio-tenant-hl 9000:9000 &
curl http://localhost:9000/minio/health/live

# Common solutions:
# 1. Check service configuration
kubectl describe service minio-tenant-hl -n data-plane

# 2. Verify credentials
kubectl get secret minio-root-user-secret -n data-plane -o yaml

# 3. Check ingress configuration
kubectl describe ingress -n data-plane
```

## 📊 Monitoring & Alerting

### Setting Up Monitoring Stack

```bash
# Deploy Prometheus and Grafana
kubectl apply -f gitops/components/observability/

# Wait for deployment
kubectl wait --for=condition=ready pod -l app=prometheus -n observability --timeout=300s
kubectl wait --for=condition=ready pod -l app=grafana -n observability --timeout=300s

# Access Grafana
kubectl port-forward -n observability svc/grafana 3000:3000

# Default credentials: admin/admin (change immediately)
```

### Key Metrics to Monitor

#### Platform Health Metrics
```bash
# GitOps metrics
flux_source_conditions{type="Ready"}
flux_kustomization_conditions{type="Ready"}
flux_helmrelease_conditions{type="Ready"}

# Operator metrics
up{job="strimzi-operator"}
up{job="minio-operator"}
up{job="spark-operator"}

# Kafka metrics
kafka_server_brokertopicmetrics_bytesinpersec
kafka_server_brokertopicmetrics_bytesoutpersec
kafka_controller_kafkacontroller_activecontrollercount

# MinIO metrics
minio_cluster_capacity_total_bytes
minio_cluster_capacity_usable_bytes
minio_heal_objects_total
```

#### Setting Up Alerts

```yaml
# Create alerting rules
# Save as: monitoring/alerts/mlops-platform-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mlops-platform-alerts
  namespace: observability
spec:
  groups:
  - name: mlops.platform
    rules:
    - alert: GitOpsSourceNotReady
      expr: flux_source_conditions{type="Ready"} == 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "GitOps source {{ $labels.name }} is not ready"
        
    - alert: KafkaClusterDown
      expr: up{job="kafka-exporter"} == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Kafka cluster is down"
        
    - alert: MinIOHighDiskUsage
      expr: minio_cluster_capacity_usable_bytes / minio_cluster_capacity_total_bytes < 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "MinIO disk usage above 90%"
```

### Performance Monitoring

#### Resource Usage Monitoring
```bash
# Create monitoring script
cat > scripts/resource-monitor.sh << 'EOF'
#!/bin/bash
echo "📊 Resource Usage Report $(date)"
echo "================================"

echo "🔧 Node Resources:"
kubectl top nodes

echo ""
echo "💾 Storage Usage:"
kubectl get pv -o custom-columns=NAME:.metadata.name,SIZE:.spec.capacity.storage,USED:.status.phase,STORAGECLASS:.spec.storageClassName

echo ""
echo "🚀 Top CPU Consumers:"
kubectl top pods -A --sort-by=cpu | head -10

echo ""
echo "💭 Top Memory Consumers:"
kubectl top pods -A --sort-by=memory | head -10

echo ""
echo "📈 Namespace Resource Usage:"
kubectl top pods -A | awk '{if(NR>1) print $1}' | sort | uniq -c | sort -nr
EOF

chmod +x scripts/resource-monitor.sh
```

## 🔐 Security Operations

### Regular Security Checks

#### 1. Check for Security Updates
```bash
# Check for operator updates
helm repo update
helm search repo strimzi --versions | head -5
helm search repo minio-operator --versions | head -5

# Check for base image updates
kubectl get pods -A -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort | uniq
```

#### 2. Validate RBAC Configuration
```bash
# Audit service account permissions
kubectl auth can-i --list --as=system:serviceaccount:processing-jobs:spark-job-runner

# Check for overprivileged accounts
kubectl get clusterrolebinding -o jsonpath='{.items[?(@.roleRef.name=="cluster-admin")].subjects[*].name}'

# Review network policies
kubectl get networkpolicy -A
```

#### 3. Secret Management Audit
```bash
# List all secrets
kubectl get secrets -A

# Check for hardcoded secrets in manifests
grep -r "password\|secret\|key" gitops/ --exclude-dir=.git

# Verify secret rotation dates
kubectl get secrets -A -o jsonpath='{.items[*].metadata.creationTimestamp}' | tr ' ' '\n' | sort
```

## 📋 Maintenance Procedures

### Weekly Maintenance Tasks

#### 1. Platform Health Review
```bash
# Run comprehensive health check
./scripts/health-check.sh > weekly-health-$(date +%Y%m%d).log

# Review GitOps status
kubectl get gitrepository,kustomization,helmrelease -A

# Check for stuck resources
kubectl get pods -A | grep -E "(Pending|Error|CrashLoopBackOff)"
```

#### 2. Update Management
```bash
# Check for available updates
helm repo update

# Review security advisories
# Check operator project pages for security updates

# Plan update windows
# Schedule updates during low-usage periods
```

#### 3. Backup Verification
```bash
# Verify GitOps configuration backup
git log --oneline -10

# Check persistent volume snapshots
kubectl get volumesnapshot -A

# Test restore procedures (in development environment)
```

### Monthly Maintenance Tasks

#### 1. Performance Review
```bash
# Generate performance report
./scripts/resource-monitor.sh > monthly-performance-$(date +%Y%m).log

# Review resource requests and limits
kubectl get pods -A -o jsonpath='{.items[*].spec.containers[*].resources}' | jq .

# Capacity planning review
kubectl describe nodes | grep -A 5 "Allocated resources"
```

#### 2. Security Audit
```bash
# Run security scan
kubectl get pods -A -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort | uniq > images.txt
# Use trivy or similar tool to scan images

# Review access logs
kubectl logs -n flux-system -l app=source-controller | grep -i error

# Update security policies if needed
```

## 🚨 Emergency Procedures

### GitOps System Recovery

#### If Flux CD is Completely Down
```bash
# 1. Reinstall Flux CD
kubectl delete namespace flux-system
./scripts/bootstrap-gitops-latest.sh

# 2. Verify recovery
kubectl get pods -n flux-system
kubectl get kustomization -n flux-system
```

#### If Repository Access is Lost
```bash
# 1. Suspend GitOps temporarily
kubectl patch gitrepository mlops-infrastructure -n flux-system -p '{"spec":{"suspend":true}}'

# 2. Apply critical resources manually
kubectl apply -f gitops/base/
kubectl apply -f gitops/components/

# 3. Fix repository access and resume
kubectl patch gitrepository mlops-infrastructure -n flux-system -p '{"spec":{"suspend":false}}'
```

### Data Service Recovery

#### Kafka Cluster Recovery
```bash
# 1. Check cluster status
kubectl get kafka mlops-kafka-cluster -n data-plane

# 2. If cluster is corrupted, backup topics
kubectl exec -n data-plane mlops-kafka-cluster-kafka-0 -- bin/kafka-topics.sh --bootstrap-server localhost:9092 --list > kafka-topics-backup.txt

# 3. Delete and recreate cluster
kubectl delete kafka mlops-kafka-cluster -n data-plane
kubectl apply -f infrastructure/manifests/kafka/kafka-cluster.yaml

# 4. Restore topics and data from backups
```

#### MinIO Recovery
```bash
# 1. Check tenant status
kubectl get tenant minio-tenant -n data-plane

# 2. If data corruption is suspected
kubectl exec -n data-plane minio-tenant-ss-0-0 -- mc admin heal minio

# 3. For complete recovery
# Restore from backup storage or replicas
```

---

This operations guide provides the practical knowledge needed for day-to-day platform management, troubleshooting, and maintenance. Keep it handy for quick reference during operations.
