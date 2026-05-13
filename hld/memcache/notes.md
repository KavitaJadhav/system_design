https://www.youtube.com/watch?v=6fOoXT1HYxk&list=PLrtCHHeadkHp92TyPt1Fj452_VGLipJnL&index=7


Based on the provided source, here are detailed notes on designing a scalable key-value store similar to Memcached:

### **1. Core Requirements**
A key-value store typically serves as a caching layer to reduce load on primary databases and improve response times for frequent queries.

*   **Functional Requirements:**
    *   **Put(key, value):** Store data associated with a specific key.
    *   **Get(key):** Retrieve data using a key.
    *   **Data Format:** For simplicity, both keys and values are often treated as text.
*   **Non-Functional Requirements:**
    *   **Availability:** The system must be highly available; if it goes down, the database may be overwhelmed by traffic.
    *   **Scalability:** The system must handle growth by distributing data across multiple services or geographical locations.
    *   **Performance:** Operations must be fast (constant time) to ensure low latency.

### **2. Single-Node Architecture**
To manage data on a single machine, a combination of data structures is used to balance speed and memory constraints.

*   **Data Structure:** A **Hash Table** is used because it provides efficient $O(1)$ time complexity for retrieving and adding data.
*   **Memory Management (Eviction Policies):** Since caching hardware is expensive and limited, not all data can be stored. When the cache is full, an eviction policy must remove old data:
    *   **LRU (Least Recently Used):** Chosen for this design. It removes the item that hasn't been accessed for the longest time.
    *   **LFU (Least Frequently Used):** Removes items with the lowest access frequency.
    *   **FIFO (First-In, First-Out):** Removes the oldest item added to the list.
*   **Implementing LRU:** This is achieved by combining a **Hash Table with a Doubly Linked List**.
    *   The hash table stores references to nodes in the doubly linked list.
    *   Newly added or accessed items move to the **head** of the list.
    *   When the cache is full, the item at the **tail** is evicted.

### **3. Scaling to Multiple Nodes**
To scale the system, data must be distributed across multiple cache servers.

*   **Deployment Strategies:**
    *   **Colocated:** Deploying the cache on the same host as the service. This simplifies maintenance and scales with the service but risks losing the cache if the host fails.
    *   **Distributed:** Deploying caches on dedicated hosts. This allows for independent scaling of hardware and higher availability, though it increases maintenance overhead.
*   **Data Partitioning (Sharding):**
    *   **Naive Approach:** Using a hash function and modulo (e.g., `hash(key) % number_of_hosts`). This is problematic because adding or removing a server changes the result for most keys, causing massive cache misses.
    *   **Consistent Hashing:** Servers and keys are mapped onto a logical circle (ring). When a server is added or removed, only a small subset of keys needs to be redistributed, minimizing the impact on the system.
    *   **Jump Hashing:** An alternative mentioned to solve potential uneven distribution and memory issues in consistent hashing.

### **4. System Components & Orchestration**
*   **Cache Client:** An independent library or module integrated into each service. It is responsible for locating the correct cache server, fetching data, and updating the database.
*   **Service Discovery:** The client needs to know the URLs of cache servers.
    *   **Static Config:** Handled via CI/CD processes (simple but less flexible).
    *   **Dynamic Registry:** Using a service like **Zookeeper** for health checks and real-time updates to the server list.

### **5. High Availability and Consistency**
*   **Read Replicas:** To ensure availability and handle high traffic, read replicas are added to the main cache server.
*   **Replication Styles:**
    *   **Asynchronous:** Fast performance, but there is a risk of stale data if the main server fails before syncing.
    *   **Synchronous:** Ensures data integrity (vital for financial systems) but introduces higher latency.

### **6. Security and Monitoring**
*   **Security:** Cache servers should be placed behind a firewall and accessed only by trusted clients.
*   **Monitoring:** It is critical to track metrics such as **cache hit/miss rates**, access frequency, and disk usage to measure and improve performance.

Consistent hashing is used both with and without ZooKeeper, depending on how the system manages server membership.
## Consistent Hashing WITH ZooKeeper
In this setup, ZooKeeper acts as the "source of truth" for which servers are active.

* Membership: Servers register as ephemeral nodes in ZooKeeper.
* Updates: When a server joins or crashes, ZooKeeper sends a watch notification to all clients.
* Ring Rebuild: Clients receive the notification and update their local hash ring immediately.
* Best for: Systems requiring high coordination and fast, consistent updates across all clients (e.g., Kafka, custom distributed caches).

------------------------------
## Consistent Hashing WITHOUT ZooKeeper
This approach is decentralized; nodes manage the hash ring through configuration or direct communication.

* Gossip Protocols: Nodes talk to each other to share their status (e.g., Apache Cassandra).
* Client-Side Logic: The client is hard-coded with a list of servers and builds the ring locally (e.g., Memcached).
* Static Config: A load balancer or sidecar manages the ring based on a fixed configuration file.
* Best for: Massive scale where a central coordinator might become a bottleneck or for simpler architectures.

------------------------------
📍 Key Takeaway: Consistent hashing is the algorithm for mapping data to nodes, while ZooKeeper is a coordination tool that helps nodes agree on which servers are currently part of that hash ring.
If you'd like to see how this works in practice:

* Java/Python code snippets for a ZooKeeper-backed hash ring
* Architectural pros and cons for your specific project
* Examples of alternative coordination tools (like Etcd or Consul)

Which area should we dive into?



