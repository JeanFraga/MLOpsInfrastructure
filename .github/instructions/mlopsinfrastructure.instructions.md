---
applyTo: '**'
---

Architecting a Scalable MLOps Platform on Kubernetes: An End-to-End Guide


Introduction


Purpose and Scope

This report provides a comprehensive architectural blueprint for building a production-grade, scalable Machine Learning Operations (MLOps) and data processing platform on Kubernetes. It details the deployment, configuration, and integration of a powerful open-source stack: Apache Airflow 3 for orchestration, Apache Flink and Apache Spark for batch and stream processing, Apache Kafka for real-time messaging, MinIO for S3-compatible object storage, and MLflow for end-to-end machine learning lifecycle management. The methodologies presented are grounded in industry best practices, emphasizing the use of official and community-endorsed Helm charts for deployment while adopting a robust, operator-centric approach for managing stateful components. The scope extends beyond simple installation to provide a holistic view of how these disparate systems connect to form a cohesive, automated, and scalable platform capable of supporting complex data engineering and machine learning pipelines from development to production.

Core Philosophy: Cloud-Native and Operator-Driven

The central architectural principle of this platform is a commitment to cloud-native patterns, specifically leveraging the Kubernetes Operator model for managing stateful services. This approach is fundamental to achieving the resilience, automation, and operational maturity required for production systems. While Helm charts are an excellent mechanism for packaging and deploying applications, they primarily address initial installation and configuration (Day 1 operations).1 For complex stateful applications like Kafka, Flink, and MinIO, which require nuanced lifecycle management—such as ordered updates, data rebalancing, automated backups, and failure recovery (Day 2 operations)—a more intelligent management layer is necessary.2
Kubernetes Operators fulfill this role by extending the Kubernetes API with custom controllers that encode domain-specific operational knowledge.3 Instead of manually performing complex administrative tasks, platform teams can declaratively manage these services through Custom Resources (CRs). For instance, upgrading a Kafka cluster becomes a matter of changing a version number in a YAML file, with the Strimzi Operator orchestrating the complex rolling update process to ensure zero downtime and data integrity.4
Therefore, the architectural decision is to use Helm to deploy the Operators for Kafka, Flink, and MinIO. The application instances themselves will then be managed via their respective Custom Resource Definitions (CRDs). This strategy creates a powerful abstraction layer, simplifying management and promoting a stable, self-healing platform foundation.5 For stateless or less complex components like Airflow and MLflow, their official Helm charts provide sufficient capability for a production-grade deployment.

The End-to-End Vision

To contextualize the architecture, consider a typical MLOps workflow executed on this platform. This sequence illustrates the seamless interaction between the integrated components:
Orchestration and Triggering: An Apache Airflow Directed Acyclic Graph (DAG) is triggered, either on a schedule or by an external event. This DAG defines the entire end-to-end machine learning pipeline.
Batch Feature Engineering: The first task in the DAG uses the SparkKubernetesOperator to launch a distributed Apache Spark job. This job reads raw data from a "data lake" bucket in MinIO, performs large-scale transformations and feature engineering, and writes the resulting feature set back to another bucket in MinIO.
Real-time Data Processing: Concurrently, a long-running Apache Flink application, deployed via its operator, continuously consumes a stream of real-time events from an Apache Kafka topic. It performs stateful aggregations (e.g., calculating user activity features over a sliding window) and writes the enriched data to another Kafka topic.
Model Training and Experiment Tracking: Once the batch feature engineering is complete, a subsequent Airflow task launches another Spark job dedicated to model training. This job reads the prepared features from MinIO. Crucially, the Spark code is instrumented with the MLflow Tracking client. As the model trains, mlflow.spark.autolog() automatically logs hyperparameters, performance metrics, and model artifacts to the central MLflow Tracking Server.6
Artifact and Model Storage: The MLflow Tracking Server, configured to use MinIO as its artifact store, transparently saves the trained model files, plots, and other artifacts to a versioned path within a designated MinIO bucket.7 The model is then registered with the MLflow Model Registry, which uses a PostgreSQL backend for its metadata, creating a versioned, auditable catalog of all production-candidate models.
Model Deployment: After automated validation checks (e.g., comparing the new model's metrics in MLflow against the production model's), a final task in the Airflow DAG can trigger a separate CI/CD pipeline or use a custom operator to deploy the newly registered model version into a serving environment.
This entire process is orchestrated, automated, and observable, forming the backbone of a robust and scalable MLOps platform.

Part 1: Foundational Architecture and Kubernetes Strategy

Before deploying any applications, establishing a solid architectural foundation is paramount. This involves defining the overall system layout, adopting a consistent management pattern for stateful services, creating a logical namespace structure, and implementing a secure strategy for managing secrets. These foundational decisions directly impact the platform's scalability, maintainability, and security.

High-Level System Architecture Diagram

A visual representation of the platform architecture clarifies the relationships and boundaries between components. The system is logically partitioned into several layers, each residing in its own Kubernetes namespace to enforce isolation and manage resources effectively.
Platform Operators Layer (platform-operators namespace): This foundational layer contains the controllers that manage the lifecycle of the data services. It houses the Strimzi Operator for Kafka, the MinIO Operator, the Flink Kubernetes Operator, and the Spark on Kubernetes Operator. These operators do not run the applications themselves but watch for Custom Resources in other namespaces.
Data and Storage Layer (data-plane namespace): This layer contains the stateful application instances managed by the operators. This includes the Kafka broker cluster and the distributed MinIO tenant. These are long-lived, foundational services providing messaging and storage for the entire platform.
Orchestration Layer (orchestration namespace): This layer is dedicated to the Apache Airflow deployment. This includes the Airflow webserver, scheduler, metadata database (PostgreSQL), and message broker (Redis). It is the control plane for all batch-oriented workflows.
ML Lifecycle Layer (ml-lifecycle namespace): This layer hosts the MLflow deployment, including its tracking server, backend database, and user interface. It serves as the central hub for experiment tracking and model management.
Processing Layer (processing-jobs namespace): This is a transient execution environment. Airflow dynamically launches Spark and Flink job pods into this namespace. This isolation allows for applying specific resource quotas, network policies, and security contexts to data processing workloads without affecting the core platform services.
Data flows primarily from external sources into Kafka or MinIO. Spark and Flink jobs in the processing-jobs namespace consume data from the data-plane namespace, process it, and write results back to MinIO or Kafka. Airflow, in the orchestration namespace, sends control signals (i.e., creates SparkApplication or FlinkDeployment CRs) to the processing-jobs namespace. MLflow, in the ml-lifecycle namespace, receives tracking data from Spark jobs and uses MinIO for artifact storage.

The Operator Pattern: A Prerequisite for Stateful Services

The decision to use the Kubernetes Operator pattern for stateful services is the most critical architectural choice for building a production-ready platform. A simple deployment using a standard Helm chart is insufficient for applications like Kafka and MinIO, which have complex operational requirements that extend far beyond initial deployment.
Helm charts are fundamentally a templating and packaging mechanism.9 They excel at bundling Kubernetes manifests (Deployments, Services, ConfigMaps) and allowing for configurable installations via a
values.yaml file. This is perfectly suitable for stateless applications or applications with simple state management needs. However, Helm's lifecycle management capabilities end once the helm install or helm upgrade command completes. It does not actively monitor the application's health or manage its internal state. This limitation becomes a significant liability for stateful systems.3
Kubernetes Operators, in contrast, are active, long-running controllers within the cluster that encode the operational knowledge of a human expert.1 By defining Custom Resource Definitions (CRDs) like
Kafka, FlinkDeployment, or MinIO Tenant, they create a new, high-level API for managing the application. When a user creates or modifies one of these custom resources, the operator's reconciliation loop is triggered. The operator then takes the necessary, often complex, steps to drive the actual state of the world to match the desired state defined in the resource.
For a Kafka cluster, this means the Strimzi operator can:
Perform safe, rolling updates of brokers, ensuring that the controller is rolled last and that minimum in-sync replicas are maintained to prevent data loss.2
Automatically generate and renew TLS certificates for secure communication between brokers and clients.
Manage user credentials and Access Control Lists (ACLs) through KafkaUser CRs.5
Scale the cluster up or down, potentially triggering data rebalancing via Cruise Control integration.10
Attempting to replicate this logic with Helm alone would require complex, brittle scripting and manual intervention, defeating the purpose of an automated, cloud-native platform. Therefore, the strategy is clear: use Helm as a tool to install and manage the Operator, and then use declarative kubectl apply with Custom Resource manifests to manage the application instances themselves. This approach provides the simplicity of Helm for the initial setup of the management layer, combined with the operational robustness of the Operator pattern for the critical stateful services.

