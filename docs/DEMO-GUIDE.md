# MLOps Platform Demo - Real-Time Data Processing Pipeline

This comprehensive demonstration showcases the complete MLOps platform capabilities using a real-time sensor data processing pipeline that integrates all major components: Kafka, Flink, MLflow, MinIO, and Airflow.

## Demo Overview

The demo simulates an IoT sensor monitoring system that:
1. **Generates** synthetic sensor data with realistic patterns and anomalies
2. **Streams** data through Kafka for real-time processing
3. **Processes** streams with PyFlink for feature engineering and aggregation
4. **Stores** processed data in MinIO with proper partitioning
5. **Trains** ML models for anomaly detection using MLflow
6. **Orchestrates** the entire pipeline with Airflow
7. **Monitors** performance and generates comprehensive reports

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Data Source   │───▶│      Kafka      │───▶│      Flink      │
│  IoT Sensors    │    │   Streaming     │    │   Processing    │
│  (Simulated)    │    │   Platform      │    │    Engine       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     MLflow      │◀───│     MinIO       │◀───│   Processed     │
│   ML Tracking   │    │  Data Storage   │    │     Data        │
│   & Registry    │    │   & Archive     │    │   & Features    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                        │
        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐
│    Airflow      │    │   Monitoring    │
│  Orchestration  │    │   & Alerting    │
│   & Workflow    │    │   (Grafana)     │
└─────────────────┘    └─────────────────┘
```

## Components Demonstrated

### 1. Data Generation (`generate_data.py`)
- **Purpose**: Simulates realistic IoT sensor readings
- **Features**:
  - Time-series data with daily patterns and seasonality
  - Multiple sensor types (temperature, humidity, pressure)
  - Configurable anomaly injection (5-15% rate)
  - Realistic device metadata and location information
  - Kafka producer with optimized settings

### 2. Stream Processing (`process_streams.py`)
- **Purpose**: Real-time data processing with PyFlink
- **Features**:
  - Kafka source and sink connectors
  - Feature engineering and transformation
  - Windowed aggregations for metrics
  - MinIO/S3 integration for data archival
  - Watermark handling for event-time processing

### 3. ML Training (`train_model.py`)
- **Purpose**: Automated model training with MLflow integration
- **Features**:
  - Multiple algorithm comparison (Random Forest, Logistic Regression, Isolation Forest)
  - Hyperparameter tuning with GridSearchCV
  - Comprehensive metric logging
  - Model registry and versioning
  - Feature engineering pipeline

### 4. Orchestration (`mlops_demo_dag.py`)
- **Purpose**: End-to-end workflow orchestration with Airflow
- **Features**:
  - Health checks and validation
  - Task dependencies and error handling
  - KubernetesPodOperator for scalable execution
  - Comprehensive monitoring and reporting

## Quick Start

### Prerequisites
1. **Kubernetes cluster** with MLOps platform deployed
2. **kubectl** configured with cluster access
3. **Required namespaces**: data-plane, processing-jobs, ml-lifecycle, orchestration

### Running the Demo

```bash
# 1. Navigate to the project directory
cd "/Users/jeanfraga/Library/CloudStorage/GoogleDrive-fragajean7@gmail.com/My Drive/Github/MLOPS Helm Charts"

# 2. Run the complete demo pipeline
./scripts/run-mlops-demo.sh

# 3. Optional: Run with custom duration (1 hour)
./scripts/run-mlops-demo.sh --duration 3600

# 4. View help for all options
./scripts/run-mlops-demo.sh --help
```

### Manual Component Testing

#### 1. Test Data Generation
```bash
# Install dependencies
pip install kafka-python numpy pandas

# Run data generator
python src/demo/generate_data.py \
    --kafka-servers localhost:9092 \
    --topic sensor-data \
    --sensors 10 \
    --interval 1.0 \
    --duration 300 \
    --anomaly-rate 0.05
```

#### 2. Test Stream Processing
```bash
# Install PyFlink
pip install apache-flink pandas boto3

# Run stream processor
python src/demo/process_streams.py
```

#### 3. Test ML Training
```bash
# Install ML dependencies
pip install -r src/demo/requirements.txt

# Set MLflow tracking URI
export MLFLOW_TRACKING_URI=http://localhost:5000

# Run training
python src/demo/train_model.py
```

## Demo Data Flow

### 1. Sensor Data Generation
```json
{
  "sensor_id": "sensor_001",
  "timestamp": "2025-07-13T15:30:00.000Z",
  "temperature": 24.5,
  "humidity": 45.2,
  "pressure": 1013.8,
  "is_anomaly": false,
  "location": {
    "building": "Building_001",
    "floor": 3,
    "room": "Room_301"
  },
  "device_info": {
    "model": "SensorPro-X1",
    "firmware_version": "v2.1.3",
    "battery_level": 85
  }
}
```

### 2. Feature Engineering
The Flink processor adds derived features:
- **Temporal**: hour, day_of_week, is_weekend, is_business_hours
- **Statistical**: rolling means, standard deviations, rate of change
- **Domain-specific**: comfort_index, anomaly_score, trend categories
- **Cross-features**: temperature-humidity interactions

### 3. ML Model Pipeline
```python
# Supervised Models
- RandomForestClassifier: High interpretability, handles non-linear patterns
- LogisticRegression: Baseline linear model, fast inference

