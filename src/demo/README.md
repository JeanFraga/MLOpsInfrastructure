# MLOps Platform Demo Guide

Welcome to the comprehensive MLOps Platform Demo! This guide showcases an end-to-end machine learning operations pipeline that demonstrates real-time data processing, stream analytics, and automated model training using modern cloud-native technologies.

## 🎯 Demo Overview

This demo simulates a real-world IoT sensor monitoring system with anomaly detection capabilities. It demonstrates:

- **Real-time Data Streaming**: Synthetic sensor data generation and Kafka publishing
- **Stream Processing**: Apache Flink for real-time feature engineering and anomaly detection
- **ML Model Training**: Automated training with MLflow experiment tracking
- **Orchestration**: Apache Airflow for end-to-end pipeline coordination
- **Storage**: MinIO for scalable artifact and data lake storage

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Data Generator │    │  Apache Kafka   │    │  Apache Flink   │
│  (generate_data) │───▶│   (Streaming)   │───▶│ (Stream Process)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
┌─────────────────┐    ┌─────────────────┐             │
│   Apache Airflow│    │     MLflow      │             │
│  (Orchestration)│───▶│ (ML Lifecycle)  │◀────────────┘
└─────────────────┘    └─────────────────┘
                                │
                       ┌─────────────────┐
                       │     MinIO       │
                       │ (Object Storage)│
                       └─────────────────┘
```

## 📁 Demo Components

### 1. `generate_data.py` - Data Generation Engine
**Purpose**: Simulates IoT sensor readings with realistic patterns and anomalies

**Key Features**:
- **Synthetic Data Generation**: Creates realistic temperature, humidity, and pressure readings
- **Temporal Patterns**: Implements daily cycles and seasonal trends
- **Anomaly Injection**: Randomly introduces 5% anomalous readings for ML training
- **Kafka Publishing**: Streams data to `sensor-data` topic in real-time

**Usage**:
```bash
# Generate streaming data for 1 hour with 1-second intervals
python generate_data.py --duration 3600 --interval 1

# Generate with custom anomaly rate
python generate_data.py --duration 1800 --anomaly-rate 0.08
```

**Data Schema**:
```json
{
  "sensor_id": "sensor_001",
  "event_time": "2025-07-13T10:30:00Z",
  "temperature": 23.45,
  "humidity": 42.1,
  "pressure": 1013.25,
  "comfort_index": 87.5,
  "location": "Building_A_Floor_2",
  "is_anomaly": false
}
```

### 2. `process_streams.py` - Real-time Stream Processing
**Purpose**: Processes sensor data streams using Apache Flink (PyFlink)

**Key Features**:
- **Real-time Processing**: Consumes from Kafka and processes data with sub-second latency
- **Windowed Aggregations**: Calculates rolling statistics over 5-minute windows
- **Feature Engineering**: Creates derived features for ML model consumption
- **Anomaly Detection**: Implements statistical outlier detection
- **Data Archival**: Stores processed data in MinIO for batch ML training

**Processing Pipeline**:
1. **Source**: Reads from `sensor-data` Kafka topic
2. **Transformation**: 
   - Parses JSON sensor readings
   - Calculates rolling averages and standard deviations
   - Computes z-scores for anomaly detection
   - Enriches with time-based features (hour, day-of-week)
3. **Sink**: Writes enriched data to MinIO (`sensor-archive` bucket)

**Flink SQL Operations**:
```sql
-- Example windowed aggregation
SELECT 
    sensor_id,
    TUMBLE_START(event_time, INTERVAL '5' MINUTE) as window_start,
    AVG(temperature) as avg_temp,
    STDDEV(temperature) as temp_stddev,
    COUNT(*) as reading_count