Kubernetes Namespace and Naming Strategy

A disciplined approach to Kubernetes namespaces is essential for security, organization, and resource management in a multi-component platform. Deploying everything into the default namespace leads to a chaotic and insecure environment. By creating dedicated namespaces for distinct functional areas, we can apply granular Role-Based Access Control (RBAC), resource quotas, and network policies.
The following namespace structure is recommended for this platform:
platform-operators: This namespace is reserved for the operator deployments themselves (Strimzi, MinIO, Flink, Spark). Access to this namespace should be highly restricted to platform administrators, as these components have cluster-wide or broad permissions.
data-plane: This namespace will host the actual instances of our stateful services: the Kafka cluster and the MinIO Tenant. Applications from other namespaces will interact with services in this namespace, but will not run within it. This separation protects the core data infrastructure.
orchestration: The Apache Airflow deployment, including its webserver, scheduler, workers (if using CeleryExecutor), and metadata database, resides here.11 This isolates the workflow management system.
ml-lifecycle: The MLflow server and its backend database are deployed here. This centralizes the components responsible for the ML model lifecycle.
processing-jobs: This namespace is designated for the dynamic, transient pods created by Airflow to run Spark and Flink jobs.12 This is a critical isolation boundary. By launching jobs here, we can:
Apply strict ResourceQuota objects to limit the total CPU and memory that ad-hoc or scheduled jobs can consume, preventing a single runaway job from impacting the entire Kubernetes cluster.
Define specific NetworkPolicy objects that allow pods in this namespace to connect to Kafka and MinIO in the data-plane namespace and to the MLflow server in the ml-lifecycle namespace, while denying all other egress traffic.
Assign a dedicated Kubernetes ServiceAccount with the minimal permissions required to run a job (e.g., creating and deleting executor pods for Spark).
This multi-namespace strategy creates clear security and resource boundaries, making the platform more manageable, secure, and resilient as it scales.

Platform-Wide Secrets Management

Managing sensitive data such as database passwords, API keys, and user credentials is a critical security concern. A common anti-pattern is to hardcode these values directly into Helm values.yaml files, which are often checked into version control, leading to severe security exposures.13 The best practice is to externalize secrets from the application configuration.
The recommended approach is to use native Kubernetes Secret objects. These objects are designed to hold confidential data and can be created and managed independently of the pods that consume them.14
The implementation strategy for this platform is as follows:
Manual Secret Creation: Before deploying any application, a platform administrator or an automated CI/CD pipeline with appropriate privileges will create the necessary Kubernetes Secrets. For example, to create a secret for the PostgreSQL database that Airflow and MLflow will use:
Bash
kubectl create secret generic airflow-postgres-secret \
  --namespace orchestration \
  --from-literal=postgresql-password='your-strong-password'

A similar secret would be created for MinIO's root credentials in the data-plane namespace.
Reference Secrets in Helm Values: The Helm charts for our applications will be configured to use these pre-existing secrets rather than generating new ones. Most robust charts support this pattern. For example, in the Airflow values.yaml, you would configure:
YAML
postgresql:
  existingSecret: "airflow-postgres-secret"
  existingSecretKey: "postgresql-password"

Similarly, the MLflow chart allows referencing an existing secret for its database backend, and the MinIO tenant chart can reference a secret for its initial user credentials.15
This approach cleanly separates the concerns of infrastructure configuration (which can be safely version-controlled in Git) and secret management. It enables a secure GitOps workflow, where deployment pipelines can apply Helm charts without ever needing to access the plaintext secret values. The pipeline only needs to know the name of the Kubernetes Secret object.
For even more advanced security postures, organizations can adopt the External Secrets Operator. This operator acts as a bridge between Kubernetes and an external, dedicated secrets management system like HashiCorp Vault, AWS Secrets Manager, or Google Secret Manager.18 The operator syncs secrets from the external vault into native Kubernetes
Secret objects. This provides a centralized, single source of truth for all secrets, with robust auditing and access control features provided by the external vault. While a full implementation is beyond the scope of this report, it represents the next logical step in maturing the platform's security posture.

Part 2: Deploying the Core Infrastructure: Storage and Messaging

With the foundational strategy in place, the next step is to deploy the stateful services that form the backbone of the data platform: Apache Kafka for messaging and MinIO for object storage. Both will be deployed using their respective Kubernetes Operators to ensure production-grade stability and manageability.

Deploying Apache Kafka with the Strimzi Operator

For running Apache Kafka on Kubernetes, the Strimzi project is the undisputed, de-facto standard. As a Cloud Native Computing Foundation (CNCF) incubating project, it provides a mature, robust, and feature-rich operator that far surpasses the capabilities of generic Helm charts like the one from Bitnami.5 The primary advantage of Strimzi is its deep, Kafka-specific operational intelligence, which automates complex day-2 tasks that would otherwise require significant manual effort and expertise.2
Step 1: Install the Strimzi Operator Helm Chart
The first step is to install the Strimzi Cluster Operator itself. The official Strimzi Helm chart is the recommended method for this. It sets up the Operator Deployment, required RBAC roles, and all necessary Custom Resource Definitions (CRDs).

Bash


# Add the official Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts/

# Update the local Helm chart repository cache
helm repo update

# Install the Strimzi Operator into the dedicated 'platform-operators' namespace
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace platform-operators \
  --create-namespace


This command deploys the operator, which will now watch for Kafka custom resources across the cluster (or in specified namespaces if configured).
Step 2: Create a Kafka Cluster using the Kafka CRD
With the operator running, you do not modify Helm values to create a Kafka cluster. Instead, you define the desired state of your cluster in a Kafka custom resource manifest and apply it to the cluster. This declarative approach is the core of the operator pattern.
Below is an example manifest, kafka-cluster.yaml, for a production-oriented Kafka cluster.

YAML


# kafka-cluster.yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: mlops-kafka-cluster
  namespace: data-plane
spec:
  kafka:
    # Specify the desired Kafka version
    version: 3.7.0
    # Deploy a 3-node cluster for high availability
    replicas: 3
    # Configure listeners for client connections
    listeners:
      # Listener for internal cluster traffic (Spark, Flink, etc.) on port 9092
      - name: plain
        port: 9092
        type: internal
        tls: false
      # Listener for external access (e.g., from a developer's machine) on a NodePort
      - name: external
        port: 9094
        type: nodeport
        tls: false
        configuration:
          # Strimzi automatically manages advertised listeners
          bootstrap:
            host: your-k8s-node-ip # Replace with an actual node IP for external access
    # Configure storage for the brokers
    storage:
      type: jbod # Use multiple disks per broker if available
      volumes:
        - id: 0
          type: persistent-claim
          size: 100Gi
          # Critical for production: do not delete the PVC when the Kafka resource is deleted
          deleteClaim: false
    # Define resource requests and limits for Kafka broker pods
    resources:
      requests:
        cpu: "1"
        memory: 4Gi
      limits:
        cpu: "2"
        memory: 4Gi
    # Set key Kafka configuration properties for reliability
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.insync.replicas: 2
      default.replication.factor: 3
      min.insync.replicas: 2
      auto.create.topics.enable: false # Explicit topic creation is a best practice
  # For this example, we use the Strimzi-managed Zookeeper.
  # For new deployments, KRaft mode should be strongly considered.
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 10Gi
      deleteClaim: false
    resources:
      requests:
        cpu: "500m"
        memory: 1Gi
      limits:
        cpu: "1"
        memory: 1Gi


To deploy the cluster, simply run:
kubectl apply -f kafka-cluster.yaml
The Strimzi operator will detect this new resource and proceed to provision all the necessary underlying Kubernetes objects: StatefulSets for brokers and Zookeeper, PersistentVolumeClaims, Services for internal and external access, ConfigMaps, and Secrets for certificates.
The following table details the most critical parameters in the Kafka CRD for a production deployment:

