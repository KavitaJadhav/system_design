https://www.youtube.com/watch?v=lZ5QuFLCVn0&list=PLrtCHHeadkHp92TyPt1Fj452_VGLipJnL&index=4



The following detailed notes summarize the system design for a **Distributed LRU Cache**, based on the interview transcript provided.

### 1. Requirements and Core Concepts
*   **Definition:** An LRU (Least Recently Used) cache is a system for frequently accessed data that makes reads and writes faster by storing data in memory.
*   **Functional Requirements:**
    *   **Insert Data:** Users must be able to add new key-value pairs.
    *   **Retrieve Data:** Users must be able to fetch existing data efficiently.
*   **Non-Functional Requirements:**
    *   **High Availability:** The system should remain accessible even if components fail.
    *   **Scalability:** The cache must handle an increasing number of requests without degrading performance.
    *   **High Performance:** Retrieval and insertion must be as fast as possible.
    *   **Consistency:** There is an inherent trade-off between tight consistency and high availability/performance that must be managed.

### 2. Single Machine Implementation (Data Structures)
Before scaling to a distributed system, the core LRU logic is implemented using two primary data structures:
*   **Hashmap:** Used for **$O(1)$ retrieval** by storing unique keys and their corresponding values.
*   **Doubly Linked List:** Used to track the **order of access** and manage eviction.
    *   **Head:** Stores the most recently used (fresh) items.
    *   **Tail:** Stores the least recently used items, which are evicted first when the cache is full.
    *   **Advantage of Doubly Linked:** It allows for easier rearrangement and removal of nodes from any position in the list compared to a simple linked list.

**Operations Logic:**
*   **On Retrieval:** If the key exists, the item is moved to the **head** of the list to mark it as recently used. If it doesn't exist, it is a "cache miss," and data must be fetched from the actual data store.
*   **On Insertion:** If the cache is full, the item at the **tail** is evicted to make room. The new item is then inserted at the **head**.

### 3. Distributed Architecture and Scaling
To handle more data than one machine can store, the cache is distributed across multiple servers.
*   **Dedicated Cache Cluster:** The design uses a separate cluster for caching rather than "collocating" cache processes on application servers. This provides **better isolation of resources** and flexibility in choosing hardware.
*   **Sharding (Data Partitioning):** Data is distributed across different machines using **range-based sharding** (e.g., Keys A-M on Server 1, N-Z on Server 2). **Consistent hashing** is also mentioned as a more advanced strategy to improve availability.
*   **Cache Client:** A library residing on the application servers (service hosts) that knows the partitioning configuration and routes requests to the correct cache server.

### 4. Configuration and Service Discovery
A critical challenge in distributed systems is keeping the cache clients updated when servers are added or removed.
*   **Zookeeper:** Instead of manual configuration files, the system uses a configuration management service like **Zookeeper**.
*   **Automation:** Zookeeper maintains a "heartbeat" connection with cache servers. If a server fails or a new one is added, Zookeeper updates the configuration automatically, and the cache clients read this latest state.

### 5. High Availability and Consistency
*   **Read Replicas:** Each cache shard consists of a **primary node** and multiple **read replicas**.
*   **Fault Tolerance:** If a primary node goes down, Zookeeper triggers a **leader election** (often using algorithms like Raft) to promote a replica to primary.
*   **Multi-AZ Deployment:** Placing replicas in different data centers (Availability Zones) ensures the system can survive a regional failure.
*   **The Consistency Trade-off:**
    *   **Strong Consistency:** Requires waiting for all replicas to update before confirming a write, which increases latency and reduces performance.
    *   **Eventual Consistency:** Prioritizes performance by allowing replicas to be slightly out of sync with the primary, which is often the preferred trade-off for a high-performance cache.

### 6. Design Limitations
The primary limitations of this design include the **operational overhead** of maintaining a separate configuration service (Zookeeper) and the hardware costs of dedicated clusters and replicas. Additionally, the system must choose between **tight consistency and high performance**, as it is impossible to maximize both simultaneously in a distributed environment.