FROM sensor_stream
GROUP BY sensor_id, TUMBLE(event_time, INTERVAL '5' MINUTE)
```

### 3. `train_model.py` - ML Model Training Pipeline
**Purpose**: Automated machine learning model training with MLflow integration

**Key Features**:
- **Data Loading**: Fetches historical sensor data from MinIO
- **Feature Engineering**: Creates 25+ engineered features from raw sensor data
- **Multi-Model Training**: Trains both supervised and unsupervised anomaly detection models
- **Hyperparameter Tuning**: Grid search optimization for best model performance
- **MLflow Integration**: Comprehensive experiment tracking and model registry

**Supported Models**:
- **Supervised Models**:
  - Random Forest Classifier
  - Logistic Regression
- **Unsupervised Models**:
  - Isolation Forest
  - One-Class SVM

**Feature Engineering Pipeline**:
```python
# Time-based features
hour, day_of_week, is_weekend, is_business_hours

# Statistical features
temp_deviation, temp_rate_change, temp_zscore
humidity_deviation, pressure_deviation

# Rolling window features (5, 10, 20 minute windows)
temp_std_5, humidity_std_10, pressure_std_20

# Interaction features
temp_humidity_interaction, comfort_score
```

**MLflow Tracking**:
- **Experiments**: Organized by model type and training date
- **Metrics**: Accuracy, Precision, Recall, F1-score, ROC-AUC
- **Artifacts**: Model files, confusion matrices, classification reports
- **Model Registry**: Versioned model catalog with deployment stages

### 4. `mlops_demo_dag.py` - Airflow Orchestration
**Purpose**: Coordinates the entire MLOps pipeline using Apache Airflow

**Key Features**:
- **Task Dependencies**: Ensures proper execution order and error handling
- **Kubernetes Integration**: Uses KubernetesPodOperator for scalable execution
- **Health Monitoring**: Validates component health before pipeline execution
- **Error Recovery**: Implements retry logic and failure notifications

**DAG Structure**:
```
health_check → start_data_generation → start_stream_processing → train_models → deploy_models
     ↓              ↓                        ↓                      ↓              ↓
 validate_kafka → monitor_data_flow → validate_processing → evaluate_models → update_registry
```

**Task Details**:
1. **health_check**: Validates Kafka, MinIO, and MLflow connectivity
2. **start_data_generation**: Launches data generator pod
3. **start_stream_processing**: Deploys Flink job for stream processing
4. **train_models**: Triggers ML training pipeline
5. **deploy_models**: Promotes best model to production registry

## 🚀 Running the Demo

### Prerequisites
Ensure your MLOps platform is deployed and all components are healthy:

```bash
# Check platform status
kubectl get pods -n data-plane
kubectl get pods -n ml-lifecycle
kubectl get pods -n orchestration

# Validate connectivity
./scripts/validate-setup.sh
```

### Option 1: Automated Demo Execution
Run the comprehensive demo script:

```bash
# Execute the full demo pipeline
./scripts/run-mlops-demo.sh

# The script will:
# 1. Validate platform health
# 2. Start data generation
# 3. Launch stream processing
# 4. Monitor pipeline progress
# 5. Generate performance report
```

### Option 2: Manual Component Testing

#### Step 1: Test Data Generation
```bash
# Navigate to demo directory
cd src/demo

# Install requirements
pip install -r requirements.txt

# Start data generator (run in background)
python generate_data.py --duration 3600 --interval 1 &

# Monitor Kafka topic
kubectl exec -n data-plane mlops-kafka-cluster-controller-0 -- \
  kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic sensor-data \
  --from-beginning
```

#### Step 2: Deploy Stream Processing
```bash
# Deploy Flink job using kubectl
kubectl apply -f - <<EOF
apiVersion: flink.apache.org/v1beta1
kind: FlinkDeployment
metadata:
  name: sensor-stream-processor
  namespace: processing-jobs