Parameter
Description
Recommended Value & Rationale
spec.kafka.replicas
Number of Kafka broker pods.
A minimum of 3 is essential for a high-availability production environment, allowing for one broker to fail while maintaining quorum and data availability.
spec.kafka.storage.type
The type of storage configuration for brokers.
jbod (Just a Bunch of Disks) is recommended, allowing multiple persistent-claim volumes per broker for better I/O performance and scalability.
spec.kafka.storage.volumes.size
The size of the Persistent Volume Claim (PVC) for each broker's data directory.
This must be sized according to expected data throughput, message size, and retention policies. Start with a reasonable size like 100Gi and monitor usage.
spec.kafka.storage.volumes.deleteClaim
Determines if the PVC should be deleted when the Kafka resource is deleted.
Always set to false in production. This prevents catastrophic, accidental data loss if the cluster manifest is deleted. The storage will persist and can be re-attached.
spec.kafka.listeners
Defines the network interfaces for Kafka clients.
Configure at least one internal listener for secure and efficient in-cluster communication. An external listener of type nodeport or loadbalancer can be added for access from outside the Kubernetes network.19
spec.kafka.config.min.insync.replicas
The minimum number of replicas that must acknowledge a write for it to be considered successful.
Set to 2 for a 3-replica cluster. This ensures that data is written to at least two brokers before acknowledging the write to the producer, guaranteeing durability even if one broker fails immediately after the write.
spec.kafka.resources
CPU and Memory requests and limits for the broker pods.
These values are highly workload-dependent and must be tuned. Insufficient memory is a common cause of instability. A starting point of 4Gi for memory is reasonable for a moderately loaded cluster.
spec.zookeeper.replicas
Number of Zookeeper pods.
3 is the standard for a production Zookeeper ensemble, providing fault tolerance. Note: New deployments should favor KRaft mode to eliminate the Zookeeper dependency entirely.

A significant benefit of using Strimzi is its automated management of network complexity. Manually configuring Kafka's advertised.listeners in Kubernetes is notoriously difficult. Strimzi handles this automatically. When you define an internal listener, it creates a stable ClusterIP service and configures each broker to advertise an address that is resolvable within the cluster. This means a Spark or Flink job can simply connect to the bootstrap service DNS name (mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092) without needing to know the individual pod IPs, drastically simplifying client configuration and service discovery.5

Deploying MinIO with the MinIO Operator

For object storage, MinIO provides a high-performance, S3-compatible solution. For production use, it is critical to run MinIO in a distributed mode to ensure data durability and high availability through its erasure coding mechanism.20 The official MinIO Kubernetes Operator is explicitly designed to manage these complex distributed deployments, and MinIO strongly recommends it over community Helm charts for production environments.15
Step 1: Install the MinIO Operator Helm Chart
Similar to Strimzi, the first step is to install the operator itself into the platform-operators namespace.

Bash


# Add the official MinIO Operator Helm repository
helm repo add minio-operator https://operator.min.io/

# Update the local Helm chart repository cache
helm repo update

# Install the MinIO Operator
helm install operator minio-operator/operator \
  --namespace platform-operators


43
Step 2: Deploy a MinIO Tenant
A "Tenant" in MinIO's terminology is a dedicated MinIO object storage instance managed by the operator. The operator provides a separate Helm chart specifically for deploying tenants. We will use this chart and provide a custom values.yaml file to configure our distributed instance.
Here is an example minio-tenant-values.yaml for a distributed MinIO deployment:

YAML


# minio-tenant-values.yaml
# Define the pools of servers for the tenant. A single pool is sufficient for most cases.
pools:
  # A distributed setup requires a minimum of 4 servers.
  - servers: 4
    # Each server will have 4 persistent volumes. More volumes can improve I/O.
    volumesPerServer: 4
    # The size of each individual persistent volume.
    size: 256Gi
    # Define resource requests and limits for the MinIO server pods.
    resources:
      requests:
        memory: "2Gi"
        cpu: "1"
      limits:
        memory: "4Gi"
        cpu: "2"

# Define buckets to be created automatically upon tenant creation.
buckets:
  - name: mlflow-artifacts
  - name: flink-checkpoints
  - name: spark-checkpoints
  - name: data-lake-raw

# Reference a pre-existing Kubernetes secret for the root user credentials.
# This secret must be created manually before deploying the tenant.
users:
  - secret:
      name: minio-root-user-secret

# Expose the MinIO service via an Ingress for external access to the console.
ingress:
  api:
    enabled: false # API access will be via the internal service
  console:
    enabled: true
    ingressClassName: nginx # Specify your ingress controller
    host: minio.your-domain.com


22
Before deploying, create the secret for the root user:
kubectl create secret generic minio-root-user-secret --namespace data-plane --from-literal=accessKey='your-minio-access-key' --from-literal=secretKey='your-minio-secret-key'
Then, deploy the tenant using Helm:
helm install minio-tenant minio-operator/tenant --namespace data-plane -f minio-tenant-values.yaml
The following table highlights key parameters for a distributed MinIO tenant:

Parameter
Description
Recommended Value & Rationale
pools.servers
The number of MinIO server pods in the distributed set.
4 is the minimum required for erasure coding in a production environment. This allows the cluster to tolerate the failure of up to 2 nodes.20
pools.volumesPerServer
The number of PersistentVolumeClaims (PVCs) attached to each server pod.
A minimum of 4 is recommended. MinIO's performance scales with the number of drives.
pools.size
The capacity of each individual PVC.
This should be sized based on the total expected storage for ML artifacts, checkpoints, and the data lake. Total capacity will be servers * volumesPerServer * size.
buckets
An array of bucket names to be created automatically at startup.
Pre-creating buckets like mlflow-artifacts and flink-checkpoints simplifies application configuration and ensures they exist before being used.15
users.secret.name
The name of a pre-existing Kubernetes secret containing the accessKey and secretKey for the root user.
This adheres to the best practice of separating secrets from configuration, enabling secure GitOps workflows.
ingress.console.enabled
Enables an Ingress resource for the MinIO Console UI.
Set to true to provide a user-friendly way for administrators and data scientists to browse the object store via a web browser.

The choice between a standalone and distributed MinIO deployment is a critical one that dictates the resilience of the entire platform's storage layer. Standalone mode, which runs on a single pod, offers no data redundancy and is suitable only for ephemeral development or testing.23 Any pod failure results in data loss. The distributed mode, managed by the MinIO Operator, stripes data and parity blocks across multiple nodes and drives. This architecture ensures that the object store can withstand multiple node or drive failures without data loss, a non-negotiable requirement for storing valuable ML models, checkpoints, and datasets in a production MLOps environment. The operator abstracts away the immense complexity of setting up and managing such a distributed stateful system.

Part 3: Deploying the Compute and Orchestration Engines

With the data storage and messaging backbone in place, the next layer to deploy consists of the engines that will execute data processing tasks and orchestrate the workflows: Apache Spark, Apache Flink, and Apache Airflow. For Spark and Flink, we will continue to leverage the operator pattern, as it provides a superior, cloud-native way to manage job lifecycles. For Airflow, the official Helm chart provides a comprehensive and production-ready deployment solution.

Deploying Apache Spark with the Kubernetes Operator

The official method for running Spark on Kubernetes is now through the Apache Spark Kubernetes Operator, a subproject of Apache Spark itself.24 This operator-based approach replaces older, more cumbersome methods like deploying a standalone Spark cluster on Kubernetes. The operator provides a native Kubernetes experience for defining and managing Spark applications.
Installation
The operator is installed via its official Helm chart into the platform-operators namespace.

Bash


# Add the official Apache Spark Operator Helm repository
helm repo add spark https://apache.github.io/spark-kubernetes-operator

# Update the local Helm chart repository cache
helm repo update

# Install the Spark Operator
helm install spark-operator spark/spark-kubernetes-operator \
  --namespace platform-operators


24
Core Concept: The SparkApplication CRD
The fundamental shift with the operator is that users no longer interact with spark-submit directly. Instead, a Spark job is defined declaratively as a SparkApplication custom resource. The Spark Operator continuously watches for these resources. When a new SparkApplication is created, the operator takes on the responsibility of running spark-submit internally, creating the Spark driver pod, and managing the lifecycle of the corresponding executor pods.26 This provides a clean separation of concerns: the user defines
what to run, and the operator handles how to run it on Kubernetes.
An example SparkApplication manifest for a simple Pi calculation job demonstrates the structure:

YAML


# spark-pi-app.yaml
apiVersion: "spark.apache.org/v1beta2"
kind: SparkApplication
metadata:
  name: spark-pi-example
  namespace: processing-jobs # Jobs are run in the dedicated processing namespace
spec:
  type: Scala
  mode: cluster
  image: "gcr.io/spark-operator/spark:v3.3.0"
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples_2.12-3.3.0.jar"
  sparkVersion: "3.3.0"
  restartPolicy:
    type: Never # For batch jobs, do not restart on failure
  driver:
    cores: 1
    memory: "512m"
    # Best practice: use a dedicated service account with minimal permissions
    serviceAccount: spark-job-runner
  executor:
    cores: 1
    instances: 2
    memory: "512m"


