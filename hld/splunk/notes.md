https://www.youtube.com/watch?v=cqs5t7zqzCk&list=PLPtUyMfD0mNJDZg50fg2CptjLBavHot47&index=17

### **Overview of Distributed Logging System**
A **distributed logging platform** is an online system designed to collect logs from various microservices, providing a centralized interface—similar to Splunk, Logstash, or OpenObserve—to monitor and troubleshoot service logs.

---

### **System Requirements**
#### **Functional Requirements**
*   **Multi-source Ingestion:** The system must ingest logs from multiple microservices globally.
*   **Near Real-Time & Batch Support:** Logs should ideally be available for searching almost immediately after generation. However, the system must also support **offline/batch ingestion** for applications that cannot maintain a constant internet connection, syncing logs once reconnected.
*   **Validation & Normalization:** Incoming logs must be validated for malicious content, parsed, and **normalized into a standard format** to ensure meaningful rendering in the UI.
*   **Searchable Dashboard:** Users require a UI or dashboard with searching logic to find specific logs based on various criteria.

#### **Non-Functional Requirements**
*   **Scalability:** Must handle **millions of log events per hour**.
*   **Low Latency:** Data submission and retrieval must be as fast as possible to assist with immediate troubleshooting.
*   **Availability over Consistency:** In line with the CAP theorem, the system prioritizes **availability**, ensuring clients can always submit logs even if they aren't immediately consistent across all nodes.
*   **Reliability & Retention:** The system must ensure **no data loss** during ingestion. It should also implement a **Time to Live (TTL)** for log persistence (e.g., 30–45 days) rather than storing logs forever.

---

### **Core Entities & API Design**
The primary entities identified include **log events**, **ingestion jobs** (for offline scenarios), and the **agents** (sources) providing the data.

Key API endpoints facilitate these interactions:
*   **Agent Onboarding:** Endpoints to register, edit, and monitor the heartbeat of agents.
*   **Log Ingestion:** A `POST` endpoint for real-time log submission and a specific endpoint for **file-based ingestion** for legacy/offline data.
*   **Dashboarding:** Endpoints for searching logs and viewing them in real-time, potentially using **WebSockets** for a "tailing" effect or repeated HTTP polling.

---

### **High-Level Ingestion Flow**
Log data typically follows a stepwise process rather than being sent directly from a microservice to the logging backend.
1.  A library like **Log4j** writes logs to standard I/O streams (`stdout`/`stderr`).
2.  In a Kubernetes environment, these logs are captured and stored in a **container log file** on the node.
3.  An **agent (e.g., Fluent Bit)** monitors these files, reads the logs, and forwards them in near real-time to the distributed logging system's ingestion service.

---

### **Detailed System Architecture**
#### **1. Onboarding Service**
Before logs are accepted, an organization (e.g., Amazon) must register once to receive a **Client ID and Token ID**. This metadata, including environment details (Dev, QA, Prod) and Token TTL, is stored in a **relational database (PostgreSQL)**.

#### **2. Ingestion & Processing Layer**
To handle massive scale without crashing, the ingestion service is split and buffered:
*   **Kafka Broker:** Acts as a **buffer** for incoming raw logs from both real-time agents and offline file uploaders.
*   **Apache Flink:** Instead of multiple microservices, a single **Apache Flink** streaming processor is used for **validation, parsing, normalization, enrichment, and deduplication**.

#### **3. Multi-Tier Storage Strategy**
To balance cost and performance, the system uses three storage layers:
*   **Elasticsearch (Hot Storage):** Stores the most recent **14 days of data** for high-speed, text-based searching.
*   **Cassandra (Warm Storage):** A **write-optimized** NoSQL database used to persist logs for **45 days**. It is indexed by log level, trace ID, and service name to optimize searches beyond the 14-day Elasticsearch window.
*   **S3/Blob Storage (Cold Storage):** A cheap storage option where all data is persisted long-term, allowing for "soft deletes" from the primary databases while retaining the ability to recover data if needed.

#### **4. Alerting & Notification**
Apache Flink identifies critical error logs and pushes them to a dedicated **Kafka Alert Topic**. An **Alert Service** consumes these messages, checks them against a **Rule Book (Alert DB)** and user preferences (e.g., email vs. pager) in the **Client DB**, and triggers notifications through a third-party service.