# Unsupervised Models  
- IsolationForest: Anomaly detection without labels
- OneClassSVM: Robust outlier detection

# Evaluation Metrics
- Precision, Recall, F1-Score for classification
- ROC-AUC for probability-based models
- Confusion matrices and classification reports
```

## Expected Results

### Data Generation
- **Volume**: 25 sensors × 2 readings/second × duration
- **Anomaly Rate**: ~8% of total readings
- **Data Quality**: Realistic patterns with noise and trends

### Stream Processing
- **Throughput**: 50+ events/second processing
- **Latency**: <5 seconds end-to-end processing
- **Storage**: Partitioned data in MinIO by date/hour

### ML Training
- **Models**: 4 different algorithms trained and compared
- **Performance**: F1 scores >0.7 for supervised models
- **Registry**: Models registered in MLflow with full lineage

### Infrastructure
- **Reliability**: >99% uptime for all services
- **Scalability**: Auto-scaling based on load
- **Monitoring**: Full observability stack operational

## Monitoring and Observability

### Metrics Available
1. **Data Metrics**:
   - Message throughput and latency
   - Data quality scores
   - Anomaly detection rates

2. **Processing Metrics**:
   - Flink job performance
   - Resource utilization
   - Checkpoint success rates

3. **ML Metrics**:
   - Model accuracy and performance
   - Training duration and resource usage
   - Model drift detection

### Dashboards
- **Grafana**: Real-time operational metrics
- **MLflow**: Experiment tracking and model registry
- **Airflow**: Pipeline execution monitoring

## Troubleshooting

### Common Issues

#### 1. Kafka Connection Issues
```bash
# Check Kafka cluster status
kubectl get kafka mlops-kafka-cluster -n data-plane

# Verify Kafka topics
kubectl exec -it mlops-kafka-cluster-kafka-0 -n data-plane -- \
    kafka-topics --bootstrap-server localhost:9092 --list
```

#### 2. Flink Job Failures
```bash
# Check Flink cluster status
kubectl get pods -n processing-jobs | grep flink

# View Flink logs
kubectl logs -n processing-jobs -l app=flink-jobmanager
```

#### 3. MLflow Connection Issues
```bash
# Check MLflow service
kubectl get service mlflow -n ml-lifecycle

# Port forward for local access
kubectl port-forward service/mlflow 5000:5000 -n ml-lifecycle
```

#### 4. MinIO Storage Issues
```bash
# Check MinIO status
kubectl get service minio -n ml-lifecycle

# Access MinIO console
kubectl port-forward service/minio-console 9001:9001 -n ml-lifecycle
```

### Performance Tuning

#### 1. Increase Data Generation Rate
```bash
# Modify the demo script parameters
./scripts/run-mlops-demo.sh --duration 7200
```

#### 2. Scale Flink Processing
```bash
# Increase parallelism in process_streams.py
table_env.get_config().set("parallelism.default", "4")
```

#### 3. Optimize ML Training
```bash
# Use more cores for training
# Modify train_model.py GridSearchCV n_jobs parameter
GridSearchCV(..., n_jobs=4)
```

## Demo Cleanup

### Automatic Cleanup
```bash
# Clean up demo resources
./scripts/run-mlops-demo.sh --cleanup-only
```

### Manual Cleanup
```bash
# Delete demo namespace (if needed)
kubectl delete namespace mlops-demo

# Clean up Kafka topics (optional)
kubectl exec -it mlops-kafka-cluster-kafka-0 -n data-plane -- \
    kafka-topics --bootstrap-server localhost:9092 --delete --topic sensor-data
```

## Extending the Demo

### 1. Add New Data Sources
- Modify `generate_data.py` to include additional sensor types
- Update Flink processing schema in `process_streams.py`
- Extend feature engineering pipeline

### 2. Advanced ML Models
- Add deep learning models (TensorFlow/PyTorch)
- Implement online learning capabilities
- Add model explainability features

### 3. Real-time Inference
- Deploy models as REST APIs
- Implement model serving with Seldon Core
- Add A/B testing capabilities

### 4. Enhanced Monitoring
- Add custom metrics and alerts
- Implement data quality monitoring
- Create business KPI dashboards

## Best Practices Demonstrated

### 1. Data Engineering
- ✅ Schema evolution and versioning
- ✅ Data partitioning and compression
- ✅ Error handling and data validation
- ✅ Scalable stream processing

### 2. ML Engineering
- ✅ Experiment tracking and reproducibility
- ✅ Model versioning and registry
- ✅ Automated hyperparameter tuning
- ✅ Comprehensive model evaluation

### 3. DevOps/MLOps
- ✅ Infrastructure as Code
- ✅ Container orchestration
- ✅ CI/CD pipeline integration
- ✅ Comprehensive monitoring

### 4. Security
- ✅ Service account permissions
- ✅ Network policies
- ✅ Secret management
- ✅ Access control

## Next Steps

After running this demo successfully, consider:

1. **Production Deployment**: Scale the pipeline for real workloads
2. **Integration**: Connect to real data sources and systems
3. **Automation**: Implement full CI/CD pipelines
4. **Governance**: Add data lineage and compliance features
5. **Optimization**: Performance tuning and cost optimization

---

*This demo showcases a production-ready MLOps platform capable of handling real-world data processing and machine learning workloads at scale.*