12
This manifest can be applied directly with kubectl apply -f spark-pi-app.yaml. In our MLOps platform, these SparkApplication resources will be created dynamically by Airflow tasks.

Deploying Apache Flink with the Kubernetes Operator

Similar to Spark, the Apache Flink community provides an official Kubernetes Operator that has become the standard for running Flink applications in a cloud-native manner.28 It supports both long-running session clusters and per-job application clusters, providing robust management of checkpoints, savepoints, and high availability.
Installation
The Flink Kubernetes Operator is also installed via a Helm chart. The repository URL is often tied to a specific operator release, so it is important to consult the official Flink documentation for the latest version.

Bash


# The repository URL is version-specific; check the Flink release announcements
helm repo add flink-kubernetes-operator https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.12.0/

# Update the local Helm chart repository cache
helm repo update

# Install the Flink Operator into the 'platform-operators' namespace
helm install flink-operator flink-kubernetes-operator/flink-kubernetes-operator \
  --namespace platform-operators


28
Core Concept: The FlinkDeployment CRD
The Flink Operator manages applications through the FlinkDeployment custom resource. This CRD can describe either a session cluster (which can accept multiple jobs) or a self-contained application cluster (which runs a single job and shuts down when the job finishes).29 For our MLOps pipelines, the application mode is often preferred as it provides better resource isolation for each job.
An example FlinkDeployment manifest for a streaming job demonstrates how to configure it to use MinIO for checkpointing and high-availability state, a critical feature for production stream processing:

YAML


# flink-streaming-job.yaml
apiVersion: flink.apache.org/v1beta1
kind: FlinkDeployment
metadata:
  name: flink-kafka-processor
  namespace: processing-jobs
spec:
  # Use a custom image containing the Flink job JAR
  image: my-registry/my-flink-job:1.0
  flinkVersion: v1_20 # Corresponds to Flink version 1.20
  # Pass Flink configurations
  flinkConfiguration:
    taskmanager.numberOfTaskSlots: "2"
    # Use our MinIO tenant for high-availability metadata
    high-availability.storageDir: "s3a://flink-checkpoints/ha/"
    # Use MinIO for state checkpoints
    state.checkpoints.dir: "s3a://flink-checkpoints/checkpoints/"
    # S3 endpoint configuration for MinIO
    s3.endpoint: "http://minio-tenant.data-plane.svc.cluster.local:9000"
    s3.path.style.access: "true"
  # Use a dedicated service account for Flink jobs
  serviceAccount: flink-job-runner
  jobManager:
    resource:
      memory: "2048m"
      cpu: 1
  taskManager:
    resource:
      memory: "2048m"
      cpu: 1
  # Define the job to be run
  job:
    jarURI: local:///opt/flink/usrlib/my-flink-job.jar
    entryClass: "com.mycompany.MyFlinkStreamingJob"
    parallelism: 2
    upgradeMode: stateless # Or 'savepoint' for stateful upgrades


29
This manifest declaratively defines a Flink application, including its resource requirements and its integration with the MinIO storage backend for state management. This integration is crucial for fault tolerance; if a TaskManager pod fails, Flink can restore its state from the latest checkpoint in MinIO.

Deploying Apache Airflow 3

Apache Airflow serves as the central orchestrator for the platform's batch workflows. The Apache Software Foundation maintains an official, comprehensive, and highly configurable Helm chart, which is the definitive method for deploying Airflow on Kubernetes.31
Installation
The chart is installed from the official Apache repository into the orchestration namespace. A custom values.yaml file is used to tailor the deployment to our platform's needs.

Bash


# Add the official Apache Airflow Helm repository
helm repo add apache-airflow https://airflow.apache.org

# Update the local Helm chart repository cache
helm repo update

# Install Airflow using a custom values file
helm install airflow apache-airflow/airflow \
  --namespace orchestration \
  --create-namespace \
  -f airflow-values.yaml


11
Key airflow-values.yaml Configurations
A production Airflow deployment requires careful configuration of the executor, DAG management, and backend services.

YAML


# airflow-values.yaml
# Use a powerful executor that can leverage Kubernetes for dynamic task scheduling.
executor: CeleryKubernetesExecutor

# Use git-sync to manage DAGs, aligning with GitOps principles.
dags:
  persistence:
    enabled: false # git-sync makes persistent volume for DAGs unnecessary
  gitSync:
    enabled: true
    repo: "https://github.com/my-org/my-mlops-dags.git"
    branch: "main"
    # For private repositories, create a secret with SSH key or token
    # and reference it here.
    # credentialsSecret: "git-credentials-secret"

# Configure backend services (metadata database and message broker).
data:
  # The official chart bundles a Bitnami PostgreSQL sub-chart.
  # For heavy production use, an external managed database is recommended.
  postgresql:
    enabled: true
  # Redis is required for the CeleryExecutor.
  redis:
    enabled: true

# Configure how the CeleryKubernetesExecutor launches pods.
workers:
  kubernetes:
    enabled: true
    # Launch dynamic task pods in the dedicated 'processing-jobs' namespace.
    namespace: "processing-jobs"
    # A pod template can be provided to customize worker pods, e.g.,
    # to add specific labels, annotations, or a service account.
    podTemplate:
      spec:
        serviceAccountName: airflow-worker


11
The following table explains the rationale behind these key configuration choices:

Parameter
Description
Recommended Value & Rationale
executor
The engine Airflow uses to run tasks.
CeleryKubernetesExecutor is a powerful hybrid. It allows some lightweight tasks to run on a fixed pool of Celery workers while offloading heavy, resource-intensive tasks (like triggering a Spark job) to dynamically created Kubernetes pods. This provides both efficiency and scalability.31
KubernetesExecutor is a simpler alternative if every task is suitable to run in its own pod.
dags.gitSync.enabled
Enables a sidecar container in the scheduler and webserver pods that continuously pulls DAGs from a Git repository.
true. This is the modern, standard way to manage DAGs. It treats workflow code as code, enabling version control, code reviews, and automated deployments. It is vastly superior to older methods like baking DAGs into the image or using shared persistent volumes.11
dags.gitSync.repo
The URL of the Git repository containing the DAG definitions.
This should point to the dags/ directory in the mono-repo structure defined in Part 6.
data.postgresql.enabled
Enables the bundled PostgreSQL sub-chart for the Airflow metadata database.
true is convenient for getting started. However, the metadata database is a critical component. For high-volume production environments, using an external, managed database (e.g., AWS RDS, Google Cloud SQL) is a best practice for performance, resilience, and manageability.
workers.kubernetes.enabled
Enables the Kubernetes-specific capabilities of the CeleryKubernetesExecutor.
true. This is what allows the executor to spin up pods for tasks that specify queue='kubernetes'.
workers.kubernetes.namespace
The Kubernetes namespace where dynamic worker pods will be created.
processing-jobs. This is a crucial security and resource management decision. It isolates transient Airflow tasks from the core Airflow control plane, allowing for separate quotas and permissions.

This configuration establishes Airflow as a robust, Kubernetes-native orchestrator, fully integrated with a GitOps workflow for managing DAGs and capable of dynamically scaling its task execution using the power of the underlying Kubernetes cluster.

Part 4: Deploying the Machine Learning Lifecycle Hub

The final core component of the platform is MLflow, which serves as the central nervous system for the machine learning lifecycle. It provides the tools for experiment tracking, model packaging, model registration, and deployment. A properly configured MLflow deployment is essential for creating reproducible, auditable, and production-ready ML workflows.

Deploying MLflow

While there is no official Helm chart for MLflow provided by the MLflow project itself, the community-charts/mlflow chart has emerged as a de-facto standard. It is well-maintained, feature-rich, and supports the necessary configurations for a production deployment, including external database backends and S3-compatible artifact stores, which are critical for our architecture.17
Installation
The MLflow deployment will reside in its own ml-lifecycle namespace. The installation requires a custom values.yaml to integrate MLflow with the PostgreSQL backend (for metadata) and the MinIO tenant (for artifacts).

Bash


# Add the community-charts Helm repository
helm repo add community-charts https://community-charts.github.io/helm-charts

# Update the local Helm chart repository cache
helm repo update

# Install MLflow using a custom values file
helm install mlflow community-charts/mlflow \
  --namespace ml-lifecycle \
  --create-namespace \
  -f mlflow-values.yaml


17
Key mlflow-values.yaml Configurations
A production-grade MLflow server cannot use the default file-based backend and artifact stores. It must be configured to use a robust database and a scalable object store.

YAML


# mlflow-values.yaml