spec:
  image: flink:1.17-scala_2.12-java11
  flinkVersion: v1_17
  flinkConfiguration:
    taskmanager.numberOfTaskSlots: "2"
    state.checkpoints.dir: "s3a://flink-checkpoints/"
    s3.endpoint: "http://minio.data-plane.svc.cluster.local:9000"
  serviceAccount: flink-job-runner
  jobManager:
    resource:
      memory: "2048m"
      cpu: 1
  taskManager:
    resource:
      memory: "2048m"
      cpu: 1
  job:
    jarURI: local:///opt/flink/usrlib/stream-processor.jar
    entryClass: "StreamProcessor"
    parallelism: 2
EOF
```

#### Step 3: Train ML Models
```bash
# Execute training pipeline
python train_model.py

# Monitor MLflow experiments
kubectl port-forward -n ml-lifecycle svc/mlflow 5000:5000
# Access MLflow UI at http://localhost:5000
```

#### Step 4: Trigger Airflow DAG
```bash
# Access Airflow UI
kubectl port-forward -n orchestration svc/airflow-webserver 8080:8080
# Login at http://localhost:8080 (admin/admin)

# Trigger the demo DAG
airflow dags trigger mlops_demo_pipeline
```

## 📊 Monitoring and Observability

### Key Metrics to Monitor

#### Data Generation Metrics
- **Throughput**: Messages/second published to Kafka
- **Anomaly Rate**: Percentage of anomalous readings generated
- **Topic Lag**: Kafka consumer lag for downstream processing

#### Stream Processing Metrics
- **Processing Latency**: Time from ingestion to output
- **Throughput**: Records processed per second
- **Checkpoint Duration**: State consistency and recovery time
- **Backpressure**: Queue buildup indicators

#### ML Training Metrics
- **Training Duration**: Time to complete model training
- **Model Performance**: Accuracy, F1-score, ROC-AUC
- **Feature Importance**: Top contributing features
- **Data Quality**: Missing values, outliers, distribution drift

### Accessing Monitoring Dashboards

```bash
# MLflow Experiments and Model Registry
kubectl port-forward -n ml-lifecycle svc/mlflow 5000:5000
# http://localhost:5000

# Airflow Pipeline Monitoring
kubectl port-forward -n orchestration svc/airflow-webserver 8080:8080
# http://localhost:8080

# Flink Job Monitoring
kubectl port-forward -n processing-jobs svc/sensor-stream-processor-rest 8081:8081
# http://localhost:8081

# MinIO Object Browser
kubectl port-forward -n data-plane svc/minio-console 9001:9001
# http://localhost:9001
```

## 🔍 Demo Scenarios and Use Cases

### Scenario 1: Normal Operations Monitoring
**Objective**: Demonstrate steady-state operations with normal sensor readings

**Steps**:
1. Generate data with low anomaly rate (2%)
2. Monitor real-time processing latency
3. Observe model predictions and confidence scores
4. Validate data archival in MinIO

**Expected Results**:
- Processing latency < 100ms
- 98% of readings classified as normal
- Continuous data flow to archive buckets

### Scenario 2: Anomaly Detection and Alerting
**Objective**: Test system response to sudden anomaly bursts

**Steps**:
1. Inject high anomaly rate (20%) for 10 minutes
2. Monitor anomaly detection algorithms
3. Validate alerting mechanisms
4. Observe model retraining triggers

**Expected Results**:
- Real-time anomaly detection with < 1-second latency
- Automated alerts for anomaly rate threshold breach
- Model retraining triggered for significant distribution shift

### Scenario 3: Scale Testing
**Objective**: Validate system performance under high load

**Steps**:
1. Scale data generators to 100 messages/second
2. Monitor Kafka partition utilization
3. Scale Flink job parallelism
4. Observe system resource consumption

**Expected Results**:
- Linear scaling with increased parallelism
- Stable processing latency under load
- Successful auto-scaling of Kubernetes pods

## 🛠️ Troubleshooting Guide

### Common Issues and Solutions

#### Data Generator Not Producing Messages
```bash
# Check Kafka connectivity
kubectl exec -n data-plane mlops-kafka-cluster-controller-0 -- \
  kafka-topics.sh --bootstrap-server localhost:9092 --list

