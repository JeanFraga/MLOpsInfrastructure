#!/usr/bin/env python3
"""
Demo Data Generator for MLOps Platform Stress Test

This script generates synthetic streaming data simulating IoT sensor readings
and publishes them to Kafka for real-time processing with Flink.

Components demonstrated:
- Kafka producer for real-time data streaming
- Synthetic time-series data generation
- Error simulation and anomaly injection
"""

import json
import random
import time
import logging
from datetime import datetime, timezone
from typing import Dict, Any
from kafka import KafkaProducer
import numpy as np
import argparse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SensorDataGenerator:
    """Generates realistic sensor data with trends, seasonality, and anomalies"""
    
    def __init__(self):
        self.timestamp_start = datetime.now(timezone.utc)
        self.base_temperature = 20.0
        self.base_humidity = 50.0
        self.base_pressure = 1013.25
        
    def generate_sensor_reading(self, sensor_id: str, anomaly_probability: float = 0.05) -> Dict[str, Any]:
        """Generate a single sensor reading with optional anomalies"""
        
        # Calculate time-based trends and seasonality
        elapsed_hours = (datetime.now(timezone.utc) - self.timestamp_start).total_seconds() / 3600
        daily_cycle = np.sin(2 * np.pi * elapsed_hours / 24)  # 24-hour cycle
        
        # Base values with natural variation
        temperature = self.base_temperature + 5 * daily_cycle + random.gauss(0, 1)
        humidity = self.base_humidity - 10 * daily_cycle + random.gauss(0, 3)
        pressure = self.base_pressure + random.gauss(0, 5)
        
        # Inject anomalies
        is_anomaly = random.random() < anomaly_probability
        if is_anomaly:
            anomaly_type = random.choice(['spike', 'dip', 'stuck'])
            if anomaly_type == 'spike':
                temperature += random.uniform(10, 20)
                humidity += random.uniform(15, 25)
            elif anomaly_type == 'dip':
                temperature -= random.uniform(10, 15)
                humidity -= random.uniform(15, 20)
            else:  # stuck sensor
                temperature = self.base_temperature + random.gauss(0, 0.1)
                humidity = self.base_humidity + random.gauss(0, 0.1)
        
        # Ensure realistic bounds
        humidity = max(0, min(100, humidity))
        pressure = max(950, min(1100, pressure))
        
        return {
            'sensor_id': sensor_id,
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'temperature': round(temperature, 2),
            'humidity': round(humidity, 2),
            'pressure': round(pressure, 2),
            'is_anomaly': is_anomaly,
            'location': {
                'building': f"Building_{sensor_id.split('_')[1]}",
                'floor': random.randint(1, 10),
                'room': f"Room_{random.randint(101, 999)}"
            },
            'device_info': {
                'model': random.choice(['SensorPro-X1', 'EnviroSense-2000', 'ClimateMonitor-Pro']),
                'firmware_version': f"v{random.randint(1,3)}.{random.randint(0,9)}.{random.randint(0,9)}",
                'battery_level': random.randint(20, 100)
            }
        }

class KafkaDataProducer:
    """Handles Kafka connection and data publishing"""
    
    def __init__(self, bootstrap_servers: str, topic: str):
        self.topic = topic
        self.producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            value_serializer=lambda x: json.dumps(x, default=str).encode('utf-8'),
            key_serializer=lambda x: x.encode('utf-8') if x else None,
            acks='all',  # Wait for all replicas to acknowledge
            retries=3,
            batch_size=16384,
            linger_ms=10,
            buffer_memory=33554432,
            compression_type='gzip'
        )
        logger.info(f"Connected to Kafka at {bootstrap_servers}, topic: {topic}")
        
    def send_data(self, data: Dict[str, Any]) -> None:
        """Send data to Kafka topic"""
        try:
            # Use sensor_id as partition key for even distribution
            key = data['sensor_id']
            future = self.producer.send(self.topic, key=key, value=data)
            
            # Optional: wait for delivery confirmation
            # record_metadata = future.get(timeout=10)
            # logger.debug(f"Sent to partition {record_metadata.partition} at offset {record_metadata.offset}")
            
        except Exception as e:
            logger.error(f"Failed to send data: {e}")
            
    def close(self):
        """Close the producer connection"""
        self.producer.flush()
        self.producer.close()
        logger.info("Kafka producer closed")

def main():
    parser = argparse.ArgumentParser(description="Generate streaming sensor data for MLOps demo")
    parser.add_argument(
        '--kafka-servers', 
        default='mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092',
        help='Kafka bootstrap servers'
    )
    parser.add_argument(
        '--topic', 
        default='sensor-data',
        help='Kafka topic to publish data'
    )
    parser.add_argument(
        '--sensors', 
        type=int, 
        default=10,
        help='Number of sensors to simulate'
    )
    parser.add_argument(
        '--interval', 
        type=float, 
        default=1.0,
        help='Interval between readings in seconds'
    )
    parser.add_argument(
        '--anomaly-rate', 
        type=float, 
        default=0.05,
        help='Probability of anomalies (0.0-1.0)'
    )
    parser.add_argument(
        '--duration', 
        type=int, 
        default=3600,
        help='Duration to run in seconds (default: 1 hour)'
    )
    
    args = parser.parse_args()
    
    # Initialize components
    generator = SensorDataGenerator()
    producer = KafkaDataProducer(args.kafka_servers, args.topic)
    
    # Generate sensor IDs
    sensor_ids = [f"sensor_{i:03d}" for i in range(1, args.sensors + 1)]
    
    logger.info(f"Starting data generation for {args.sensors} sensors")
    logger.info(f"Publishing to {args.topic} every {args.interval}s for {args.duration}s")
    logger.info(f"Anomaly rate: {args.anomaly_rate*100:.1f}%")
    
    start_time = time.time()
    messages_sent = 0
    
    try:
        while time.time() - start_time < args.duration:
            # Generate data for all sensors
            for sensor_id in sensor_ids:
                data = generator.generate_sensor_reading(sensor_id, args.anomaly_rate)
                producer.send_data(data)
                messages_sent += 1
            
            # Log progress
            if messages_sent % (args.sensors * 60) == 0:  # Every minute for all sensors
                elapsed = time.time() - start_time
                rate = messages_sent / elapsed
                logger.info(f"Sent {messages_sent} messages ({rate:.1f} msg/s) over {elapsed:.0f}s")
            
            time.sleep(args.interval)
            
    except KeyboardInterrupt:
        logger.info("Received interrupt, stopping data generation...")
    except Exception as e:
        logger.error(f"Error during data generation: {e}")
    finally:
        producer.close()
        elapsed = time.time() - start_time
        logger.info(f"Data generation complete. Sent {messages_sent} messages in {elapsed:.0f}s")

if __name__ == "__main__":
    main()