# Configure the backend store to use a PostgreSQL database.
# The chart can deploy a sub-chart, but for consistency and control,
# we assume a separate PostgreSQL instance is managed (or use the Airflow one).
# For this example, we'll use the bundled sub-chart.
backendStore:
  postgres:
    enabled: true
    # For production, use 'existingSecret' to point to a manually created secret.
    # Example for bundled chart:
    postgresqlPassword: "your-strong-mlflow-db-password"
  # This is critical for ensuring the database schema is kept up-to-date
  # during MLflow version upgrades.
  databaseMigration: true

# Configure the artifact store to use our MinIO tenant.
# The artifactRoot is the default location for all new experiments.
artifactRoot: "s3://mlflow-artifacts"

# Pass environment variables to the MLflow server pod to configure S3 access.
extraEnvVars:
  # The key configuration to point MLflow's S3 client to our MinIO service.
  MLFLOW_S3_ENDPOINT_URL: "http://minio-tenant.data-plane.svc.cluster.local:9000"
  # Securely mount the MinIO credentials from the Kubernetes secret we created earlier.
  AWS_ACCESS_KEY_ID:
    valueFrom:
      secretKeyRef:
        name: minio-root-user-secret
        key: accessKey
  AWS_SECRET_ACCESS_KEY:
    valueFrom:
      secretKeyRef:
        name: minio-root-user-secret
        key: secretKey

# Resource allocation for the MLflow server pod.
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1"
    memory: "2Gi"

# Expose the MLflow UI via an Ingress.
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: mlflow.your-domain.com
      paths:
        - path: /
          pathType: ImplementationSpecific


7
The following table provides the rationale for these critical MLflow configurations:

Parameter
Description
Recommended Value & Rationale
backendStore.postgres.enabled
Enables the use of a PostgreSQL database for the MLflow backend store, which holds metadata for experiments, runs, and registered models.
true. Using a database backend (like PostgreSQL or MySQL) is a strict requirement for enabling the MLflow Model Registry. The default file-based store is only suitable for single-user, local development and does not scale.7
backendStore.databaseMigration
If true, the Helm chart will run a Kubernetes Job to apply any necessary database schema migrations before starting the server.
true. This is essential for maintaining a healthy deployment and ensuring smooth upgrades of the MLflow application without manual database intervention.17
artifactRoot
The default root location for storing all artifacts (models, plots, data files) logged during MLflow runs.
s3://mlflow-artifacts. This URI format tells MLflow to use an S3-compatible client and points to the dedicated bucket created in our MinIO tenant. Using a scalable object store is critical for handling large model artifacts.34
extraEnvVars.MLFLOW_S3_ENDPOINT_URL
The endpoint URL that MLflow's S3 client (boto3) should use instead of the default AWS S3 endpoint.
"http://minio-tenant.data-plane.svc.cluster.local:9000". This is the most crucial setting for integrating MLflow with our self-hosted MinIO. It directs all S3 traffic to the internal Kubernetes service of our MinIO tenant.8
extraEnvVars.AWS_...
AWS credentials used by the S3 client.
Use valueFrom.secretKeyRef to securely inject the access and secret keys from the minio-root-user-secret Kubernetes Secret. This avoids hardcoding credentials and follows security best practices.17

This configuration results in a robust, scalable MLflow instance. All experiment metadata is stored reliably in a PostgreSQL database, enabling the powerful features of the Model Registry. All large artifacts are stored in our distributed, fault-tolerant MinIO cluster, ensuring they are safe and accessible. The entire deployment is self-contained within the Kubernetes cluster, with secure, internal communication between the components.

Part 5: Weaving the Fabric: Integrating the Platform Components

Deploying the individual components is only the first step. The true power of this platform emerges from how these services are integrated to create automated, end-to-end pipelines. This section details the specific mechanisms and configurations required to connect Airflow, Spark, Flink, Kafka, MLflow, and MinIO into a cohesive whole.

Component Integration Matrix

The following table provides a high-level overview of the primary integration points between the platform components, serving as a quick reference for the key interaction patterns discussed in this section.

From Component
To Component
Integration Method
Key Configuration / Code Snippet
Airflow
Spark
SparkKubernetesOperator
application_file: 'path/to/spark-app.yaml', namespace: 'processing-jobs' 35
Spark
Kafka
spark-sql-kafka-0-10 library
spark.readStream.format("kafka").option("kafka.bootstrap.servers", "...") 36
Flink
Kafka
flink-connector-kafka library
KafkaSource.builder().setBootstrapServers(...) 37
Spark
MLflow
mlflow.spark client library
mlflow.set_tracking_uri("http://mlflow-service..."), mlflow.spark.autolog() 38
MLflow
MinIO
S3-compatible artifact store backend
artifactRoot: "s3://mlflow-artifacts", MLFLOW_S3_ENDPOINT_URL in MLflow server config 8
Flink
MinIO
Checkpointing & HA state backend
state.checkpoints.dir: "s3a://flink-checkpoints/...", high-availability.storageDir: "s3a://..." 30
Spark
MinIO
Direct data access & checkpointing
spark.read.parquet("s3a://data-lake-raw/..."), checkpointLocation: "s3a://..."


Airflow as the Conductor: Orchestrating Spark Jobs

In this architecture, Apache Airflow acts as the master orchestrator for batch-oriented MLOps pipelines. The primary mechanism for launching Spark jobs from an Airflow DAG is the SparkKubernetesOperator, which is part of the official CNCF Kubernetes provider package for Airflow.35
A common misconception is that this operator runs spark-submit from within an Airflow worker. Instead, it operates in a more cloud-native, declarative fashion. The operator's main function is to create a SparkApplication custom resource in the target Kubernetes namespace (in our case, processing-jobs). The Spark Operator, which is watching that namespace, then detects this new CR and takes over the responsibility of actually submitting and managing the Spark job.12
This approach creates a powerful separation of concerns. The Airflow DAG defines the what and when of the job execution, while the SparkApplication manifest defines the how (the specific container image, resource allocation, and Spark configuration). This allows platform engineers to manage standardized SparkApplication templates, while data scientists and engineers can simply invoke them from their DAGs.
The following example Airflow DAG demonstrates how to use the SparkKubernetesOperator to launch a model training job. The SparkApplication manifest is embedded directly in the DAG for clarity, but it could also be loaded from a separate, version-controlled YAML file.

Python


# dags/ml_training_pipeline.py
from __future__ import annotations

import pendulum

from airflow.models.dag import DAG
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator

# The internal service URL for the MLflow tracking server
MLFLOW_TRACKING_URI = "http://mlflow-service.ml-lifecycle.svc.cluster.local:5000"