# Verify topic exists
kubectl exec -n data-plane mlops-kafka-cluster-controller-0 -- \
  kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic sensor-data

# Check producer logs
kubectl logs -n processing-jobs -l app=data-generator
```

#### Flink Job Failing to Start
```bash
# Check Flink deployment status
kubectl get flinkdeployment -n processing-jobs

# View job manager logs
kubectl logs -n processing-jobs -l app=sensor-stream-processor,component=jobmanager

# Verify S3 connectivity to MinIO
kubectl exec -n processing-jobs deployment/sensor-stream-processor-jobmanager -- \
  curl -I http://minio.data-plane.svc.cluster.local:9000/minio/health/live
```

#### MLflow Training Pipeline Errors
```bash
# Check MLflow server status
kubectl get pods -n ml-lifecycle

# View training logs
kubectl logs -n processing-jobs -l app=ml-training

# Verify MinIO bucket access
kubectl exec -n ml-lifecycle deployment/mlflow -- \
  python -c "import boto3; s3=boto3.client('s3', endpoint_url='http://minio.data-plane.svc.cluster.local:9000'); print(s3.list_buckets())"
```

#### Airflow DAG Not Triggering
```bash
# Check Airflow scheduler status
kubectl get pods -n orchestration -l component=scheduler

# View DAG import errors
kubectl logs -n orchestration -l component=scheduler | grep ERROR

# Verify DAG file sync from Git
kubectl logs -n orchestration -l component=git-sync
```

## 📈 Performance Benchmarks

### Expected Performance Metrics

| Component | Metric | Target | Notes |
|-----------|--------|--------|-------|
| Data Generator | Throughput | 1000 msg/sec | Single pod capacity |
| Kafka | Latency | < 10ms | End-to-end publish latency |
| Flink Processing | Latency | < 100ms | Stream processing latency |
| ML Training | Duration | < 10 minutes | 10k samples, 3 models |
| Model Inference | Latency | < 50ms | Single prediction time |

### Scaling Guidelines

#### Horizontal Scaling
- **Data Generators**: Scale pods linearly with throughput requirements
- **Flink Jobs**: Increase parallelism based on Kafka partition count
- **ML Training**: Use distributed training for large datasets (>1M samples)

#### Resource Allocation
- **Memory**: 4GB per Flink TaskManager for complex windowing operations
- **CPU**: 2 cores per data generator for sustained 1000 msg/sec
- **Storage**: 100GB MinIO per million sensor readings

## 🎓 Learning Outcomes

After completing this demo, you will understand:

1. **Stream Processing Patterns**: Real-time data ingestion, transformation, and storage
2. **MLOps Best Practices**: Experiment tracking, model versioning, and automated training
3. **Kubernetes Orchestration**: Cloud-native deployment and scaling strategies
4. **Data Pipeline Design**: Building resilient, fault-tolerant data systems
5. **Monitoring and Observability**: Comprehensive system health tracking

## 🔗 Additional Resources

### Documentation Links
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Apache Flink PyFlink Guide](https://nightlies.apache.org/flink/flink-docs-release-1.17/docs/dev/python/)
- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)
- [Apache Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/)

### Platform-Specific Guides
- [Strimzi Kafka Operator](https://strimzi.io/docs/operators/latest/overview.html)
- [Flink Kubernetes Operator](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.5/)
- [MinIO Kubernetes Documentation](https://min.io/docs/minio/kubernetes/upstream/)

### Extended Examples
```bash
# View additional examples in the platform repository
ls -la ../examples/
# - advanced-streaming/
# - model-deployment/
# - production-configs/
```

---

**🎉 Congratulations!** You've completed the MLOps Platform Demo. This hands-on experience demonstrates production-ready patterns for building scalable, automated machine learning systems using modern cloud-native technologies.

For questions or support, refer to the main project documentation or reach out to the MLOps platform team.
