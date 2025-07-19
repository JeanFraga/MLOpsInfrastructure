#!/usr/bin/env python3
"""
Real-time Stream Processing with PyFlink

This script processes sensor data from Kafka in real-time using Apache Flink,
performing feature engineering, anomaly detection, and storing results in MinIO.

Components demonstrated:
- PyFlink Kafka source and sink connectors
- Real-time stream processing and windowing
- Feature engineering and anomaly detection
- MinIO integration for data storage
"""

import logging
from typing import Any, Optional

# PyFlink imports - these will be available in the Flink runtime environment
try:
    from pyflink.table import TableEnvironment, EnvironmentSettings
except ImportError:
    # Handle case when running outside Flink environment for development
    TableEnvironment = Any
    EnvironmentSettings = Any

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def setup_flink_environment():
    """Configure Flink environment with necessary dependencies"""
    
    # Create streaming environment
    env_settings = EnvironmentSettings.in_streaming_mode()
    table_env = TableEnvironment.create(env_settings)
    
    # Add required JAR dependencies for connectors
    jar_dependencies = [
        "file:///opt/flink/lib/flink-sql-connector-kafka.jar",
        "file:///opt/flink/lib/flink-s3-fs-hadoop.jar",
        "file:///opt/flink/lib/flink-json.jar"
    ]
    
    table_env.get_config().set("pipeline.jars", ";".join(jar_dependencies))
    
    # Configure checkpointing and state backend
    table_env.get_config().set("execution.checkpointing.interval", "30s")
    table_env.get_config().set("state.backend", "filesystem")
    table_env.get_config().set("state.checkpoints.dir", "s3a://mlops-data/checkpoints")
    
    # Configure parallelism
    table_env.get_config().set("parallelism.default", "2")
    
    logger.info("Flink environment configured successfully")
    return table_env

def create_kafka_source_table(table_env: TableEnvironment):
    """Create Kafka source table for sensor data"""
    
    source_ddl = """
    CREATE TABLE sensor_source (
        sensor_id STRING,
        event_time TIMESTAMP(3),
        temperature DOUBLE,
        humidity DOUBLE,
        pressure DOUBLE,
        is_anomaly BOOLEAN,
        building STRING,
        floor INT,
        room STRING,
        model STRING,
        firmware_version STRING,
        battery_level INT,
        WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
    ) WITH (
        'connector' = 'kafka',
        'topic' = 'sensor-data',
        'properties.bootstrap.servers' = 'mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092',
        'properties.group.id' = 'flink-processor-group',
        'scan.startup.mode' = 'latest-offset',
        'format' = 'json',
        'json.timestamp-format.standard' = 'ISO-8601'
    )
    """
    
    table_env.execute_sql(source_ddl)
    logger.info("Kafka source table created")

def create_processed_kafka_sink(table_env: TableEnvironment):
    """Create Kafka sink for processed/enriched data"""
    
    sink_ddl = """
    CREATE TABLE processed_sink (
        sensor_id STRING,
        event_time TIMESTAMP(3),
        temperature DOUBLE,
        humidity DOUBLE,
        pressure DOUBLE,
        temp_trend STRING,
        humidity_category STRING,
        comfort_index DOUBLE,
        anomaly_score DOUBLE,
        is_anomaly BOOLEAN,
        processing_time TIMESTAMP(3)
    ) WITH (
        'connector' = 'kafka',
        'topic' = 'processed-sensor-data',
        'properties.bootstrap.servers' = 'mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092',
        'format' = 'json'
    )
    """
    
    table_env.execute_sql(sink_ddl)
    logger.info("Processed data Kafka sink created")

def create_minio_sink(table_env: TableEnvironment):
    """Create MinIO/S3 sink for data archival and ML training"""
    
    minio_ddl = """
    CREATE TABLE minio_archive (
        sensor_id STRING,
        event_time TIMESTAMP(3),
        temperature DOUBLE,
        humidity DOUBLE,
        pressure DOUBLE,
        temp_trend STRING,
        humidity_category STRING,
        comfort_index DOUBLE,
        anomaly_score DOUBLE,
        is_anomaly BOOLEAN,
        processing_time TIMESTAMP(3),
        partition_date STRING,
        partition_hour STRING
    ) PARTITIONED BY (partition_date, partition_hour) WITH (
        'connector' = 'filesystem',
        'path' = 's3a://mlops-data/sensor-archive',
        'format' = 'parquet',
        'sink.partition-commit.delay' = '1 min',
        'sink.partition-commit.trigger' = 'process-time',
        'sink.partition-commit.policy.kind' = 'success-file'
    )
    """
    
    table_env.execute_sql(minio_ddl)
    logger.info("MinIO archive sink created")

