https://www.youtube.com/watch?v=cqs5t7zqzCk&list=PLPtUyMfD0mNJDZg50fg2CptjLBavHot47&index=17


A distributed logging system is a crucial online platform designed to **collect, process, and store logs from various microservices** in a centralized location, such as Splunk or Logstash. These systems allow developers and application support engineers to identify and troubleshoot issues across a distributed architecture in near real-time.

### 1. Core Requirements

#### Functional Requirements
*   **Multi-source Ingestion:** The system must be capable of ingesting logs from microservices deployed anywhere globally.
*   **Near Real-Time and Batch Support:** It must support **near real-time ingestion** for active services and **batch/offline ingestion** for applications that store logs locally and upload them once an internet connection is established.
*   **Validation and Normalization:** Before storage, the system should validate logs (to prevent malicious content), parse them, and **normalize them into a standard format** to ensure meaningful rendering in the UI.
*   **Searchable Dashboard:** A user interface must be provided to allow developers to search and filter logs based on specific criteria.

#### Non-Functional Requirements
*   **Scalability:** The system must handle massive scale, targeting **millions of events (log requests) per hour**.
*   **Low Latency:** To support near real-time troubleshooting, the time between a log being generated and appearing in the dashboard must be minimal.
*   **Availability over Consistency:** In line with the CAP theorem, the system prioritizes **availability**, ensuring it is always ready to ingest logs, even if it means sacrificing immediate consistency.
*   **Reliability and Retention:** There should be no data loss during ingestion. However, logs are not stored forever; a **Time-to-Live (TTL)** or retention period (e.g., 30–45 days) is defined to manage storage costs.

### 2. High-Level Architecture and Flow

The process of moving a log from a code statement to the logging platform involves several steps:
1.  **Application Side:** A microservice uses a library (like Log4j) to write logs to standard IO streams (**std out/err**).
2.  **Environment Capture:** In a Kubernetes environment, these logs are captured and stored in a **container log file** on the node (e.g., `raw.logs`).
3.  **Agent Ingestion:** A specialized agent (e.g., **Fluent Bit**) monitors these files and transmits the logs to the distributed logging system's backend.
4.  **Gateway:** Traffic passes through a **Load Balancer and API Gateway** for authentication, authorization, rate limiting, and routing.

### 3. Deep Dive System Components

#### Client Onboarding Service
*   **Organization-Level Registration:** Instead of registering every individual microservice, an entire organization registers once to receive a **Client ID and Token**.
*   **Data Storage:** Metadata (ID, Token, TTL, Environment) is stored in a relational database like **PostgreSQL** because the schema is flat and straightforward.

#### Ingestion Layer
*   **Decoupled Services:** The ingestion service is divided into a **File Ingestion Service** (for offline batch uploads) and an **Agent-Based Service** (for real-time streams).
*   **Kafka as a Buffer:** To handle millions of requests per minute without crashing the database, **Kafka** acts as a streaming buffer.
*   **Apache Flink (Processor):** Flink is used as a versatile streaming processor to handle **sanitization, validation, normalization, enrichment, and deduplication** before the logs reach the final databases.

#### Tiered Storage Strategy
To balance cost and performance, the system uses a tiered approach:
1.  **Hot Storage (Elastic Search):** Stores the most recent **14 days of data** to facilitate low-latency, text-based searches.
2.  **Warm Storage (Cassandra):** A **write-heavy, right-optimized** NoSQL database that stores data for up to **45 days**.
3.  **Cold Storage (S3/Blob Storage):** A cheap storage option where all data is persisted long-term for recovery or future business needs.

#### Dashboard and Search Service
*   **Search Logic:** For logs within 14 days, the system queries **Elastic Search**. For older logs, it queries **Cassandra**, which may result in higher latency.
*   **Real-Time Tailing:** The UI can show logs in near real-time using **WebSockets** for a full-duplex connection, or by repeatedly triggering a standard GET request every few seconds.
*   **Retention Management:** A **Cron Job** runs daily to perform a "soft delete" of logs older than 45 days from Cassandra, as they are already backed up in cold storage.

### 4. Alerting Extension
An optional but critical feature is the **Alerting Service**:
*   **Alert Topics:** Apache Flink identifies specific error patterns and pushes them to an "Alert Topic" in Kafka.
*   **Notification:** An **Alert Service** consumes these events and triggers notifications (Email, SMS, Pager) via a **Notification Service**.
*   **Rule Engine:** The system checks an **Alert DB** (containing client-defined rules and preferences) to determine if an error log meets the threshold for a notification.