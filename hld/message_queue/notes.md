https://www.youtube.com/watch?v=ZwwYgiT9GH0&list=PLrtCHHeadkHp92TyPt1Fj452_VGLipJnL&index=11

Based on the source provided, here are detailed notes on designing a **scalable, topic-based distributed message queue**.

### **1. Requirements and Capacity Estimation**
*   **Functional Requirements:** The system must allow producers to insert entries (produce) and consumers to remove entries (consume).
*   **Non-Functional Requirements:**
    *   **Scalability:** Must handle high data volumes, such as 10 million messages and 10,000 topics per day.
    *   **Latency vs. Throughput:** The goal is near real-time delivery, with a target latency of 2 to 5 minutes.
    *   **Durability/Retention:** Messages should be retained for a set period (e.g., 30 days).
    *   **Availability:** The system must be fault-tolerant and handle traffic surges like "Black Friday" events.
*   **Storage Estimation:** With 10 million messages a day at 100 bytes each, a 30-day retention period requires approximately **300 terabytes** of storage.

### **2. Queue Models**
The source outlines three primary messaging patterns:
*   **Topic-Based:** (Selected for this design) Consumers subscribe to specific topics (e.g., "order placed"), and producers send messages to those specific topics.
*   **Fan-Out (Broadcasting):** Messages are broadcast to all queues listening to the system.
*   **Direct:** A specific key-to-queue mapping, often used for routing messages to a specific user or driver.

### **3. High-Level Architecture**
*   **Pull Model:** The design uses a **pull model** where consumers pull messages from the queue at their own rate. This provides better scalability than a push model, as it prevents consumers from being overwhelmed by traffic surges.
*   **Scalability through Batching:** To reduce network calls, both producers and consumers should use batching (e.g., pulling 50 messages at a time or using OS-level batching).
*   **Horizontal Scaling:** Scalability is achieved by adding more servers to handle increased production or consumption loads.

### **4. Storage Layer Design**
*   **Append-Only Log (Write-Ahead Log):** Instead of standard SQL or NoSQL databases, the system uses an **append-only log** for message storage. This is highly efficient because sequential disk writes are very fast, especially when using RAID configurations.
*   **Segmentation:** To prevent files from becoming too large, logs are split into smaller segments (e.g., 10 KB or based on size).
*   **Partitioning (Sharding):** Topics are partitioned across multiple servers using **consistent hashing** (often based on a key like Buyer ID) to ensure the system scales horizontally.
*   **Message Structure:** Each message contains a topic, a key (for sharding), a JSON payload, a timestamp, and a checksum (CRC) for data integrity.

### **5. Coordination and Metadata**
The system requires a coordination service (like **Zookeeper**) to manage three types of information:
*   **Metadata Storage:** Stores topic configurations, retention periods, and replication factors.
*   **State Storage:** Tracks the **consumer offset**, which is the exact point in the log where a specific consumer last read.
*   **Leader/Follower Coordination:** Manages heartbeats between servers and handles leader election if a server goes down.

### **6. Fault Tolerance and Replication**
*   **Leader-Follower Approach:** Producers write to a **leader** broker, which then replicates the data to **followers** (in-sync replicas).
*   **Acknowledgments:** Reliability can be tuned by requiring the leader to receive an acknowledgment from all replicas before confirming to the producer that the message was successfully written.
*   **Cleanup:** A background job is used to delete segments once they exceed the 30-day retention period.