def create_aggregated_metrics_sink(table_env: TableEnvironment):
    """Create sink for real-time metrics and dashboards"""
    
    metrics_ddl = """
    CREATE TABLE metrics_sink (
        window_start TIMESTAMP(3),
        window_end TIMESTAMP(3),
        building STRING,
        sensor_count BIGINT,
        avg_temperature DOUBLE,
        avg_humidity DOUBLE,
        avg_pressure DOUBLE,
        anomaly_count BIGINT,
        anomaly_rate DOUBLE,
        low_battery_count BIGINT
    ) WITH (
        'connector' = 'kafka',
        'topic' = 'sensor-metrics',
        'properties.bootstrap.servers' = 'mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092',
        'format' = 'json'
    )
    """
    
    table_env.execute_sql(metrics_ddl)
    logger.info("Metrics sink created")

def process_sensor_data(table_env: TableEnvironment):
    """Main data processing logic with feature engineering"""
    
    # Feature engineering query
    processed_query = """
    INSERT INTO processed_sink
    SELECT 
        sensor_id,
        event_time,
        temperature,
        humidity,
        pressure,
        CASE 
            WHEN temperature > 25 THEN 'HOT'
            WHEN temperature < 18 THEN 'COLD'
            ELSE 'NORMAL'
        END AS temp_trend,
        CASE 
            WHEN humidity > 70 THEN 'HIGH'
            WHEN humidity < 30 THEN 'LOW'
            ELSE 'MODERATE'
        END AS humidity_category,
        -- Comfort index calculation (simplified)
        (100 - ABS(temperature - 22) * 2 - ABS(humidity - 45) * 0.5) AS comfort_index,
        -- Simple anomaly score based on deviation from normal ranges
        (
            ABS(temperature - 22) / 22 + 
            ABS(humidity - 50) / 50 + 
            ABS(pressure - 1013) / 1013
        ) AS anomaly_score,
        is_anomaly,
        PROCTIME() AS processing_time
    FROM sensor_source
    """
    
    # Archive to MinIO with partitioning
    archive_query = """
    INSERT INTO minio_archive
    SELECT 
        sensor_id,
        event_time,
        temperature,
        humidity,
        pressure,
        CASE 
            WHEN temperature > 25 THEN 'HOT'
            WHEN temperature < 18 THEN 'COLD'
            ELSE 'NORMAL'
        END AS temp_trend,
        CASE 
            WHEN humidity > 70 THEN 'HIGH'
            WHEN humidity < 30 THEN 'LOW'
            ELSE 'MODERATE'
        END AS humidity_category,
        (100 - ABS(temperature - 22) * 2 - ABS(humidity - 45) * 0.5) AS comfort_index,
        (
            ABS(temperature - 22) / 22 + 
            ABS(humidity - 50) / 50 + 
            ABS(pressure - 1013) / 1013
        ) AS anomaly_score,
        is_anomaly,
        PROCTIME() AS processing_time,
        DATE_FORMAT(event_time, 'yyyy-MM-dd') AS partition_date,
        DATE_FORMAT(event_time, 'HH') AS partition_hour
    FROM sensor_source
    """
    
    # Real-time metrics aggregation
    metrics_query = """
    INSERT INTO metrics_sink
    SELECT 
        TUMBLE_START(event_time, INTERVAL '1' MINUTE) AS window_start,
        TUMBLE_END(event_time, INTERVAL '1' MINUTE) AS window_end,
        building,
        COUNT(*) AS sensor_count,
        ROUND(AVG(temperature), 2) AS avg_temperature,
        ROUND(AVG(humidity), 2) AS avg_humidity,
        ROUND(AVG(pressure), 2) AS avg_pressure,
        SUM(CASE WHEN is_anomaly THEN 1 ELSE 0 END) AS anomaly_count,
        ROUND(
            CAST(SUM(CASE WHEN is_anomaly THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*), 3
        ) AS anomaly_rate,
        SUM(CASE WHEN battery_level < 20 THEN 1 ELSE 0 END) AS low_battery_count
    FROM sensor_source
    GROUP BY TUMBLE(event_time, INTERVAL '1' MINUTE), building
    """
    
    logger.info("Starting data processing pipelines...")
    
    # Execute all processing pipelines
    table_env.execute_sql(processed_query)
    logger.info("Feature engineering pipeline started")
    
    table_env.execute_sql(archive_query)
    logger.info("Data archival pipeline started")
    
    table_env.execute_sql(metrics_query)
    logger.info("Metrics aggregation pipeline started")

def main():
    """Main function to set up and run the Flink streaming job"""
    
    logger.info("Starting PyFlink sensor data processing job...")
    
    try:
        # Set up Flink environment
        table_env = setup_flink_environment()
        
        # Create source and sink tables
        create_kafka_source_table(table_env)
        create_processed_kafka_sink(table_env)
        create_minio_sink(table_env)
        create_aggregated_metrics_sink(table_env)
        
        # Start processing
        process_sensor_data(table_env)
        
        logger.info("All streaming pipelines started successfully")
        logger.info("Processing will continue until manually stopped...")
        
        # Keep the job running
        # Note: In a real deployment, this would be managed by the Flink cluster
        
    except Exception as e:
        logger.error("Error in Flink job: %s", e)
        raise

if __name__ == "__main__":
    main()