with DAG(
    dag_id="ml_training_pipeline",
    start_date=pendulum.datetime(2023, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    tags=["mlops", "spark"],
) as dag:
    submit_spark_training_job = SparkKubernetesOperator(
        task_id="submit_spark_ml_job",
        namespace="processing-jobs",
        # The SparkApplication manifest can be defined as a multi-line string.
        application_file="""
apiVersion: "spark.apache.org/v1beta2"
kind: SparkApplication
metadata:
  name: "training-job-{{ ds_nodash }}"
  namespace: "processing-jobs"
spec:
  type: Python
  pythonVersion: "3"
  mode: cluster
  image: "my-registry/my-spark-ml-app:latest"
  mainApplicationFile: "local:///app/src/jobs/spark/training.py"
  sparkVersion: "3.3.0"
  restartPolicy:
    type: Never
  # Pass the MLflow tracking URI to the Spark job via spark-conf.
  # The Spark job's code will use this to connect to the MLflow server.
  sparkConf:
    "spark.mlflow.trackingUri": '""" + MLFLOW_TRACKING_URI + """'
    # Configure S3A connector to work with MinIO
    "spark.hadoop.fs.s3a.endpoint": "http://minio-tenant.data-plane.svc.cluster.local:9000"
    "spark.hadoop.fs.s3a.access.key": "your-minio-access-key" # Best practice: use a K8s secret
    "spark.hadoop.fs.s3a.secret.key": "your-minio-secret-key" # Best practice: use a K8s secret
    "spark.hadoop.fs.s3a.path.style.access": "true"
    "spark.hadoop.fs.s3a.connection.ssl.enabled": "false"
  driver:
    cores: 1
    memory: "1024m"
    serviceAccount: spark-job-runner
  executor:
    instances: 3
    cores: 1
    memory: "2048m"
""",
        kubernetes_conn_id="kubernetes_default",
        # The operator will wait for the SparkApplication to complete.
        do_xcom_push=True,
    )



This declarative definition within the DAG is a powerful pattern. It makes the workflow self-contained and version-controllable, while cleanly separating the orchestration logic from the execution details of the Spark application itself.

Connecting Compute to Messaging: Spark/Flink and Kafka

Both Spark and Flink jobs running in the processing-jobs namespace need to connect to the Kafka cluster in the data-plane namespace. The key to this integration is stable service discovery. As established, the Strimzi Operator provides a crucial abstraction here by creating a headless bootstrap service. The fully qualified domain name (FQDN) of this service is predictable and stable: <kafka-cluster-name>-kafka-bootstrap.<namespace>.svc.cluster.local. For our architecture, this resolves to mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092.
This stable endpoint is all that the client applications need. They do not need to be aware of the individual broker pod IPs, which can change during upgrades or failures.
Example: Flink Job Consuming from Kafka
A Flink job uses the flink-connector-kafka library. The bootstrap server address is provided when building the KafkaSource.

Java


// Inside a Flink Job
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;

String kafkaBootstrapServers = "mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092";
String inputTopic = "raw-sensor-data";

KafkaSource<String> source = KafkaSource.<String>builder()
   .setBootstrapServers(kafkaBootstrapServers)
   .setTopics(inputTopic)
   .setGroupId("flink-sensor-processor-group")
   .setStartingOffsets(OffsetsInitializer.latest())
   .setValueOnlyDeserializer(new SimpleStringSchema())
   .build();

DataStream<String> stream = env.fromSource(source, WatermarkStrategy.noWatermarks(), "Kafka Source");


37
Example: Spark Structured Streaming Job Consuming from Kafka
A Spark Structured Streaming job uses the spark-sql-kafka-0-10 library. The configuration is passed via .option() calls when defining the read stream. The job also needs to be configured with the S3A connector settings to use MinIO for checkpointing, which is essential for stream processing fault tolerance.

Python


# Inside a PySpark Structured Streaming job
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("KafkaToMinIO").getOrCreate()

kafka_bootstrap_servers = "mlops-kafka-cluster-kafka-bootstrap.data-plane.svc.cluster.local:9092"
input_topic = "raw-data-topic"
# Checkpointing to MinIO is crucial for fault-tolerant streaming
checkpoint_location = "s3a://spark-checkpoints/my-stream-processor"

# Read from Kafka
df = spark.readStream \
   .format("kafka") \
   .option("kafka.bootstrap.servers", kafka_bootstrap_servers) \
   .option("subscribe", input_topic) \
   .option("startingOffsets", "latest") \
   .load()

#... processing logic...
processed_df = df.selectExpr("CAST(value AS STRING) as json_payload")

# Write to a sink (e.g., Parquet files in MinIO)
query = processed_df.writeStream \
   .format("parquet") \
   .option("path", "s3a://data-lake-processed/my-output/") \
   .option("checkpointLocation", checkpoint_location) \
   .start()

query.awaitTermination()


36

Closing the Loop: Spark, MLflow, and MinIO Integration

The final and most critical integration is connecting the model training process (Spark) with the experiment tracking and storage systems (MLflow and MinIO). This creates a fully auditable and reproducible machine learning lifecycle.
The interaction follows a specific, indirect pattern that enhances security and modularity:
Spark to MLflow: The Spark job, running in a pod in the processing-jobs namespace, communicates directly with the MLflow Tracking Server's service in the ml-lifecycle namespace. The address of this server is passed to the Spark job, typically via a sparkConf setting in the SparkApplication manifest, as shown in the Airflow DAG example.
MLflow to MinIO: The MLflow Tracking Server is the only component that communicates directly with MinIO for the purpose of storing artifacts. It was configured during its deployment (in Part 4) with the MinIO endpoint URL and credentials.
This architecture means the Spark job itself does not need MinIO credentials. It only needs to know the address of the MLflow server. The MLflow server acts as a secure gateway or proxy to the artifact store. When a data scientist calls mlflow.spark.log_model in their Spark code, the MLflow client library within the Spark driver sends the model artifacts to the MLflow Tracking Server via an HTTP request. The server then uses its own S3 client and pre-configured credentials to write those artifacts to the correct bucket and path in MinIO.40
This decoupling is a significant architectural advantage. It centralizes the responsibility and credentials for artifact storage within the MLflow service, simplifying the configuration of every Spark job on the platform and reducing the attack surface by not distributing storage credentials to transient job pods.
Example: Spark ML Training Code with MLflow Autologging
The code within the Spark training job (training.py) becomes remarkably simple, thanks to MLflow's autologging capabilities.

Python


# src/jobs/spark/training.py
from pyspark.sql import SparkSession
from pyspark.ml.classification import LogisticRegression
from pyspark.ml.feature import VectorAssembler
import mlflow
import mlflow.spark

def train_model():
    spark = SparkSession.builder.appName("MLflowSparkTraining").getOrCreate()

    # The MLflow Tracking URI is automatically picked up from the
    # spark.mlflow.trackingUri conf set by the Airflow operator.

    # Enable MLflow's automatic logging for Spark MLlib models.
    # This will log parameters, metrics, and the model itself.
    mlflow.spark.autolog(log_models=True, registered_model_name="MyProductionModel")

    # Load data from the data lake in MinIO
    training_df = spark.read.parquet("s3a://data-lake-processed/training_features/")

    #... feature assembly and model definition...
    assembler = VectorAssembler(inputCols=["feature1", "feature2"], outputCol="features")
    lr = LogisticRegression(featuresCol="features", labelCol="label")
    
    with mlflow.start_run() as run:
        # The model, its parameters (regParam, maxIter, etc.), and training
        # metrics will be automatically logged to MLflow when.fit() is called.
        pipeline = Pipeline(stages=[assembler, lr])
        model = pipeline.fit(training_df)

        # The model artifact is sent to the MLflow server, which then saves it to MinIO.
        # The model is also registered under "MyProductionModel" in the Model Registry.

    spark.stop()

if __name__ == "__main__":
    train_model()


38
When this code executes, MLflow's autologging feature automatically captures the fitted pipeline model, serializes it, and sends it to the MLflow server. The server, using its configured artifactRoot and S3 credentials, writes the model to s3://mlflow-artifacts/<experiment_id>/<run_id>/artifacts/spark-model. This seamless, transparent integration is the cornerstone of an efficient and scalable MLOps workflow.

Part 6: A Scalable MLOps Project Repository Structure

A well-defined project structure is essential for managing the complexity of an integrated MLOps platform. It promotes consistency, reproducibility, and collaboration between different teams (Data Engineering, Data Science, Platform/Ops). Adopting a GitOps methodology, where a Git repository serves as the single source of truth for both infrastructure and application code, is a modern best practice.

Guiding Principles: GitOps and Infrastructure as Code (IaC)

The entire platform configuration and application code should be managed declaratively in a version control system, preferably Git. This approach, known as GitOps, has several key benefits:
Single Source of Truth: The Git repository contains the desired state of the entire system. Any changes to infrastructure or applications are reflected as commits in the repository.
Auditability and Traceability: Every change is a Git commit, providing a clear, auditable history of who changed what, when, and why.
Automated and Repeatable Deployments: CI/CD pipelines can be triggered by Git events (e.g., a pull request merge) to automatically test and apply changes to the Kubernetes cluster, ensuring deployments are consistent and repeatable across environments.41
Collaboration: Pull requests become the mechanism for proposing and reviewing changes, fostering collaboration between platform engineers, data engineers, and data scientists.42

Recommended Mono-Repo Structure

For a tightly integrated platform like this, a mono-repo approach is often advantageous. It simplifies dependency management and ensures that changes to infrastructure (e.g., a new Kafka topic) and the application code that uses it can be coordinated within a single pull request.
The following directory structure provides a logical and scalable organization for the MLOps platform, separating infrastructure configuration from application source code.



mlops-platform/
├──.github/workflows/         # CI/CD pipelines (e.g., for GitHub Actions)
│   ├── validate.yaml          # Runs on PRs: linting, unit tests, static analysis
│   └── deploy.yaml            # Runs on merge to main: deploys infrastructure and jobs
│
├── infrastructure/            # Infrastructure as Code (IaC) definitions
│   ├── helm-values/           # Centralized Helm values override files for each component
│   │   ├── airflow.yaml
│   │   ├── mlflow.yaml
│   │   └── operators.yaml     # Combined values for Strimzi, MinIO, Spark/Flink operators
│   └── manifests/             # Raw Kubernetes manifests for declarative management
│       ├── platform-setup/    # Initial setup: Namespaces, RBAC, Secret definitions (as templates)
│       ├── kafka/
│       │   └── mlops-kafka-cluster.yaml # The Kafka CRD manifest
│       ├── spark-applications/
│       │   └── training-app-template.yaml # Reusable SparkApplication templates
│       └── flink-deployments/
│           └── streaming-job-template.yaml # Reusable FlinkDeployment templates
│
├── src/                       # Application source code
│   ├── jobs/
│   │   ├── spark/             # PySpark job source files
│   │   │   └── training.py
│   │   └── flink/             # Flink (Java/Scala) job source files
│   │       └── StreamProcessor.java
│   └── ml/                    # Shared Python libraries (e.g., for feature engineering, model utils)
│       └── features.py
│
├── dags/                      # Airflow DAG definitions
│   └── ml_training_pipeline.py # This directory is synced to Airflow via git-sync
│
├── notebooks/                 # Jupyter notebooks for exploration and analysis (not for production)
│   └── exploratory_analysis.ipynb
│
├── docker/                    # Dockerfiles for building custom application images
│   ├── spark/Dockerfile       # Dockerfile to build the image for Spark jobs
│   └── flink/Dockerfile       # Dockerfile to build the image for Flink jobs
│
├── scripts/                   # Helper scripts for local development and management
│   └── deploy-local.sh
│
├── requirements.txt           # Top-level Python requirements for setting up a local venv
└── README.md                  # Project documentation


42

Workflow Explained

This structure enables a clear and efficient workflow for different roles:
Data Scientist (Exploration & Development):
Works in the notebooks/ directory for initial data exploration and model prototyping.
Once a viable approach is found, the logic is refactored into production-quality Python or Scala code within the src/ directory (e.g., src/jobs/spark/training.py).
A custom Docker image containing this code and its dependencies is defined in docker/spark/Dockerfile.
Data Engineer (Pipeline & Orchestration):
Creates or modifies an Airflow DAG in the dags/ directory to orchestrate the new Spark job.
The DAG's SparkKubernetesOperator task references a SparkApplication manifest, which can be defined inline or point to a standardized template in infrastructure/manifests/spark-applications/.
This DAG is automatically deployed to Airflow when the changes are merged into the main branch, thanks to git-sync.
Platform Engineer (Infrastructure Management):
Manages the core platform configuration in the infrastructure/ directory.
To upgrade a component, they would update the chart version and any necessary values in the corresponding infrastructure/helm-values/ file.
To provision a new Kafka topic, they would add a KafkaTopic CRD manifest to the infrastructure/manifests/kafka/ directory.
CI/CD Automation (The Glue):
When a developer opens a pull request, the validate.yaml workflow in .github/workflows/ is triggered. This pipeline can run static code analysis, Python unit tests (pytest on the src/ directory), and linting for YAML files and Dockerfiles.
Upon merging the pull request to the main branch, the deploy.yaml workflow is triggered. This pipeline executes the deployment logic:
It runs helm upgrade --install for each core component, using the -f flag to apply the corresponding configuration from infrastructure/helm-values/.
It runs kubectl apply -k or kubectl apply -f on the infrastructure/manifests/ directory to apply any changes to the declarative CRs (like the Kafka cluster definition or Flink deployments).
It can also include steps to build and push the new Docker images defined in the docker/ directory to a container registry.
This GitOps-driven, mono-repo structure provides a robust, transparent, and scalable framework for managing the entire MLOps platform as a single, cohesive system.

Conclusion and Future Considerations


Summary of Architecture

This report has detailed a comprehensive, production-grade architecture for an MLOps and Big Data platform on Kubernetes. The core architectural tenets are centered on cloud-native principles to ensure scalability, resilience, and maintainability. The key decisions that underpin this architecture are:
Operator-Led Management: For complex stateful services—Kafka, Flink, and MinIO—the Kubernetes Operator pattern is not just a preference but a necessity. By using operators like Strimzi and the official MinIO Operator, we delegate complex Day-2 operational tasks to automated, domain-specific controllers, ensuring robust lifecycle management that is unattainable with basic Helm charts alone.
Declarative Application Management: Spark and Flink jobs are managed declaratively through their respective SparkApplication and FlinkDeployment Custom Resources. This approach, orchestrated by Airflow, separates the "what" from the "how," allowing for cleaner, more maintainable workflows.
Centralized and Secure Backends: MLflow is configured with a PostgreSQL backend for metadata and Model Registry functionality, while all large artifacts (models, data, checkpoints) are stored in a distributed MinIO cluster. This separation of metadata and artifact storage is a critical design pattern for performance and scalability.
GitOps as the Foundation: The entire platform, from infrastructure configuration in Helm values and manifests to application code and DAGs, is managed in a single Git repository. This provides a version-controlled, auditable, and automated source of truth for the entire system.
By weaving these components together—using Airflow to orchestrate Spark jobs, which in turn use Kafka for data streams, MinIO for storage, and MLflow for lifecycle tracking—we create a powerful, integrated platform capable of supporting the most demanding MLOps and data engineering use cases.

Operating the Platform

Deploying the platform is the first step. For true production readiness, ongoing operational excellence is required. The following areas represent the immediate next steps for hardening and managing the platform:
Monitoring and Observability: A robust monitoring solution is non-negotiable. Most of the chosen Helm charts and operators expose metrics in a Prometheus-compatible format.5 The next step is to deploy a Prometheus Operator and Grafana stack to scrape these metrics and build comprehensive dashboards. Key metrics to monitor include Kafka broker health (under-replicated partitions, leader counts), Flink job checkpointing latency, Spark executor resource utilization, and MLflow server API latency.
Centralized Logging: To effectively debug issues across this distributed system, logs from all components must be centralized. Deploying a logging stack such as the EFK (Elasticsearch, Fluentd, Kibana) stack or the PLG (Promtail, Loki, Grafana) stack is essential. Fluentd or Promtail would be deployed as a DaemonSet on each Kubernetes node to collect container logs and forward them to a central storage and query engine.
Advanced Security: The current architecture establishes a solid security baseline with namespaces and secrets management. Further hardening should include:
Fine-Grained RBAC: Creating specific Roles and RoleBindings for each application's ServiceAccount to grant the absolute minimum required permissions (e.g., the Spark job runner service account should only be able to create and delete pods in the processing-jobs namespace).
Network Policies: Implementing strict NetworkPolicy resources to control traffic flow between namespaces, ensuring, for example, that only pods from the processing-jobs and orchestration namespaces can connect to the Kafka brokers.
Image Scanning: Integrating a container image scanner (like Trivy or Clair) into the CI/CD pipeline to detect known vulnerabilities in all custom and third-party Docker images before they are deployed.

Final Thoughts

The architecture detailed in this report represents a significant investment in building a durable, scalable, and automated platform. While the initial setup is complex, the long-term benefits are substantial. By embracing Kubernetes-native patterns like operators and GitOps, organizations can move away from brittle, manually managed systems and toward a truly agile MLOps environment. This platform empowers data teams to rapidly iterate, experiment, and deploy machine learning models into production with confidence, providing a powerful competitive advantage in a data-driven world.
Works cited
Kubernetes Operator Vs. Helm: What's the Difference? - Cloud Native Now, accessed July 8, 2025, https://cloudnativenow.com/topics/cloudnativedevelopment/kubernetes-operator-vs-helm-whats-the-difference/
Difference between Kafka operator vs kafka helm chart - Stack Overflow, accessed July 8, 2025, https://stackoverflow.com/questions/75695295/difference-between-kafka-operator-vs-kafka-helm-chart
Kubernetes Operators vs HELM: Package Management Comparison ..., accessed July 8, 2025, https://konghq.com/blog/learning-center/kubernetes-operators-vs-helm
Strimzi operator, bitnami's helm chart - whats your opinion? : r/apachekafka - Reddit, accessed July 8, 2025, https://www.reddit.com/r/apachekafka/comments/1h76q2h/strimzi_operator_bitnamis_helm_chart_whats_your/
Strimzi Kafka vs. Bitnami Kafka: A Deep Dive for Kubernetes Deployments - AutoMQ, accessed July 8, 2025, https://www.automq.com/blog/strimzi-vs-bitnami-kafka-kubernetes-comparison
Automatic Logging with MLflow Tracking, accessed July 8, 2025, https://mlflow.org/docs/latest/tracking/autolog/
Backend Stores - MLflow, accessed July 8, 2025, https://mlflow.org/docs/latest/ml/tracking/backend-stores/
Artifact Stores | MLflow, accessed July 8, 2025, https://mlflow.org/docs/latest/ml/tracking/artifact-stores/
Getting Started - Helm, accessed July 8, 2025, https://helm.sh/docs/chart_template_guide/getting_started/
strimzi-kafka-operator 0.46.1 - Artifact Hub, accessed July 8, 2025, https://artifacthub.io/packages/helm/strimzi/strimzi-kafka-operator
Deploying Apache Airflow on Kubernetes with Helm and Minikube, Syncing DAGs from GitHub | by Jdegbun | Medium, accessed July 8, 2025, https://medium.com/@jdegbun/deploying-apache-airflow-on-kubernetes-with-helm-and-minikube-syncing-dags-from-github-bce4730d7881
Best of 2023: Using Airflow to Run Spark on Kubernetes - Cloud Native Now, accessed July 8, 2025, https://cloudnativenow.com/features/using-airflow-to-run-spark-on-kubernetes/
Secrets in Helm: Best Practices and a Comprehensive Guide - Cycode, accessed July 8, 2025, https://cycode.com/blog/helm-secret-scanning/
Secrets | Kubernetes, accessed July 8, 2025, https://kubernetes.io/docs/concepts/configuration/secret/
austince/minio-official - Helm chart - Artifact Hub, accessed July 8, 2025, https://artifacthub.io/packages/helm/minio-official/minio
ome/minio-helm-chart - GitHub, accessed July 8, 2025, https://github.com/ome/minio-helm-chart
MLflow Chart Usage Guide - Community Charts, accessed July 8, 2025, https://community-charts.github.io/docs/charts/mlflow/usage
Kubernetes Secrets Management: Limitations & Best Practices - groundcover, accessed July 8, 2025, https://www.groundcover.com/blog/kubernetes-secret-management
Kafka - Bitnami - Artifact Hub, accessed July 8, 2025, https://artifacthub.io/packages/helm/bitnami/kafka
Core Operational Concepts — MinIO Object Storage for Linux, accessed July 8, 2025, https://min.io/docs/minio/linux/operations/concepts.html
Deployment Architecture — MinIO Object Storage for Linux, accessed July 8, 2025, https://min.io/docs/minio/linux/operations/concepts/architecture.html
Deploy a MinIO Tenant with Helm Charts, accessed July 8, 2025, https://min.io/docs/minio/kubernetes/openshift/operations/install-deploy-manage/deploy-minio-tenant-helm.html
Minio - IBM, accessed July 8, 2025, https://www.ibm.com/docs/SSBS6K_3.2.0/manage_cluster/minio.html
Apache Spark Kubernetes Operator - GitHub, accessed July 8, 2025, https://github.com/apache/spark-kubernetes-operator
spark-kubernetes-operator 1.1.0 - Artifact Hub, accessed July 8, 2025, https://artifacthub.io/packages/helm/spark-kubernetes-operator/spark-kubernetes-operator
Getting started with Spark Operator - Kubeflow, accessed July 8, 2025, https://www.kubeflow.org/docs/components/spark-operator/getting-started/
User Guide | spark-operator - GitHub Pages, accessed July 8, 2025, https://kubeflow.github.io/spark-operator/docs/user-guide.html
Apache Flink Kubernetes Operator 1.12.0 Release Announcement ..., accessed July 8, 2025, https://flink.apache.org/2025/06/03/apache-flink-kubernetes-operator-1.12.0-release-announcement/
Get Running with Apache Flink on Kubernetes, part 1 of 2 - Decodable, accessed July 8, 2025, https://www.decodable.co/blog/get-running-with-apache-flink-on-kubernetes-1
Kubernetes Deployment - My Flink Studies, accessed July 8, 2025, https://jbcodeforce.github.io/flink-studies/coding/k8s-deploy/
Apache Airflow - Helm chart - Artifact Hub, accessed July 8, 2025, https://artifacthub.io/packages/helm/apache-airflow/airflow
Helm Chart for Apache Airflow — helm-chart Documentation, accessed July 8, 2025, https://airflow.apache.org/docs/helm-chart/stable/index.html
mlflow - Community Helm Charts - Artifact Hub, accessed July 8, 2025, https://artifacthub.io/packages/helm/community-charts/mlflow
Introduction to MLflow for MLOps Part 3: Database Tracking, Minio Artifact Storage, and Registry | by Tyler Chase | Noodling on The Future of AI | Medium, accessed July 8, 2025, https://medium.com/noodle-labs-the-future-of-ai/introduction-to-mlflow-for-mlops-part-3-database-tracking-minio-artifact-storage-and-registry-9fef196aaf42
airflow.providers.cncf.kubernetes.operators.spark_kubernetes, accessed July 8, 2025, https://airflow.apache.org/docs/apache-airflow-providers-cncf-kubernetes/stable/_api/airflow/providers/cncf/kubernetes/operators/spark_kubernetes/index.html
Structured Streaming + Kafka Integration Guide (Kafka broker ..., accessed July 8, 2025, https://spark.apache.org/docs/latest/structured-streaming-kafka-integration.html
kafka-flink-kubernetes-example/pom.xml at master - GitHub, accessed July 8, 2025, https://github.com/patrickneubauer/kafka-flink-kubernetes-example/blob/master/pom.xml
mlflow.spark, accessed July 8, 2025, https://mlflow.org/docs/latest/api_reference/python_api/mlflow.spark.html
apache-airflow-providers-cncf-kubernetes 10.6.1 - PyPI, accessed July 8, 2025, https://pypi.org/project/apache-airflow-providers-cncf-kubernetes/
MLflow Tracking, accessed July 8, 2025, https://www.mlflow.org/docs/1.21.0/tracking.html
sidhyaashu/MLOps-End-To-End-Project: Foundation of MLOps - GitHub, accessed July 8, 2025, https://github.com/sidhyaashu/MLOps-End-To-End-Project
Master Machine Learning Pipeline Development | MlOps Project-1 | Project Structure Setup | Part-3 | by Krishan Walia | DevOps.dev, accessed July 8, 2025, https://blog.devops.dev/master-machine-learning-pipeline-development-mlops-project-1-project-structure-setup-part-3-618ad96560fa
Deploy Operator With Helm — MinIO Object Storage for Kubernetes, accessed July 8, 2025, https://min.io/docs/minio/kubernetes/upstream/operations/install-deploy-manage/deploy-operator-helm.html
Tenant Helm Charts — MinIO Object Storage for Kubernetes, accessed July 8, 2025, https://min.io/docs/minio/kubernetes/upstream/reference/tenant-chart-values.html
Apache Spark™ K8s Operator | spark-kubernetes-operator - GitHub Pages, accessed July 8, 2025, https://apache.github.io/spark-kubernetes-operator/
Apache Flink Kubernetes Operator 1.11.0 Release Announcement, accessed July 8, 2025, https://flink.apache.org/2025/03/03/apache-flink-kubernetes-operator-1.11.0-release-announcement/
Parameters reference — helm-chart Documentation - Apache Airflow, accessed July 8, 2025, https://airflow.apache.org/docs/helm-chart/stable/parameters-ref.html
airflow/chart/values.yaml at main - GitHub, accessed July 8, 2025, https://github.com/apache/airflow/blob/main/chart/values.yaml
Apache Flink — Kafka Consumer & Producer — Example | by MUNIANDI BASKARAN, accessed July 8, 2025, https://medium.com/@muniandibaskaran/apache-flink-kafka-consumer-producer-example-0e657d8a3471
Spark Structured Streaming With Kafka and MinIO, accessed July 8, 2025, https://blog.min.io/spark-structured-streaming-with-kafka-and-minio/
mlflow.org, accessed July 8, 2025, https://mlflow.org/docs/latest/ml/traditional-ml/sparkml/#:~:text=The%20integration%20of%20MLflow%20with,feature%20engineering%20to%20final%20model
MLflow PySpark ML autologging, accessed July 8, 2025, https://mlflow.org/docs/latest/api_reference/python_api/mlflow.pyspark.ml.html
Building a Simple and Professional MLOps Project Structure: A Hands-On Project | by Amarachi Crystal Omereife - Medium, accessed July 8, 2025, https://medium.com/@marameref/building-a-simple-and-professional-mlops-project-structure-a-hands-on-project-5facd53c9268
Structuring Your Machine Learning Project with MLOps in Mind | Towards Data Science, accessed July 8, 2025, https://towardsdatascience.com/structuring-your-machine-learning-project-with-mlops-in-mind-41a8d65987c9/
Tools and Project Structure - MLOps Guide, accessed July 8, 2025, https://mlops-guide.github.io/Structure/project_structure/
Chim-SO/mlops-template - GitHub, accessed July 8, 2025, https://github.com/Chim-SO/mlops-template
