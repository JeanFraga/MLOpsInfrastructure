#!/usr/bin/env python3
"""
ML Model Training Pipeline for Sensor Anomaly Detection

This script demonstrates MLflow integration with automated model training,
experiment tracking, and model registry management using sensor data from MinIO.

Components demonstrated:
- MLflow experiment tracking and autologging
- Model training with multiple algorithms
- Hyperparameter tuning and cross-validation
- Model registry and versioning
- Feature engineering and data preprocessing
"""

import os
import logging
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import boto3
from io import BytesIO
import pickle
import joblib
from typing import Dict, Any, Tuple, List

# ML libraries
from sklearn.model_selection import train_test_split, GridSearchCV, cross_val_score
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.ensemble import RandomForestClassifier, IsolationForest
from sklearn.linear_model import LogisticRegression
from sklearn.svm import OneClassSVM
from sklearn.metrics import (
    classification_report, confusion_matrix, precision_recall_curve,
    roc_auc_score, accuracy_score, precision_score, recall_score, f1_score
)
from sklearn.feature_selection import SelectKBest, f_classif

# MLflow imports
import mlflow
import mlflow.sklearn
from mlflow.models import infer_signature
from mlflow.entities import RunStatus

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DataLoader:
    """Handles data loading from MinIO/S3 storage"""
    
    def __init__(self, endpoint_url: str, access_key: str, secret_key: str, bucket_name: str):
        self.s3_client = boto3.client(
            's3',
            endpoint_url=endpoint_url,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key
        )
        self.bucket_name = bucket_name
        logger.info("Connected to MinIO storage")
    
    def load_sensor_data(self, days_back: int = 7) -> pd.DataFrame:
        """Load and combine sensor data from the last N days"""
        
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days_back)
        
        dataframes = []
        
        # Iterate through dates and load parquet files
        current_date = start_date
        while current_date <= end_date:
            date_str = current_date.strftime('%Y-%m-%d')
            prefix = f"sensor-archive/partition_date={date_str}/"
            
            try:
                # List objects with the date prefix
                response = self.s3_client.list_objects_v2(
                    Bucket=self.bucket_name,
                    Prefix=prefix
                )
                
                if 'Contents' in response:
                    for obj in response['Contents']:
                        if obj['Key'].endswith('.parquet'):
                            # Read parquet file
                            obj_data = self.s3_client.get_object(
                                Bucket=self.bucket_name,
                                Key=obj['Key']
                            )
                            df = pd.read_parquet(BytesIO(obj_data['Body'].read()))
                            dataframes.append(df)
                            
            except Exception as e:
                logger.warning("Could not load data for date %s: %s", date_str, e)
            
            current_date += timedelta(days=1)
        
        if dataframes:
            combined_df = pd.concat(dataframes, ignore_index=True)
            logger.info("Loaded %d records from %d files", len(combined_df), len(dataframes))
            return combined_df
        else:
            logger.error("No data found for the specified date range")
            raise ValueError("No data available for training")

