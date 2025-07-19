#!/bin/bash
# MLOps Demo Deployment and Execution Script
#
# This script deploys and runs the complete MLOps demonstration pipeline
# showcasing real-time data processing, stream analytics, and ML model training
# across the entire technology stack.

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEMO_NAMESPACE="mlops-demo"
DATA_GENERATION_DURATION=3600  # 1 hour
PROCESSING_DURATION=7200       # 2 hours

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if required namespaces exist
    local required_namespaces=("data-plane" "processing-jobs" "ml-lifecycle" "orchestration")
    for ns in "${required_namespaces[@]}"; do
        if ! kubectl get namespace "$ns" &> /dev/null; then
            error "Required namespace '$ns' does not exist"
            exit 1
        fi
    done
    
    success "Prerequisites check passed"
}

# Verify platform health
verify_platform_health() {
    log "Verifying MLOps platform health..."
    
    # Check operator deployments
    local operators=("strimzi-cluster-operator" "minio-operator" "spark-operator" "flink-kubernetes-operator")
    
    for operator in "${operators[@]}"; do
        if kubectl get deployment "$operator" -n platform-operators &> /dev/null; then
            local ready=$(kubectl get deployment "$operator" -n platform-operators -o jsonpath='{.status.readyReplicas}')
            local desired=$(kubectl get deployment "$operator" -n platform-operators -o jsonpath='{.spec.replicas}')
            
            if [[ "$ready" == "$desired" ]]; then
                success "$operator is healthy ($ready/$desired)"
            else
                warning "$operator is not fully ready ($ready/$desired)"
            fi
        else
            warning "$operator deployment not found"
        fi
    done
    
    # Check core services
    log "Checking core service health..."
    
    # Kafka
        local kafka_ready=$(kubectl get kafka mlops-kafka-cluster -n data-plane -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
        if [[ "$kafka_ready" == "True" ]]; then
            success "Kafka cluster is ready"
        else
            warning "Kafka cluster is not ready (status: $kafka_ready)"
        fi
    
    # MLflow
    if kubectl get service mlflow -n ml-lifecycle &> /dev/null; then
        if kubectl get endpoints mlflow -n ml-lifecycle -o jsonpath='{.subsets[0].addresses[0].ip}' &> /dev/null; then
            success "MLflow service is ready"
        else
            warning "MLflow service has no ready endpoints"
        fi
    fi
    
    # MinIO
    if kubectl get service minio -n data-plane &> /dev/null; then
        if kubectl get endpoints minio -n data-plane -o jsonpath='{.subsets[0].addresses[0].ip}' &> /dev/null; then
            success "MinIO service is ready"
        else
            warning "MinIO service has no ready endpoints"
        fi
    else
        warning "MinIO service not found"
    fi
}

# Create demo namespace and resources
setup_demo_environment() {
    log "Setting up demo environment..."
    
    # Create demo namespace
    kubectl create namespace "$DEMO_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ConfigMap with demo scripts
    kubectl create configmap demo-scripts \
        --from-file=generate_data.py=src/demo/generate_data.py \
        --from-file=process_streams.py=src/demo/process_streams.py \
        --from-file=train_model.py=src/demo/train_model.py \
        --from-file=requirements.txt=src/demo/requirements.txt \
        -n "$DEMO_NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create demo service account with necessary permissions
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mlops-demo-sa
  namespace: $DEMO_NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: mlops-demo-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: mlops-demo-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: mlops-demo-role
subjects:
- kind: ServiceAccount
  name: mlops-demo-sa
  namespace: $DEMO_NAMESPACE
EOF
    
    success "Demo environment setup complete"
}

# Create Kafka topics for the demo
create_kafka_topics() {
    log "Creating Kafka topics for demo..."
    
    # Create a job to set up Kafka topics
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: kafka-topic-setup
  namespace: $DEMO_NAMESPACE
spec:
  template:
    spec:
      serviceAccountName: mlops-demo-sa
      restartPolicy: OnFailure
      containers:
      - name: kafka-setup
        image: confluentinc/cp-kafka:7.4.0
        command:
        - sh
        - -c
        - |
          echo "Waiting for Kafka to be ready..."
          sleep 30
          
          # Create sensor data topic
          kafka-topics --bootstrap-server mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092 \\
              --create --if-not-exists \\
              --topic sensor-data \\
              --partitions 6 \\
              --replication-factor 3 \\
              --config retention.ms=86400000 \\
              --config compression.type=gzip
          
          # Create processed data topic
          kafka-topics --bootstrap-server mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092 \\
              --create --if-not-exists \\
              --topic processed-sensor-data \\
              --partitions 6 \\
              --replication-factor 3 \\
              --config retention.ms=86400000
          
          # Create metrics topic
          kafka-topics --bootstrap-server mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092 \\
              --create --if-not-exists \\
              --topic sensor-metrics \\
              --partitions 3 \\
              --replication-factor 3 \\
              --config retention.ms=604800000
          
          echo "Kafka topics created successfully"
          kafka-topics --bootstrap-server mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092 --list
EOF
    
    # Wait for job completion
    kubectl wait --for=condition=complete --timeout=300s job/kafka-topic-setup -n "$DEMO_NAMESPACE"
    success "Kafka topics created successfully"
}

# Start data generation
start_data_generation() {
    log "Starting sensor data generation..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sensor-data-generator
  namespace: $DEMO_NAMESPACE
  labels:
    app: sensor-data-generator
    component: data-generation
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sensor-data-generator
  template:
    metadata:
      labels:
        app: sensor-data-generator
        component: data-generation
    spec:
      serviceAccountName: mlops-demo-sa
      containers:
      - name: data-generator
        image: python:3.9-slim
        command:
        - sh
        - -c
        - |
          pip install kafka-python numpy pandas requests
          python /scripts/generate_data.py \\
              --kafka-servers mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092 \\
              --topic sensor-data \\
              --sensors 25 \\
              --interval 0.5 \\
              --duration $DATA_GENERATION_DURATION \\
              --anomaly-rate 0.08
        volumeMounts:
        - name: demo-scripts
          mountPath: /scripts
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1Gi
      volumes:
      - name: demo-scripts
        configMap:
          name: demo-scripts
EOF
    
    success "Data generation started - will run for ${DATA_GENERATION_DURATION} seconds"
}

# Start stream processing with Flink
start_stream_processing() {
    log "Starting Flink stream processing..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: flink-stream-processor
  namespace: $DEMO_NAMESPACE
spec:
  template:
    spec:
      serviceAccountName: mlops-demo-sa
      restartPolicy: OnFailure
      containers:
      - name: flink-processor
        image: flink:1.17.1-scala_2.12-java11
        command:
        - sh
        - -c
        - |
          # Install PyFlink and dependencies
          pip install apache-flink pandas boto3 requests
          
          # Download required JARs
          curl -L -o /opt/flink/lib/flink-sql-connector-kafka.jar \\
              https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/1.17.1/flink-sql-connector-kafka-1.17.1.jar
          
          curl -L -o /opt/flink/lib/flink-s3-fs-hadoop.jar \\
              https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-hadoop/1.17.1/flink-s3-fs-hadoop-1.17.1.jar
          
          # Configure S3/MinIO settings
          echo "s3.endpoint: http://minio.ml-lifecycle.svc.cluster.local:9000" >> /opt/flink/conf/flink-conf.yaml
          echo "s3.access-key: minioadmin" >> /opt/flink/conf/flink-conf.yaml
          echo "s3.secret-key: minioadmin123" >> /opt/flink/conf/flink-conf.yaml
          echo "s3.path.style.access: true" >> /opt/flink/conf/flink-conf.yaml
          
          # Run for specified duration
          timeout $PROCESSING_DURATION python /scripts/process_streams.py || echo "Processing completed"
        volumeMounts:
        - name: demo-scripts
          mountPath: /scripts
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 4Gi
      volumes:
      - name: demo-scripts
        configMap:
          name: demo-scripts
EOF
    
    success "Stream processing started - will run for ${PROCESSING_DURATION} seconds"
}

# Start ML model training
start_ml_training() {
    log "Starting ML model training..."
    
    # Wait for some data to be processed first
    log "Waiting 5 minutes for data to accumulate..."
    sleep 300
    
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ml-model-trainer
  namespace: $DEMO_NAMESPACE
spec:
  template:
    spec:
      serviceAccountName: mlops-demo-sa
      restartPolicy: OnFailure
      containers:
      - name: model-trainer
        image: python:3.9-slim
        command:
        - sh
        - -c
        - |
          pip install mlflow scikit-learn pandas numpy boto3 requests
          export MLFLOW_TRACKING_URI=http://mlflow.ml-lifecycle.svc.cluster.local:5000
          python /scripts/train_model.py
        volumeMounts:
        - name: demo-scripts
          mountPath: /scripts
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 4000m
            memory: 8Gi
      volumes:
      - name: demo-scripts
        configMap:
          name: demo-scripts
EOF
    
    success "ML training job started"
}

# Monitor demo progress
monitor_demo() {
    log "Monitoring demo progress..."
    
    # Monitor for 30 minutes or until all jobs complete
    local timeout=1800
    local elapsed=0
    local check_interval=30
    
    while [ $elapsed -lt $timeout ]; do
        echo ""
        log "Demo Status Check (${elapsed}s elapsed):"
        
        # Check data generation
        local data_gen_pods=$(kubectl get pods -n "$DEMO_NAMESPACE" -l app=sensor-data-generator --field-selector=status.phase=Running -o name | wc -l)
        if [ "$data_gen_pods" -gt 0 ]; then
            success "Data generation: RUNNING ($data_gen_pods pods)"
        else
            warning "Data generation: STOPPED"
        fi
        
        # Check stream processing
        local processing_jobs=$(kubectl get jobs -n "$DEMO_NAMESPACE" -l job-name=flink-stream-processor -o jsonpath='{.items[0].status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "Unknown")
        if [ "$processing_jobs" == "True" ]; then
            success "Stream processing: COMPLETED"
        elif kubectl get jobs -n "$DEMO_NAMESPACE" flink-stream-processor &>/dev/null; then
            success "Stream processing: RUNNING"
        else
            warning "Stream processing: NOT STARTED"
        fi
        
        # Check ML training
        local training_jobs=$(kubectl get jobs -n "$DEMO_NAMESPACE" -l job-name=ml-model-trainer -o jsonpath='{.items[0].status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "Unknown")
        if [ "$training_jobs" == "True" ]; then
            success "ML training: COMPLETED"
        elif kubectl get jobs -n "$DEMO_NAMESPACE" ml-model-trainer &>/dev/null; then
            success "ML training: RUNNING"
        else
            warning "ML training: NOT STARTED"
        fi
        
        # Check if all critical jobs are complete
        if [ "$processing_jobs" == "True" ] && [ "$training_jobs" == "True" ]; then
            success "All demo jobs completed successfully!"
            break
        fi
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
}

# Generate demo report
generate_demo_report() {
    log "Generating demo performance report..."
    
    local report_file="mlops_demo_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" <<EOF
# MLOps Platform Demo Report

**Generated:** $(date)
**Duration:** ${PROCESSING_DURATION} seconds
**Demo Namespace:** $DEMO_NAMESPACE

## Infrastructure Status

### Kubernetes Cluster
- **Cluster:** $(kubectl config current-context)
- **Nodes:** $(kubectl get nodes --no-headers | wc -l)
- **Platform Namespaces:** $(kubectl get namespaces | grep -E "(data-plane|processing-jobs|ml-lifecycle|orchestration)" | wc -l)/4

### Core Services Status
EOF
    
    # Check service statuses
    echo "### Service Health Checks" >> "$report_file"
    
    if kubectl get service mlflow -n ml-lifecycle &>/dev/null; then
        echo "- ✅ MLflow: AVAILABLE" >> "$report_file"
    else
        echo "- ❌ MLflow: NOT AVAILABLE" >> "$report_file"
    fi
    
    if kubectl get kafka mlops-kafka-cluster -n data-plane &>/dev/null; then
        echo "- ✅ Kafka: AVAILABLE" >> "$report_file"
    else
        echo "- ❌ Kafka: NOT AVAILABLE" >> "$report_file"
    fi
    
    if kubectl get service minio -n ml-lifecycle &>/dev/null; then
        echo "- ✅ MinIO: AVAILABLE" >> "$report_file"
    else
        echo "- ❌ MinIO: NOT AVAILABLE" >> "$report_file"
    fi
    
    # Demo execution results
    cat >> "$report_file" <<EOF

## Demo Execution Results

### Data Generation
$(kubectl get deployment sensor-data-generator -n "$DEMO_NAMESPACE" -o wide 2>/dev/null || echo "❌ Data generation deployment not found")

### Stream Processing
$(kubectl get job flink-stream-processor -n "$DEMO_NAMESPACE" -o wide 2>/dev/null || echo "❌ Stream processing job not found")

### ML Training
$(kubectl get job ml-model-trainer -n "$DEMO_NAMESPACE" -o wide 2>/dev/null || echo "❌ ML training job not found")

## Resource Utilization

### Demo Namespace Pods
\`\`\`
$(kubectl get pods -n "$DEMO_NAMESPACE" -o wide)
\`\`\`

### Events
\`\`\`
$(kubectl get events -n "$DEMO_NAMESPACE" --sort-by='.lastTimestamp' | tail -20)
\`\`\`

## Recommendations

1. **Data Quality**: Monitor sensor data quality and anomaly detection accuracy
2. **Performance**: Consider scaling processing resources based on data volume
3. **Model Management**: Implement automated model retraining pipelines
4. **Monitoring**: Set up comprehensive alerting for production workloads

---
*Report generated by MLOps Demo Pipeline*
EOF
    
    success "Demo report generated: $report_file"
    
    # Display summary
    echo ""
    log "Demo Summary:"
    echo "==============================================="
    cat "$report_file" | grep -E "^- [✅❌]"
    echo "==============================================="
}

# Cleanup demo resources
cleanup_demo() {
    log "Cleaning up demo resources..."
    
    # Delete demo deployments and jobs
    kubectl delete deployment sensor-data-generator -n "$DEMO_NAMESPACE" --ignore-not-found=true
    kubectl delete job flink-stream-processor -n "$DEMO_NAMESPACE" --ignore-not-found=true
    kubectl delete job ml-model-trainer -n "$DEMO_NAMESPACE" --ignore-not-found=true
    kubectl delete job kafka-topic-setup -n "$DEMO_NAMESPACE" --ignore-not-found=true
    
    # Optionally delete the demo namespace (uncomment if desired)
    # kubectl delete namespace "$DEMO_NAMESPACE"
    
    success "Demo cleanup completed"
}

# Main execution flow
main() {
    echo ""
    echo "🚀 MLOps Platform Demo Pipeline"
    echo "==============================="
    echo ""
    
    # Check if help was requested
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        cat <<EOF
MLOps Demo Deployment Script

This script deploys and runs a comprehensive MLOps demonstration pipeline
showcasing real-time data processing, stream analytics, and ML model training.

Usage: $0 [OPTIONS]

Options:
  --help, -h          Show this help message
  --skip-health       Skip platform health checks
  --duration SECONDS  Override processing duration (default: 7200)
  --cleanup-only      Only run cleanup (no deployment)

Demo Components:
  - Kafka data streaming with IoT sensor simulation
  - Flink real-time stream processing and feature engineering
  - MLflow model training with experiment tracking
  - MinIO data archival with partitioning
  - Comprehensive monitoring and reporting

Prerequisites:
  - Kubernetes cluster with MLOps platform deployed
  - kubectl configured with cluster access
  - Required namespaces: data-plane, processing-jobs, ml-lifecycle, orchestration

Examples:
  $0                          # Run full demo with default settings
  $0 --duration 3600         # Run demo for 1 hour
  $0 --cleanup-only          # Clean up previous demo runs
  $0 --skip-health           # Skip health checks and run demo
EOF
        exit 0
    fi
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-health)
                SKIP_HEALTH_CHECK=true
                shift
                ;;
            --duration)
                PROCESSING_DURATION="$2"
                shift 2
                ;;
            --cleanup-only)
                cleanup_demo
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Execute demo pipeline
    check_prerequisites
    
    if [[ "${SKIP_HEALTH_CHECK:-false}" != "true" ]]; then
        verify_platform_health
    fi
    
    setup_demo_environment
    create_kafka_topics
    start_data_generation
    start_stream_processing
    start_ml_training
    monitor_demo
    generate_demo_report
    
    echo ""
    success "🎉 MLOps Demo Pipeline completed successfully!"
    echo ""
    log "Next steps:"
    echo "  1. Review the generated demo report"
    echo "  2. Check MLflow UI for trained models: http://localhost:5000 (if port-forwarded)"
    echo "  3. Explore Grafana dashboards for monitoring metrics"
    echo "  4. Run '$0 --cleanup-only' to clean up demo resources"
    echo ""
}

# Execute main function with all arguments
main "$@"