class FeatureEngineer:
    """Handles feature engineering and preprocessing"""
    
    def __init__(self):
        self.scaler = StandardScaler()
        self.label_encoders = {}
        self.feature_selector = SelectKBest(score_func=f_classif, k=10)
        
    def engineer_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Create engineered features from raw sensor data"""
        
        df = df.copy()
        
        # Convert timestamp
        df['event_time'] = pd.to_datetime(df['event_time'])
        
        # Time-based features
        df['hour'] = df['event_time'].dt.hour
        df['day_of_week'] = df['event_time'].dt.dayofweek
        df['is_weekend'] = df['day_of_week'].isin([5, 6]).astype(int)
        df['is_business_hours'] = ((df['hour'] >= 8) & (df['hour'] <= 18)).astype(int)
        
        # Temperature features
        df['temp_deviation'] = abs(df['temperature'] - df['temperature'].rolling(10).mean())
        df['temp_rate_change'] = df['temperature'].diff().abs()
        df['temp_zscore'] = (df['temperature'] - df['temperature'].mean()) / df['temperature'].std()
        
        # Humidity features
        df['humidity_deviation'] = abs(df['humidity'] - df['humidity'].rolling(10).mean())
        df['humidity_rate_change'] = df['humidity'].diff().abs()
        
        # Pressure features
        df['pressure_deviation'] = abs(df['pressure'] - df['pressure'].rolling(10).mean())
        df['pressure_rate_change'] = df['pressure'].diff().abs()
        
        # Cross-feature interactions
        df['temp_humidity_interaction'] = df['temperature'] * df['humidity']
        df['comfort_score'] = 100 - abs(df['temperature'] - 22) * 2 - abs(df['humidity'] - 45) * 0.5
        
        # Statistical features over rolling windows
        for window in [5, 10, 20]:
            df[f'temp_std_{window}'] = df['temperature'].rolling(window).std()
            df[f'humidity_std_{window}'] = df['humidity'].rolling(window).std()
            df[f'pressure_std_{window}'] = df['pressure'].rolling(window).std()
        
        # Fill NaN values created by rolling operations
        df = df.fillna(method='bfill').fillna(method='ffill')
        
        return df
    
    def prepare_features(self, df: pd.DataFrame, is_training: bool = True) -> Tuple[pd.DataFrame, pd.Series]:
        """Prepare features for ML training"""
        
        # Engineer features
        df_engineered = self.engineer_features(df)
        
        # Select numeric features for ML
        feature_columns = [
            'temperature', 'humidity', 'pressure', 'comfort_index',
            'hour', 'day_of_week', 'is_weekend', 'is_business_hours',
            'temp_deviation', 'temp_rate_change', 'temp_zscore',
            'humidity_deviation', 'humidity_rate_change',
            'pressure_deviation', 'pressure_rate_change',
            'temp_humidity_interaction', 'comfort_score'
        ]
        
        # Add rolling statistics features
        for window in [5, 10, 20]:
            feature_columns.extend([
                f'temp_std_{window}', f'humidity_std_{window}', f'pressure_std_{window}'
            ])
        
        # Select available features (some might be missing in small datasets)
        available_features = [col for col in feature_columns if col in df_engineered.columns]
        X = df_engineered[available_features]
        
        # Handle categorical features if present
        categorical_features = ['temp_trend', 'humidity_category']
        for feature in categorical_features:
            if feature in df_engineered.columns:
                if is_training:
                    le = LabelEncoder()
                    X[feature + '_encoded'] = le.fit_transform(df_engineered[feature].astype(str))
                    self.label_encoders[feature] = le
                else:
                    if feature in self.label_encoders:
                        X[feature + '_encoded'] = self.label_encoders[feature].transform(
                            df_engineered[feature].astype(str)
                        )
        
        # Scale features
        if is_training:
            X_scaled = pd.DataFrame(
                self.scaler.fit_transform(X),
                columns=X.columns,
                index=X.index
            )
        else:
            X_scaled = pd.DataFrame(
                self.scaler.transform(X),
                columns=X.columns,
                index=X.index
            )
        
        # Target variable
        y = df_engineered['is_anomaly'] if 'is_anomaly' in df_engineered.columns else None
        
        return X_scaled, y

class ModelTrainer:
    """Handles model training, evaluation, and MLflow integration"""
    
    def __init__(self, experiment_name: str = "sensor-anomaly-detection"):
        # Set up MLflow
        mlflow.set_tracking_uri("http://mlflow.ml-lifecycle.svc.cluster.local:5000")
        mlflow.set_experiment(experiment_name)
        
        # Enable autologging
        mlflow.sklearn.autolog(
            log_input_examples=True,
            log_model_signatures=True,
            log_models=True
        )
        
        logger.info("MLflow configured for experiment: %s", experiment_name)
    
    def train_supervised_models(self, X: pd.DataFrame, y: pd.Series) -> Dict[str, Any]:
        """Train supervised anomaly detection models"""
        
        results = {}
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        models = {
            'RandomForest': {
                'model': RandomForestClassifier(random_state=42),
                'params': {
                    'n_estimators': [50, 100, 200],
                    'max_depth': [5, 10, None],
                    'min_samples_split': [2, 5, 10]
                }
            },
            'LogisticRegression': {
                'model': LogisticRegression(random_state=42, max_iter=1000),
                'params': {
                    'C': [0.1, 1.0, 10.0],
                    'penalty': ['l1', 'l2'],
                    'solver': ['liblinear']
                }
            }
        }
        
        for model_name, model_config in models.items():
            with mlflow.start_run(run_name=f"{model_name}_supervised"):
                try:
                    logger.info("Training %s model...", model_name)
                    
                    # Grid search for hyperparameters
                    grid_search = GridSearchCV(
                        model_config['model'],
                        model_config['params'],
                        cv=5,
                        scoring='f1',
                        n_jobs=-1
                    )
                    
                    grid_search.fit(X_train, y_train)
                    best_model = grid_search.best_estimator_
                    
                    # Predictions
                    y_pred = best_model.predict(X_test)
                    y_pred_proba = best_model.predict_proba(X_test)[:, 1] if hasattr(best_model, 'predict_proba') else None
                    
                    # Metrics
                    metrics = {
                        'accuracy': accuracy_score(y_test, y_pred),
                        'precision': precision_score(y_test, y_pred),
                        'recall': recall_score(y_test, y_pred),
                        'f1': f1_score(y_test, y_pred)
                    }
                    
                    if y_pred_proba is not None:
                        metrics['roc_auc'] = roc_auc_score(y_test, y_pred_proba)
                    
                    # Log additional metrics
                    mlflow.log_metrics(metrics)
                    mlflow.log_params(grid_search.best_params_)
                    
                    # Log confusion matrix as artifact
                    cm = confusion_matrix(y_test, y_pred)
                    cm_df = pd.DataFrame(cm, columns=['Predicted_Normal', 'Predicted_Anomaly'],
                                       index=['Actual_Normal', 'Actual_Anomaly'])
                    cm_df.to_csv('confusion_matrix.csv')
                    mlflow.log_artifact('confusion_matrix.csv')
                    
                    # Log classification report
                    report = classification_report(y_test, y_pred, output_dict=True)
                    report_df = pd.DataFrame(report).transpose()
                    report_df.to_csv('classification_report.csv')
                    mlflow.log_artifact('classification_report.csv')
                    
                    # Model signature
                    signature = infer_signature(X_train, y_pred)
                    
                    # Log model manually for more control
                    model_info = mlflow.sklearn.log_model(
                        sk_model=best_model,
                        name=f"{model_name.lower()}_anomaly_detector",
                        signature=signature,
                        input_example=X_train.head(3),
                        registered_model_name=f"anomaly_detection_{model_name.lower()}"
                    )
                    
                    results[model_name] = {
                        'model': best_model,
                        'metrics': metrics,
                        'model_uri': model_info.model_uri
                    }
                    
                    logger.info("%s training completed. F1 Score: %.3f", model_name, metrics['f1'])
                    
                except Exception as e:
                    logger.error("Error training %s: %s", model_name, e)
                    mlflow.set_tag("status", "failed")
                    mlflow.set_tag("error", str(e))
        
        return results
    
    def train_unsupervised_models(self, X: pd.DataFrame) -> Dict[str, Any]:
        """Train unsupervised anomaly detection models"""
        
        results = {}
        
        models = {
            'IsolationForest': {
                'model': IsolationForest(random_state=42),
                'params': {
                    'contamination': [0.05, 0.1, 0.15],
                    'n_estimators': [50, 100, 200]
                }
            },
            'OneClassSVM': {
                'model': OneClassSVM(),
                'params': {
                    'kernel': ['rbf', 'linear'],
                    'gamma': ['scale', 'auto', 0.001, 0.01],
                    'nu': [0.05, 0.1, 0.15]
                }
            }
        }
        
        for model_name, model_config in models.items():
            with mlflow.start_run(run_name=f"{model_name}_unsupervised"):
                try:
                    logger.info("Training %s model...", model_name)
                    
                    # For unsupervised models, we'll use a simple approach
                    # In practice, you might want to use more sophisticated validation
                    best_score = -float('inf')
                    best_model = None
                    best_params = None
                    
                    # Manual grid search for unsupervised models
                    param_combinations = self._generate_param_combinations(model_config['params'])
                    
                    for params in param_combinations[:10]:  # Limit combinations
                        model = model_config['model'].__class__(**params)
                        model.fit(X)
                        
                        # Use silhouette score or other unsupervised metric
                        anomaly_scores = model.decision_function(X) if hasattr(model, 'decision_function') else model.score_samples(X)
                        score = np.mean(anomaly_scores)
                        
                        if score > best_score:
                            best_score = score
                            best_model = model
                            best_params = params
                    
                    # Predictions
                    predictions = best_model.predict(X)
                    # Convert to binary (1 for normal, -1 for anomaly in sklearn format)
                    y_pred = (predictions == 1).astype(int)
                    
                    # Log parameters and metrics
                    mlflow.log_params(best_params)
                    mlflow.log_metric("anomaly_score", best_score)
                    mlflow.log_metric("anomaly_rate", (predictions == -1).mean())
                    
                    # Model signature
                    signature = infer_signature(X, y_pred)
                    
                    # Log model
                    model_info = mlflow.sklearn.log_model(
                        sk_model=best_model,
                        name=f"{model_name.lower()}_anomaly_detector",
                        signature=signature,
                        input_example=X.head(3),
                        registered_model_name=f"unsupervised_anomaly_{model_name.lower()}"
                    )
                    
                    results[model_name] = {
                        'model': best_model,
                        'predictions': y_pred,
                        'model_uri': model_info.model_uri
                    }
                    
                    logger.info("%s training completed. Anomaly rate: %.3f", 
                              model_name, (predictions == -1).mean())
                    
                except Exception as e:
                    logger.error("Error training %s: %s", model_name, e)
                    mlflow.set_tag("status", "failed")
                    mlflow.set_tag("error", str(e))
        
        return results
    
    def _generate_param_combinations(self, param_grid: Dict[str, List]) -> List[Dict[str, Any]]:
        """Generate parameter combinations for grid search"""
        import itertools
        
        keys = param_grid.keys()
        values = param_grid.values()
        combinations = []
        
        for combination in itertools.product(*values):
            combinations.append(dict(zip(keys, combination)))
        
        return combinations

def main():
    """Main training pipeline"""
    
    logger.info("Starting ML training pipeline for sensor anomaly detection...")
    
    # Configuration
    MINIO_ENDPOINT = "http://minio.ml-lifecycle.svc.cluster.local:9000"
    MINIO_ACCESS_KEY = "minioadmin"
    MINIO_SECRET_KEY = "minioadmin123"
    BUCKET_NAME = "mlops-data"
    DAYS_BACK = 7
    
    try:
        # Load data
        data_loader = DataLoader(MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY, BUCKET_NAME)
        df = data_loader.load_sensor_data(DAYS_BACK)
        
        if df.empty:
            logger.warning("No data available for training. Generating synthetic data...")
            # Generate some synthetic data for demo purposes
            df = generate_synthetic_data(1000)
        
        # Feature engineering
        feature_engineer = FeatureEngineer()
        X, y = feature_engineer.prepare_features(df, is_training=True)
        
        logger.info("Feature engineering completed. Shape: %s", X.shape)
        
        # Initialize trainer
        trainer = ModelTrainer()
        
        # Train models
        if y is not None and y.sum() > 10:  # Ensure we have enough anomalies
            logger.info("Training supervised models...")
            supervised_results = trainer.train_supervised_models(X, y)
        else:
            logger.info("Insufficient labeled anomalies, skipping supervised training...")
            supervised_results = {}
        
        logger.info("Training unsupervised models...")
        unsupervised_results = trainer.train_unsupervised_models(X)
        
        # Save feature engineer for inference
        with mlflow.start_run(run_name="feature_preprocessor"):
            mlflow.log_artifact('feature_engineer.pkl')
            with open('feature_engineer.pkl', 'wb') as f:
                pickle.dump(feature_engineer, f)
            mlflow.log_artifact('feature_engineer.pkl')
        
        # Log training summary
        with mlflow.start_run(run_name="training_summary"):
            mlflow.log_param("data_points", len(df))
            mlflow.log_param("features", len(X.columns))
            mlflow.log_param("supervised_models", len(supervised_results))
            mlflow.log_param("unsupervised_models", len(unsupervised_results))
            
            if y is not None:
                mlflow.log_param("anomaly_rate", y.mean())
                mlflow.log_param("normal_samples", (y == 0).sum())
                mlflow.log_param("anomaly_samples", (y == 1).sum())
        
        logger.info("ML training pipeline completed successfully!")
        logger.info("Supervised models trained: %s", list(supervised_results.keys()))
        logger.info("Unsupervised models trained: %s", list(unsupervised_results.keys()))
        
    except Exception as e:
        logger.error("Error in training pipeline: %s", e)
        raise

def generate_synthetic_data(n_samples: int) -> pd.DataFrame:
    """Generate synthetic sensor data for demo purposes"""
    
    logger.info("Generating %d synthetic data samples...", n_samples)
    
    np.random.seed(42)
    
    # Generate base sensor readings
    timestamps = pd.date_range(
        start=datetime.now() - timedelta(hours=n_samples//60),
        periods=n_samples,
        freq='1min'
    )
    
    data = []
    for i, ts in enumerate(timestamps):
        # Normal pattern with some noise
        hour_of_day = ts.hour
        daily_pattern = np.sin(2 * np.pi * hour_of_day / 24)
        
        temperature = 22 + 5 * daily_pattern + np.random.normal(0, 1)
        humidity = 50 - 10 * daily_pattern + np.random.normal(0, 3)
        pressure = 1013 + np.random.normal(0, 5)
        
        # Inject anomalies (5% chance)
        is_anomaly = np.random.random() < 0.05
        if is_anomaly:
            temperature += np.random.choice([-15, 15])
            humidity += np.random.choice([-20, 20])
        
        # Ensure bounds
        humidity = np.clip(humidity, 0, 100)
        pressure = np.clip(pressure, 950, 1100)
        
        # Calculate derived fields
        comfort_index = 100 - abs(temperature - 22) * 2 - abs(humidity - 45) * 0.5
        
        data.append({
            'sensor_id': f'sensor_{i % 5:03d}',
            'event_time': ts,
            'temperature': round(temperature, 2),
            'humidity': round(humidity, 2),
            'pressure': round(pressure, 2),
            'comfort_index': round(comfort_index, 2),
            'is_anomaly': is_anomaly,
            'temp_trend': 'HOT' if temperature > 25 else 'COLD' if temperature < 18 else 'NORMAL',
            'humidity_category': 'HIGH' if humidity > 70 else 'LOW' if humidity < 30 else 'MODERATE'
        })
    
    df = pd.DataFrame(data)
    logger.info("Generated synthetic dataset with %d samples (%.1f%% anomalies)", 
               len(df), df['is_anomaly'].mean() * 100)
    
    return df

if __name__ == "__main__":
    main()
